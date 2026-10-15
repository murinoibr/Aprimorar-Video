import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'app_shell.dart';

/// Abertura de 1,8 s: as faixas de cinema fecham o quadro, o timecode corre e
/// a marca aparece — como o primeiro plano de um filme. Tudo desenhado em
/// código: nenhum asset, nenhum vídeo, zero KB a mais no app.
class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _intro =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1800),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _finished = true);
          }
        });
    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_finished) setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _finished
          ? const AppShell(key: ValueKey('app-shell'))
          : _buildIntro(),
    );
  }

  Widget _buildIntro() {
    return Scaffold(
      key: const ValueKey('launch-page'),
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _intro,
        builder: (context, _) {
          final t = _intro.value;
          final bars = Curves.easeInOutCubic.transform(
            (t / 0.45).clamp(0.0, 1.0),
          );
          final mark = Curves.easeOut.transform(
            ((t - 0.25) / 0.5).clamp(0.0, 1.0),
          );
          final frames = (t * 1.8 * 24).floor();
          final timecode =
              '00:00:${(frames ~/ 24).toString().padLeft(2, '0')}:${(frames % 24).toString().padLeft(2, '0')}';

          return LayoutBuilder(
            builder: (context, c) {
              final barHeight =
                  math.max(0.0, (c.maxHeight - c.maxWidth / 2.39) / 2) *
                  bars *
                  0.62;
              return Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.1),
                          radius: 0.9,
                          colors: [
                            Color.lerp(
                              Colors.black,
                              AppColors.primary,
                              0.14 * mark,
                            )!,
                            Colors.black,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: barHeight,
                    child: const ColoredBox(color: Color(0xFF000000)),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: barHeight,
                    child: const ColoredBox(color: Color(0xFF000000)),
                  ),
                  Center(
                    child: Opacity(
                      opacity: mark,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'VANGOGH',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w300,
                              color: AppColors.textPrimary,
                              letterSpacing: 4 + 8 * mark,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: 28 * mark,
                            height: 1.5,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'ESTÚDIO DE CINEMA NO SEU BOLSO',
                            style: AppTheme.label,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 8, 20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(
                                    alpha: (t * 6).floor().isEven ? 1 : 0.25,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('REC  $timecode', style: AppTheme.timecode),
                              const Spacer(),
                              TextButton(
                                onPressed: _continue,
                                child: const Text('Pular'),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              const Text('4K', style: AppTheme.label),
                              const SizedBox(width: 14),
                              const Text('24 FPS', style: AppTheme.label),
                              const SizedBox(width: 14),
                              const Text('2.39:1', style: AppTheme.label),
                              const Spacer(),
                              Text(
                                '${(t * 100).round()}%',
                                style: AppTheme.timecode,
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
