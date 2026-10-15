import 'dart:async';
import 'dart:io';

import '../../../core/engine/command_builder.dart';
import '../../../core/engine/render_engine.dart';
import '../../../core/engine/render_job.dart';
import '../../../core/engine/staging.dart';
import '../../../core/media/media_asset.dart';
import '../../../core/media/media_probe.dart';
import '../domain/entities/enhance_job.dart';
import '../domain/entities/enhance_options.dart';
import '../domain/repositories/enhance_repository.dart';
import '../domain/services/enhance_recipe.dart';

/// Aprimoramento real, arquivo por arquivo, no próprio aparelho.
///
/// Substitui a versão anterior, que chamava uma classe inexistente
/// (`RenderFormat`) — o app nem compilava — e, mesmo se compilasse, mandava
/// fotos para um comando de corte de vídeo e ignorava ruído, nitidez e cor.
class FfmpegEnhanceRepository implements EnhanceRepository {
  FfmpegEnhanceRepository({
    required this.engine,
    required this.probe,
    required this._codec,
    RenderStaging? staging,
  }) : _staging = staging ?? const RenderStaging();

  final RenderEngine engine;
  final MediaProbe probe;
  final HwCodec _codec;
  final RenderStaging _staging;

  bool _cancelled = false;
  List<MediaAsset> _results = const [];

  @override
  List<MediaAsset> get results => _results;

  @override
  Stream<EnhanceProgress> enhance(
    List<MediaAsset> sources,
    EnhanceOptions options,
  ) async* {
    _cancelled = false;
    _results = const [];
    final total = sources.length;
    final produced = <MediaAsset>[];

    for (var index = 0; index < total; index++) {
      if (_cancelled) return;
      yield EnhanceProgress(
        stage: EnhanceStage.preparing,
        percent: index / total,
        index: index,
        total: total,
      );

      final source = await probe.enrich(sources[index]);
      final request = source.isVideo
          ? await _videoRequest(source, options)
          : await _imageRequest(source, options);

      await for (final progress in engine.run(request)) {
        if (_cancelled) return;
        if (progress.stage == RenderStage.done) continue;
        final stage = progress.stage == RenderStage.finalizing
            ? EnhanceStage.saving
            : (source.isVideo
                  ? EnhanceStage.processing
                  : EnhanceStage.encoding);
        yield EnhanceProgress(
          stage: stage,
          percent: (index + progress.fraction) / total,
          etaSeconds: progress.eta?.inSeconds,
          index: index,
          total: total,
        );
      }
      if (_cancelled) return;

      produced.add(await _describe(request.outputPath, source, options));
    }

    _results = List.unmodifiable(produced);
    yield EnhanceProgress(
      stage: EnhanceStage.done,
      percent: 1,
      index: total - 1,
      total: total,
    );
  }

  Future<RenderRequest> _videoRequest(
    MediaAsset source,
    EnhanceOptions options,
  ) async {
    final output = await _staging.newOutputPath(
      prefix: 'aprimorado_${_stem(source.name)}',
      extension: 'mp4',
    );
    final hasAudio = await probe.hasAudio(source.path);
    final size = EnhanceRecipe.outputSize(options, source);
    final fps = source.fps?.round();

    List<String> build(HwCodec codec) => FfmpegCommand.enhanceVideo(
      inputPath: source.path,
      outputPath: output,
      videoFilters: EnhanceRecipe.video(options, source),
      audioFilters: EnhanceRecipe.audio(options),
      width: size?.$1,
      height: size?.$2,
      fps: fps,
      quality: options.quality,
      codec: codec,
      sourceHasAudio: hasAudio,
    );

    return RenderRequest(
      arguments: build(_codec),
      fallbackArguments: _codec.isHardware ? build(HwCodec.software) : null,
      outputPath: output,
      expectedDurationMs: source.duration?.inMilliseconds ?? 0,
      label: 'Aprimorando ${source.name}',
    );
  }

  Future<RenderRequest> _imageRequest(
    MediaAsset source,
    EnhanceOptions options,
  ) async {
    final output = await _staging.newOutputPath(
      prefix: 'foto_${_stem(source.name)}',
      extension: 'jpg',
    );
    return RenderRequest(
      arguments: FfmpegCommand.enhanceImage(
        inputPath: source.path,
        outputPath: output,
        filters: EnhanceRecipe.image(options, source),
      ),
      outputPath: output,
      expectedDurationMs: 0,
      label: 'Aprimorando ${source.name}',
    );
  }

  Future<MediaAsset> _describe(
    String path,
    MediaAsset source,
    EnhanceOptions options,
  ) async {
    final file = File(path);
    final size = EnhanceRecipe.outputSize(options, source);
    final asset = MediaAsset(
      path: path,
      name: path.split('/').last,
      kind: source.kind,
      sizeBytes: file.existsSync() ? file.lengthSync() : 0,
      duration: source.duration,
      fps: source.fps,
    );
    final probed = await probe.enrich(asset);
    return probed.hasSize || size == null
        ? probed
        : probed.copyWith(width: size.$1, height: size.$2);
  }

  static String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  @override
  void cancel() {
    _cancelled = true;
    unawaited(engine.cancel());
  }
}
