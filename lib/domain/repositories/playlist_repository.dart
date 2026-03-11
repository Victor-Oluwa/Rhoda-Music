import 'package:fpdart/fpdart.dart';
import '../../core/error/failures.dart';
import '../entities/playlist.dart';

abstract class PlaylistRepository {
  Future<Either<Failure, List<Playlist>>> getPlaylists();
  Future<Either<Failure, Unit>> createPlaylist(String name);
  Future<Either<Failure, Unit>> addSongToPlaylist(String playlistId, String songPath);
  Future<Either<Failure, Unit>> removeSongFromPlaylist(String playlistId, String songPath);
  Future<Either<Failure, Unit>> deletePlaylist(String id);
  
  // Favourites
  Future<Either<Failure, List<String>>> getFavouriteSongPaths();
  Future<Either<Failure, Unit>> toggleFavourite(String songPath);
  
  // Recent
  Future<Either<Failure, List<String>>> getRecentSongPaths();
  Future<Either<Failure, Unit>> addToRecent(String songPath);
}
