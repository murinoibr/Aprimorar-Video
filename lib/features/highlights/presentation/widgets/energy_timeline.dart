import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/analysis.dart';
import '../../domain/entities/moment.dart';

/// Mapa de energia do vídeo: a curva de áudio, os cortes de cena e, por cima,
/// os momentos — dourados os que entram no corte, cinza os que ficaram fora.
/// O cliente enxerga *por que* aquele trecho foi escolhido.
class EnergyTimeline extends StatelessWidget {
  const EnergyTimeline({
    super.key,
    required this.duration,
    required this.signals,
    required this.moments,
    required this.chosen,
    this.height = 96,
  });

  final Duration duration;
  final AnalysisSignals? signals;
  final List<Moment> moments;
  final Set<String> chosen;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _EnergyPainter(
          seconds: duration.inMilliseconds / 1000,
          signals: signals,
          moments: moments,
          chosen: chosen,
        ),
      ),
    );
  }
}

class _EnergyPainter extends CustomPainter {
  _EnergyPainter({
    required this.seconds,
    required this.signals,
    required this.moments,
    required this.chosen,
  });

  final double seconds;
  final AnalysisSignals? signals;
  final List<Moment> moments;
  final Set<String> chosen;

  @override
  void paint(Canvas canvas, Size size) {
    if (seconds <= 0) return;
    final w = size.width;
    final h = size.height;
    double x(double t) => (t / seconds).clamp(0.0, 1.0) * w;

    final base = Paint()..color = AppColors.surfaceHigh;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      base,
    );

    // Momentos: faixas atrás da curva.
    for (final m in moments) {
      final on = chosen.contains(m.id);
      final rect = Rect.fromLTRB(
        x(m.start.inMilliseconds / 1000),
        0,
        math.max(
          x(m.end.inMilliseconds / 1000),
          x(m.start.inMilliseconds / 1000) + 2,
        ),
        h,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = on
              ? AppColors.primary.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.05),
      );
      canvas.drawRect(
        Rect.fromLTWH(rect.left, h - 3, rect.width, 3),
        Paint()..color = on ? AppColors.primary : AppColors.textMuted,
      );
    }

    // Cortes de cena: linhas finas.
    final cutPaint = Paint()
      ..color = AppColors.teal.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final s in signals?.scenes ?? const []) {
      if (s.value < 0.3) continue;
      final cx = x(s.seconds);
      canvas.drawLine(Offset(cx, 6), Offset(cx, h - 6), cutPaint);
    }

    // Curva de áudio, espelhada como forma de onda.
    final audio = signals?.audio ?? const [];
    if (audio.length > 2) {
      final finite =
          audio.where((s) => s.value.isFinite).map((s) => s.value).toList()
            ..sort();
      if (finite.isNotEmpty) {
        final lo = finite[(finite.length * 0.05).floor()];
        final hi =
            finite[(finite.length * 0.98).floor().clamp(0, finite.length - 1)];
        final range = math.max(hi - lo, 1.0);
        final mid = h / 2;
        final top = Path()..moveTo(0, mid);
        final bottom = <Offset>[];
        for (final s in audio) {
          final v = s.value.isFinite
              ? ((s.value - lo) / range).clamp(0.0, 1.0)
              : 0.0;
          final amp = v * (h / 2 - 8);
          top.lineTo(x(s.seconds), mid - amp);
          bottom.add(Offset(x(s.seconds), mid + amp));
        }
        for (final p in bottom.reversed) {
          top.lineTo(p.dx, p.dy);
        }
        top.close();
        canvas.drawPath(
          top,
          Paint()..color = AppColors.textPrimary.withValues(alpha: 0.28),
        );
      }
    } else {
      canvas.drawLine(
        Offset(0, h / 2),
        Offset(w, h / 2),
        Paint()
          ..color = AppColors.border
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EnergyPainter old) =>
      old.seconds != seconds ||
      old.signals != signals ||
      old.moments != moments ||
      old.chosen != chosen;
}
