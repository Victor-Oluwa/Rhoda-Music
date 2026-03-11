import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:equatable/equatable.dart';

class Song extends Equatable {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? genre;
  final Duration duration;
  final String path;
  final Uint8List? artwork;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.genre,
    required this.duration,
    required this.path,
    this.artwork,
  });

  MediaItem toMediaItem() {
    return MediaItem(
      id: path,
      album: album,
      title: title,
      artist: artist,
      duration: duration,
      genre: genre,
      extras: {
        'artwork': artwork,
      },
    );
  }

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? genre,
    Duration? duration,
    String? path,
    Uint8List? artwork,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      duration: duration ?? this.duration,
      path: path ?? this.path,
      artwork: artwork ?? this.artwork,
    );
  }

  @override
  List<Object?> get props => [id, path, title, artist, album];
}
