import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/media/media_asset.dart';

class ExportEntry {
  const ExportEntry({
    required this.asset,
    required this.feature,
    required this.createdAt,
  });

  final MediaAsset asset;
  final String feature;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'asset': asset.toJson(),
    'feature': feature,
    'createdAt': createdAt.toIso8601String(),
  };

  static ExportEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final asset = json['asset'];
    if (asset is! Map) return null;
    final parsed = MediaAsset.fromJson(asset.cast<String, Object?>());
    if (parsed == null) return null;
    return ExportEntry(
      asset: parsed,
      feature: json['feature'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Onde a biblioteca mora. Separado para os testes trocarem por memória.
abstract interface class LibraryStore {
  Future<List<ExportEntry>> load();
  Future<void> save(List<ExportEntry> entries);

  /// Copia o arquivo para fora do cache (que o sistema limpa sozinho).
  Future<MediaAsset> keep(MediaAsset asset);
  Future<void> delete(MediaAsset asset);
}

class FileLibraryStore implements LibraryStore {
  const FileLibraryStore();

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/biblioteca');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _index() async => File('${(await _dir()).path}/index.json');

  @override
  Future<List<ExportEntry>> load() async {
    try {
      final file = await _index();
      if (!file.existsSync()) return const [];
      final data = jsonDecode(await file.readAsString());
      if (data is! List) return const [];
      return [
        for (final item in data)
          if (ExportEntry.fromJson(item) case final entry?)
            if (File(entry.asset.path).existsSync()) entry,
      ];
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> save(List<ExportEntry> entries) async {
    final file = await _index();
    await file.writeAsString(jsonEncode([for (final e in entries) e.toJson()]));
  }

  @override
  Future<MediaAsset> keep(MediaAsset asset) async {
    final dir = await _dir();
    if (asset.path.startsWith(dir.path)) return asset;
    final source = File(asset.path);
    if (!source.existsSync()) return asset;
    final target = '${dir.path}/${asset.name}';
    final copied = await source.copy(
      File(target).existsSync()
          ? '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${asset.name}'
          : target,
    );
    return asset.copyWith(path: copied.path, name: copied.path.split('/').last);
  }

  @override
  Future<void> delete(MediaAsset asset) async {
    final dir = await _dir();
    final file = File(asset.path);
    if (asset.path.startsWith(dir.path) && file.existsSync()) {
      await file.delete();
    }
  }
}

final libraryStoreProvider = Provider<LibraryStore>(
  (ref) => const FileLibraryStore(),
);

final libraryProvider = NotifierProvider<LibraryController, List<ExportEntry>>(
  LibraryController.new,
);

/// Tudo o que o cliente guardou, persistido entre aberturas do app.
class LibraryController extends Notifier<List<ExportEntry>> {
  @override
  List<ExportEntry> build() {
    _restore();
    return const [];
  }

  LibraryStore get _store => ref.read(libraryStoreProvider);

  Future<void> _restore() async {
    final saved = await _store.load();
    if (saved.isEmpty) return;
    final known = state.map((e) => e.asset.path).toSet();
    state = [...state, ...saved.where((e) => !known.contains(e.asset.path))];
  }

  bool contains(MediaAsset asset) => state.any(
    (e) => e.asset.path == asset.path || e.asset.name == asset.name,
  );

  Future<void> add(MediaAsset asset, String feature) async {
    if (contains(asset)) return;
    MediaAsset kept;
    try {
      kept = await _store.keep(asset);
    } on Object {
      kept = asset;
    }
    state = [
      ExportEntry(asset: kept, feature: feature, createdAt: DateTime.now()),
      ...state,
    ];
    await _persist();
  }

  Future<void> remove(MediaAsset asset) async {
    state = state.where((e) => e.asset.path != asset.path).toList();
    try {
      await _store.delete(asset);
    } on Object {
      // Arquivo já removido.
    }
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _store.save(state);
    } on Object {
      // Sem disco: a lista continua em memória nesta sessão.
    }
  }
}
