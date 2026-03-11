import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoBackground extends StatefulWidget {
  final String? videoUrl;
  final String? assetPath;
  const VideoBackground({super.key, this.videoUrl, this.assetPath});

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  late VideoPlayerController _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    final options = VideoPlayerOptions(mixWithOthers: true);
    
    if (widget.assetPath != null) {
      _controller = VideoPlayerController.asset(widget.assetPath!, videoPlayerOptions: options);
    } else if (widget.videoUrl != null) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!), videoPlayerOptions: options);
    } else {
      _hasError = true;
      return;
    }

    _controller.initialize().then((_) {
      if (mounted) {
        _controller.setLooping(true);
        _controller.setVolume(0);
        _controller.play();
        setState(() {});
      }
    }).catchError((error) {
      debugPrint("VideoPlayer Error: $error");
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.white24, size: 40),
        ),
      );
    }

    return SizedBox.expand(
      child: _controller.value.isInitialized
          ? FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            )
          : Container(color: Colors.black),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
