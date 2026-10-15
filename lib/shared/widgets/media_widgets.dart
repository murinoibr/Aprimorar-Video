import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/engine/engine_providers.dart';
import '../../core/media/media_asset.dart';
import '../../core/media/media_picker.dart';
import '../../core/media/media_providers.dart';
import '../../core/media/render_settings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/duration_x.dart';
import '../../features/library/application/library_controller.dart';
import 'ui_kit.dart';

/// Abre o seletor e transforma qualquer falha em aviso na tela, em vez de o
/// toque "não fazer nada".
Future<T?> pickSafely<T>(
  BuildContext context,
  Future<T> Function() pick,
) async {
  try {
    return await pick();
  } on MediaPickException catch (error) {
    if (context.mounted) showToast(context, error.message);
  } on Object catch (error) {
    if (context.mounted) {
      showToast(context, 'Não foi possível abrir o arquivo: $error');
    }
  }
  return null;
}

/// Área vazia de importação, desenhada como um visor de câmera.
class ImportStage extends StatelessWidget {
  const ImportStage({
    super.key,
    required this.title,
    required this.message,
    required this.onTap,
    this.icon = Icons.add_rounded,
    this.aspectRatio = 4 / 5,
    this.secondary,
  });

  final String title;
  final String message;
  final VoidCallback onTap;
  final IconData icon;
  final double aspectRatio;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Viewfinder(
        background: AppColors.surface,
        topLeft: const HudText('STBY', dot: AppColors.textMuted),
        topRight: const HudText('--:--:--'),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 1.4,
                        ),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (secondary != null) ...[
                      const SizedBox(height: 18),
                      secondary!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Miniatura de vídeo ou foto, gerada uma vez e guardada em cache.
class MediaThumb extends ConsumerWidget {
  const MediaThumb({super.key, required this.asset, this.fit = BoxFit.cover});

  final MediaAsset asset;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (asset.isImage) {
      return Image.file(
        File(asset.path),
        fit: fit,
        cacheWidth: 480,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            const _ThumbFallback(icon: Icons.image_outlined),
      );
    }
    final path = ref.watch(thumbnailProvider(asset.path)).value;
    if (path == null) return const _ThumbFallback(icon: Icons.movie_outlined);
    return Image.file(
      File(path),
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          const _ThumbFallback(icon: Icons.movie_outlined),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.surfaceHigh,
    child: Center(child: Icon(icon, size: 20, color: AppColors.textMuted)),
  );
}

/// Linha técnica: resolução · duração · peso.
String techLine(MediaAsset asset) => [
  if (asset.hasSize) '${asset.width}×${asset.height}',
  if (asset.isVideo && asset.duration != null) asset.duration!.clock,
  if (asset.isVideo && asset.fps != null) '${asset.fps!.round()} fps',
  if (asset.sizeBytes > 0) asset.sizeLabel,
].join('  ·  ');

/// Painel de resultado: prévia, ficha técnica e as ações que importam.
class ResultPanel extends ConsumerStatefulWidget {
  const ResultPanel({
    super.key,
    required this.assets,
    required this.feature,
    this.onAgain,
    this.againLabel = 'Refazer',
  });

  final List<MediaAsset> assets;
  final String feature;
  final VoidCallback? onAgain;
  final String againLabel;

  @override
  ConsumerState<ResultPanel> createState() => _ResultPanelState();
}

class _ResultPanelState extends ConsumerState<ResultPanel> {
  bool _saving = false;
  bool _saved = false;

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    final saver = ref.read(gallerySaverProvider);
    final library = ref.read(libraryProvider.notifier);
    var ok = 0;
    String? failure;
    for (final asset in widget.assets) {
      final outcome = await saver.save(asset);
      if (outcome.isSuccess) {
        ok++;
      } else {
        failure = outcome.message;
      }
      await library.add(asset, widget.feature);
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = ok == widget.assets.length;
    });
    showToast(
      context,
      failure ??
          (ok == 1 ? 'Salvo na galeria' : '$ok arquivos salvos na galeria'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.assets.first;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => openViewer(context, first),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MediaThumb(asset: first),
                        if (first.isVideo)
                          const Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HudText('PRONTO', dot: AppColors.success),
                    const SizedBox(height: 8),
                    Text(
                      widget.assets.length == 1
                          ? first.tierLabel == '—'
                                ? 'Seu arquivo está pronto'
                                : '${first.tierLabel} pronto'
                          : '${widget.assets.length} arquivos prontos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      techLine(first),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.timecode.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: _saved ? 'Salvo na galeria' : 'Salvar na galeria',
            icon: _saved ? Icons.check_rounded : Icons.download_rounded,
            enabled: !_saving && !_saved,
            onPressed: _saveAll,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => openViewer(context, first),
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                  label: const Text('Assistir'),
                ),
              ),
              if (widget.onAgain != null)
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.onAgain,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(widget.againLabel),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

void openViewer(BuildContext context, MediaAsset asset) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => MediaViewerPage(asset: asset)),
  );
}

