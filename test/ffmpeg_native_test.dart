// Roda os comandos que o app gera contra o FFmpeg instalado na máquina.
//
// Os testes de command_builder verificam a *forma* dos argumentos; este
// verifica que o FFmpeg de verdade aceita os grafos de filtro (aspas,
// expressões, ordem) e produz o arquivo. O encoder de hardware não existe no
// desktop, então usa o codec por software do app — o mesmo da reserva.
//
// Pulado automaticamente quando não há `ffmpeg` no PATH.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vangogh/core/engine/command_builder.dart';
import 'package:vangogh/core/engine/media_range.dart';
import 'package:vangogh/core/media/cinema_look.dart';
import 'package:vangogh/core/media/media_asset.dart';
import 'package:vangogh/core/media/render_settings.dart';
import 'package:vangogh/features/enhance/domain/entities/enhance_options.dart';
import 'package:vangogh/features/enhance/domain/services/enhance_recipe.dart';
import 'package:vangogh/features/highlights/domain/entities/target_duration.dart';
import 'package:vangogh/features/highlights/domain/services/moment_detector.dart';

bool get _hasFfmpeg {
  try {
    return Process.runSync('ffmpeg', ['-version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

late Directory _dir;

String _p(String name) => '${_dir.path}/$name';

Future<void> _ff(List<String> args) async {
  final result = await Process.run('ffmpeg', args);
  if (result.exitCode != 0) {
    fail(
      'ffmpeg falhou (${result.exitCode}):\n${args.join(' ')}\n${result.stderr}',
    );
  }
}

(int, int) _size(String path) {
  final out = Process.runSync('ffprobe', [
    '-v',
    'error',
    '-select_streams',
    'v:0',
    '-show_entries',
    'stream=width,height',
    '-of',
    'csv=p=0',
    path,
  ]).stdout.toString().trim().split(',');
  return (int.parse(out[0]), int.parse(out[1]));
}

double _duration(String path) => double.parse(
  Process.runSync('ffprobe', [
    '-v',
    'error',
    '-show_entries',
    'format=duration',
    '-of',
    'csv=p=0',
    path,
  ]).stdout.toString().trim(),
);

void main() {
  final skip = _hasFfmpeg ? null : 'ffmpeg não instalado';

  setUpAll(() async {
    if (!_hasFfmpeg) return;
    _dir = Directory.systemTemp.createTempSync('vangogh_ff');
    // Vídeo deitado de 12 s: barra de cor e, entre 4 s e 6 s, áudio alto.
    await _ff([
      '-hide_banner',
      '-loglevel',
      'error',
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=s=640x360:r=30:d=6',
      '-f',
      'lavfi',
      '-i',
      'mandelbrot=s=640x360:r=30',
      '-f',
      'lavfi',
      '-i',
      'sine=f=440:d=12',
      '-filter_complex',
      "[1]trim=duration=6,setpts=PTS-STARTPTS[b];[0][b]concat=n=2:v=1[v];"
          "[2]volume='if(between(t,4,6),1,0.03)':eval=frame[a]",
      '-map',
      '[v]',
      '-map',
      '[a]',
      '-g',
      '30',
      '-c:v',
      'mpeg4',
      '-q:v',
      '4',
      '-c:a',
      'aac',
      _p('land.mp4'),
    ]);
    // Vídeo em pé, sem áudio.
    await _ff([
      '-hide_banner',
      '-loglevel',
      'error',
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=s=360x640:r=30:d=3',
      '-c:v',
      'mpeg4',
      _p('port.mp4'),
    ]);
    await _ff([
      '-hide_banner',
      '-loglevel',
      'error',
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=s=800x600',
      '-frames:v',
      '1',
      _p('photo.jpg'),
    ]);
  });

  tearDownAll(() {
    if (_hasFfmpeg) _dir.deleteSync(recursive: true);
  });

  const land = MediaAsset(
    path: '',
    name: 'land.mp4',
    kind: MediaKind.video,
    sizeBytes: 1,
    width: 640,
    height: 360,
    duration: Duration(seconds: 12),
    fps: 30,
  );

  group('FFmpeg nativo', skip: skip, () {
    test('cada look de cinema renderiza', () async {
      for (final look in CinemaLook.values) {
        final out = _p('look_${look.name}.mp4');
        await _ff(
          FfmpegCommand.concatenate(
            inputPath: _p('land.mp4'),
            outputPath: out,
            ranges: const [
              MediaRange(Duration(seconds: 1), Duration(seconds: 2)),
            ],
            settings: RenderSettings(
              look: look,
              cinemaBars: true,
              format: OutputFormat.vertical,
            ),
            codec: HwCodec.software,
          ),
        );
        expect(_size(out), (1080, 1920), reason: look.name);
      }
    });

    test('aprimorar vídeo: Full HD pelo lado menor, com áudio limpo', () async {
      final source = land.copyWith(path: _p('land.mp4'));
      const options = EnhanceOptions(
        resolution: EnhanceResolution.fullHd,
        stabilize: true,
        look: CinemaLook.blockbuster,
        brightness: 0.2,
        warmth: -0.3,
      );
      final out = _p('enh.mp4');
      final size = EnhanceRecipe.outputSize(options, source)!;
      await _ff(
        FfmpegCommand.enhanceVideo(
          inputPath: source.path,
          outputPath: out,
          videoFilters: EnhanceRecipe.video(options, source),
          audioFilters: EnhanceRecipe.audio(options),
          width: size.$1,
          height: size.$2,
          codec: HwCodec.software,
        ),
      );
      expect(_size(out), (1920, 1080));
      expect(size, (1920, 1080));
    });

    test('aprimorar vídeo em pé continua em pé', () async {
      const source = MediaAsset(
        path: '',
        name: 'p',
        kind: MediaKind.video,
        sizeBytes: 1,
        width: 360,
        height: 640,
      );
      final out = _p('enh_port.mp4');
      await _ff(
        FfmpegCommand.enhanceVideo(
          inputPath: _p('port.mp4'),
          outputPath: out,
          videoFilters: EnhanceRecipe.video(const EnhanceOptions(), source),
          codec: HwCodec.software,
          sourceHasAudio: false,
        ),
      );
      // Auto (vídeo): 360p sobe para 1080 no lado menor.
      expect(_size(out), (1080, 1920));
    });

    test('aprimorar foto gera JPEG 4:4:4 no tamanho pedido', () async {
      const source = MediaAsset(
        path: '',
        name: 'photo.jpg',
        kind: MediaKind.image,
        sizeBytes: 1,
        width: 800,
        height: 600,
      );
      const options = EnhanceOptions(
        resolution: EnhanceResolution.qhd,
        look: CinemaLook.pelicula,
        saturation: 0.4,
      );
      final out = _p('photo_hd.jpg');
      await _ff(
        FfmpegCommand.enhanceImage(
          inputPath: _p('photo.jpg'),
          outputPath: out,
          filters: EnhanceRecipe.image(options, source),
        ),
      );
      expect(_size(out), (1920, 1440));
    });

    test('prévia antes/depois saem do mesmo tamanho', () async {
      final source = land.copyWith(path: _p('land.mp4'));
      const options = EnhanceOptions(resolution: EnhanceResolution.uhd);
      final before = _p('before.jpg');
      final after = _p('after.jpg');
      await _ff(
        FfmpegCommand.frame(
          inputPath: source.path,
          outputPath: before,
          at: const Duration(seconds: 3),
          filters: EnhanceRecipe.previewBefore(options, source),
        ),
      );
      await _ff(
        FfmpegCommand.frame(
          inputPath: source.path,
          outputPath: after,
          at: const Duration(seconds: 3),
          filters: EnhanceRecipe.preview(options, source),
        ),
      );
      expect(_size(before), _size(after));
      expect(_size(after).$2, 1080);
    });

    test('filmstrip vira uma imagem só', () async {
      final out = _p('strip.jpg');
      await _ff(
        FfmpegCommand.filmstrip(
          inputPath: _p('land.mp4'),
          outputPath: out,
          duration: const Duration(seconds: 12),
          tiles: 8,
          height: 60,
        ),
      );
      expect(_size(out).$2, 60);
    });

    test('análise acha o pico de áudio e o corte de cena', () async {
      final scenes = _p('scenes.txt');
      final audio = _p('audio.txt');
      await _ff(
        FfmpegCommand.analyze(
          inputPath: _p('land.mp4'),
          scenesPath: scenes,
          audioPath: audio,
        ),
      );
      final sceneSamples = MetadataParser.parse(
        File(scenes).readAsStringSync(),
        'lavfi.scene_score',
      );
      final audioSamples = MetadataParser.parse(
        File(audio).readAsStringSync(),
        'lavfi.astats.Overall.RMS_level',
      );
      expect(sceneSamples.length, greaterThan(5));
      expect(audioSamples.length, greaterThanOrEqualTo(20));

      final cut = sceneSamples.reduce((a, b) => a.value >= b.value ? a : b);
      expect(cut.seconds, closeTo(6, 1));

      final moments = MomentDetector.detect(
        duration: const Duration(seconds: 12),
        audio: audioSamples,
        scenes: sceneSamples,
        target: TargetDuration.seg30,
      );
      // Vídeo menor que o alvo vira um momento só, inteiro.
      expect(moments, hasLength(1));
    });

    test('análise de vídeo sem áudio não quebra', () async {
      await _ff(
        FfmpegCommand.analyze(
          inputPath: _p('port.mp4'),
          scenesPath: _p('s2.txt'),
          audioPath: _p('a2.txt'),
          sourceHasAudio: false,
        ),
      );
      expect(File(_p('s2.txt')).existsSync(), isTrue);
    });

    test('montagem segmentada: trechos + junção por cópia', () async {
      final ranges = const [
        MediaRange(Duration(seconds: 1), Duration(seconds: 3)),
        MediaRange(Duration(seconds: 5), Duration(seconds: 7)),
        MediaRange(Duration(seconds: 9), Duration(seconds: 11)),
      ];
      final parts = <String>[];
      for (var i = 0; i < ranges.length; i++) {
        final part = _p('part_$i.mp4');
        await _ff(
          FfmpegCommand.concatenate(
            inputPath: _p('land.mp4'),
            outputPath: part,
            ranges: [ranges[i]],
            settings: const RenderSettings(look: CinemaLook.noir),
            codec: HwCodec.software,
          ),
        );
        parts.add(part);
      }
      final list = _p('list.txt');
      File(list).writeAsStringSync(FfmpegCommand.concatList(parts));
      final out = _p('joined.mp4');
      await _ff(FfmpegCommand.joinCopy(listPath: list, outputPath: out));
      expect(_duration(out), closeTo(6, 0.3));
    });
  });
}
