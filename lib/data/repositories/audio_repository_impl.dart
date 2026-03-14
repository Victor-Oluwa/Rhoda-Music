import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/audio_repository.dart';

class AudioRepositoryImpl implements AudioRepository {
  @override
  Future<Either<Failure, List<Song>>> getSongs() async {
    try {
      final status = await _requestPermissions();
      if (!status) {
        return const Left(PermissionFailure("Required permissions not granted"));
      }

      final List<File> audioFiles = [];
      
      // Production-grade scanning: Target specific directories first for speed
      final List<String> pathsToScan = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Audiobooks',
        '/storage/emulated/0/Notifications',
      ];

      for (final path in pathsToScan) {
        final dir = Directory(path);
        if (await dir.exists()) {
          await _findAudioFiles(dir, audioFiles);
        }
      }

      // Also scan app documents and external storage music directories
      final appDocs = await getApplicationDocumentsDirectory();
      await _findAudioFiles(appDocs, audioFiles);

      final externalDirs = await getExternalStorageDirectories(type: StorageDirectory.music);
      if (externalDirs != null) {
        for (final dir in externalDirs) {
          await _findAudioFiles(dir, audioFiles);
        }
      }

      // If we found very few songs, we might want to do a deeper scan, 
      // but for production-grade reliability, we avoid scanning the entire root 
      // unless necessary, as it hits many restricted Android folders.
      
      if (audioFiles.isEmpty) {
        final rootDir = Directory('/storage/emulated/0/');
        if (await rootDir.exists()) {
           await _findAudioFiles(rootDir, audioFiles, depth: 0, maxDepth: 2);
        }
      }

      // Use a Set to avoid duplicates if same file found via different paths
      final uniqueFiles = audioFiles.map((f) => f.path).toSet().map((p) => File(p)).toList();

      final List<Song> songs = await compute(_parseMetadata, uniqueFiles);

      return Right(songs);
    } catch (e) {
      return Left(DeviceStorageFailure("Failed to scan library: ${e.toString()}"));
    }
  }

  static List<Song> _parseMetadata(List<File> files) {
    final List<Song> songs = [];
    for (var file in files) {
      try {
        // Production grade: Don't load full image here if it's too large, 
        // but audio_metadata_reader is generally efficient.
        final metadata = readMetadata(file, getImage: true);
        
        songs.add(Song(
          id: file.path,
          title: metadata.title?.trim().isNotEmpty == true ? metadata.title! : file.path.split('/').last,
          artist: metadata.artist?.trim().isNotEmpty == true ? metadata.artist! : "Unknown Artist",
          album: metadata.album?.trim().isNotEmpty == true ? metadata.album! : "Unknown Album",
          genre: metadata.genres.isNotEmpty ? metadata.genres.first : "Unknown Genre",
          duration: metadata.duration ?? Duration.zero,
          path: file.path,
          artwork: metadata.pictures.isNotEmpty
              ? metadata.pictures.first.bytes
              : null,
        ));
      } catch (e) {
        // Log error in production if needed
        continue;
      }
    }
    return songs;
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await Permission.audio.status;
      if (androidInfo.isGranted) return true;

      Map<Permission, PermissionStatus> statuses = await [
        Permission.audio,
        Permission.storage,
      ].request();
      
      return statuses[Permission.audio]?.isGranted == true || 
             statuses[Permission.storage]?.isGranted == true;
    }
    return true;
  }

  Future<void> _findAudioFiles(Directory dir, List<File> audioFiles, {int depth = 0, int maxDepth = 10}) async {
    if (depth > maxDepth) return;
    
    try {
      final entities = await dir.list(recursive: false, followLinks: false).toList();
      for (final entity in entities) {
        if (entity is File) {
          final path = entity.path.toLowerCase();
          if (path.endsWith('.mp3') ||
              path.endsWith('.wav') ||
              path.endsWith('.flac') ||
              path.endsWith('.m4a') ||
              path.endsWith('.ogg')) {
            audioFiles.add(entity);
          }
        } else if (entity is Directory) {
          final name = entity.path.split('/').last;
          // Skip system and hidden directories
          if (!name.startsWith('.') &&
              name != 'Android' &&
              name != 'Data' &&
              !name.contains('cache')) {
            await _findAudioFiles(entity, audioFiles, depth: depth + 1, maxDepth: maxDepth);
          }
        }
      }
    } catch (e) {
      // Access denied or other IO error, skip
    }
  }
}
