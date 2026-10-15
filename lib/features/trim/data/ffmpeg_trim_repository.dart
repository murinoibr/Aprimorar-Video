import 'dart:async';
import 'dart:io';

import '../../../core/engine/clip_assembler.dart';
import '../../../core/engine/command_builder.dart';
import '../../../core/engine/ffmpeg_render_engine.dart';
import '../../../core/engine/media_range.dart';
import '../../../core/engine/render_engine.dart';
import '../../../core/engine/render_job.dart';
import '../../../core/engine/staging.dart';
import '../../../core/media/media_asset.dart';
import '../../../core/media/media_probe.dart';
import '../../../core/media/render_settings.dart';
import '../domain/entities/trim_plan.dart';
import '../domain/repositories/trim_repository.dart';

/// Corta e concatena trechos reais com FFmpeg.
///
/// Substitui o antigo `MockTrimRepository`, que fabricava caminhos `/saida/` e
/// não produzia arquivo nenhum. O plano de corte e as preferências de export
/// viram argumentos de FFmpeg em [FfmpegCommand] (Dart puro, testável sem
/// aparelho); aqui só se orquestra o motor.
class FfmpegTrimRepository implements TrimRepository {
  FfmpegTrimRepository({
    required this.engine,
    required this.probe,
    RenderStaging? staging,
    HwCodec? codec,
  }) : _staging = staging ?? const RenderStaging(),
       _assembler = ClipAssembler(
         engine: engine,
         codec: codec ?? FfmpegRenderEngine.defaultCodec,
         staging: staging,
       );

  final RenderEngine engine;
  final MediaProbe probe;
  final RenderStaging _staging;
  final ClipAssembler _assembler;

  String? _outputPath;
  TrimPlan? _lastPlan;

  @override
  Stream<double> render(
    MediaAsset source,
    TrimPlan plan,
    RenderSettings settings,
  ) => renderWithProgress(source, plan, settings).map((p) => p.fraction);

  /// Mesma execução, com o progresso completo para a UI mostrar ETA e velocidade.
  Stream<RenderProgress> renderWithProgress(
    MediaAsset source,
    TrimPlan plan,
    RenderSettings settings,
  ) async* {
    _outputPath = null;
    _lastPlan = plan;

    final outputPath = await _staging.newOutputPath(
      prefix: plan.cutCount <= 0
          ? 'corte'
          : 'corte_${plan.cutCount + 1}trechos',
      extension: 'mp4',
    );

    // Sem faixa de áudio, um `-map 0:a` quebraria o concat inteiro — e a
    // maioria dos vídeos gravados por celular tem áudio, mas não todos.
    final hasAudio = await probe.hasAudio(source.path);

    yield* _assembler.assemble(
      inputPath: source.path,
      outputPath: outputPath,
      ranges: plan.segments
          .map((segment) => MediaRange(segment.start, segment.end))
          .where((range) => !range.isEmpty)
          .toList(),
      settings: settings,
      sourceHasAudio: hasAudio,
      label: plan.cutCount == 0
          ? 'Exportar corte'
          : 'Exportar ${plan.cutCount + 1} trechos',
    );

    // Só marca o caminho depois que o stream fecha sem erro: em cancelamento ou
    // falha, `buildResult` não deve descrever um arquivo pela metade.
    _outputPath = outputPath;
  }

  @override
  Future<MediaAsset> buildResult(RenderSettings settings) async {
    final path = _outputPath;
    if (path == null) {
      throw StateError('buildResult chamado antes de render() concluir.');
    }

    final file = File(path);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw StateError('O arquivo exportado não existe: $path');
    }

    // A duração medida pelo FFprobe é a verdade; a do plano é só uma
    // estimativa razoável quando a sondagem falha.
    final probed = await probe.enrich(
      MediaAsset(
        path: path,
        name: path.split('/').last,
        kind: MediaKind.video,
        sizeBytes: file.lengthSync(),
        duration: _lastPlan?.totalLength,
        width: settings.format.width,
        height: settings.format.height,
        fps: settings.fps?.toDouble(),
      ),
    );

    return probed;
  }

  @override
  void cancel() => unawaited(_assembler.cancel());
}
