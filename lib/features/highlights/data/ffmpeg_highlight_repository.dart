import 'dart:async';
import 'dart:io';

import '../../../core/engine/clip_assembler.dart';
import '../../../core/engine/command_builder.dart';
import '../../../core/engine/media_range.dart';
import '../../../core/engine/render_engine.dart';
import '../../../core/engine/render_job.dart';
import '../../../core/engine/staging.dart';
import '../../../core/media/media_asset.dart';
import '../../../core/media/media_probe.dart';
import '../../../core/media/render_settings.dart';
import '../domain/entities/analysis.dart';
import '../domain/entities/highlight_plan.dart';
import '../domain/repositories/highlight_repository.dart';
import '../domain/services/moment_detector.dart';

/// Melhores momentos de verdade: uma passada de análise no FFmpeg (áudio +
/// cenas) e export segmentado só dos trechos escolhidos.
class FfmpegHighlightRepository implements HighlightRepository {
  FfmpegHighlightRepository({
    required this.engine,
    required this.probe,
    required HwCodec codec,
    RenderStaging? staging,
  }) : _staging = staging ?? const RenderStaging(),
       _assembler = ClipAssembler(
         engine: engine,
         codec: codec,
         staging: staging,
       );

  final RenderEngine engine;
  final MediaProbe probe;
  final RenderStaging _staging;
  final ClipAssembler _assembler;

  bool _cancelled = false;
  String? _lastOutputPath;
  RenderSettings? _lastSettings;

  @override
  Stream<AnalysisProgress> analyze(MediaAsset source) async* {
    _cancelled = false;
    yield const AnalysisProgress(stage: AnalysisStage.abrindo, percent: 0.02);

    final hasAudio = await probe.hasAudio(source.path);
    final scenesPath = await _staging.newOutputPath(
      prefix: 'cenas',
      extension: 'txt',
    );
    final audioPath = await _staging.newOutputPath(
      prefix: 'audio',
      extension: 'txt',
    );

    try {
      final request = RenderRequest(
        arguments: FfmpegCommand.analyze(
          inputPath: source.path,
          scenesPath: scenesPath,
          audioPath: audioPath,
          sourceHasAudio: hasAudio,
        ),
        outputPath: scenesPath,
        expectedDurationMs: source.duration?.inMilliseconds ?? 0,
        label: 'Analisando',
        cleanupOnFailure: false,
        expectsOutput: false,
      );

      await for (final progress in engine.run(request)) {
        if (_cancelled) return;
        if (progress.stage == RenderStage.done) continue;
        yield AnalysisProgress(
          stage: AnalysisStage.lendoAudio,
          percent: 0.05 + progress.fraction * 0.85,
        );
      }
      if (_cancelled) return;

      yield const AnalysisProgress(
        stage: AnalysisStage.classificandoMomentos,
        percent: 0.94,
      );
      final scenes = MetadataParser.parse(
        await _read(scenesPath),
        'lavfi.scene_score',
      );
      final audio = hasAudio
          ? MetadataParser.parse(
              await _read(audioPath),
              'lavfi.astats.Overall.RMS_level',
            )
          : const <SignalSample>[];

      yield AnalysisProgress(
        stage: AnalysisStage.concluido,
        percent: 1,
        signals: AnalysisSignals(audio: audio, scenes: scenes),
      );
    } finally {
      _staging.discard(scenesPath);
      _staging.discard(audioPath);
    }
  }

  Future<String> _read(String path) async {
    final file = File(path);
    if (!file.existsSync()) return '';
    return file.readAsString();
  }

  @override
  Stream<double> export(
    MediaAsset source,
    HighlightPlan plan,
    RenderSettings settings,
  ) async* {
    _cancelled = false;
    _lastOutputPath = null;
    _lastSettings = settings;

    final outputPath = await _staging.newOutputPath(
      prefix: 'momentos_${plan.target.label}',
      extension: 'mp4',
    );
    final hasAudio = await probe.hasAudio(source.path);

    await for (final progress in _assembler.assemble(
      inputPath: source.path,
      outputPath: outputPath,
      ranges: [for (final m in plan.moments) MediaRange(m.start, m.end)],
      settings: settings,
      sourceHasAudio: hasAudio,
      label: 'Melhores momentos',
    )) {
      if (_cancelled) return;
      yield progress.fraction;
    }
    _lastOutputPath = outputPath;
  }

  @override
  Future<MediaAsset> buildResult(HighlightPlan plan) async {
    final path = _lastOutputPath;
    if (path == null) throw StateError('Nenhum export concluído.');

    final file = File(path);
    if (!file.existsSync()) throw StateError('Arquivo não encontrado.');

    return probe.enrich(
      MediaAsset(
        path: path,
        name: path.split('/').last,
        kind: MediaKind.video,
        sizeBytes: file.lengthSync(),
        duration: plan.totalLength,
        width: _lastSettings?.format.width,
        height: _lastSettings?.format.height,
      ),
    );
  }

  @override
  void cancel() {
    _cancelled = true;
    unawaited(_assembler.cancel());
  }
}
