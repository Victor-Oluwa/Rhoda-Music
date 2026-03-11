import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/song.dart';
import 'music_library_event.dart';
import 'music_library_state.dart';

class MusicLibraryBloc extends Bloc<MusicLibraryEvent, MusicLibraryState> {
  MusicLibraryBloc() : super(MusicLibraryState.initial()) {
    on<LoadLibraryEvent>((event, emit) {
      emit(state.copyWith(isLoading: true));

      final Map<String, List<Song>> artists = {};
      final Map<String, List<Song>> albums = {};
      final Map<String, List<Song>> genres = {};
      final Map<String, List<Song>> folders = {};

      for (var song in event.allSongs) {
        // Organize by Artist
        artists.putIfAbsent(song.artist, () => []).add(song);

        // Organize by Album
        albums.putIfAbsent(song.album, () => []).add(song);

        // Organize by Genre
        if (song.genre != null) {
          genres.putIfAbsent(song.genre!, () => []).add(song);
        }

        // Organize by Folder
        final folderPath = song.path.substring(0, song.path.lastIndexOf('/'));
        final folderName = folderPath.split('/').last;
        folders.putIfAbsent(folderName, () => []).add(song);
      }

      emit(state.copyWith(
        allSongs: event.allSongs,
        artists: artists,
        albums: albums,
        genres: genres,
        folders: folders,
        isLoading: false,
      ));
    });
  }
}
