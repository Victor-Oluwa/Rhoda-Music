import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/audio/audio_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../bloc/playlist/playlist_bloc.dart';
import '../../bloc/playlist/playlist_event.dart';
import '../../bloc/playlist/playlist_state.dart';
import '../../providers/audio_providers.dart';
import '../../providers/bloc_providers.dart';
import '../../widgets/equalizer_sheet.dart';
import '../../widgets/video_background.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _visualizerController;
  String? _lastTrackPath;

  @override
  void initState() {
    super.initState();
    _visualizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _visualizerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = ref.watch(currentSongProvider).value;
    final playbackState = ref.watch(playbackStateProvider).value;
    final handler = ref.watch(audioHandlerProvider);
    final playlistBloc = ref.watch(playlistBlocProvider);

    // Side effect: Add to recent when track changes
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

    if (playing) {
      if (!_visualizerController.isAnimating) {
        _visualizerController.repeat();
      }
    } else {
      _visualizerController.stop();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(
            child: VideoBackground(
              assetPath: 'assets/videos/background_video.mp4',
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
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  _buildHeader(context),
                  const Spacer(flex: 3),
                  _buildVisualizer(playing),
                  const Spacer(flex: 3),
                  _buildTrackInfo(context, currentItem),
                  SizedBox(height: 30.h),
                  _buildProgressBar(handler, currentItem),
                  SizedBox(height: 20.h),
                  _buildMainControls(context, handler, playing, repeatMode, shuffleMode),
                  const Spacer(flex: 4),
                  _buildBottomToolbar(context, playlistBloc, currentItem),
                  SizedBox(height: 10.h),
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
      child: CustomPaint(
        size: Size(300.w, 180.h),
        painter: ModernVisualizerPainter(
          animation: _visualizerController,
          isPlaying: isPlaying,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildGlassIconButton(
            icon: Icons.keyboard_arrow_down_rounded,
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              Text(
                "NOW PLAYING",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 3.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                "Rhoda Music",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          _buildGlassIconButton(
            icon: Icons.graphic_eq_rounded,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const  EqualizerSheet(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({required IconData icon, required VoidCallback onPressed}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 26.sp),
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
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 24.sp,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 8.h),
        Text(
          item.artist?.toUpperCase() ?? "UNKNOWN ARTIST",
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressBar(AudioHandler handler, MediaItem item) {
    return StreamBuilder<Duration>(
      stream: AudioService.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = item.duration ?? Duration.zero;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5.h,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.r, elevation: 6),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 14.r),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                thumbColor: Colors.white,
                trackShape: const RectangularSliderTrackShape(),
              ),
              child: Slider(
                min: 0.0,
                max: duration.inMilliseconds.toDouble(),
                value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                onChanged: (value) {
                  handler.seek(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 22.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position), style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10.sp, fontWeight: FontWeight.w600)),
                  Text(_formatDuration(duration), style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10.sp, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainControls(BuildContext context, AudioHandler handler, bool playing, AudioServiceRepeatMode repeatMode, AudioServiceShuffleMode shuffleMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildShuffleButton(handler, shuffleMode),
        IconButton(
          onPressed: () => handler.skipToPrevious(),
          icon: Icon(Icons.skip_previous_rounded, size: 50.sp, color: Colors.white),
        ),
        _buildPlayPauseButton(handler, playing),
        IconButton(
          onPressed: () => handler.skipToNext(),
          icon: Icon(Icons.skip_next_rounded, size: 50.sp, color: Colors.white),
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
        color: isEnabled ? AppColors.primary : Colors.white.withValues(alpha: 0.4),
        size: 24.sp,
      ),
    );
  }

  Widget _buildRepeatButton(AudioHandler handler, AudioServiceRepeatMode repeatMode) {
    IconData icon;
    Color color;
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        icon = Icons.repeat_rounded;
        color = Colors.white.withValues(alpha: 0.4);
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
      icon: Icon(icon, color: color, size: 24.sp),
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
              color: Colors.white.withValues(alpha: 0.25),
              blurRadius: 35,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 55.sp,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(BuildContext context, PlaylistBloc playlistBloc, MediaItem item) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(28.r),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isLiked ? "Removed from Favorites" : "Added to Favorites"),
                      duration: const Duration(seconds: 1),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
              );
            },
          ),
          _ToolbarButton(
            icon: Icons.playlist_add_rounded, 
            label: "ADD", 
            onPressed: () => _showPlaylistSelector(context, playlistBloc, item.id),
          ),
          _ToolbarButton(icon: Icons.share_rounded, label: "SHARE", onPressed: () {}),
          _ToolbarButton(icon: Icons.lyrics_rounded, label: "LYRICS", onPressed: () {}),
        ],
      ),
    );
  }

  void _showPlaylistSelector(BuildContext context, PlaylistBloc playlistBloc, String songPath) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25.r))),
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
                  Text("Add to Playlist", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  SizedBox(height: 20.h),
                  if (state.playlists.isEmpty)
                    Center(child: Text("No playlists created yet", style: TextStyle(color: AppColors.greyBase.withValues(alpha: 0.5))))
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
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: const Icon(Icons.playlist_add_rounded, color: AppColors.taupeLight),
                            ),
                            title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            subtitle: Text("${p.songPaths.length} tracks", style: TextStyle(color: AppColors.greyBase, fontSize: 11.sp)),
                            onTap: () {
                              playlistBloc.add(AddSongToPlaylistEvent(p.id, songPath));
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.primary,
                                  content: Text("Added to ${p.name}", style: const TextStyle(color: Colors.white)),
                                ),
                              );
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }
}

class ModernVisualizerPainter extends CustomPainter {
  final Animation<double> animation;
  final bool isPlaying;
  final Color color;

  ModernVisualizerPainter({
    required this.animation,
    required this.isPlaying,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final barWidth = 4.w;
    final spacing = 6.w;
    final barCount = (size.width / (barWidth + spacing)).floor();
    
    final random = math.Random(42);

    for (int i = 0; i < barCount; i++) {
      double heightFactor;
      if (isPlaying) {
        final t = animation.value * 2 * math.pi;
        final variance = random.nextDouble();
        heightFactor = 0.2 + 0.8 * (math.sin(t + i * 0.4).abs() * variance);
      } else {
        heightFactor = 0.1;
      }

      final x = i * (barWidth + spacing);
      final h = size.height * heightFactor;
      final y = (size.height - h) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, h),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );

      if (isPlaying && heightFactor > 0.5) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 2, y - 2, barWidth + 4, h + 4),
            Radius.circular(barWidth / 2 + 2),
          ),
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ModernVisualizerPainter oldDelegate) => true;
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
          SizedBox(height: 5.h),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9.sp, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
