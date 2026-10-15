import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';

import 'command_builder.dart';
import 'staging.dart';

/// Extrai quadros únicos: prévia antes/depois, miniaturas e filmstrip.
///
/// Fica fora do [RenderEngine] de propósito: o motor é exclusivo (um export
/// por vez), e uma prévia de 200 ms não pode esperar nem bloquear um export.
/// Cada pedido novo da mesma [lane] cancela o anterior — arrastar um slider
/// gera só a última prévia, nunca uma fila.
class FrameGrabber {
  FrameGrabber({RenderStaging? staging})
    : _staging = staging ?? const RenderStaging();

  final RenderStaging _staging;
  final Map<String, int> _lanes = {};
  final Map<String, Future<String?>> _cache = {};

  /// Um quadro de [inputPath] em [at] com [filters]. Devolve o caminho do JPEG
  /// ou `null` se falhar ou for substituído por um pedido mais novo.
  Future<String?> grab({
    required String inputPath,
    Duration at = Duration.zero,
    List<String> filters = const [],
    bool isImage = false,
    String lane = 'default',
    String prefix = 'quadro',
  }) async {
    final output = await _staging.newOutputPath(
      prefix: prefix,
      extension: 'jpg',
    );
    final args = FfmpegCommand.frame(
      inputPath: inputPath,
      outputPath: output,
      at: at,
      filters: filters,
      isImage: isImage,
    );
    return _run(args, output, lane: lane);
  }

  /// Tira de quadros para a timeline. Fica em cache por arquivo.
  Future<String?> filmstrip({
    required String inputPath,
    required Duration duration,
    int tiles = 12,
  }) {
    final key = 'strip:$inputPath:${duration.inMilliseconds}:$tiles';
    return _cached(key, () async {
      final output = await _staging.newOutputPath(
        prefix: 'tira',
        extension: 'jpg',
      );
      return _run(
        FfmpegCommand.filmstrip(
          inputPath: inputPath,
          outputPath: output,
          duration: duration,
          tiles: tiles,
        ),
        output,
        lane: key,
      );
    });
  }

  /// Miniatura de um vídeo ou foto. Fica em cache por arquivo.
  Future<String?> thumbnail(String inputPath, {bool isImage = false}) {
    final key = 'thumb:$inputPath';
    return _cached(
      key,
      () => grab(
        inputPath: inputPath,
        at: isImage ? Duration.zero : const Duration(milliseconds: 800),
        filters: const ['scale=360:-2'],
        isImage: isImage,
        lane: key,
        prefix: 'miniatura',
      ),
    );
  }

  /// Cache que se corrige sozinho: falha não fica guardada, e um arquivo
  /// apagado pela limpeza do cache é gerado de novo.
  Future<String?> _cached(String key, Future<String?> Function() create) async {
    final existing = _cache[key];
    if (existing != null) {
      final path = await existing;
      if (path != null && File(path).existsSync()) return path;
      _cache.remove(key);
    }
    final future = create();
    _cache[key] = future;
    final path = await future;
    if (path == null) _cache.remove(key);
    return path;
  }

  Future<String?> _run(
    List<String> args,
    String output, {
    required String lane,
  }) async {
    final previous = _lanes[lane];
    if (previous != null && previous >= 0) unawaited(_cancel(previous));

    final done = Completer<FFmpegSession>();
    try {
      final session = await FFmpegKit.executeWithArgumentsAsync(args, (s) {
        if (!done.isCompleted) done.complete(s);
      });
      final id = session.getSessionId() ?? -1;
      _lanes[lane] = id;
      final finished = await done.future;
      final superseded = _lanes[lane] != id;
      if (!superseded) _lanes.remove(lane);
      if (superseded) {
        _staging.discard(output);
        return null;
      }

      final code = await finished.getReturnCode();
      final file = File(output);
      if (!ReturnCode.isSuccess(code) ||
          !file.existsSync() ||
          file.lengthSync() == 0) {
        _staging.discard(output);
        return null;
      }
      return output;
    } on Object {
      _staging.discard(output);
      return null;
    }
  }

  Future<void> _cancel(int id) async {
    try {
      await FFmpegKit.cancel(id);
    } on Object {
      // A sessão já terminou.
    }
  }

  void forget(String inputPath) {
    _cache.removeWhere((key, _) => key.contains(inputPath));
  }
}