/// Tela cheia, fundo preto, só a imagem — como numa sala de projeção.
class MediaViewerPage extends StatefulWidget {
  const MediaViewerPage({super.key, required this.asset});

  final MediaAsset asset;

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  VideoPlayerController? _video;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.asset.isVideo) _open();
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.file(File(widget.asset.path));
    _video = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
    } on Object {
      _failed = true;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final video = _video;
    Widget body;
    if (asset.isImage) {
      body = InteractiveViewer(
        maxScale: 6,
        child: Center(child: Image.file(File(asset.path), fit: BoxFit.contain)),
      );
    } else if (_failed) {
      body = const EmptyState(
        icon: Icons.videocam_off_outlined,
        title: 'Não foi possível reproduzir',
        message: 'O arquivo pode ter sido removido do aparelho.',
      );
    } else if (video == null || !video.value.isInitialized) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 1.6));
    } else {
      body = GestureDetector(
        onTap: () => setState(() {
          video.value.isPlaying ? video.pause() : video.play();
        }),
        child: Center(
          child: AspectRatio(
            aspectRatio: video.value.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayer(video),
                if (!video.value.isPlaying)
                  const Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    video,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.primary,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          asset.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: body),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(techLine(asset), style: AppTheme.timecode),
            ),
          ],
        ),
      ),
    );
  }
}

/// Folha de exportação compartilhada por Cortar e Momentos.
Future<RenderSettings?> showExportSheet(
  BuildContext context, {
  required RenderSettings initial,
  String action = 'Exportar',
}) {
  return showModalBottomSheet<RenderSettings>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ExportSheet(initial: initial, action: action),
  );
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.initial, required this.action});

  final RenderSettings initial;
  final String action;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  late RenderSettings _settings = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exportar', style: Theme.of(context).textTheme.titleLarge),
            SectionLabel(
              'Formato',
              padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
            ),
            ChoiceRow<OutputFormat>(
              values: OutputFormat.values,
              selected: _settings.format,
              label: (f) => f == OutputFormat.original ? 'Original' : f.ratio,
              hint: (f) => f.hint,
              onChanged: (f) =>
                  setState(() => _settings = _settings.copyWith(format: f)),
            ),
            SectionLabel(
              'Look',
              padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
            ),
            LookStrip(
              selected: _settings.look,
              onChanged: (l) =>
                  setState(() => _settings = _settings.copyWith(look: l)),
            ),
            ToggleTile(
              title: 'Faixas de cinema 2.39:1',
              subtitle: 'Enquadramento widescreen (só vídeo deitado)',
              value: _settings.cinemaBars,
              onChanged: (v) =>
                  setState(() => _settings = _settings.copyWith(cinemaBars: v)),
            ),
            SectionLabel(
              'Qualidade',
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
            ),
            ChoiceRow<RenderQuality>(
              values: RenderQuality.values,
              selected: _settings.quality,
              label: (q) => q.label,
              hint: (q) => q.hint,
              onChanged: (q) =>
                  setState(() => _settings = _settings.copyWith(quality: q)),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: widget.action,
              icon: Icons.movie_creation_outlined,
              onPressed: () => Navigator.of(context).pop(_settings),
            ),
          ],
        ),
      ),
    );
  }
}
