import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_handler.dart';

final audioHandlerProvider = Provider<AudioHandler>((ref) {
  throw UnimplementedError(); // Initialized in main.dart
});

final currentSongProvider = StreamProvider<MediaItem?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.mediaItem;
});

final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.playbackState;
});

final positionDataProvider = StreamProvider<PositionData>((ref) {
  final handler = ref.watch(audioHandlerProvider) as RhodaAudioHandler;
  return handler.positionDataStream;
});
