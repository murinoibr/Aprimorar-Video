import '../../../../core/media/cinema_look.dart';
import '../../../../core/media/media_asset.dart';
import '../entities/enhance_options.dart';

/// Traduz [EnhanceOptions] em cadeia de filtros FFmpeg. Dart puro e testável.
///
/// A ordem importa e segue a de uma suíte de finalização:
/// 1. **Estabilizar** na resolução original (mais informação de movimento).
/// 2. **Limpar ruído e banding** antes de escalar — ampliar ruído só o deixa
///    maior.
/// 3. **Escalar** com Lanczos, pelo lado menor (vertical continua vertical).
/// 4. **Nitidez** depois da escala, onde ela recupera o contorno que a
///    interpolação suaviza.
/// 5. **Cor**: ajustes finos e, por cima, o look de cinema e as faixas.
abstract final class EnhanceRecipe {
  /// Lado menor do resultado, ou `null` para manter o tamanho da fonte.
  static int? targetShortSide(EnhanceOptions options, MediaAsset source) {
    final side = source.shortSide;
    if (options.resolution == EnhanceResolution.auto) {
      if (side == null) return null;
      // Foto: dobra o lado menor até 4K — é onde o upscale mais aparece.
      // Vídeo: só sobe para Full HD, para o render continuar rápido.
      if (source.isImage) {
        if (side >= 2160) return null;
        final doubled = side * 2;
        return doubled > 2160 ? 2160 : doubled;
      }
      return side < 1080 ? 1080 : null;
    }
    return options.resolution.shortSide;
  }

  /// Largura e altura finais (pares), quando a fonte tem medidas conhecidas.
  static (int, int)? outputSize(EnhanceOptions options, MediaAsset source) {
    if (!source.hasSize) return null;
    final target = targetShortSide(options, source);
    if (target == null) return (source.width!, source.height!);
    final w = source.width!;
    final h = source.height!;
    if (w >= h) return (_even(w * target / h), target);
    return (target, _even(h * target / w));
  }

  /// Filtros de vídeo do export final.
  static List<String> video(EnhanceOptions options, MediaAsset source) =>
      _chain(options, source, image: false);

  /// Filtros de foto do export final.
  static List<String> image(EnhanceOptions options, MediaAsset source) =>
      _chain(options, source, image: true);

  /// Filtros da prévia instantânea: mesma receita, limitada a [cap] px no lado
  /// menor para sair em fração de segundo. Estabilização fica de fora (não
  /// existe em um quadro só).
  static List<String> preview(
    EnhanceOptions options,
    MediaAsset source, {
    int cap = 1080,
  }) {
    final target = targetShortSide(options, source) ?? source.shortSide ?? cap;
    final side = target < cap ? target : cap;
    final upscale = (source.shortSide ?? side) < side;
    return [
      if (!upscale) _scale(side),
      ..._clean(options, image: !source.isVideo),
      if (upscale) _scale(side),
      ..._finish(options, source, upscaled: upscale),
    ];
  }

  /// Quadro "antes" da prévia, no mesmo tamanho do "depois".
  static List<String> previewBefore(
    EnhanceOptions options,
    MediaAsset source, {
    int cap = 1080,
  }) {
    final target = targetShortSide(options, source) ?? source.shortSide ?? cap;
    final side = target < cap ? target : cap;
    return [_scale(side, flags: 'bicubic')];
  }

  static List<String> audio(EnhanceOptions options) => options.cleanAudio
      ? const [
          'highpass=f=80',
          'afftdn=nf=-25',
          'loudnorm=I=-16:TP=-1.5:LRA=11',
        ]
      : const [];

  static List<String> _chain(
    EnhanceOptions options,
    MediaAsset source, {
    required bool image,
  }) {
    final target = targetShortSide(options, source);
    final side = source.shortSide;
    final upscaled = target != null && (side == null || target > side);
    return [
      if (!image && options.stabilize) 'deshake',
      ..._clean(options, image: image),
      if (target != null) _scale(target),
      ..._finish(options, source, upscaled: upscaled),
    ];
  }

  static List<String> _clean(EnhanceOptions options, {required bool image}) => [
    if (options.denoise) ...[
      // Foto: NL-means (mais lento, preserva textura). Vídeo: hqdn3d, que usa
      // os quadros vizinhos e roda em tempo real.
      image ? 'nlmeans=s=1.6:p=5:r=9' : 'hqdn3d=2:1.5:4:3',
      // Remove o "degrau" de cor em céu e parede que a compressão do celular
      // deixa.
      'gradfun=1.2:16',
    ],
  ];

  static List<String> _finish(
    EnhanceOptions options,
    MediaAsset source, {
    required bool upscaled,
  }) {
    final out = <String>[];
    if (options.sharpness > 0) {
      final amount = 0.25 + options.sharpness * 1.25 + (upscaled ? 0.2 : 0);
      out.add('unsharp=5:5:${amount.toStringAsFixed(2)}:5:5:0');
    }
    if (options.brightness != 0 ||
        options.contrast != 0 ||
        options.saturation != 0) {
      out.add(
        'eq=brightness=${_f(options.brightness * 0.15)}'
        ':contrast=${_f(1 + options.contrast * 0.35)}'
        ':saturation=${_f(1 + options.saturation * 0.6)}',
      );
    }
    if (options.warmth != 0) {
      final w = options.warmth;
      out.add(
        'colorbalance=rs=${_f(w * 0.08)}:bs=${_f(-w * 0.08)}'
        ':rm=${_f(w * 0.06)}:bm=${_f(-w * 0.06)}',
      );
    }
    out.addAll(options.look.filters);
    if (options.cinemaBars) out.addAll(cinemaBarsFilters);
    return out;
  }

  /// Escala pelo lado menor, decidindo a orientação no próprio FFmpeg — que
  /// enxerga o quadro já girado, ao contrário dos metadados do arquivo.
  static String _scale(int shortSide, {String flags = 'lanczos'}) =>
      "scale=w='if(gte(iw,ih),-2,$shortSide)'"
      ":h='if(gte(iw,ih),$shortSide,-2)':flags=$flags";

  static String _f(double value) => value.toStringAsFixed(3);

  static int _even(double value) {
    final rounded = value.round();
    return rounded.isEven ? rounded : rounded + 1;
  }
}
