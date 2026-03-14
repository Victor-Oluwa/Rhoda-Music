import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/song.dart';
import 'music_library_event.dart';
import 'music_library_state.dart';

class MusicLibraryBloc extends Bloc<MusicLibraryEvent, MusicLibraryState> {
  MusicLibraryBloc() : super(MusicLibraryState.initial()) {
    on<LoadLibraryEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true));

      // Performance optimization: Move library processing to a separate isolate
      // to keep the UI completely smooth during large library loads.
      final processedLibrary = await compute(_processSongs, event.allSongs);

      emit(state.copyWith(
        allSongs: event.allSongs,
        artists: processedLibrary.artists,
        albums: processedLibrary.albums,
        genres: processedLibrary.genres,
        folders: processedLibrary.folders,
        isLoading: false,
      ));
    });
  }

  static LibraryData _processSongs(List<Song> allSongs) {
    final Map<String, List<Song>> artists = {};
    final Map<String, List<Song>> albums = {};
    final Map<String, List<Song>> genres = {};
    final Map<String, List<Song>> folders = {};

    for (var song in allSongs) {
      // Organize by Artist
      artists.putIfAbsent(song.artist, () => []).add(song);

      // Organize by Album
      albums.putIfAbsent(song.album, () => []).add(song);

      // Organize by Genre
      if (song.genre != null && song.genre!.isNotEmpty) {
        genres.putIfAbsent(song.genre!, () => []).add(song);
      }

      // Organize by Folder
      try {
        final folderPath = song.path.substring(0, song.path.lastIndexOf('/'));
        final folderName = folderPath.split('/').last;
        if (folderName.isNotEmpty) {
          folders.putIfAbsent(folderName, () => []).add(song);
        }
      } catch (_) {
        folders.putIfAbsent("Unknown Folder", () => []).add(song);
      }
    }

    return LibraryData(
      artists: artists,
      albums: albums,
      genres: genres,
      folders: folders,
    );
  }
}

class LibraryData {
  final Map<String, List<Song>> artists;
  final Map<String, List<Song>> albums;
  final Map<String, List<Song>> genres;
  final Map<String, List<Song>> folders;

  LibraryData({
    required this.artists,
    required this.albums,
    required this.genres,
    required this.folders,
  });
}
