import 'dart:async';
import 'dart:io';

import '../media/render_settings.dart';
import 'command_builder.dart';
import 'media_range.dart';
import 'render_engine.dart';
import 'render_job.dart';
import 'staging.dart';

/// Monta vários trechos de um vídeo em um arquivo só, do jeito rápido.
///
/// O caminho ingênuo (`trim` + `concat` num único grafo) decodifica o vídeo
/// inteiro até o último trecho: num vídeo de 40 min com 10 momentos, são 40
/// min de decodificação para 1 min de resultado. Aqui cada trecho é
/// renderizado com *seek* de entrada — só o que vai para o corte é
/// decodificado — e no fim os clipes são unidos por cópia de pacotes, sem
/// re-encode. Resultado: tempo proporcional ao corte, não à fonte.
class ClipAssembler {
  ClipAssembler({
    required this.engine,
    required this._codec,
    RenderStaging? staging,
  }) : _staging = staging ?? const RenderStaging();

  final RenderEngine engine;
  final HwCodec _codec;
  final RenderStaging _staging;

  bool _cancelled = false;

  /// Renderiza [ranges] de [inputPath] em [outputPath].
  ///
  /// Emite progresso de 0 a 1 sobre a duração total do corte. Em falha emite
  /// [RenderFailure]; em cancelamento, [RenderCancelled].
  Stream<RenderProgress> assemble({
    required String inputPath,
    required String outputPath,
    required List<MediaRange> ranges,
    required RenderSettings settings,
    required bool sourceHasAudio,
    String label = 'Exportar',
  }) async* {
    _cancelled = false;
    final valid = ranges.where((range) => !range.isEmpty).toList();
    if (valid.isEmpty) {
      throw const RenderFailure('Nenhum trecho com duração para exportar.');
    }

    if (valid.length == 1) {
      yield* engine.run(
        _request(
          inputPath: inputPath,
          outputPath: outputPath,
          range: valid.single,
          settings: settings,
          sourceHasAudio: sourceHasAudio,
          codec: _codec,
          label: label,
        ),
      );
      return;
    }

    final totalMs = valid.fold<int>(
      0,
      (sum, r) => sum + r.length.inMilliseconds,
    );
    final parts = <String>[];
    String? listPath;
    var codec = _codec;

    try {
      var index = 0;
      var doneMs = 0;
      while (index < valid.length) {
        final range = valid[index];
        final partPath = await _staging.newOutputPath(
          prefix: 'parte_$index',
          extension: 'mp4',
        );
        var restart = false;

        await for (final progress in engine.run(
          _request(
            inputPath: inputPath,
            outputPath: partPath,
            range: range,
            settings: settings,
            sourceHasAudio: sourceHasAudio,
            codec: codec,
            label: label,
          ),
        )) {
          if (progress.stage == RenderStage.done) {
            if (progress.usedFallback && codec.isHardware) {
              // O encoder de hardware recusou este trecho. A junção por cópia
              // exige o mesmo codec em todos: refaz os anteriores por software.
              codec = HwCodec.software;
              restart = index > 0;
            }
            continue;
          }
          final ms = doneMs + progress.fraction * range.length.inMilliseconds;
          yield RenderProgress(
            fraction: (ms / totalMs * 0.97).clamp(0.0, 0.97),
            stage: RenderStage.encoding,
            processedMs: ms.round(),
            totalMs: totalMs,
            speed: progress.speed,
          );
        }
        if (_cancelled) throw const RenderCancelled();

        parts.add(partPath);
        if (restart) {
          _discardAll(parts);
          parts.clear();
          index = 0;
          doneMs = 0;
          continue;
        }
        doneMs += range.length.inMilliseconds;
        index++;
      }

      yield RenderProgress(
        fraction: 0.98,
        stage: RenderStage.finalizing,
        processedMs: totalMs,
        totalMs: totalMs,
      );

      listPath = await _staging.newOutputPath(
        prefix: 'lista',
        extension: 'txt',
      );
      await File(listPath).writeAsString(FfmpegCommand.concatList(parts));

      await for (final progress in engine.run(
        RenderRequest(
          arguments: FfmpegCommand.joinCopy(
            listPath: listPath,
            outputPath: outputPath,
          ),
          outputPath: outputPath,
          expectedDurationMs: totalMs,
          label: label,
        ),
      )) {
        if (progress.stage == RenderStage.done) {
          yield RenderProgress(
            fraction: 1,
            stage: RenderStage.done,
            processedMs: totalMs,
            totalMs: totalMs,
            sizeBytes: progress.sizeBytes,
          );
        }
      }
    } finally {
      _discardAll(parts);
      if (listPath != null) _staging.discard(listPath);
    }
  }

  RenderRequest _request({
    required String inputPath,
    required String outputPath,
    required MediaRange range,
    required RenderSettings settings,
    required bool sourceHasAudio,
    required HwCodec codec,
    required String label,
  }) {
    List<String> build(HwCodec c) => FfmpegCommand.concatenate(
      inputPath: inputPath,
      outputPath: outputPath,
      ranges: [range],
      settings: settings,
      codec: c,
      sourceHasAudio: sourceHasAudio,
    );

    return RenderRequest(
      arguments: build(codec),
      fallbackArguments: codec.isHardware ? build(HwCodec.software) : null,
      outputPath: outputPath,
      expectedDurationMs: range.length.inMilliseconds,
      label: label,
    );
  }

  void _discardAll(List<String> paths) {
    for (final path in paths) {
      _staging.discard(path);
    }
  }

  Future<void> cancel() async {
    _cancelled = true;
    await engine.cancel();
  }
}
