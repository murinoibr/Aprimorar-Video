import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/media_information.dart';
import 'package:ffmpeg_kit_flutter_new_full/stream_information.dart';
import 'package:video_player/video_player.dart';

import 'media_asset.dart';

/// Descobre metadados que o `file_picker` não traz.
///
/// Duas fontes, em ordem: **FFprobe** (duração, resolução, fps e bitrate
/// exatos, sem decodificar) e, como reserva, `video_player`. O `video_player`
/// sozinho nunca devolve `fps` nem `bitrate` — justamente os campos que o
/// timeline usa para quantizar o corte por frame e o `MediaAsset` exibe ao
/// cliente.
class MediaProbe {
  const MediaProbe();

  Future<MediaAsset> enrich(MediaAsset asset) async {
    if (asset.path.isEmpty) return asset;
    if (!File(asset.path).existsSync()) return asset;

    final probed = await _enrichWithFfprobe(asset);
    if (!asset.isVideo) return probed ?? asset;
    if (probed != null) return probed;
    return _enrichWithPlayer(asset);
  }

  /// Verdadeiro se a fonte tem faixa de áudio.
  ///
  /// Sem isso, um `-map 0:a` num vídeo mudo quebra o concat inteiro, então o
  /// repositório de render precisa saber antes de montar o comando.
  Future<bool> hasAudio(String path) async {
    final information = await _probe(path);
    if (information == null) return false;
    return information.getStreams().any(
      (stream) => stream.getType() == 'audio',
    );
  }

  Future<MediaAsset?> _enrichWithFfprobe(MediaAsset asset) async {
    final information = await _probe(asset.path);
    if (information == null) return null;

    StreamInformation? video;
    for (final stream in information.getStreams()) {
      if (stream.getType() == 'video') {
        video = stream;
        break;
      }
    }

    final duration = _seconds(information.getDuration());
    var width = _int(video?.getStringProperty(StreamInformation.keyWidth));
    var height = _int(video?.getStringProperty(StreamInformation.keyHeight));
    // Celular grava vídeo em pé como 1920x1080 + metadado de rotação. O FFmpeg
    // gira ao decodificar, então a UI e a escala precisam das medidas giradas.
    if (_isQuarterTurn(video)) {
      final swap = width;
      width = height;
      height = swap;
    }
    final fps = _ratio(video?.getAverageFrameRate());
    final bitrate =
        _int(information.getBitrate()) ??
        _int(video?.getStringProperty(StreamInformation.keyBitRate));

    // FFprobe sem streams de vídeo devolve format=null: trata como falha para
    // cair no `video_player`, que dá um erro mais claro.
    if (video == null && duration == null) return null;

    if (!asset.isVideo) {
      return asset.copyWith(width: width, height: height);
    }

    return MediaAsset(
      path: asset.path,
      name: asset.name,
      kind: asset.kind,
      sizeBytes: asset.sizeBytes,
      duration: asset.duration ?? duration,
      width: asset.width ?? width,
      height: asset.height ?? height,
      fps: asset.fps ?? fps,
      bitrate: asset.bitrate ?? bitrate,
    );
  }

  Future<MediaAsset> _enrichWithPlayer(MediaAsset asset) async {
    final controller = VideoPlayerController.file(File(asset.path));
    try {
      await controller.initialize();
      final value = controller.value;
      return MediaAsset(
        path: asset.path,
        name: asset.name,
        kind: asset.kind,
        sizeBytes: asset.sizeBytes,
        duration: asset.duration ?? value.duration,
        width: asset.width ?? value.size.width.round(),
        height: asset.height ?? value.size.height.round(),
        fps: asset.fps,
        bitrate: asset.bitrate,
      );
    } on Object {
      return asset;
    } finally {
      await controller.dispose();
    }
  }

  Future<MediaInformation?> _probe(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      return session.getMediaInformation();
    } on Object {
      return null;
    }
  }

  bool _isQuarterTurn(StreamInformation? stream) {
    if (stream == null) return false;
    final props = stream.getAllProperties() ?? const {};
    num? rotation;
    final sideData = props['side_data_list'];
    if (sideData is List) {
      for (final entry in sideData) {
        if (entry is Map && entry['rotation'] is num) {
          rotation = entry['rotation'] as num;
        }
      }
    }
    final tags = props['tags'];
    if (rotation == null && tags is Map) {
      rotation = num.tryParse('${tags['rotate'] ?? ''}');
    }
    if (rotation == null) return false;
    return (rotation.round().abs() % 180) == 90;
  }

  /// Duração em segundos. O FFprobe devolve string decimal.
  Duration? _seconds(String? raw) {
    final value = _double(raw);
    if (value == null || value <= 0 || !value.isFinite) return null;
    return Duration(milliseconds: (value * 1000).round());
  }

  /// Converte `num/den` de taxa de quadro (ex.: `30000/1001`) em double.
  double? _ratio(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('/');
    if (parts.length == 2) {
      final den = double.tryParse(parts[1]);
      final num = double.tryParse(parts[0]);
      if (num == null || den == null || den == 0) return null;
      final value = num / den;
      return value > 0 && value.isFinite ? value : null;
    }
    return _double(raw);
  }

  int? _int(String? raw) {
    final value = _double(raw);
    if (value == null || value <= 0 || !value.isFinite) return null;
    return value.round();
  }

  double? _double(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return double.tryParse(raw.trim());
  }
}
