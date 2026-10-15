import 'package:vangogh/core/media/media_asset.dart';
import 'package:vangogh/core/utils/duration_x.dart';
import 'package:vangogh/core/media/cinema_look.dart';
import 'package:vangogh/features/enhance/domain/entities/enhance_options.dart';
import 'package:vangogh/features/enhance/domain/services/enhance_recipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DurationX', () {
    test('clock', () {
      expect(const Duration(seconds: 75).clock, '1:15');
      expect(const Duration(minutes: 3).clock, '3:00');
    });

    test('approxHuman', () {
      expect(const Duration(seconds: 46).approxHuman, '~45s');
      expect(const Duration(minutes: 2).approxHuman, '~2 min');
    });

    test('human', () {
      expect(const Duration(seconds: 30).human, '30s');
      expect(const Duration(minutes: 1).human, '1 min');
    });
  });

  group('formatBytes', () {
    test('escala', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBytes(2 * 1024 * 1024 * 1024), '2.00 GB');
    });
  });

  group('MediaAsset', () {
    test('classifica a resolução', () {
      const hd = MediaAsset(
        path: '/a.mp4',
        name: 'a.mp4',
        kind: MediaKind.video,
        sizeBytes: 1,
        width: 1920,
        height: 1080,
      );
      const sd = MediaAsset(
        path: '/b.mp4',
        name: 'b.mp4',
        kind: MediaKind.video,
        sizeBytes: 1,
        width: 640,
        height: 480,
      );

      expect(hd.resolutionLabel, 'Full HD · 1920x1080');
      expect(sd.resolutionLabel, 'SD · 640x480');
    });

    test('vídeo em pé usa o lado menor', () {
      const vertical = MediaAsset(
        path: '/c.mp4',
        name: 'c.mp4',
        kind: MediaKind.video,
        sizeBytes: 1,
        width: 1080,
        height: 1920,
      );
      expect(vertical.tierLabel, 'Full HD');
      expect(vertical.isPortrait, isTrue);
    });

    test('ida e volta em JSON', () {
      const asset = MediaAsset(
        path: '/d.jpg',
        name: 'd.jpg',
        kind: MediaKind.image,
        sizeBytes: 10,
        width: 4000,
        height: 3000,
      );
      final back = MediaAsset.fromJson(asset.toJson())!;
      expect(back.kind, MediaKind.image);
      expect(back.width, 4000);
      expect(back.tierLabel, '12 MP');
    });

    test('marca arquivo grande', () {
      const big = MediaAsset(
        path: '/a.mp4',
        name: 'a.mp4',
        kind: MediaKind.video,
        sizeBytes: 900 * 1024 * 1024,
      );
      expect(big.isLarge, isTrue);
    });
  });

  group('EnhanceOptions', () {
    test('lista os filtros ativos', () {
      const options = EnhanceOptions(
        resolution: EnhanceResolution.uhd,
        look: CinemaLook.neon,
        brightness: 0.1,
      );

      expect(options.activeFilters, contains('4K'));
      expect(options.activeFilters, contains('Sem ruído'));
      expect(options.activeFilters, contains('Neon Noir'));
      expect(options.activeFilters, contains('Brilho +10%'));
    });

    test('copyWith e igualdade', () {
      const base = EnhanceOptions();
      final updated = base.copyWith(saturation: -0.2, look: CinemaLook.noir);

      expect(updated.saturation, -0.2);
      expect(updated.look, CinemaLook.noir);
      expect(updated.sharpness, base.sharpness);
      expect(
        updated == base.copyWith(saturation: -0.2, look: CinemaLook.noir),
        isTrue,
      );
      expect(updated.resetColor().hasColorAdjust, isFalse);
    });
  });

  group('EnhanceRecipe', () {
    const phone720 = MediaAsset(
      path: '/v.mp4',
      name: 'v.mp4',
      kind: MediaKind.video,
      sizeBytes: 1,
      width: 720,
      height: 1280,
    );
    const fullHd = MediaAsset(
      path: '/v.mp4',
      name: 'v.mp4',
      kind: MediaKind.video,
      sizeBytes: 1,
      width: 1920,
      height: 1080,
    );

    test('auto sobe para Full HD só quando a fonte é menor', () {
      const options = EnhanceOptions();
      expect(EnhanceRecipe.targetShortSide(options, phone720), 1080);
      const photo = MediaAsset(
        path: '/f.jpg',
        name: 'f.jpg',
        kind: MediaKind.image,
        sizeBytes: 1,
        width: 1600,
        height: 1067,
      );
      expect(EnhanceRecipe.targetShortSide(options, photo), 2134);
      expect(EnhanceRecipe.targetShortSide(options, fullHd), isNull);
    });

    test('vertical continua vertical e com lados pares', () {
      const options = EnhanceOptions(resolution: EnhanceResolution.uhd);
      expect(EnhanceRecipe.outputSize(options, phone720), (2160, 3840));
      expect(EnhanceRecipe.outputSize(options, fullHd), (3840, 2160));
    });

    test('limpa antes de escalar e afia depois', () {
      const options = EnhanceOptions(
        resolution: EnhanceResolution.uhd,
        stabilize: true,
      );
      final chain = EnhanceRecipe.video(options, fullHd);
      final scale = chain.indexWhere((f) => f.startsWith('scale='));
      expect(chain.first, 'deshake');
      expect(chain.indexWhere((f) => f.startsWith('hqdn3d')), lessThan(scale));
      expect(
        chain.indexWhere((f) => f.startsWith('unsharp')),
        greaterThan(scale),
      );
      expect(chain[scale], contains('lanczos'));
    });

    test('foto usa NL-means e nunca estabiliza', () {
      const photo = MediaAsset(
        path: '/f.jpg',
        name: 'f.jpg',
        kind: MediaKind.image,
        sizeBytes: 1,
        width: 4000,
        height: 3000,
      );
      final chain = EnhanceRecipe.image(
        const EnhanceOptions(stabilize: true),
        photo,
      );
      expect(chain, isNot(contains('deshake')));
      expect(chain.any((f) => f.startsWith('nlmeans')), isTrue);
    });

    test('look e faixas entram no fim da cadeia', () {
      const options = EnhanceOptions(look: CinemaLook.noir, cinemaBars: true);
      final chain = EnhanceRecipe.video(options, fullHd);
      expect(chain.last, startsWith('drawbox'));
      expect(chain, contains('hue=s=0'));
    });

    test('prévia limita o tamanho e pula a estabilização', () {
      const options = EnhanceOptions(
        resolution: EnhanceResolution.uhd,
        stabilize: true,
      );
      final chain = EnhanceRecipe.preview(options, fullHd);
      expect(chain, isNot(contains('deshake')));
      expect(
        chain.where((f) => f.startsWith('scale=')).single,
        contains('1080'),
      );
    });

    test('áudio limpo normaliza o volume', () {
      expect(
        EnhanceRecipe.audio(const EnhanceOptions()).last,
        startsWith('loudnorm'),
      );
      expect(
        EnhanceRecipe.audio(const EnhanceOptions(cleanAudio: false)),
        isEmpty,
      );
    });
  });
}
