import '../../../domain/entities/song.dart';

abstract class MusicSearchEvent {}

class SearchQueryChangedEvent extends MusicSearchEvent {
  final String query;
  final List<Song> allSongs;
  SearchQueryChangedEvent(this.query, this.allSongs);
}

class ClearSearchEvent extends MusicSearchEvent {}
