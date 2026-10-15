import 'package:vangogh/core/engine/command_builder.dart';
import 'package:vangogh/core/engine/media_range.dart';
import 'package:vangogh/core/media/render_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Achata os argumentos para uma string, facilitando as asserções.
String _flat(List<String> args) => args.join(' ');

/// Valor de uma opção, ex.: `_valueOf(args, '-c:v')` -> `h264_mediacodec`.
String _valueOf(List<String> args, String flag) {
  final index = args.indexOf(flag);
  if (index < 0 || index + 1 >= args.length) return '';
  return args[index + 1];
}

const _full = [MediaRange(Duration.zero, Duration(seconds: 10))];

void main() {
  group('trecho único sem filtro', () {
    final args = FfmpegCommand.concatenate(
      inputPath: '/in.mp4',
      outputPath: '/out.mp4',
      ranges: _full,
      settings: const RenderSettings(),
    );

    test('usa seek de entrada em vez de filter_complex', () {
      // -ss/-t antes do -i: é seek no arquivo, não na rede, e evita
      // decodificar tudo que vem antes do corte.
      expect(args.indexOf('-ss'), lessThan(args.indexOf('-i')));
      expect(args.contains('-filter_complex'), isFalse);
    });

    test('o -ss aponta para o início do trecho e o -t para a duração', () {
      final range = const MediaRange(
        Duration(seconds: 5, milliseconds: 500),
        Duration(seconds: 20),
      );
      final out = FfmpegCommand.concatenate(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        ranges: [range],
        settings: const RenderSettings(),
      );
      expect(_valueOf(out, '-ss'), '5.500');
      expect(_valueOf(out, '-t'), '14.500');
    });
  });

  group('vários trechos', () {
    final ranges = [
      const MediaRange(Duration.zero, Duration(seconds: 3)),
      const MediaRange(Duration(seconds: 10), Duration(seconds: 15, milliseconds: 250)),
      const MediaRange(Duration(seconds: 40), Duration(seconds: 44)),
    ];
    final args = FfmpegCommand.concatenate(
      inputPath: '/in.mp4',
      outputPath: '/out.mp4',
      ranges: ranges,
      settings: const RenderSettings(),
    );
    final graph = _valueOf(args, '-filter_complex');

    test('faz trim e atrim de cada trecho', () {
      expect(graph, contains('[0:v]trim=start=0.000:end=3.000'));
      expect(graph, contains('[0:a]atrim=start=10.000:end=15.250'));
      expect(graph, contains('[0:v]trim=start=40.000:end=44.000'));
    });

    test('concatena os três trechos em um único passe', () {
      expect(graph, contains('concat=n=3:v=1:a=1'));
      // Sem arquivos intermediários: é um filter_complex só.
      expect(_flat(args).split('-i').length - 1, 1);
    });

    test('mapeia as saídas nomeadas do grafo', () {
      expect(args, containsAllInOrder(['-map', '[vout]']));
      expect(args, containsAllInOrder(['-map', '[aout]']));
    });

    test('sem -ss/-t, porque o corte é por filtro', () {
      expect(args.contains('-ss'), isFalse);
    });
  });

  group('formato de saída', () {
    test('escala e centraliza para 9:16 preservando proporção', () {
      final args = FfmpegCommand.concatenate(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        ranges: _full,
        settings: const RenderSettings(format: OutputFormat.vertical),
      );
      final filter = _valueOf(args, '-vf');
      expect(filter, contains('force_original_aspect_ratio=decrease'));
      expect(filter, contains('pad=w=1080:h=1920'));
      // setsar=1 evita o player esticando a imagem por pixel não quadrado.
      expect(filter, contains('setsar=1'));
    });

    test('o pad usa x=/y= nomeados (regressão)', () {
      // Misturar `w=`/`h=` nomeados com a expressão posicional faz o FFmpeg
      // mapear `(oh-ih)/2` para a opção errada e abortar o render com
      // "Error when evaluating the expression".
      final filter = _valueOf(
        FfmpegCommand.concatenate(
          inputPath: '/in.mp4',
          outputPath: '/out.mp4',
          ranges: _full,
          settings: const RenderSettings(format: OutputFormat.vertical),
        ),
        '-vf',
      );
      expect(filter, contains('x=(ow-iw)/2'));
      expect(filter, contains('y=(oh-ih)/2'));
      expect(filter, isNot(contains('h=1920:(ow-iw)/2')));
    });

    test('dimensões alvo são múltiplas de 2, como o H.264 exige', () {
      for (final format in OutputFormat.values) {
        if (format.width == null) continue;
        expect(format.width! % 2, 0, reason: '${format.name} tem largura ímpar');
        expect(format.height! % 2, 0, reason: '${format.name} tem altura ímpar');
      }
    });

    test('formato original não insere filtro de escala', () {
      final args = FfmpegCommand.concatenate(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        ranges: _full,
        settings: const RenderSettings(format: OutputFormat.original),
      );
      expect(args.contains('-vf'), isFalse);
    });

    test('fps explícito vira filtro', () {
      final args = FfmpegCommand.concatenate(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        ranges: _full,
        settings: const RenderSettings(fps: 60),
      );
      expect(_valueOf(args, '-vf'), contains('fps=60'));
    });
  });

  group('áudio', () {
    test('sem áudio na saída quando o usuário desliga', () {
      final args = FfmpegCommand.concatenate(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        ranges: _full,
        settings: const RenderSettings(keepAudio: false),
      );
      expect(args.contains('-c:a'), isFalse);
      expect(_flat(args), isNot(contains('[0:a]')));
    });

    test('concat sem áudio usa a=0 em vez de quebrar', () {
      final args = FfmpegCommand.concatenate(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        ranges: [
          const MediaRange(Duration.zero, Duration(seconds: 2)),
          const MediaRange(Duration(seconds: 5), Duration(seconds: 8)),
        ],
        settings: const RenderSettings(keepAudio: false),
      );
      expect(_valueOf(args, '-filter_complex'), contains('concat=n=2:v=1:a=0'));
    });

    test('fonte sem faixa de áudio não gera mapa de áudio', () {
      final args = FfmpegCommand.concatenate(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        ranges: _full,
        settings: const RenderSettings(),
        sourceHasAudio: false,
      );
      expect(args.contains('-c:a'), isFalse);
    });

    test('áudio é normalizado quando pedido', () {
      final args = FfmpegCommand.concatenate(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        ranges: _full,
        settings: const RenderSettings(),
        normalizeAudio: true,
      );
      expect(_valueOf(args, '-af'), contains('loudnorm'));
      // Normalizar o áudio não deve sujar o filtro de vídeo.
      expect(args.contains('-vf'), isFalse);
    });
  });

  group('encode', () {
    test('usa o codec pedido', () {
      final args = FfmpegCommand.concatenate(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        ranges: _full,
        settings: const RenderSettings(),
        codec: HwCodec.videoToolbox,
      );
      expect(_valueOf(args, '-c:v'), 'h264_videotoolbox');
    });

    test('nunca emite codec GPL', () {
      for (final codec in HwCodec.values) {
        final args = FfmpegCommand.concatenate(
          inputPath: '/in.mp4',
          outputPath: '/out.mp4',
          ranges: _full,
          settings: const RenderSettings(),
          codec: codec,
        );
        final flat = _flat(args);
        expect(flat, isNot(contains('libx264')));
        expect(flat, isNot(contains('libx265')));
        expect(flat, isNot(contains('libvpx')));
      }
    });

    test('define taxa de bits, teto e buffer para caber em qualquer player', () {
      final args = FfmpegCommand.concatenate(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        ranges: _full,
        settings: const RenderSettings(
          format: OutputFormat.vertical,
          quality: RenderQuality.equilibrado,
        ),
      );
      // 1080x1920@30 no preset equilibrado -> 6220 kbps.
      expect(_valueOf(args, '-b:v'), '6221k');
      expect(_valueOf(args, '-maxrate'), '12442k');
      expect(_valueOf(args, '-bufsize'), '12442k');
    });

    test('yuv420p e faststart sempre presentes', () {
      final args = FfmpegCommand.concatenate(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        ranges: _full,
        settings: const RenderSettings(),
      );
      expect(_valueOf(args, '-pix_fmt'), 'yuv420p');
      expect(_valueOf(args, '-movflags'), '+faststart');
    });

    test('codec de hardware recebe GOP explícito', () {
      final args = FfmpegCommand.concatenate(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        ranges: _full,
        settings: const RenderSettings(fps: 30),
        codec: HwCodec.mediaCodec,
      );
      expect(_valueOf(args, '-g'), '60');
    });
  });

  group('taxa de bits alvo', () {
    test('qualidade mais alta pede mais bits', () {
      int bits(RenderQuality q) => FfmpegCommand.targetBitrateKbps(
        quality: q,
        width: 1920,
        height: 1080,
        fps: 30,
      )!;
      expect(bits(RenderQuality.leve), lessThan(bits(RenderQuality.equilibrado)));
      expect(bits(RenderQuality.equilibrado), lessThan(bits(RenderQuality.maxima)));
    });

    test('mais pixels e mais fps pedem mais bits', () {
      final sd = FfmpegCommand.targetBitrateKbps(
        quality: RenderQuality.equilibrado,
        width: 1280,
        height: 720,
        fps: 30,
      )!;
      final uhd = FfmpegCommand.targetBitrateKbps(
        quality: RenderQuality.equilibrado,
        width: 3840,
        height: 2160,
        fps: 30,
      )!;
      expect(sd, lessThan(uhd));
    });

    test('tem piso para não gerar arquivo degenerado', () {
      final tiny = FfmpegCommand.targetBitrateKbps(
        quality: RenderQuality.leve,
        width: 64,
        height: 64,
        fps: 5,
      )!;
      expect(tiny, 400);
    });

    test('dimensões inválidas devolvem null em vez de zero', () {
      expect(
        FfmpegCommand.targetBitrateKbps(
          quality: RenderQuality.equilibrado,
          width: 0,
          height: 1080,
          fps: 30,
        ),
        isNull,
      );
    });
  });

  group('validação', () {
    test('recusa lista sem nenhum trecho válido', () {
      expect(
        () => FfmpegCommand.concatenate(
          inputPath: '/in.mp4',
          outputPath: '/out.mp4',
          ranges: const [
            MediaRange(Duration(seconds: 5), Duration(seconds: 5)),
          ],
          settings: const RenderSettings(),
        ),
        throwsArgumentError,
      );
    });

    test('ignora trechos vazios mas usa os válidos', () {
      final args = FfmpegCommand.concatenate(
        inputPath: '/in.mp4',
        outputPath: '/out.mp4',
        ranges: const [
          MediaRange(Duration(seconds: 5), Duration(seconds: 5)),
          MediaRange(Duration.zero, Duration(seconds: 4)),
        ],
        settings: const RenderSettings(),
      );
      // Sobrou um trecho só, então o atalho de seek é válido.
      expect(args.contains('-ss'), isTrue);
    });
  });
}
