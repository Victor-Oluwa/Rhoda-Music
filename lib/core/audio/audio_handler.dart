import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}

class RhodaAudioHandler extends BaseAudioHandler with SeekHandler, QueueHandler {
  final AndroidEqualizer _equalizer = AndroidEqualizer();
  late final AudioPlayer _player;
  bool _isEqualizerReady = false;

  RhodaAudioHandler() {
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [_equalizer],
      ),
    );

    _init();
  }

  Future<void> _init() async {
    // 1. Configure Audio Session
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // 2. Handle Audio Interruptions
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(0.5);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });

    // 3. Handle Becoming Noisy
    session.becomingNoisyEventStream.listen((_) => pause());

    // 4. Reactive State Management
    Rx.merge([
      _player.playbackEventStream,
      _player.loopModeStream,
      _player.shuffleModeEnabledStream,
      _player.playerStateStream,
    ]).listen((_) => _broadcastState());

    // 5. Sync MediaItem with current sequence source
    _player.sequenceStateStream.listen((state) {
      final item = state?.currentSource?.tag as MediaItem?;
      if (item != null) {
        mediaItem.add(item);
      }
    });

    // 6. Native Looping & Completion Watchdog
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (state.playing) {
          if (_player.loopMode == LoopMode.one) {
            _player.seek(Duration.zero);
            _player.play();
          } else {
            _player.pause();
          }
        }
      }
    });

    _initEqualizer();
  }

  Future<void> _initEqualizer() async {
    try {
      await _equalizer.parameters;
      _isEqualizerReady = true;
    } catch (e) {
      _isEqualizerReady = false;
    }
  }

  AndroidEqualizer get equalizer => _equalizer;
  bool get isEqualizerReady => _isEqualizerReady;

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (position, bufferedPosition, duration) =>
            PositionData(position, bufferedPosition, duration ?? Duration.zero),
      );

  void _broadcastState() {
    playbackState.add(_transformEvent());
  }

  @override
  Future<void> play() async {
    final session = await AudioSession.instance;
    if (await session.setActive(true)) {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      _player.play();
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    final session = await AudioSession.instance;
    await session.setActive(false);
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    if (enabled) {
      await _player.shuffle();
    }
    await _player.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  Future<AudioSource> _resolveAudioSource(MediaItem item) async {
    if (item.id.startsWith('asset:///')) {
      try {
        final assetPath = item.id.replaceFirst('asset:///', '');
        final appDir = await getApplicationSupportDirectory();
        final persistentFolder = Directory('${appDir.path}/media_assets');
        
        if (!await persistentFolder.exists()) {
          await persistentFolder.create(recursive: true);
        }
        
        final fileName = assetPath.replaceAll('/', '_');
        final localFile = File('${persistentFolder.path}/$fileName');

        if (!await localFile.exists() || (await localFile.length()) == 0) {
          final data = await rootBundle.load(assetPath);
          final bytes = data.buffer.asUint8List();
          await localFile.writeAsBytes(bytes, flush: true);
        }
        
        return AudioSource.file(localFile.localPath, tag: item);
      } catch (e) {
        return AudioSource.uri(Uri.parse(item.id), tag: item);
      }
    } else {
      return AudioSource.file(item.id, tag: item);
    }
  }

  Future<void> setQueueAndPlay(List<MediaItem> newQueue, int index) async {
    mediaItem.add(newQueue[index]);
    queue.add(newQueue);

    try {
      final List<AudioSource> sources = await Future.wait(
        newQueue.map((item) => _resolveAudioSource(item))
      );

      final playlist = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: sources,
      );
      
      await _player.setAudioSource(playlist, initialIndex: index);
      await play();
    } catch (e) {
      if (e is PlatformException && e.message?.contains("android.media.audiofx.Equalizer") == true) {
      } else {
        rethrow;
      }
    }
  }

  PlaybackState _transformEvent() {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setRepeatMode,
        MediaAction.setShuffleMode,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
      repeatMode: const {
        LoopMode.off: AudioServiceRepeatMode.none,
        LoopMode.one: AudioServiceRepeatMode.one,
        LoopMode.all: AudioServiceRepeatMode.all,
      }[_player.loopMode]!,
      shuffleMode: _player.shuffleModeEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
  }
}

extension FileExt on File {
  String get localPath => path;
}
