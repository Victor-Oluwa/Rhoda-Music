import '../../../domain/entities/song.dart';

abstract class MusicScannerState {}

class MusicScannerInitial extends MusicScannerState {}

class MusicScannerLoading extends MusicScannerState {}

class MusicScannerSuccess extends MusicScannerState {
  final List<Song> songs;
  MusicScannerSuccess(this.songs);
}

class MusicScannerFailure extends MusicScannerState {
  final String message;
  MusicScannerFailure(this.message);
}
