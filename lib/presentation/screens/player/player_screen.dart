import 'dart:io';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/audio/audio_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../bloc/playlist/playlist_bloc.dart';
import '../../bloc/playlist/playlist_event.dart';
import '../../bloc/playlist/playlist_state.dart';
import '../../providers/audio_providers.dart';
import '../../providers/bloc_providers.dart';
import '../../widgets/equalizer_sheet.dart';
import '../../widgets/video_background.dart'; 
import '../../widgets/stunning_progress_bar.dart';
import '../../widgets/stunning_visualizer.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  String? _lastTrackPath;
  bool _showVideoBackground = true;
  String? _customMediaPath;
  static const String _mediaPathKey = 'custom_background_media_path';

  @override
  void initState() {
    super.initState();
    _loadCustomMedia();
  }

  Future<void> _loadCustomMedia() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedPath = prefs.getString(_mediaPathKey);
    
    if (savedPath != null) {
      if (!File(savedPath).existsSync()) {
        await prefs.remove(_mediaPathKey);
        savedPath = null;
      }
    }

    if (mounted) {
      setState(() {
        _customMediaPath = savedPath;
      });
    }
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final XFile? media = await picker.pickMedia();
    
    if (media != null && mounted) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'bg_media_${DateTime.now().millisecondsSinceEpoch}${p.extension(media.path)}';
        final savedFile = await File(media.path).copy(p.join(appDir.path, fileName));

        final prefs = await SharedPreferences.getInstance();
        if (_customMediaPath != null) {
          final oldFile = File(_customMediaPath!);
          if (oldFile.existsSync()) await oldFile.delete();
        }

        await prefs.setString(_mediaPathKey, savedFile.path);
        setState(() {
          _customMediaPath = savedFile.path;
          _showVideoBackground = true;
        });
      } catch (e) {
        debugPrint("Error saving picked media: $e");
      }
    }
  }

  Future<void> _resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    if (_customMediaPath != null) {
      final file = File(_customMediaPath!);
      if (file.existsSync()) await file.delete();
    }
    await prefs.remove(_mediaPathKey);
    if (mounted) {
      setState(() {
        _customMediaPath = null;
        _showVideoBackground = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = ref.watch(currentSongProvider).value;
    final playbackState = ref.watch(playbackStateProvider).value;
    final handler = ref.watch(audioHandlerProvider);
    final playlistBloc = ref.watch(playlistBlocProvider);
    final positionData = ref.watch(positionDataProvider).value;

    ref.listen(currentSongProvider, (previous, next) {
      final song = next.value;
      if (song != null && song.id != _lastTrackPath) {
        _lastTrackPath = song.id;
        playlistBloc.add(AddToRecentEvent(song.id));
      }
    });

    if (currentItem == null) {
      return const Scaffold(body: Center(child: Text("No song selected")));
    }

    final playing = playbackState?.playing ?? false;
    final repeatMode = playbackState?.repeatMode ?? AudioServiceRepeatMode.none;
    final shuffleMode = playbackState?.shuffleMode ?? AudioServiceShuffleMode.none;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Layer
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: _showVideoBackground
                  ? MediaBackground(
                      key: ValueKey(_customMediaPath ?? 'default_bg'),
                      assetPath: _customMediaPath == null ? 'assets/videos/background_video.mp4' : null,
                      filePath: _customMediaPath,
                      showBlur: true,
                    )
                  : Container(
                      key: const ValueKey('black_bg'),
                      color: Colors.black,
                    ),
            ),
          ),
          
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  SizedBox(height: 8.h),
                  _buildHeader(context),
                  const Spacer(flex: 3),
                  _buildVisualizer(playing),
                  const Spacer(flex: 3),
                  _buildTrackInfo(context, currentItem),
                  const Spacer(flex: 1),
                  _buildProgressBar(handler, positionData),
                  SizedBox(height: 12.h),
                  _buildMainControls(context, handler, playing, repeatMode, shuffleMode),
                  const Spacer(flex: 4),
                  _buildBottomToolbar(context, playlistBloc, currentItem),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizer(bool isPlaying) {
    return Center(
      child: StunningVisualizer(
        isPlaying: isPlaying,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildGlassIconButton(
          icon: Icons.keyboard_arrow_down_rounded,
          onPressed: () => Navigator.pop(context),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "NOW PLAYING",
              style: GoogleFonts.lexendDeca(
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 4.0,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              "Rhoda Music",
              style: GoogleFonts.lexendDeca(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        _buildGlassIconButton(
          icon: _showVideoBackground ? Icons.movie_filter_rounded : Icons.movie_filter_outlined,
          onPressed: () {
            setState(() {
              _showVideoBackground = !_showVideoBackground;
            });
          },
          isActive: _showVideoBackground,
        ),
      ],
    );
  }

  void _showBackgroundSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          ),
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Text(
                "Background Style",
                style: GoogleFonts.lexendDeca(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24.h),
              _buildSettingsOption(
                icon: Icons.perm_media_rounded,
                title: "Choose Custom Media",
                subtitle: "Select an image or video from gallery",
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia();
                },
              ),
              if (_customMediaPath != null)
                _buildSettingsOption(
                  icon: Icons.refresh_rounded,
                  title: "Restore Default",
                  subtitle: "Return to the original loop",
                  onTap: () {
                    Navigator.pop(context);
                    _resetToDefault();
                  },
                ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(vertical: 8.h),
      leading: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: GoogleFonts.lexendDeca(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: GoogleFonts.lexendDeca(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.sp)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon, 
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isActive 
                ? AppColors.primary.withValues(alpha: 0.2) 
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isActive 
                  ? AppColors.primary.withValues(alpha: 0.5) 
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon, 
              color: isActive ? AppColors.primary : Colors.white, 
              size: 24.sp,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackInfo(BuildContext context, MediaItem item) {
    return Column(
      children: [
        Text(
          item.title,
          style: GoogleFonts.lexendDeca(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 26.sp,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 10.h),
        Text(
          item.artist?.toUpperCase() ?? "UNKNOWN ARTIST",
          style: GoogleFonts.lexendDeca(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 3.0,
            fontSize: 11.sp,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressBar(AudioHandler handler, PositionData? positionData) {
    return StunningProgressBar(
      position: positionData?.position ?? Duration.zero,
      bufferedPosition: positionData?.bufferedPosition ?? Duration.zero,
      duration: positionData?.duration ?? Duration.zero,
      onSeek: (duration) => handler.seek(duration),
    );
  }

  Widget _buildMainControls(BuildContext context, AudioHandler handler, bool playing, AudioServiceRepeatMode repeatMode, AudioServiceShuffleMode shuffleMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildShuffleButton(handler, shuffleMode),
        IconButton(
          onPressed: () => handler.skipToPrevious(),
          icon: Icon(Icons.skip_previous_rounded, size: 48.sp, color: Colors.white),
        ),
        _buildPlayPauseButton(handler, playing),
        IconButton(
          onPressed: () => handler.skipToNext(),
          icon: Icon(Icons.skip_next_rounded, size: 48.sp, color: Colors.white),
        ),
        _buildRepeatButton(handler, repeatMode),
      ],
    );
  }

  Widget _buildShuffleButton(AudioHandler handler, AudioServiceShuffleMode shuffleMode) {
    final bool isEnabled = shuffleMode == AudioServiceShuffleMode.all;
    return IconButton(
      onPressed: () {
        handler.setShuffleMode(isEnabled ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all);
      },
      icon: Icon(
        Icons.shuffle_rounded,
        color: isEnabled ? AppColors.primary : Colors.white.withValues(alpha: 0.3),
        size: 22.sp,
      ),
    );
  }

  Widget _buildRepeatButton(AudioHandler handler, AudioServiceRepeatMode repeatMode) {
    IconData icon;
    Color color;
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        icon = Icons.repeat_rounded;
        color = Colors.white.withValues(alpha: 0.3);
        break;
      case AudioServiceRepeatMode.one:
        icon = Icons.repeat_one_rounded;
        color = AppColors.primary;
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        icon = Icons.repeat_rounded;
        color = AppColors.primary;
        break;
    }

    return IconButton(
      onPressed: () {
        final nextMode = _getNextRepeatMode(repeatMode);
        handler.setRepeatMode(nextMode);
      },
      icon: Icon(icon, color: color, size: 22.sp),
    );
  }

  AudioServiceRepeatMode _getNextRepeatMode(AudioServiceRepeatMode current) {
    switch (current) {
      case AudioServiceRepeatMode.none: return AudioServiceRepeatMode.all;
      case AudioServiceRepeatMode.all: return AudioServiceRepeatMode.one;
      case AudioServiceRepeatMode.one: return AudioServiceRepeatMode.none;
      case AudioServiceRepeatMode.group: return AudioServiceRepeatMode.none;
    }
  }

  Widget _buildPlayPauseButton(AudioHandler handler, bool isPlaying) {
    return GestureDetector(
      onTap: () => isPlaying ? handler.pause() : handler.play(),
      child: Container(
        height: 80.w,
        width: 80.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.2),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 52.sp,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(BuildContext context, PlaylistBloc playlistBloc, MediaItem item) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 24.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(32.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          BlocBuilder<PlaylistBloc, PlaylistState>(
            bloc: playlistBloc,
            builder: (context, state) {
              bool isLiked = false;
              if (state is PlaylistSuccess) {
                isLiked = state.favouriteSongPaths.contains(item.id);
              }
              return _ToolbarButton(
                icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                iconColor: isLiked ? Colors.redAccent : null,
                label: "LIKE",
                onPressed: () {
                  playlistBloc.add(ToggleFavouriteEvent(item.id));
                },
              );
            },
          ),
          _ToolbarButton(
            icon: Icons.playlist_add_rounded, 
            label: "ADD", 
            onPressed: () => _showPlaylistSelector(context, playlistBloc, item.id),
          ),
          _ToolbarButton(
            icon: Icons.wallpaper_rounded, 
            label: "BG", 
            onPressed: () => _showBackgroundSettings(context),
          ),
          _ToolbarButton(
            icon: Icons.graphic_eq_rounded, 
            label: "EQ", 
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const EqualizerSheet(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPlaylistSelector(BuildContext context, PlaylistBloc playlistBloc, String songPath) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32.r))),
      builder: (sheetContext) {
        return BlocBuilder<PlaylistBloc, PlaylistState>(
          bloc: playlistBloc,
          builder: (context, state) {
            if (state is! PlaylistSuccess) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            
            return Container(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Add to Playlist", style: GoogleFonts.lexendDeca(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 20.h),
                  if (state.playlists.isEmpty)
                    Center(child: Text("No playlists created yet", style: TextStyle(color: Colors.white.withValues(alpha: 0.3))))
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: state.playlists.length,
                        itemBuilder: (context, idx) {
                          final p = state.playlists[idx];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: AppColors.taupeDark.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: const Icon(Icons.playlist_add_rounded, color: AppColors.taupeLight),
                            ),
                            title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            subtitle: Text("${p.songPaths.length} tracks", style: TextStyle(color: AppColors.greyBase, fontSize: 11.sp)),
                            onTap: () {
                              playlistBloc.add(AddSongToPlaylistEvent(p.id, songPath));
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
                    ),
                  SizedBox(height: 10.h),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback onPressed;

  const _ToolbarButton({required this.icon, this.iconColor, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor ?? Colors.white.withValues(alpha: 0.7), size: 22.sp),
          SizedBox(height: 6.h),
          Text(
            label,
            style: GoogleFonts.lexendDeca(color: Colors.white.withValues(alpha: 0.3), fontSize: 9.sp, fontWeight: FontWeight.w600, letterSpacing: 1.0),
          ),
        ],
      ),
    );
  }
}
