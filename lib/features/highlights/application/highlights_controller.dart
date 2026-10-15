import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/engine/engine_providers.dart';
import '../../../core/engine/ffmpeg_render_engine.dart';
import '../../../core/engine/render_job.dart';
import '../../../core/media/media_asset.dart';
import '../../../core/media/media_providers.dart';
import '../../../core/media/render_settings.dart';
import '../data/ffmpeg_highlight_repository.dart';
import '../domain/entities/analysis.dart';
import '../domain/entities/target_duration.dart';
import '../domain/repositories/highlight_repository.dart';
import '../domain/services/moment_detector.dart';
import 'highlights_state.dart';

final highlightRepositoryProvider = Provider<HighlightRepository>(
  (ref) => FfmpegHighlightRepository(
    engine: ref.watch(renderEngineProvider),
    probe: ref.watch(mediaProbeProvider),
    codec: FfmpegRenderEngine.defaultCodec,
    staging: ref.watch(renderStagingProvider),
  ),
);

final highlightsControllerProvider =
    NotifierProvider<HighlightsController, HighlightsState>(
      HighlightsController.new,
    );

class HighlightsController extends Notifier<HighlightsState> {
  StreamSubscription<Object?>? _subscription;

  @override
  HighlightsState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const HighlightsState();
  }

  HighlightRepository get _repository => ref.read(highlightRepositoryProvider);

  /// Escolhe o vídeo e já começa a análise: um toque a menos para o cliente.
  Future<void> selectSource(MediaAsset asset) async {
    _subscription?.cancel();
    final probed = await ref.read(mediaProbeProvider).enrich(asset);
    state = HighlightsState(
      source: probed,
      target: state.target,
      settings: state.settings,
    );
    await analyze();
  }

  void clearSource() {
    _repository.cancel();
    _subscription?.cancel();
    state = HighlightsState(target: state.target, settings: state.settings);
  }

  void setTarget(TargetDuration target) {
    if (target == state.target) return;
    state = state.copyWith(
      target: target,
      excluded: const {},
      clearResult: true,
    );
    _detect();
  }

  void setSettings(RenderSettings settings) {
    state = state.copyWith(settings: settings);
  }

  void toggleMoment(String id) {
    final next = {...state.excluded};
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(excluded: next);
  }

  void _detect() {
    final signals = state.signals;
    if (signals == null) return;
    state = state.copyWith(
      candidates: MomentDetector.detect(
        duration: state.sourceDuration,
        audio: signals.audio,
        scenes: signals.scenes,
        target: state.target,
      ),
    );
  }

  Future<void> analyze() async {
    final source = state.source;
    if (source == null || state.isBusy) return;

    _subscription?.cancel();
    state = state.copyWith(
      status: HighlightsStatus.analyzing,
      stage: AnalysisStage.abrindo,
      progress: 0,
      candidates: const [],
      excluded: const {},
      clearSignals: true,
      clearResult: true,
      clearError: true,
    );

    final done = Completer<void>();
    _subscription = _repository
        .analyze(source)
        .listen(
          (progress) {
            state = state.copyWith(
              stage: progress.stage,
              progress: progress.percent,
              signals: progress.signals,
            );
            if (progress.isFinished) {
              _detect();
              state = state.copyWith(status: HighlightsStatus.ready);
            }
          },
          onError: (Object error) {
            state = state.copyWith(
              status: HighlightsStatus.failure,
              errorMessage: _messageFor(error, 'Falha na análise'),
            );
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );
    await done.future;
  }

  Future<void> export() async {
    final source = state.source;
    if (source == null || state.isBusy) return;

    final plan = state.plan;
    if (plan.moments.isEmpty) {
      state = state.copyWith(errorMessage: 'Selecione ao menos um momento.');
      return;
    }

    _subscription?.cancel();
    state = state.copyWith(
      status: HighlightsStatus.exporting,
      progress: 0,
      clearResult: true,
      clearError: true,
    );

    final repository = _repository;
    _subscription = repository
        .export(source, plan, state.settings)
        .listen(
          (value) => state = state.copyWith(progress: value),
          onError: (Object error) {
            state = state.copyWith(
              status: HighlightsStatus.failure,
              errorMessage: _messageFor(error, 'Falha na exportação'),
            );
          },
          onDone: () async {
            if (state.status != HighlightsStatus.exporting) return;
            try {
              final result = await repository.buildResult(plan);
              state = state.copyWith(
                status: HighlightsStatus.done,
                progress: 1,
                result: result,
              );
            } on Object catch (error) {
              state = state.copyWith(
                status: HighlightsStatus.failure,
                errorMessage: _messageFor(error, 'Falha na exportação'),
              );
            }
          },
        );
  }

  String _messageFor(Object error, String prefix) {
    if (error is RenderCancelled) return 'Cancelado.';
    if (error is RenderFailure) return error.message;
    return '$prefix: $error';
  }

  void cancel() {
    _repository.cancel();
    _subscription?.cancel();
    state = state.copyWith(
      status: state.isAnalyzed ? HighlightsStatus.ready : HighlightsStatus.idle,
      progress: 0,
    );
  }
}
