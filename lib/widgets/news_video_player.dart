import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class NewsVideoPlayer extends StatefulWidget {
  final String youtubeUrl;
  final bool isActive;

  const NewsVideoPlayer({super.key, required this.youtubeUrl, this.isActive = true});

  @override
  State<NewsVideoPlayer> createState() => _NewsVideoPlayerState();
}

class _NewsVideoPlayerState extends State<NewsVideoPlayer> {
  late YoutubePlayerController _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant NewsVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.youtubeUrl != widget.youtubeUrl) {
      _controller.close();
      _initController();
    }
    // Pause video if user navigates away from the tab
    if (oldWidget.isActive && !widget.isActive) {
      _controller.pauseVideo();
    }
  }

  void _initController() {
    final videoId = YoutubePlayerController.convertUrlToId(widget.youtubeUrl);
    
    if (videoId == null) {
      setState(() => _hasError = true);
      return;
    }

    _hasError = false;
    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 220,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Text(
          'Invalid YouTube Video URL',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: YoutubePlayer(
          controller: _controller,
        ),
      ),
    );
  }
}
