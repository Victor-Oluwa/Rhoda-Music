import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class RhodaAudioHandler extends BaseAudioHandler with SeekHandler, QueueHandler {
  final AndroidEqualizer _equalizer = AndroidEqualizer();
  late final AudioPlayer _player;

  RhodaAudioHandler() {
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [_equalizer],
      ),
    );

    // Combine multiple streams to ensure PlaybackState is updated whenever any relevant state changes
    _player.playbackEventStream.listen((event) => _broadcastState());
    _player.loopModeStream.listen((event) => _broadcastState());
    _player.shuffleModeEnabledStream.listen((event) => _broadcastState());
    _player.playerStateStream.listen((event) => _broadcastState());

    // Listen to changes in the current item
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });

    // Handle completions by skipping to next
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  AndroidEqualizer get equalizer => _equalizer;

  void _broadcastState() {
    playbackState.add(_transformEvent());
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

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

  Future<void> setQueueAndPlay(List<MediaItem> newQueue, int index) async {
    if (_isQueueSame(queue.value, newQueue)) {
      await skipToQueueItem(index);
    } else {
      queue.add(newQueue);
      final audioSource = ConcatenatingAudioSource(
        children: newQueue.map((item) {
          if (item.id.startsWith('asset:///')) {
            // Handle Flutter assets
            return AudioSource.uri(Uri.parse(item.id));
          } else {
            // Handle local files
            return AudioSource.file(item.id);
          }
        }).toList(),
      );
      await _player.setAudioSource(audioSource, initialIndex: index);
    }
    play();
  }

  bool _isQueueSame(List<MediaItem> q1, List<MediaItem> q2) {
    if (q1.length != q2.length) return false;
    for (int i = 0; i < q1.length; i++) {
      if (q1[i].id != q2[i].id) return false;
    }
    return true;
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
