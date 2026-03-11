import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/playlist_repository.dart';
import 'playlist_event.dart';
import 'playlist_state.dart';

class PlaylistBloc extends Bloc<PlaylistEvent, PlaylistState> {
  final PlaylistRepository _playlistRepository;

  PlaylistBloc(this._playlistRepository) : super(PlaylistInitial()) {
    on<LoadPlaylistsEvent>((event, emit) async {
      emit(PlaylistLoading());
      await _loadAll(emit);
    });

    on<LoadFavouritesAndRecentEvent>((event, emit) async {
      // Don't emit loading here to avoid UI flickering for background updates
      await _loadAll(emit);
    });

    on<CreatePlaylistEvent>((event, emit) async {
      final result = await _playlistRepository.createPlaylist(event.name);
      await result.fold(
        (failure) async => emit(PlaylistFailure(failure.message)),
        (_) async => await _loadAll(emit),
      );
    });

    on<AddSongToPlaylistEvent>((event, emit) async {
      final result = await _playlistRepository.addSongToPlaylist(event.playlistId, event.songPath);
      await result.fold(
        (failure) async => emit(PlaylistFailure(failure.message)),
        (_) async => await _loadAll(emit),
      );
    });

    on<RemoveSongFromPlaylistEvent>((event, emit) async {
      final result = await _playlistRepository.removeSongFromPlaylist(event.playlistId, event.songPath);
      await result.fold(
        (failure) async => emit(PlaylistFailure(failure.message)),
        (_) async => await _loadAll(emit),
      );
    });

    on<DeletePlaylistEvent>((event, emit) async {
      final result = await _playlistRepository.deletePlaylist(event.id);
      await result.fold(
        (failure) async => emit(PlaylistFailure(failure.message)),
        (_) async => await _loadAll(emit),
      );
    });

    on<ToggleFavouriteEvent>((event, emit) async {
      final result = await _playlistRepository.toggleFavourite(event.songPath);
      await result.fold(
        (failure) async => emit(PlaylistFailure(failure.message)),
        (_) async => await _loadAll(emit),
      );
    });

    on<AddToRecentEvent>((event, emit) async {
      final result = await _playlistRepository.addToRecent(event.songPath);
      await result.fold(
        (failure) async => emit(PlaylistFailure(failure.message)),
        (_) async => await _loadAll(emit),
      );
    });
  }

  Future<void> _loadAll(Emitter<PlaylistState> emit) async {
    final playlistsResult = await _playlistRepository.getPlaylists();
    final favouritesResult = await _playlistRepository.getFavouriteSongPaths();
    final recentResult = await _playlistRepository.getRecentSongPaths();

    // Check for failures explicitly
    if (playlistsResult.isLeft()) {
      playlistsResult.fold((l) => emit(PlaylistFailure(l.message)),(r){});
      return;
    }
    if (favouritesResult.isLeft()) {
      favouritesResult.fold((l) => emit(PlaylistFailure(l.message)),(r){});
      return;
    }
    if (recentResult.isLeft()) {
      recentResult.fold((l) => emit(PlaylistFailure(l.message)) ,(r){});
      return;
    }

    emit(PlaylistSuccess(
      playlists: playlistsResult.getOrElse((l) => []),
      favouriteSongPaths: favouritesResult.getOrElse((l) => []),
      recentSongPaths: recentResult.getOrElse((l) => []),
    ));
  }
}
