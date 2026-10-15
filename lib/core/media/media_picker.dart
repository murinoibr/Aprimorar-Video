import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'media_asset.dart';

/// Falha ao trazer um arquivo, já com texto para o cliente.
class MediaPickException implements Exception {
  const MediaPickException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Seleção de vídeos e fotos.
///
/// Fotos usam o tipo `image` do seletor, que no Android abre a **galeria**
/// (Google Fotos / Galeria) e no iOS o PHPicker. O tipo `custom` com lista de
/// extensões, usado antes, abria o gerenciador de arquivos — onde a maioria
/// das fotos do celular nem aparece — e era por isso que a foto "não subia".
class MediaPicker {
  const MediaPicker();

  static const imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
    'bmp',
    'gif',
    'tif',
    'tiff',
    'dng',
  };

  /// Formatos que o FFmpeg nem sempre decodifica; viram PNG pelo decodificador
  /// de imagem do próprio sistema antes de entrar no pipeline.
  static const _platformDecoded = {'heic', 'heif', 'dng'};

  Future<MediaAsset?> pickVideo() async {
    final files = await _pick(type: FileType.video, title: 'Escolher vídeo');
    if (files.isEmpty) return null;
    return _assetFrom(files.first, forceKind: MediaKind.video);
  }

  Future<List<MediaAsset>> pickImages() async {
    final files = await _pick(type: FileType.image, title: 'Escolher fotos');
    final assets = <MediaAsset>[];
    for (final file in files) {
      final asset = await _assetFrom(file, forceKind: MediaKind.image);
      if (asset != null) assets.add(asset);
    }
    return assets;
  }

  /// Vídeos e fotos misturados, para a importação rápida da tela inicial.
  Future<List<MediaAsset>> pickMedia() async {
    final files = await _pick(type: FileType.media, title: 'Importar mídia');
    final assets = <MediaAsset>[];
    for (final file in files) {
      final asset = await _assetFrom(file);
      if (asset != null) assets.add(asset);
    }
    return assets;
  }

  Future<List<PlatformFile>> _pick({
    required FileType type,
    required String title,
  }) async {
    try {
      final files = await FilePicker.pickFiles(dialogTitle: title, type: type);
      return files.where((f) => (f.path ?? '').isNotEmpty).toList();
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      if (code.contains('permission') || code.contains('denied')) {
        throw const MediaPickException(
          'Sem acesso às mídias. Libere a permissão nas configurações.',
        );
      }
      throw MediaPickException(
        'Não foi possível abrir a galeria (${error.message ?? error.code}).',
      );
    }
  }

  Future<MediaAsset?> _assetFrom(
    PlatformFile file, {
    MediaKind? forceKind,
  }) async {
    var path = file.path ?? '';
    if (path.isEmpty || !File(path).existsSync()) return null;

    final extension = (file.extension ?? _extensionOf(path)).toLowerCase();
    final kind =
        forceKind ??
        (imageExtensions.contains(extension)
            ? MediaKind.image
            : MediaKind.video);
    var name = file.name;

    if (kind == MediaKind.image && _platformDecoded.contains(extension)) {
      final converted = await _toPng(path);
      if (converted == null) {
        throw MediaPickException(
          'Não foi possível abrir "${file.name}". Tente exportar a foto como JPEG.',
        );
      }
      path = converted;
      name = '${_stem(name)}.png';
    }

    return MediaAsset(
      path: path,
      name: name,
      kind: kind,
      sizeBytes: File(path).lengthSync(),
    );
  }

  /// Decodifica com o codec do sistema (HEIC no iPhone e Android 9+) e grava
  /// PNG sem perda. Devolve `null` se o aparelho não souber ler o formato.
  Future<String?> _toPng(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (data == null) return null;
      final dir = await workingDirectory();
      final out = File(
        '${dir.path}/foto_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return out.path;
    } on Object {
      return null;
    }
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    return dot < 0 ? '' : path.substring(dot + 1);
  }

  static String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  Future<Directory> workingDirectory() async {
    final root = await getTemporaryDirectory();
    final dir = Directory('${root.path}/aprimorar_video');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
}
