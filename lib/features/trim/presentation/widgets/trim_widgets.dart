import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_x.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/entities/clip_segment.dart';

class TrimPreviewPlayer extends StatefulWidget {
  const TrimPreviewPlayer({
    super.key,
    required this.sourcePath,
    required this.segment,
    required this.playhead,
    required this.seekToken,
    required this.onPosition,
  });

  final String sourcePath;
  final ClipSegment? segment;
  final Duration playhead;
  final int seekToken;
  final ValueChanged<Duration> onPosition;

  @override
  State<TrimPreviewPlayer> createState() => _TrimPreviewPlayerState();
}

class _TrimPreviewPlayerState extends State<TrimPreviewPlayer> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.file(File(widget.sourcePath));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      final segment = widget.segment;
      if (segment != null) await controller.seekTo(segment.start);
      await controller.play();
    } catch (error) {
      _error = error;
    }
    controller.addListener(_tick);
    if (!mounted) return;
    setState(() {});
  }

  void _tick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final segment = widget.segment;
    if (segment != null && controller.value.position >= segment.end) {
      controller.seekTo(segment.start);
      if (!controller.value.isPlaying) controller.play();
      return;
    }
    widget.onPosition(controller.value.position);
  }

  void _seek(Duration position) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    controller.seekTo(position);
    if (!controller.value.isPlaying) controller.play();
  }

  @override
  void didUpdateWidget(TrimPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seekToken != oldWidget.seekToken) {
      _seek(widget.playhead);
      return;
    }
    final segment = widget.segment;
    if (segment == null || segment == oldWidget.segment) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final position = controller.value.position;
    if (position < segment.start || position >= segment.end) {
      _seek(segment.start);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_tick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null) return _shell(aspectRatio: 16 / 9, child: _fallback());
    if (controller == null || !controller.value.isInitialized) {
      return _shell(
        aspectRatio: 16 / 9,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return _shell(
      aspectRatio: controller.value.aspectRatio,
      child: _preview(controller),
    );
  }

  Widget _shell({required double aspectRatio, required Widget child}) =>
      AspectRatio(aspectRatio: aspectRatio, child: child);

  Widget _fallback() => const Center(
    child: Icon(
      Icons.videocam_off_outlined,
      color: AppColors.textMuted,
      size: 32,
    ),
  );

  Widget _preview(VideoPlayerController controller) {
    final segment = widget.segment;
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        Positioned(
          left: 4,
          bottom: 4,
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) => IconButton(
              onPressed: () =>
                  value.isPlaying ? controller.pause() : controller.play(),
              icon: Icon(
                value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 14,
          child: HudText(
            segment == null
                ? '—'
                : '${widget.playhead.clock}  ·  ${segment.length.clock}',
            dot: AppColors.accent,
          ),
        ),
      ],
    );
  }
}
