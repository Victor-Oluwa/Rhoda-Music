import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/audio_repository_impl.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../domain/repositories/playlist_repository.dart';

final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  return AudioRepositoryImpl();
});

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepositoryImpl();
});
