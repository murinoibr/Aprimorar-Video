import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/engine/engine_providers.dart';
import '../../../core/media/media_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_x.dart';
import '../../../shared/widgets/media_widgets.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../application/trim_controller.dart';
import '../application/trim_state.dart';
import 'widgets/trim_timeline.dart';
import 'widgets/trim_widgets.dart';

class TrimPage extends ConsumerWidget {
  const TrimPage({super.key});

  static Future<void> pick(BuildContext context, WidgetRef ref) async {
    final asset = await pickSafely(
      context,
      () => ref.read(mediaPickerProvider).pickVideo(),
    );
    if (asset == null) return;
    await ref.read(trimControllerProvider.notifier).selectSource(asset);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trimControllerProvider);
    final controller = ref.read(trimControllerProvider.notifier);
    final source = state.source;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CORTE · TRECHOS · EXPORT',
                          style: AppTheme.label,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cortar',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  if (source != null && !state.isRendering)
                    TextButton(
                      onPressed: controller.clearSource,
                      child: const Text('Trocar'),
                    ),
                ],
              ),
            ),
            if (source == null)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    ImportStage(
                      title: 'Escolha um vídeo para começar',
                      message:
                          'Divida em trechos, arraste as bordas e junte tudo. '
                          'Só os trechos são processados: rápido até em vídeos longos.',
                      icon: Icons.content_cut_rounded,
                      onTap: () => pick(context, ref),
                    ),
                  ],
                ),
              )
            else ...[
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Viewfinder(
                    topLeft: HudText(
                      state.isRendering ? 'REC' : 'PLAY',
                      dot: state.isRendering
                          ? AppColors.accent
                          : AppColors.success,
                    ),
                    topRight: HudText(source.tierLabel),
                    child: Center(
                      child: TrimPreviewPlayer(
                        key: ValueKey(source.path),
                        sourcePath: source.path,
                        segment: state.activeSegment,
                        playhead: state.playhead,
                        seekToken: state.seekToken,
                        onPosition: controller.setPlayhead,
                      ),
                    ),
                  ),
                ),
              ),
              _EditorDeck(state: state),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditorDeck extends ConsumerWidget {
  const _EditorDeck({required this.state});

  final TrimState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(trimControllerProvider.notifier);
    final source = state.source!;
    final plan = state.plan;

    Widget bottom;
    if (state.isRendering) {
      bottom = RenderProgressPanel(
        fraction: state.progress,
        title: plan.segments.length > 1
            ? 'Exportando ${plan.segments.length} trechos'
            : 'Exportando corte',
        detail: state.settings.label,
        onCancel: controller.cancel,
      );
    } else if (state.status == TrimStatus.done && state.result != null) {
      bottom = ResultPanel(
        assets: [state.result!],
        feature: 'Cortar',
        onAgain: controller.dismissResult,
        againLabel: 'Editar',
      );
    } else {
      bottom = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.errorMessage != null) ...[
            InlineError(state.errorMessage!),
            const SizedBox(height: 10),
          ],
          PrimaryButton(
            label: 'Exportar ${plan.totalLength.clock}',
            icon: Icons.movie_creation_outlined,
            enabled: !state.isEmpty,
            onPressed: () async {
              final settings = await showExportSheet(
                context,
                initial: state.settings,
              );
              if (settings == null) return;
              controller.setSettings(settings);
              await controller.render();
            },
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                state.playhead.clock,
                style: AppTheme.timecode.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
              Text(
                ' / ${state.sourceDuration.clock}',
                style: AppTheme.timecode,
              ),
              const Spacer(),
              Text(
                '${plan.segments.length} ${plan.segments.length == 1 ? 'trecho' : 'trechos'}'
                '  ·  ${plan.totalLength.clock}',
                style: AppTheme.timecode.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TrimTimeline(
            sourceDuration: state.sourceDuration,
            segments: state.segments,
            activeIndex: state.activeIndex,
            playhead: state.playhead,
            filmstripPath: ref
                .watch(
                  filmstripProvider((
                    source.path,
                    state.sourceDuration.inMilliseconds,
                  )),
                )
                .value,
            onSeek: (position) => controller.setPlayhead(position, seek: true),
            onSelect: controller.setActive,
            onDragStart: controller.checkpoint,
            onEdgeChanged: controller.updateActiveEdges,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Tool(
                icon: Icons.undo_rounded,
                label: 'Desfazer',
                enabled: state.canUndo,
                onTap: controller.undo,
              ),
              _Tool(
                icon: Icons.redo_rounded,
                label: 'Refazer',
                enabled: state.canRedo,
                onTap: controller.redo,
              ),
              _Tool(
                icon: Icons.content_cut_rounded,
                label: 'Dividir',
                enabled: state.canSplit,
                primary: true,
                onTap: controller.splitAtPlayhead,
              ),
              _Tool(
                icon: Icons.delete_outline_rounded,
                label: 'Excluir',
                enabled: state.segments.length > 1,
                onTap: controller.removeActive,
              ),
              _Tool(
                icon: Icons.filter_center_focus_rounded,
                label: 'Só este',
                enabled: state.segments.length > 1,
                onTap: controller.keepOnlyActive,
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: bottom,
          ),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppColors.textMuted.withValues(alpha: 0.5)
        : primary
        ? AppColors.primary
        : AppColors.textPrimary;
    return InkWell(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 62,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 10.5)),
            ],
          ),
        ),
      ),
    );
  }
}
