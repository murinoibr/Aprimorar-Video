import '../../../../core/media/cinema_look.dart';
import '../../../../core/media/render_settings.dart';

/// Resolução de saída, sempre pelo **lado menor** — 1080 vale para 1920x1080
/// e para 1080x1920, sem distorcer nem colocar faixas em vídeo vertical.
enum EnhanceResolution {
  auto('Auto', null, 'O melhor para cada arquivo'),
  original('Original', null, 'Mantém o tamanho'),
  hd('HD', 720, '720p · leve'),
  fullHd('Full HD', 1080, '1080p · padrão das redes'),
  qhd('2K', 1440, '1440p · mais detalhe'),
  uhd('4K', 2160, '2160p · máximo');

  const EnhanceResolution(this.label, this.shortSide, this.hint);

  final String label;
  final int? shortSide;
  final String hint;
}

class EnhanceOptions {
  const EnhanceOptions({
    this.resolution = EnhanceResolution.auto,
    this.denoise = true,
    this.sharpness = 0.5,
    this.stabilize = false,
    this.cleanAudio = true,
    this.look = CinemaLook.natural,
    this.cinemaBars = false,
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
    this.quality = RenderQuality.maxima,
  });

  final EnhanceResolution resolution;
  final bool denoise;

  /// 0 desliga; 1 é o máximo antes de aparecer halo.
  final double sharpness;
  final bool stabilize;
  final bool cleanAudio;
  final CinemaLook look;
  final bool cinemaBars;

  /// Ajustes finos, de -1 a 1.
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;

  final RenderQuality quality;

  bool get hasColorAdjust =>
      brightness != 0 || contrast != 0 || saturation != 0 || warmth != 0;

  List<String> get activeFilters => [
    if (resolution.shortSide != null) resolution.label,
    if (denoise) 'Sem ruído',
    if (sharpness > 0) 'Nitidez ${(sharpness * 100).round()}%',
    if (stabilize) 'Estabilizado',
    if (cleanAudio) 'Áudio limpo',
    if (!look.isNeutral) look.label,
    if (cinemaBars) '2.39:1',
    if (brightness != 0) 'Brilho ${_signed(brightness)}',
    if (contrast != 0) 'Contraste ${_signed(contrast)}',
    if (saturation != 0) 'Saturação ${_signed(saturation)}',
    if (warmth != 0) 'Temperatura ${_signed(warmth)}',
  ];

  String _signed(double value) =>
      '${value > 0 ? '+' : ''}${(value * 100).round()}%';

  EnhanceOptions copyWith({
    EnhanceResolution? resolution,
    bool? denoise,
    double? sharpness,
    bool? stabilize,
    bool? cleanAudio,
    CinemaLook? look,
    bool? cinemaBars,
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
    RenderQuality? quality,
  }) => EnhanceOptions(
    resolution: resolution ?? this.resolution,
    denoise: denoise ?? this.denoise,
    sharpness: sharpness ?? this.sharpness,
    stabilize: stabilize ?? this.stabilize,
    cleanAudio: cleanAudio ?? this.cleanAudio,
    look: look ?? this.look,
    cinemaBars: cinemaBars ?? this.cinemaBars,
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    warmth: warmth ?? this.warmth,
    quality: quality ?? this.quality,
  );

  EnhanceOptions resetColor() =>
      copyWith(brightness: 0, contrast: 0, saturation: 0, warmth: 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnhanceOptions &&
          other.resolution == resolution &&
          other.denoise == denoise &&
          other.sharpness == sharpness &&
          other.stabilize == stabilize &&
          other.cleanAudio == cleanAudio &&
          other.look == look &&
          other.cinemaBars == cinemaBars &&
          other.brightness == brightness &&
          other.contrast == contrast &&
          other.saturation == saturation &&
          other.warmth == warmth &&
          other.quality == quality;

  @override
  int get hashCode => Object.hash(
    resolution,
    denoise,
    sharpness,
    stabilize,
    cleanAudio,
    look,
    cinemaBars,
    brightness,
    contrast,
    saturation,
    warmth,
    quality,
  );
}
