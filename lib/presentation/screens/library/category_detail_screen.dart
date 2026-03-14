import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/audio/audio_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/song.dart';
import '../../bloc/music_scanner/music_scanner_bloc.dart';
import '../../bloc/music_scanner/music_scanner_state.dart';
import '../../bloc/playlist/playlist_bloc.dart';
import '../../bloc/playlist/playlist_state.dart';
import '../../providers/audio_providers.dart';
import '../../providers/bloc_providers.dart';
import '../../widgets/background_painter.dart';
import '../player/player_screen.dart';
import '../home/home_screen.dart';

class CategoryDetailScreen extends ConsumerWidget {
  final String title;
  final List<Song> songs; 
  final String type;
  final String? playlistId;

  const CategoryDetailScreen({
    super.key,
    required this.title,
    required this.songs,
    required this.type,
    this.playlistId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistBloc = ref.watch(playlistBlocProvider);
    final scannerBloc = ref.watch(musicScannerBlocProvider);

    return BlocBuilder<PlaylistBloc, PlaylistState>(
      bloc: playlistBloc,
      builder: (context, playlistState) {
        return BlocBuilder<MusicScannerBloc, MusicScannerState>(
          bloc: scannerBloc,
          builder: (context, scannerState) {
            List<Song> displayedSongs = songs;

            if (scannerState is MusicScannerSuccess && playlistState is PlaylistSuccess) {
              if (type == "FAVORITES") {
                displayedSongs = scannerState.songs
                    .where((s) => playlistState.favouriteSongPaths.contains(s.id))
                    .toList();
                
                // Also check assets
                final assetSongs = _getAssetSongs();
                for (var s in assetSongs) {
                  if (playlistState.favouriteSongPaths.contains(s.id)) {
                    displayedSongs.add(s);
                  }
                }
              } else if (type == "RECENT") {
                displayedSongs = [];
                final allPossibleSongs = [...scannerState.songs, ..._getAssetSongs()];
                for (var path in playlistState.recentSongPaths) {
                  try {
                    final song = allPossibleSongs.firstWhere((s) => s.id == path);
                    displayedSongs.add(song);
                  } catch (_) {}
                }
              } else if (type == "PLAYLIST" && playlistId != null) {
                final playlist = playlistState.playlists.firstWhere((p) => p.id == playlistId, orElse: () => playlistState.playlists.first);
                final allPossibleSongs = [...scannerState.songs, ..._getAssetSongs()];
                displayedSongs = allPossibleSongs
                    .where((s) => playlist.songPaths.contains(s.id))
                    .toList();
              }
            }

            return Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: BackgroundPainter(),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        _buildHeader(context),
                        _buildCategoryInfo(context, ref, displayedSongs),
                        Expanded(
                          child: displayedSongs.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                                  itemCount: displayedSongs.length,
                                  itemBuilder: (context, index) {
                                    final song = displayedSongs[index];
                                    return SongTile(
                                      song: song, 
                                      songs: displayedSongs, 
                                      index: index,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Song> _getAssetSongs() {
    return [
      const Song(
        id: 'asset:///assets/music/victor_track.mp3',
        title: 'Remember',
        artist: 'Victor Special',
        album: 'Asset Collection',
        duration: Duration(seconds: 33),
        path: 'asset:///assets/music/victor_track.mp3',
      ),
      const Song(
        id: 'asset:///assets/music/today_denver.mp3',
        title: 'Today',
        artist: 'Victor Special',
        album: 'Asset Collection',
        duration: Duration(seconds: 228),
        path: 'asset:///assets/music/today_denver.mp3',
      ),
    ];
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note_outlined, size: 64.sp, color: AppColors.greyBase.withOpacity(0.2)),
          SizedBox(height: 16.h),
          Text(
            "No tracks in this category",
            style: TextStyle(color: AppColors.greyBase.withOpacity(0.5), fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          ),
          Text(
            type,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryInfo(BuildContext context, WidgetRef ref, List<Song> displayedSongs) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      child: Row(
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(_getIcon(), size: 40.sp, color: AppColors.taupeLight),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "${displayedSongs.length} Tracks",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.greyBase),
                ),
              ],
            ),
          ),
          if (displayedSongs.isNotEmpty) _buildPlayAllButton(ref, displayedSongs),
        ],
      ),
    );
  }

  Widget _buildPlayAllButton(WidgetRef ref, List<Song> displayedSongs) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
      ),
      child: IconButton(
        onPressed: () async {
          final handler = ref.read(audioHandlerProvider) as RhodaAudioHandler;
          await handler.setQueueAndPlay(displayedSongs.map((s) => s.toMediaItem()).toList(), 0);
        },
        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
      ),
    );
  }

  IconData _getIcon() {
    switch (type.toUpperCase()) {
      case 'ARTIST': return Icons.person_rounded;
      case 'ALBUM': return Icons.album_rounded;
      case 'GENRE': return Icons.style_rounded;
      case 'FOLDER': return Icons.folder_rounded;
      case 'PLAYLIST': return Icons.playlist_play_rounded;
      case 'FAVORITES': return Icons.favorite_rounded;
      case 'RECENT': return Icons.history_rounded;
      case 'FEATURED': return Icons.auto_awesome_rounded;
      default: return Icons.music_note_rounded;
    }
  }
}
