import 'cinema_look.dart';

enum RenderQuality {
  leve('Leve', 'Arquivo pequeno, exporta mais rápido', 28),
  equilibrado('Equilibrado', 'Recomendado', 23),
  maxima('Máxima', 'Melhor imagem, arquivo maior', 18);

  const RenderQuality(this.label, this.hint, this.crf);

  final String label;
  final String hint;
  final int crf;
}

enum OutputFormat {
  original('Original', 'Proporção do vídeo', null, null),
  vertical('Vertical 9:16', 'Reels, Shorts, TikTok', 1080, 1920),
  square('Quadrado 1:1', 'Feed', 1080, 1080),
  horizontal('Horizontal 16:9', 'YouTube', 1920, 1080);

  const OutputFormat(this.label, this.hint, this.width, this.height);

  final String label;
  final String hint;
  final int? width;
  final int? height;

  bool get keepsOriginalSize => width == null || height == null;

  String get ratio => switch (this) {
    OutputFormat.original => 'auto',
    OutputFormat.vertical => '9:16',
    OutputFormat.square => '1:1',
    OutputFormat.horizontal => '16:9',
  };
}

class RenderSettings {
  const RenderSettings({
    this.format = OutputFormat.original,
    this.fps,
    this.quality = RenderQuality.equilibrado,
    this.keepAudio = true,
    this.look = CinemaLook.natural,
    this.cinemaBars = false,
  });

  final OutputFormat format;
  final int? fps;
  final RenderQuality quality;
  final bool keepAudio;

  /// Color grading aplicado no export.
  final CinemaLook look;

  /// Faixas pretas 2.39:1.
  final bool cinemaBars;

  /// Filtros de estética (look + faixas), aplicados depois da escala.
  List<String> get styleFilters => [
    ...look.filters,
    if (cinemaBars) ...cinemaBarsFilters,
  ];

  static const defaults = RenderSettings();
  static const fpsOptions = [24, 30, 60];

  int get crf => quality.crf;

  bool get matchesSource =>
      format.keepsOriginalSize && fps == null && styleFilters.isEmpty;

  String get label => [
    format.ratio,
    fps == null ? 'fps original' : '${fps}fps',
    quality.label,
    if (!look.isNeutral) look.label,
  ].join(' · ');

  RenderSettings copyWith({
    OutputFormat? format,
    int? fps,
    RenderQuality? quality,
    bool? keepAudio,
    CinemaLook? look,
    bool? cinemaBars,
    bool clearFps = false,
  }) => RenderSettings(
    format: format ?? this.format,
    fps: clearFps ? null : (fps ?? this.fps),
    quality: quality ?? this.quality,
    keepAudio: keepAudio ?? this.keepAudio,
    look: look ?? this.look,
    cinemaBars: cinemaBars ?? this.cinemaBars,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenderSettings &&
          other.format == format &&
          other.fps == fps &&
          other.quality == quality &&
          other.keepAudio == keepAudio &&
          other.look == look &&
          other.cinemaBars == cinemaBars;

  @override
  int get hashCode =>
      Object.hash(format, fps, quality, keepAudio, look, cinemaBars);
}
