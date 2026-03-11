import '../../../domain/entities/song.dart';

abstract class MusicLibraryEvent {}

class LoadLibraryEvent extends MusicLibraryEvent {
  final List<Song> allSongs;
  LoadLibraryEvent(this.allSongs);
}
