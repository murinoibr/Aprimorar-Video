import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/engine/engine_providers.dart';
import '../../../core/engine/ffmpeg_render_engine.dart';
import '../../../core/engine/render_job.dart';
import '../../../core/media/media_asset.dart';
import '../../../core/media/media_providers.dart';
import '../data/ffmpeg_enhance_repository.dart';
import '../domain/entities/enhance_job.dart';
import '../domain/entities/enhance_options.dart';
import '../domain/repositories/enhance_repository.dart';

enum EnhanceStatus { idle, running, done, failure }

class EnhanceState {
  const EnhanceState({
    this.sources = const [],
    this.selected = 0,
    this.options = const EnhanceOptions(),
    this.status = EnhanceStatus.idle,
    this.stage = EnhanceStage.idle,
    this.progress = 0,
    this.etaSeconds,
    this.currentIndex = 0,
    this.results = const [],
    this.errorMessage,
  });

  final List<MediaAsset> sources;

  /// Fonte mostrada na prévia.
  final int selected;
  final EnhanceOptions options;
  final EnhanceStatus status;
  final EnhanceStage stage;
  final double progress;
  final int? etaSeconds;
  final int currentIndex;
  final List<MediaAsset> results;
  final String? errorMessage;

  bool get hasSources => sources.isNotEmpty;

  bool get isRunning => status == EnhanceStatus.running;

  bool get hasVideo => sources.any((s) => s.isVideo);

  MediaAsset? get current =>
      sources.isEmpty ? null : sources[selected.clamp(0, sources.length - 1)];

  EnhanceState copyWith({
    List<MediaAsset>? sources,
    int? selected,
    EnhanceOptions? options,
    EnhanceStatus? status,
    EnhanceStage? stage,
    double? progress,
    int? etaSeconds,
    bool clearEta = false,
    int? currentIndex,
    List<MediaAsset>? results,
    String? errorMessage,
    bool clearError = false,
  }) => EnhanceState(
    sources: sources ?? this.sources,
    selected: selected ?? this.selected,
    options: options ?? this.options,
    status: status ?? this.status,
    stage: stage ?? this.stage,
    progress: progress ?? this.progress,
    etaSeconds: clearEta ? null : (etaSeconds ?? this.etaSeconds),
    currentIndex: currentIndex ?? this.currentIndex,
    results: results ?? this.results,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

final enhanceRepositoryProvider = Provider<EnhanceRepository>(
  (ref) => FfmpegEnhanceRepository(
    engine: ref.watch(renderEngineProvider),
    probe: ref.watch(mediaProbeProvider),
    codec: FfmpegRenderEngine.defaultCodec,
    staging: ref.watch(renderStagingProvider),
  ),
);

final enhanceControllerProvider =
    NotifierProvider<EnhanceController, EnhanceState>(EnhanceController.new);

class EnhanceController extends Notifier<EnhanceState> {
  StreamSubscription<EnhanceProgress>? _subscription;

  @override
  EnhanceState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const EnhanceState();
  }

  EnhanceRepository get _repository => ref.read(enhanceRepositoryProvider);

  /// Adiciona arquivos ao lote, já com medidas (a receita precisa delas para
  /// decidir upscale e a prévia para enquadrar).
  Future<void> addSources(List<MediaAsset> assets) async {
    if (assets.isEmpty || state.isRunning) return;
    final probe = ref.read(mediaProbeProvider);
    final probed = <MediaAsset>[];
    for (final asset in assets) {
      probed.add(await probe.enrich(asset));
    }
    final known = state.sources.map((s) => s.path).toSet();
    final merged = [
      ...state.sources,
      ...probed.where((a) => !known.contains(a.path)),
    ];
    state = state.copyWith(
      sources: merged,
      selected: state.sources.isEmpty ? 0 : state.selected,
      status: EnhanceStatus.idle,
      results: const [],
      clearError: true,
    );
  }

  void select(int index) {
    if (index < 0 || index >= state.sources.length) return;
    state = state.copyWith(selected: index);
  }

  void removeSource(MediaAsset source) {
    if (state.isRunning) return;
    final next = state.sources.where((s) => s.path != source.path).toList();
    state = state.copyWith(
      sources: next,
      selected: state.selected.clamp(0, next.isEmpty ? 0 : next.length - 1),
      status: EnhanceStatus.idle,
      results: const [],
    );
  }

  void clear() {
    if (state.isRunning) return;
    state = EnhanceState(options: state.options);
  }

  void updateOptions(EnhanceOptions options) {
    state = state.copyWith(
      options: options,
      status: state.status == EnhanceStatus.done ? EnhanceStatus.idle : null,
      clearError: true,
    );
  }

  Future<void> run() async {
    if (state.sources.isEmpty || state.isRunning) return;

    _subscription?.cancel();
    state = state.copyWith(
      status: EnhanceStatus.running,
      stage: EnhanceStage.preparing,
      progress: 0,
      currentIndex: 0,
      results: const [],
      clearEta: true,
      clearError: true,
    );

    final repository = _repository;
    final done = Completer<void>();
    _subscription = repository
        .enhance(state.sources, state.options)
        .listen(
          (progress) {
            state = state.copyWith(
              stage: progress.stage,
              progress: progress.percent,
              etaSeconds: progress.etaSeconds,
              clearEta: progress.etaSeconds == null,
              currentIndex: progress.index,
            );
          },
          onError: (Object error) {
            state = state.copyWith(
              status: EnhanceStatus.failure,
              errorMessage: _messageFor(error),
            );
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (state.status == EnhanceStatus.running) {
              final results = repository.results;
              state = results.isEmpty
                  ? state.copyWith(
                      status: EnhanceStatus.failure,
                      errorMessage: 'Nada foi gerado. Tente de novo.',
                    )
                  : state.copyWith(
                      status: EnhanceStatus.done,
                      stage: EnhanceStage.done,
                      progress: 1,
                      clearEta: true,
                      results: results,
                    );
            }
            if (!done.isCompleted) done.complete();
          },
        );
    await done.future;
  }

  String _messageFor(Object error) {
    if (error is RenderCancelled) return 'Cancelado.';
    if (error is RenderFailure) return error.message;
    return 'Falha ao aprimorar: $error';
  }

  void cancel() {
    _repository.cancel();
    _subscription?.cancel();
    state = state.copyWith(
      status: EnhanceStatus.idle,
      stage: EnhanceStage.idle,
      progress: 0,
      clearEta: true,
    );
  }
}
