import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/engine/engine_providers.dart';
import '../../../core/engine/render_job.dart';
import '../../../core/media/media_asset.dart';
import '../../../core/media/media_providers.dart';
import '../../../core/media/render_settings.dart';
import '../data/ffmpeg_trim_repository.dart';
import '../domain/entities/clip_segment.dart';
import '../domain/repositories/trim_repository.dart';
import '../domain/services/trim_editor.dart';
import 'trim_state.dart';

final trimRepositoryProvider = Provider<TrimRepository>(
  (ref) => FfmpegTrimRepository(
    engine: ref.watch(renderEngineProvider),
    probe: ref.watch(mediaProbeProvider),
  ),
);

final trimControllerProvider = NotifierProvider<TrimController, TrimState>(
  TrimController.new,
);

class TrimController extends Notifier<TrimState> {
  StreamSubscription<double>? _subscription;
  final List<List<ClipSegment>> _past = [];
  final List<List<ClipSegment>> _future = [];
  int _idCounter = 0;

  @override
  TrimState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const TrimState();
  }

  String _nextId() => 'seg${_idCounter++}';

  void _checkpoint() {
    _past.add(state.segments);
    if (_past.length > 60) _past.removeAt(0);
    _future.clear();
    state = state.copyWith(undoCount: _past.length, redoCount: _future.length);
  }

  Future<void> selectSource(MediaAsset asset) async {
    _subscription?.cancel();
    final probed = await ref.read(mediaProbeProvider).enrich(asset);
    final duration = probed.duration ?? const Duration(minutes: 1);
    _past.clear();
    _future.clear();
    _idCounter = 1;
    state = TrimState(
      source: probed,
      sourceDuration: duration,
      segments: TrimEditor.initial(sourceDuration: duration, id: _nextId()),
      settings: state.settings,
      status: TrimStatus.ready,
    );
  }

  void clearSource() {
    _subscription?.cancel();
    _past.clear();
    _future.clear();
    _idCounter = 0;
    state = TrimState(settings: state.settings);
  }

  void setSettings(RenderSettings settings) {
    if (settings == state.settings) return;
    state = state.copyWith(settings: settings);
  }

  void setActive(int index) {
    if (index < 0 || index >= state.segments.length) return;
    final segment = state.segments[index];
    state = state.copyWith(
      activeIndex: index,
      playhead: TrimEditor.clamp(state.playhead, segment.start, segment.end),
    );
  }

  void setPlayhead(Duration position, {bool seek = false}) {
    if (!state.hasSource) return;
    final clamped = TrimEditor.clamp(
      position,
      Duration.zero,
      state.sourceDuration,
    );
    final maxIndex = state.segments.isEmpty ? 0 : state.segments.length - 1;
    final found =
        TrimEditor.indexOfSegmentAt(
          state.segments,
          clamped,
          tolerance: TrimEditor.minSegment,
        ) ??
        state.activeIndex;
    state = state.copyWith(
      playhead: clamped,
      activeIndex: found.clamp(0, maxIndex),
      seekToken: seek ? state.seekToken + 1 : state.seekToken,
      clearError: true,
    );
  }

  void seekTo(Duration position) => setPlayhead(position, seek: true);

  void splitAtPlayhead() {
    if (!state.canSplit) return;
    final result = TrimEditor.split(
      segments: state.segments,
      position: state.playhead,
      sourceDuration: state.sourceDuration,
      idFor: _nextId,
      fps: state.source?.fps?.round(),
    );
    if (result.activeIndex < 0) {
      state = state.copyWith(
        errorMessage: 'Esse ponto está colado na borda do trecho.',
      );
      return;
    }
    _checkpoint();
    state = state.copyWith(
      segments: result.segments,
      activeIndex: result.activeIndex,
      clearError: true,
    );
  }

  void removeActive() {
    if (state.segments.isEmpty) return;
    final remaining = TrimEditor.removeAt(
      segments: state.segments,
      index: state.activeIndex,
      sourceDuration: state.sourceDuration,
    );
    if (remaining.isEmpty) {
      state = state.copyWith(
        errorMessage:
            'O corte não pode ficar vazio. Desfaça ou recarregue o vídeo.',
      );
      return;
    }
    _checkpoint();
    final maxIndex = remaining.length - 1;
    final index = state.activeIndex.clamp(0, maxIndex);
    state = state.copyWith(
      segments: remaining,
      activeIndex: index,
      playhead: TrimEditor.clamp(
        state.playhead,
        remaining[index].start,
        remaining[index].end,
      ),
      clearError: true,
    );
  }

  void keepOnlyActive() {
    if (state.segments.length < 2) return;
    _checkpoint();
    state = state.copyWith(
      segments: TrimEditor.keepOnly(
        segments: state.segments,
        index: state.activeIndex,
      ),
      activeIndex: 0,
      clearError: true,
    );
  }

  void restoreAll() {
    if (!state.hasSource) return;
    _checkpoint();
    _idCounter = 1;
    state = state.copyWith(
      segments: TrimEditor.initial(
        sourceDuration: state.sourceDuration,
        id: _nextId(),
      ),
      activeIndex: 0,
      playhead: Duration.zero,
      clearError: true,
    );
  }

  void checkpoint() => _checkpoint();

  void updateActiveEdges({Duration? start, Duration? end}) {
    final updated = TrimEditor.updateEdges(
      segments: state.segments,
      index: state.activeIndex,
      sourceDuration: state.sourceDuration,
      start: start,
      end: end,
      fps: state.source?.fps?.round(),
    );
    if (identical(updated, state.segments)) return;
    final segment = updated[state.activeIndex.clamp(0, updated.length - 1)];
    state = state.copyWith(
      segments: updated,
      activeIndex: state.activeIndex.clamp(0, updated.length - 1),
      playhead: TrimEditor.clamp(state.playhead, segment.start, segment.end),
    );
  }

  void undo() {
    if (_past.isEmpty) return;
    _future.add(state.segments);
    _apply(
      _past.removeLast(),
      undoCount: _past.length,
      redoCount: _future.length,
    );
  }

  void redo() {
    if (_future.isEmpty) return;
    _past.add(state.segments);
    _apply(
      _future.removeLast(),
      undoCount: _past.length,
      redoCount: _future.length,
    );
  }

  void _apply(
    List<ClipSegment> segments, {
    required int undoCount,
    required int redoCount,
  }) {
    if (segments.isEmpty) return;
    final maxIndex = segments.length - 1;
    final index = state.activeIndex.clamp(0, maxIndex);
    final segment = segments[index];
    state = state.copyWith(
      segments: segments,
      activeIndex: index,
      playhead: TrimEditor.clamp(state.playhead, segment.start, segment.end),
      seekToken: state.seekToken + 1,
      undoCount: undoCount,
      redoCount: redoCount,
      clearError: true,
    );
  }

  Future<void> render() async {
    final source = state.source;
    if (source == null || state.isEmpty || state.isRendering) return;

    _subscription?.cancel();
    state = state.copyWith(
      status: TrimStatus.rendering,
      progress: 0,
      clearError: true,
      clearResult: true,
    );

    final repository = _repository;
    final plan = state.plan;
    final settings = state.settings;

    _subscription = repository
        .render(source, plan, settings)
        .listen(
          (value) => state = state.copyWith(progress: value),
          onError: (Object error) => state = state.copyWith(
            status: TrimStatus.failure,
            progress: 0,
            errorMessage: _messageFor(error),
          ),
          onDone: () async {
            // O stream fecha mesmo depois de emitir erro: sem esta guarda, uma
            // exportação falha e em seguida vira "concluído" com resultado vazio.
            if (state.status != TrimStatus.rendering) return;
            try {
              final result = await repository.buildResult(settings);
              state = state.copyWith(
                status: TrimStatus.done,
                progress: 1,
                result: result,
              );
            } on Object catch (error) {
              state = state.copyWith(
                status: TrimStatus.failure,
                progress: 0,
                errorMessage: _messageFor(error),
              );
            }
          },
        );
  }

  /// Traduz falha do motor em texto que o cliente entende.
  ///
  /// Sem isto a tela mostraria `Instance of 'RenderFailure'`, que não ajuda
  /// ninguém a resolver o problema.
  String _messageFor(Object error) {
    if (error is RenderCancelled) return 'Exportação cancelada.';
    if (error is RenderFailure) return error.message;
    return 'Falha ao exportar: $error';
  }

  /// Fecha o painel de resultado e volta para a edição.
  void dismissResult() {
    state = state.copyWith(status: TrimStatus.ready, clearResult: true);
  }

  void cancel() {
    _repository.cancel();
    _subscription?.cancel();
    state = state.copyWith(status: TrimStatus.ready, progress: 0);
  }

  TrimRepository get _repository => ref.read(trimRepositoryProvider);
}
