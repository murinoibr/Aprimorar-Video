import '../utils/duration_x.dart';

enum MediaKind {
  video('Vídeo', 'mp4'),
  image('Foto', 'jpg');

  const MediaKind(this.label, this.extension);

  final String label;
  final String extension;
}

class MediaAsset {
  const MediaAsset({
    required this.path,
    required this.name,
    required this.kind,
    required this.sizeBytes,
    this.duration,
    this.width,
    this.height,
    this.fps,
    this.bitrate,
  });

  final String path;
  final String name;
  final MediaKind kind;
  final int sizeBytes;
  final Duration? duration;
  final int? width;
  final int? height;
  final double? fps;
  final int? bitrate;

  bool get isVideo => kind == MediaKind.video;

  bool get isImage => kind == MediaKind.image;

  String get sizeLabel => formatBytes(sizeBytes);

  bool get hasSize => (width ?? 0) > 0 && (height ?? 0) > 0;

  bool get isPortrait => hasSize && height! > width!;

  /// Lado menor, que é o que define "1080p" tanto em vídeo deitado quanto em
  /// pé (1080x1920 também é Full HD).
  int? get shortSide => hasSize ? (width! < height! ? width : height) : null;

  double? get aspectRatio => hasSize ? width! / height! : null;

  String get tierLabel {
    final side = shortSide;
    if (side == null) return '—';
    if (!isVideo) {
      final mp = width! * height! / 1000000;
      return '${mp.toStringAsFixed(mp >= 10 ? 0 : 1)} MP';
    }
    return switch (side) {
      >= 2160 => '4K',
      >= 1440 => '2K',
      >= 1080 => 'Full HD',
      >= 720 => 'HD',
      _ => 'SD',
    };
  }

  String get resolutionLabel {
    if (!hasSize) return '—';
    return '$tierLabel · ${width!}x${height!}';
  }

  bool get isLarge => sizeBytes > 500 * 1024 * 1024;

  MediaAsset copyWith({
    String? path,
    String? name,
    MediaKind? kind,
    int? sizeBytes,
    Duration? duration,
    int? width,
    int? height,
    double? fps,
    int? bitrate,
  }) => MediaAsset(
    path: path ?? this.path,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    duration: duration ?? this.duration,
    width: width ?? this.width,
    height: height ?? this.height,
    fps: fps ?? this.fps,
    bitrate: bitrate ?? this.bitrate,
  );

  Map<String, Object?> toJson() => {
    'path': path,
    'name': name,
    'kind': kind.name,
    'sizeBytes': sizeBytes,
    'durationMs': duration?.inMilliseconds,
    'width': width,
    'height': height,
    'fps': fps,
    'bitrate': bitrate,
  };

  static MediaAsset? fromJson(Map<String, Object?> json) {
    final path = json['path'];
    final name = json['name'];
    if (path is! String || name is! String) return null;
    final durationMs = json['durationMs'];
    return MediaAsset(
      path: path,
      name: name,
      kind: json['kind'] == MediaKind.image.name
          ? MediaKind.image
          : MediaKind.video,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      duration: durationMs is num
          ? Duration(milliseconds: durationMs.toInt())
          : null,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      fps: (json['fps'] as num?)?.toDouble(),
      bitrate: (json['bitrate'] as num?)?.toInt(),
    );
  }
}
