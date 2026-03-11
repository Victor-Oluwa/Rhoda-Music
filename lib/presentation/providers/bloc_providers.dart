import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bloc/music_library/music_library_bloc.dart';
import '../bloc/music_scanner/music_scanner_bloc.dart';
import '../bloc/music_search/music_search_bloc.dart';
import '../bloc/playlist/playlist_bloc.dart';
import '../bloc/playlist/playlist_event.dart';
import 'repository_providers.dart';

final musicScannerBlocProvider = Provider<MusicScannerBloc>((ref) {
  final repository = ref.watch(audioRepositoryProvider);
  return MusicScannerBloc(repository);
});

final musicLibraryBlocProvider = Provider<MusicLibraryBloc>((ref) {
  return MusicLibraryBloc();
});

final musicSearchBlocProvider = Provider<MusicSearchBloc>((ref) {
  return MusicSearchBloc();
});

final playlistBlocProvider = Provider<PlaylistBloc>((ref) {
  final repository = ref.watch(playlistRepositoryProvider);
  final bloc = PlaylistBloc(repository);
  bloc.add(LoadPlaylistsEvent());
  return bloc;
});
