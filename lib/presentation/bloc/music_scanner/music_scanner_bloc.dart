import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/audio_repository.dart';
import 'music_scanner_event.dart';
import 'music_scanner_state.dart';

class MusicScannerBloc extends Bloc<MusicScannerEvent, MusicScannerState> {
  final AudioRepository _audioRepository;

  MusicScannerBloc(this._audioRepository) : super(MusicScannerInitial()) {
    on<ScanMusicEvent>((event, emit) async {
      emit(MusicScannerLoading());
      
      final result = await _audioRepository.getSongs();
      
      result.fold(
        (failure) => emit(MusicScannerFailure(failure.message)),
        (songs) => emit(MusicScannerSuccess(songs)),
      );
    });
  }
}
