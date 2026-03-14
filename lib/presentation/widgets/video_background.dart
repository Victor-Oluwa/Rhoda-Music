import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MediaBackground extends StatefulWidget {
  final String? assetPath;
  final String? filePath;
  final bool showBlur;

  const MediaBackground({
    super.key,
    this.assetPath,
    this.filePath,
    this.showBlur = true,
  });

  @override
  State<MediaBackground> createState() => _MediaBackgroundState();
}

class _MediaBackgroundState extends State<MediaBackground> {
  VideoPlayerController? _controller;
  bool _isImage = false;
  bool _hasError = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  @override
  void didUpdateWidget(MediaBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath || oldWidget.assetPath != widget.assetPath) {
      _initializeMedia();
    }
  }

  void _initializeMedia() {
    _disposeController();
    
    if (mounted) {
      setState(() {
        _hasError = false;
        _isInitialized = false;
      });
    }

    final path = widget.filePath ?? widget.assetPath;
    if (path == null) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    final ext = path.toLowerCase().split('.').last;
    _isImage = ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext);

    if (!_isImage) {
      final options = VideoPlayerOptions(mixWithOthers: true);
      try {
        _controller = widget.filePath != null
            ? VideoPlayerController.file(File(widget.filePath!), videoPlayerOptions: options)
            : VideoPlayerController.asset(widget.assetPath!, videoPlayerOptions: options);

        _controller!.initialize().then((_) {
          if (mounted) {
            _controller!.setLooping(true);
            _controller!.setVolume(0);
            _controller!.play();
            setState(() => _isInitialized = true);
          }
        }).catchError((error) {
          debugPrint("MediaBackground: Video Init Error: $error");
          if (mounted) setState(() => _hasError = true);
        });
      } catch (e) {
        debugPrint("MediaBackground: Controller Setup Error: $e");
        if (mounted) setState(() => _hasError = true);
      }
    } else {
      // For images, we can consider them initialized immediately
      if (mounted) setState(() => _isInitialized = true);
    }
  }

  void _disposeController() {
    final oldController = _controller;
    _controller = null;
    if (oldController != null) {
      oldController.pause().then((_) {
        oldController.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(color: const Color(0xFF121212));
    }

    if (!_isInitialized) {
      return Container(color: Colors.black);
    }

    Widget content;
    if (_isImage) {
      content = widget.filePath != null
          ? Image.file(
              File(widget.filePath!),
              fit: BoxFit.cover,
              cacheWidth: 1080,
            )
          : Image.asset(
              widget.assetPath!,
              fit: BoxFit.cover,
            );
    } else {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) {
        return Container(color: Colors.black);
      }
      content = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      );
    }

    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned.fill(
            child: widget.showBlur
                ? ImageFiltered(
                    // Very light blur to keep Mali GPU happy
                    imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: content,
                  )
                : content,
          ),
          // Gradient overlay for better UI visibility
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }
}
