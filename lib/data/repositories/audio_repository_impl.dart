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
      // 1. Check Permissions
      final status = await _requestPermissions();
      if (!status) {
        return const Left(PermissionFailure("Storage permission denied"));
      }

      // 2. Scan Directories
      final List<File> audioFiles = [];

      final rootDir = Directory('/storage/emulated/0/');
      if (await rootDir.exists()) {
        await _findAudioFiles(rootDir, audioFiles);
      } else {
        final List<Directory?> searchDirs = [
          await getExternalStorageDirectory(),
        ];
        for (var dir in searchDirs) {
          if (dir != null) {
            await _findAudioFiles(dir, audioFiles);
          }
        }
      }

      // 3. Extract Metadata in a separate isolate to avoid blocking UI
      final List<Song> songs = await compute(_parseMetadata, audioFiles);

      return Right(songs);
    } catch (e) {
      return Left(DeviceStorageFailure(e.toString()));
    }
  }

  static List<Song> _parseMetadata(List<File> files) {
    final List<Song> songs = [];
    for (var file in files) {
      try {
        final metadata = readMetadata(file, getImage: true);
        songs.add(Song(
          id: file.path,
          title: metadata.title ?? file.path.split('/').last,
          artist: metadata.artist ?? "Unknown Artist",
          album: metadata.album ?? "Unknown Album",
          genre: metadata.genres.isNotEmpty ? metadata.genres.first : "Unknown Genre",
          duration: metadata.duration ?? Duration.zero,
          path: file.path,
          artwork: metadata.pictures.isNotEmpty
              ? metadata.pictures.first.bytes
              : null,
        ));
      } catch (e) {
        continue;
      }
    }
    return songs;
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.audio.request().isGranted) {
        return true;
      }
      return await Permission.storage.request().isGranted;
    }
    return true;
  }

  Future<void> _findAudioFiles(Directory dir, List<File> audioFiles) async {
    try {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
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
          if (!name.startsWith('.') &&
              name != 'Android' &&
              name != 'com.example.rhoda_music') {
            await _findAudioFiles(entity, audioFiles);
          }
        }
      }
    } catch (e) {
      // Ignore
    }
  }
}
