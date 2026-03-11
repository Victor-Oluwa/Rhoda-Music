import '../../../domain/entities/song.dart';

class MusicSearchState {
  final List<Song> searchResults;
  final String query;
  final bool isSearching;

  MusicSearchState({
    required this.searchResults,
    required this.query,
    this.isSearching = false,
  });

  factory MusicSearchState.initial() => MusicSearchState(
        searchResults: [],
        query: "",
        isSearching: false,
      );

  MusicSearchState copyWith({
    List<Song>? searchResults,
    String? query,
    bool? isSearching,
  }) {
    return MusicSearchState(
      searchResults: searchResults ?? this.searchResults,
      query: query ?? this.query,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}
