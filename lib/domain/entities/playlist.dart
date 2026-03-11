import 'package:equatable/equatable.dart';

class Playlist extends Equatable {
  final String id;
  final String name;
  final List<String> songPaths;
  final DateTime createdAt;

  const Playlist({
    required this.id,
    required this.name,
    required this.songPaths,
    required this.createdAt,
  });

  Playlist copyWith({
    String? id,
    String? name,
    List<String>? songPaths,
    DateTime? createdAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songPaths: songPaths ?? this.songPaths,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, songPaths, createdAt];
}
