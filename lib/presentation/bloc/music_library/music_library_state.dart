import '../../../domain/entities/song.dart';

class MusicLibraryState {
  final List<Song> allSongs;
  final Map<String, List<Song>> artists;
  final Map<String, List<Song>> albums;
  final Map<String, List<Song>> genres;
  final Map<String, List<Song>> folders;
  final bool isLoading;

  MusicLibraryState({
    required this.allSongs,
    required this.artists,
    required this.albums,
    required this.genres,
    required this.folders,
    this.isLoading = false,
  });

  factory MusicLibraryState.initial() => MusicLibraryState(
        allSongs: [],
        artists: {},
        albums: {},
        genres: {},
        folders: {},
        isLoading: false,
      );

  MusicLibraryState copyWith({
    List<Song>? allSongs,
    Map<String, List<Song>>? artists,
    Map<String, List<Song>>? albums,
    Map<String, List<Song>>? genres,
    Map<String, List<Song>>? folders,
    bool? isLoading,
  }) {
    return MusicLibraryState(
      allSongs: allSongs ?? this.allSongs,
      artists: artists ?? this.artists,
      albums: albums ?? this.albums,
      genres: genres ?? this.genres,
      folders: folders ?? this.folders,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
