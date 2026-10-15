// Ferramenta de verificação: imprime, em JSON, os argumentos que o
// FfmpegCommand produz para um conjunto de cenários, para rodar contra o
// ffmpeg nativo do container.
//
// Uso: dart run tool/dump_commands.dart > cmds.json
import 'dart:convert';
import 'dart:io';

import 'package:vangogh/core/engine/command_builder.dart';
import 'package:vangogh/core/engine/media_range.dart';
import 'package:vangogh/core/media/render_settings.dart';

final _out = <String, List<String>>{};

void _dump(String name, List<String> args) => _out[name] = args;

void main() {
  const input = 'src.mp4';
  const output = 'out.mp4';

  // 1. Corte único, formato original, sem filtro: caminho de seek.
  _dump(
    'um-trecho-original',
    FfmpegCommand.concatenate(
      inputPath: input,
      outputPath: output,
      ranges: const [MediaRange(Duration(seconds: 5), Duration(seconds: 20))],
      settings: const RenderSettings(),
    ),
  );

  // 2. Três trechos concatenados num passe só, com áudio.
  _dump(
    'tres-trechos',
    FfmpegCommand.concatenate(
      inputPath: input,
      outputPath: output,
      ranges: const [
        MediaRange(Duration.zero, Duration(seconds: 3)),
        MediaRange(Duration(seconds: 10), Duration(seconds: 15, milliseconds: 250)),
        MediaRange(Duration(seconds: 40), Duration(seconds: 44)),
      ],
      settings: const RenderSettings(),
    ),
  );

  // 3. Três trechos, sem áudio: concat com a=0.
  _dump(
    'tres-trechos-sem-audio',
    FfmpegCommand.concatenate(
      inputPath: input,
      outputPath: output,
      ranges: const [
        MediaRange(Duration.zero, Duration(seconds: 3)),
        MediaRange(Duration(seconds: 10), Duration(seconds: 15)),
        MediaRange(Duration(seconds: 40), Duration(seconds: 44)),
      ],
      settings: const RenderSettings(keepAudio: false),
    ),
  );

  // 4. Fonte sem faixa de áudio mas com keepAudio ligado.
  _dump(
    'fonte-muda',
    FfmpegCommand.concatenate(
      inputPath: input,
      outputPath: output,
      ranges: const [
        MediaRange(Duration.zero, Duration(seconds: 3)),
        MediaRange(Duration(seconds: 10), Duration(seconds: 15)),
      ],
      settings: const RenderSettings(),
      sourceHasAudio: false,
    ),
  );

  // 5. Vertical 9:16 com escala, letterbox e 60fps.
  _dump(
    'vertical-60fps',
    FfmpegCommand.concatenate(
      inputPath: input,
      outputPath: output,
      ranges: const [MediaRange(Duration.zero, Duration(seconds: 8))],
      settings: const RenderSettings(
        format: OutputFormat.vertical,
        fps: 60,
        quality: RenderQuality.maxima,
      ),
    ),
  );

  // 6. Normalização de áudio.
  _dump(
    'audio-normalizado',
    FfmpegCommand.concatenate(
      inputPath: input,
      outputPath: output,
      ranges: const [
        MediaRange(Duration.zero, Duration(seconds: 4)),
        MediaRange(Duration(seconds: 20), Duration(seconds: 26)),
      ],
      settings: const RenderSettings(),
      normalizeAudio: true,
    ),
  );

  // Os mesmos cenários para o codec por software, para validar a sintaxe
  // comum sem depender de MediaCodec/VideoToolbox.
  for (final codec in HwCodec.values) {
    _dump(
      'codec-${codec.name}',
      FfmpegCommand.concatenate(
        inputPath: input,
        outputPath: output,
        ranges: const [
          MediaRange(Duration.zero, Duration(seconds: 3)),
          MediaRange(Duration(seconds: 12), Duration(seconds: 18)),
        ],
        settings: const RenderSettings(format: OutputFormat.square),
        codec: codec,
      ),
    );
  }

  stdout.writeln(const JsonEncoder.withIndent('  ').convert(_out));
}
