import 'package:equatable/equatable.dart';
import '../../../domain/entities/playlist.dart';

abstract class PlaylistState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PlaylistInitial extends PlaylistState {}

class PlaylistLoading extends PlaylistState {}

class PlaylistSuccess extends PlaylistState {
  final List<Playlist> playlists;
  final List<String> favouriteSongPaths;
  final List<String> recentSongPaths;

  PlaylistSuccess({
    required this.playlists,
    required this.favouriteSongPaths,
    required this.recentSongPaths,
  });

  @override
  List<Object?> get props => [playlists, favouriteSongPaths, recentSongPaths];
}

class PlaylistFailure extends PlaylistState {
  final String message;
  PlaylistFailure(this.message);

  @override
  List<Object?> get props => [message];
}
