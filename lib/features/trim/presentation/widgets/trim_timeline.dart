import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_x.dart';
import '../../domain/entities/clip_segment.dart';

class TrimTimeline extends StatelessWidget {
  const TrimTimeline({
    super.key,
    required this.sourceDuration,
    required this.segments,
    required this.activeIndex,
    required this.playhead,
    required this.onSeek,
    required this.onSelect,
    required this.onDragStart,
    required this.onEdgeChanged,
    this.filmstripPath,
  });

  final Duration sourceDuration;
  final List<ClipSegment> segments;
  final int activeIndex;
  final Duration playhead;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<int> onSelect;
  final VoidCallback onDragStart;
  final void Function({Duration? start, Duration? end}) onEdgeChanged;

  /// Tira de quadros do vídeo; sem ela, uma forma de onda decorativa.
  final String? filmstripPath;

  static const double rulerHeight = 20;
  static const double trackHeight = 58;
  static const double _handleWidth = 16;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final totalMs = sourceDuration.inMilliseconds;
        if (width <= 0 || totalMs <= 0) {
          return const SizedBox(height: rulerHeight + trackHeight);
        }

        double x(Duration position) =>
            position.inMilliseconds / totalMs * width;
        Duration position(double dx) => Duration(
          milliseconds: (dx / width * totalMs).round().clamp(0, totalMs),
        );

        final active = activeIndex >= 0 && activeIndex < segments.length
            ? segments[activeIndex]
            : null;
        final playheadX = x(playhead);
        return SizedBox(
          height: rulerHeight + trackHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                _scrub(details.localPosition.dx, x, position),
            onHorizontalDragStart: (details) {
              onDragStart();
              _scrub(details.localPosition.dx, x, position);
            },
            onHorizontalDragUpdate: (details) =>
                _scrub(details.localPosition.dx, x, position),
            child: Stack(
              children: [
                _Ruler(
                  sourceDuration: sourceDuration,
                  step: _stepFor(width),
                  x: x,
                ),
                Positioned(
                  top: rulerHeight + 6,
                  left: 0,
                  right: 0,
                  height: trackHeight - 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: filmstripPath == null
                        ? const _Waveform(color: AppColors.surfaceTop)
                        : Opacity(
                            opacity: 0.55,
                            child: Image.file(
                              File(filmstripPath!),
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              errorBuilder: (_, _, _) =>
                                  const _Waveform(color: AppColors.surfaceTop),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: rulerHeight + 6,
                  left: 0,
                  right: 0,
                  height: trackHeight - 12,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                for (var i = 0; i < segments.length; i++)
                  Positioned(
                    top: rulerHeight + 7,
                    left: x(segments[i].start),
                    width: (x(segments[i].end) - x(segments[i].start)).clamp(
                      2.0,
                      width,
                    ),
                    height: trackHeight - 14,
                    child: _SegmentBar(isActive: i == activeIndex),
                  ),
                if (active case final segment?) ...[
                  _EdgeHandle(
                    label: segment.start.clock,
                    alignment: Alignment.centerLeft,
                    left: x(segment.start) - _handleWidth / 2,
                    onDragStart: onDragStart,
                    onDrag: (dx) =>
                        onEdgeChanged(start: position(x(segment.start) + dx)),
                  ),
                  _EdgeHandle(
                    label: segment.end.clock,
                    alignment: Alignment.centerRight,
                    left: x(segment.end) - _handleWidth / 2,
                    onDragStart: onDragStart,
                    onDrag: (dx) =>
                        onEdgeChanged(end: position(x(segment.end) + dx)),
                  ),
                ],
                Positioned(
                  top: rulerHeight - 6,
                  bottom: 0,
                  left: playheadX - 1,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scrub(
    double dx,
    double Function(Duration) x,
    Duration Function(double) position,
  ) {
    final target = position(dx.clamp(0.0, double.infinity));
    onSeek(target);
    final index = TrimTimeline.indexAt(segments, target);
    if (index != null && index != activeIndex) onSelect(index);
  }

  static int? indexAt(List<ClipSegment> segments, Duration position) {
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].contains(position)) return i;
    }
    return null;
  }

  static Duration _stepFor(double width) {
    final seconds = (width / 60).round().clamp(2, 12);
    const steps = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600];
    for (final step in steps) {
      if (seconds <= step) return Duration(seconds: step);
    }
    return const Duration(hours: 1);
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.35),
          width: isActive ? 2 : 1,
        ),
      ),
    );
  }
}

class _EdgeHandle extends StatelessWidget {
  const _EdgeHandle({
    required this.label,
    required this.alignment,
    required this.left,
    required this.onDragStart,
    required this.onDrag,
  });

  final String label;
  final Alignment alignment;
  final double left;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: TrimTimeline.rulerHeight + 2,
      left: left,
      width: 16,
      height: TrimTimeline.trackHeight - 4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => onDragStart(),
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: Align(
          alignment: alignment,
          child: Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ruler extends StatelessWidget {
  const _Ruler({
    required this.sourceDuration,
    required this.step,
    required this.x,
  });

  final Duration sourceDuration;
  final Duration step;
  final double Function(Duration) x;

  @override
  Widget build(BuildContext context) {
    final stepMs = step.inMilliseconds <= 0 ? 1000 : step.inMilliseconds;
    final totalMs = sourceDuration.inMilliseconds;
    final labels = <Widget>[];
    for (var ms = 0; ms <= totalMs; ms += stepMs) {
      labels.add(
        Positioned(
          left: x(Duration(milliseconds: ms)) - 8,
          top: 0,
          child: Text(
            Duration(milliseconds: ms).clock,
            style: const TextStyle(
              fontSize: 9.5,
              color: AppColors.textMuted,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: TrimTimeline.rulerHeight,
      child: Stack(clipBehavior: Clip.none, children: labels),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bars = (constraints.maxWidth / 3).floor().clamp(1, 600);
        var seed = 20240117;
        final heights = List<double>.generate(bars, (i) {
          seed = (seed * 1103515 + 12345) % 1000003;
          return 0.15 + (seed % 1000) / 1000 * 0.85;
        });
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final factor in heights)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.6),
                  child: Container(
                    height: (constraints.maxHeight * factor).clamp(
                      2.0,
                      constraints.maxHeight,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
