import 'package:fpdart/fpdart.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/repositories/playlist_repository.dart';

class PlaylistRepositoryImpl implements PlaylistRepository {
  Database? _database;
  final _uuid = const Uuid();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rhoda_music.db');

    return await openDatabase(
      path,
      version: 2, // Upgraded version
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE playlists(
            id TEXT PRIMARY KEY,
            name TEXT,
            createdAt TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE playlist_songs(
            playlistId TEXT,
            songPath TEXT,
            PRIMARY KEY (playlistId, songPath)
          )
        ''');
        await db.execute('''
          CREATE TABLE favourites(
            songPath TEXT PRIMARY KEY
          )
        ''');
        await db.execute('''
          CREATE TABLE recent(
            songPath TEXT PRIMARY KEY,
            lastPlayed TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE favourites(
              songPath TEXT PRIMARY KEY
            )
          ''');
          await db.execute('''
            CREATE TABLE recent(
              songPath TEXT PRIMARY KEY,
              lastPlayed TEXT
            )
          ''');
        }
      },
    );
  }

  @override
  Future<Either<Failure, List<Playlist>>> getPlaylists() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> playlistMaps = await db.query('playlists');
      
      final List<Playlist> playlists = [];
      for (var map in playlistMaps) {
        final id = map['id'] as String;
        final songs = await db.query(
          'playlist_songs',
          where: 'playlistId = ?',
          whereArgs: [id],
        );
        
        playlists.add(Playlist(
          id: id,
          name: map['name'] as String,
          songPaths: songs.map((s) => s['songPath'] as String).toList(),
          createdAt: DateTime.parse(map['createdAt'] as String),
        ));
      }
      return Right(playlists);
    } catch (e) {
      return Left(DeviceStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> createPlaylist(String name) async {
    try {
      final db = await database;
      await db.insert('playlists', {
        'id': _uuid.v4(),
        'name': name,
        'createdAt': DateTime.now().toIso8601String(),
      });
      return const Right(unit);
    } catch (e) {
      return Left(DeviceStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> addSongToPlaylist(String playlistId, String songPath) async {
    try {
      final db = await database;
      await db.insert('playlist_songs', {
        'playlistId': playlistId,
        'songPath': songPath,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return const Right(unit);
    } catch (e) {
      return Left(DeviceStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeSongFromPlaylist(String playlistId, String songPath) async {
    try {
      final db = await database;
      await db.delete(
        'playlist_songs',
        where: 'playlistId = ? AND songPath = ?',
        whereArgs: [playlistId, songPath],
      );
      return const Right(unit);
    } catch (e) {
      return Left(DeviceStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deletePlaylist(String id) async {
    try {
      final db = await database;
      await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
      await db.delete('playlist_songs', where: 'playlistId = ?', whereArgs: [id]);
      return const Right(unit);
    } catch (e) {
      return Left(DeviceStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getFavouriteSongPaths() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('favourites');
      return Right(maps.map((m) => m['songPath'] as String).toList());
    } catch (e) {
      return Left(DeviceStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> toggleFavourite(String songPath) async {
    try {
      final db = await database;
      final maps = await db.query('favourites', where: 'songPath = ?', whereArgs: [songPath]);
      if (maps.isEmpty) {
        await db.insert('favourites', {'songPath': songPath});
      } else {
        await db.delete('favourites', where: 'songPath = ?', whereArgs: [songPath]);
      }
      return const Right(unit);
    } catch (e) {
      return Left(DeviceStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getRecentSongPaths() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'recent', 
        orderBy: 'lastPlayed DESC',
        limit: 50,
      );
      return Right(maps.map((m) => m['songPath'] as String).toList());
    } catch (e) {
      return Left(DeviceStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> addToRecent(String songPath) async {
    try {
      final db = await database;
      await db.insert('recent', {
        'songPath': songPath,
        'lastPlayed': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return const Right(unit);
    } catch (e) {
      return Left(DeviceStorageFailure(e.toString()));
    }
  }
}
