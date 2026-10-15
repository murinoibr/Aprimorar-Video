import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ffmpeg_render_engine.dart';
import 'frame_grabber.dart';
import 'render_engine.dart';
import 'staging.dart';

final renderStagingProvider = Provider<RenderStaging>(
  (ref) => const RenderStaging(),
);

/// Motor único de mídia para o app inteiro.
///
/// Todas as features que produzem arquivo (cortar, montar highlights, melhorar
/// qualidade) dependem deste provider, e não de um motor próprio. É o que
/// garante um único lugar para cancelar, reportar progresso e recuperar
/// render interrompido.
final renderEngineProvider = Provider<RenderEngine>(
  (ref) => FfmpegRenderEngine(staging: ref.watch(renderStagingProvider)),
);

/// Quadros únicos (prévia antes/depois, miniaturas, filmstrip), fora da fila
/// exclusiva do motor de export.
final frameGrabberProvider = Provider<FrameGrabber>(
  (ref) => FrameGrabber(staging: ref.watch(renderStagingProvider)),
);

/// Miniatura por arquivo, memorizada: a tela pode reconstruir à vontade.
final thumbnailProvider = FutureProvider.family<String?, String>(
  (ref, path) => ref.read(frameGrabberProvider).thumbnail(path),
);

/// Filmstrip por (arquivo, duração em ms), memorizada.
final filmstripProvider = FutureProvider.family<String?, (String, int)>(
  (ref, key) => ref
      .read(frameGrabberProvider)
      .filmstrip(
        inputPath: key.$1,
        duration: Duration(milliseconds: key.$2),
      ),
);
