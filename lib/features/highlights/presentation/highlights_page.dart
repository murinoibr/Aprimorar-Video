import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_x.dart';
import '../../../shared/widgets/media_widgets.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../application/highlights_controller.dart';
import '../application/highlights_state.dart';
import '../domain/entities/moment.dart';
import '../domain/entities/target_duration.dart';
import 'widgets/energy_timeline.dart';

class HighlightsPage extends ConsumerWidget {
  const HighlightsPage({super.key});

  static Future<void> pick(BuildContext context, WidgetRef ref) async {
    final asset = await pickSafely(
      context,
      () => ref.read(mediaPickerProvider).pickVideo(),
    );
    if (asset == null) return;
    await ref.read(highlightsControllerProvider.notifier).selectSource(asset);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(highlightsControllerProvider);
    final controller = ref.read(highlightsControllerProvider.notifier);
    final source = state.source;
    final plan = state.plan;
    final chosen = {for (final m in plan.moments) m.id};

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
                          'ÁUDIO · CENAS · RITMO',
                          style: AppTheme.label,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Momentos',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  if (source != null && !state.isBusy)
                    TextButton(
                      onPressed: controller.clearSource,
                      child: const Text('Trocar'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (source == null)
                    ImportStage(
                      title: 'Escolha um vídeo longo',
                      message:
                          'O app escuta o áudio e lê as cenas para montar o corte '
                          'perfeito no tempo que você quiser.',
                      icon: Icons.auto_awesome_rounded,
                      onTap: () => pick(context, ref),
                    )
                  else ...[
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Viewfinder(
                        topLeft: HudText(
                          state.status == HighlightsStatus.analyzing
                              ? 'ANALISANDO'
                              : 'FONTE',
                          dot: state.status == HighlightsStatus.analyzing
                              ? AppColors.accent
                              : AppColors.success,
                        ),
                        topRight: HudText(state.sourceDuration.clock),
                        child: MediaThumb(asset: source, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      source.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      techLine(source),
                      style: AppTheme.timecode.copyWith(fontSize: 11),
                    ),
                    const SectionLabel('Duração do corte'),
                    ChoiceRow<TargetDuration>(
                      values: TargetDuration.values,
                      selected: state.target,
                      label: (t) => t.label,
                      onChanged: controller.setTarget,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${state.target.longLabel} · ${state.target.hint}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (state.status == HighlightsStatus.analyzing) ...[
                      const SizedBox(height: 18),
                      RenderProgressPanel(
                        fraction: state.progress,
                        title: state.stage.label,
                        detail: 'Lendo só quadros-chave: rápido mesmo em vídeo longo',
                        onCancel: controller.cancel,
                      ),
                    ] else if (state.isAnalyzed) ...[
                      SectionLabel(
                        'Mapa de energia',
                        trailing: Text(
                          '${plan.moments.length} momentos · ${plan.totalLength.clock}',
                          style: AppTheme.timecode.copyWith(fontSize: 11),
                        ),
                      ),
                      EnergyTimeline(
                        duration: state.sourceDuration,
                        signals: state.signals,
                        moments: state.candidates,
                        chosen: chosen,
                      ),
                      const SizedBox(height: 8),
                      _Legend(plan: state),
                      const SectionLabel('Momentos encontrados'),
                      if (state.candidates.isEmpty)
                        const Text(
                          'Nenhum momento claro. Tente uma duração menor.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      for (final moment in state.candidates)
                        _MomentRow(
                          moment: moment,
                          inPlan: chosen.contains(moment.id),
                          excluded: state.excluded.contains(moment.id),
                          onToggle: () => controller.toggleMoment(moment.id),
                        ),
                    ] else if (state.status == HighlightsStatus.failure) ...[
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Analisar de novo',
                        icon: Icons.refresh_rounded,
                        onPressed: controller.analyze,
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (source != null && state.status != HighlightsStatus.analyzing)
              _HighlightsActionBar(state: state),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.plan});

  final HighlightsState plan;

  @override
  Widget build(BuildContext context) {
    final p = plan.plan;
    final saved = (1 - p.compressionRatio) * 100;
    return Row(
      children: [
        _dot(AppColors.primary),
        const Text(
          ' no corte   ',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        _dot(AppColors.textMuted),
        const Text(
          ' fora   ',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        _dot(AppColors.teal),
        const Text(
          ' corte de cena',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const Spacer(),
        if (p.moments.isNotEmpty)
          Text(
            '−${saved.clamp(0, 100).round()}%',
            style: AppTheme.timecode.copyWith(color: AppColors.primary),
          ),
      ],
    );
  }

  Widget _dot(Color color) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({
    required this.moment,
    required this.inPlan,
    required this.excluded,
    required this.onToggle,
  });

  final Moment moment;
  final bool inPlan;
  final bool excluded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = inPlan ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              child: Text(
                '${moment.start.clock}–${moment.end.clock}',
                style: AppTheme.timecode.copyWith(
                  color: excluded ? AppColors.textMuted : AppColors.textPrimary,
                  decoration: excluded ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    moment.topSignal?.label ?? 'Momento',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: excluded
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: moment.score,
                      minHeight: 2,
                      color: color,
                      backgroundColor: AppColors.surfaceTop,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('${moment.length.inSeconds}s', style: AppTheme.timecode),
            const SizedBox(width: 8),
            Icon(
              excluded
                  ? Icons.radio_button_unchecked_rounded
                  : inPlan
                  ? Icons.check_circle_rounded
                  : Icons.remove_circle_outline_rounded,
              size: 20,
              color: excluded ? AppColors.textMuted : color,
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightsActionBar extends ConsumerWidget {
  const _HighlightsActionBar({required this.state});

  final HighlightsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(highlightsControllerProvider.notifier);
    final Widget content;

    if (state.status == HighlightsStatus.exporting) {
      content = RenderProgressPanel(
        fraction: state.progress,
        title: 'Montando ${state.plan.moments.length} momentos',
        detail: 'Só os trechos escolhidos são processados',
        onCancel: controller.cancel,
      );
    } else if (state.status == HighlightsStatus.done && state.result != null) {
      content = ResultPanel(
        assets: [state.result!],
        feature: 'Momentos',
        onAgain: () => _export(context, ref),
        againLabel: 'Refazer',
      );
    } else {
      final plan = state.plan;
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.errorMessage != null) ...[
            InlineError(state.errorMessage!),
            const SizedBox(height: 10),
          ],
          PrimaryButton(
            label: plan.moments.isEmpty
                ? 'Exportar momentos'
                : 'Exportar ${plan.totalLength.clock} · ${state.settings.format.ratio}',
            icon: Icons.movie_creation_outlined,
            enabled: state.isAnalyzed && plan.moments.isNotEmpty,
            onPressed: () => _export(context, ref),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: content,
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(highlightsControllerProvider.notifier);
    final settings = await showExportSheet(
      context,
      initial: ref.read(highlightsControllerProvider).settings,
      action: 'Exportar momentos',
    );
    if (settings == null) return;
    controller.setSettings(settings);
    await controller.export();
  }
}
