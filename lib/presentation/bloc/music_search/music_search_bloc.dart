import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'music_search_event.dart';
import 'music_search_state.dart';

class MusicSearchBloc extends Bloc<MusicSearchEvent, MusicSearchState> {
  MusicSearchBloc() : super(MusicSearchState.initial()) {
    on<SearchQueryChangedEvent>(
      (event, emit) {
        if (event.query.isEmpty) {
          emit(MusicSearchState.initial());
          return;
        }

        emit(state.copyWith(isSearching: true, query: event.query));

        final lowercaseQuery = event.query.toLowerCase();
        
        final results = event.allSongs.where((song) {
          final title = song.title.toLowerCase();
          final artist = song.artist.toLowerCase();
          final album = song.album.toLowerCase();
          
          return title.contains(lowercaseQuery) || 
                 artist.contains(lowercaseQuery) || 
                 album.contains(lowercaseQuery);
        }).toList();

        emit(state.copyWith(searchResults: results, isSearching: false));
      },
      // Production Practice: Use restartable() or debounce to prevent UI lag
      // and excessive processing during rapid typing.
      transformer: (events, mapper) {
        return events
            .debounceTime(const Duration(milliseconds: 300))
            .switchMap(mapper);
      },
    );

    on<ClearSearchEvent>((event, emit) {
      emit(MusicSearchState.initial());
    });
  }
}
