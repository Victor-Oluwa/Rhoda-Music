abstract class PlaylistEvent {}

class LoadPlaylistsEvent extends PlaylistEvent {}

class CreatePlaylistEvent extends PlaylistEvent {
  final String name;
  CreatePlaylistEvent(this.name);
}

class AddSongToPlaylistEvent extends PlaylistEvent {
  final String playlistId;
  final String songPath;
  AddSongToPlaylistEvent(this.playlistId, this.songPath);
}

class RemoveSongFromPlaylistEvent extends PlaylistEvent {
  final String playlistId;
  final String songPath;
  RemoveSongFromPlaylistEvent(this.playlistId, this.songPath);
}

class DeletePlaylistEvent extends PlaylistEvent {
  final String id;
  DeletePlaylistEvent(this.id);
}

class ToggleFavouriteEvent extends PlaylistEvent {
  final String songPath;
  ToggleFavouriteEvent(this.songPath);
}

class AddToRecentEvent extends PlaylistEvent {
  final String songPath;
  AddToRecentEvent(this.songPath);
}

class LoadFavouritesAndRecentEvent extends PlaylistEvent {}
