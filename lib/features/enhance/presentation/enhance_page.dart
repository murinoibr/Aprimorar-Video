import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/engine/engine_providers.dart';
import '../../../core/media/media_asset.dart';
import '../../../core/media/media_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/media_widgets.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../application/enhance_controller.dart';
import '../domain/entities/enhance_options.dart';
import '../domain/services/enhance_recipe.dart';

class EnhancePage extends ConsumerWidget {
  const EnhancePage({super.key});

  static Future<void> pickInto(
    BuildContext context,
    WidgetRef ref, {
    bool videos = true,
    bool images = true,
  }) async {
    final picker = ref.read(mediaPickerProvider);
    final assets = await pickSafely<List<MediaAsset>>(context, () async {
      if (videos && images) return picker.pickMedia();
      if (images) return picker.pickImages();
      final video = await picker.pickVideo();
      return video == null ? const [] : [video];
    });
    if (assets == null || assets.isEmpty) return;
    await ref.read(enhanceControllerProvider.notifier).addSources(assets);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(enhanceControllerProvider);
    final controller = ref.read(enhanceControllerProvider.notifier);
    final options = state.options;
    final current = state.current;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              hasSources: state.hasSources,
              busy: state.isRunning,
              onClear: controller.clear,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (current == null)
                    ImportStage(
                      title: 'Traga um vídeo ou fotos',
                      message:
                          'Upscale até 4K, menos ruído, mais nitidez e looks de '
                          'cinema. Tudo no aparelho, sem enviar nada.',
                      onTap: () => pickInto(context, ref),
                      secondary: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _MiniAction(
                            icon: Icons.movie_outlined,
                            label: 'Vídeo',
                            onTap: () => pickInto(context, ref, images: false),
                          ),
                          const SizedBox(width: 10),
                          _MiniAction(
                            icon: Icons.photo_library_outlined,
                            label: 'Fotos',
                            onTap: () => pickInto(context, ref, videos: false),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _LivePreview(source: current, options: options),
                    const SizedBox(height: 12),
                    _SourceStrip(
                      sources: state.sources,
                      selected: state.selected,
                      onSelect: controller.select,
                      onRemove: controller.removeSource,
                      onAdd: () => pickInto(context, ref),
                      enabled: !state.isRunning,
                    ),
                    SectionLabel(
                      'Resolução',
                      trailing: Text(
                        _resolutionHint(options, current),
                        style: AppTheme.timecode.copyWith(fontSize: 11),
                      ),
                    ),
                    ChoiceRow<EnhanceResolution>(
                      values: EnhanceResolution.values,
                      selected: options.resolution,
                      label: (r) => r.label,
                      hint: (r) => r.hint,
                      onChanged: (r) => controller.updateOptions(
                        options.copyWith(resolution: r),
                      ),
                    ),
                    const SectionLabel('Look de cinema'),
                    LookStrip(
                      selected: options.look,
                      onChanged: (l) =>
                          controller.updateOptions(options.copyWith(look: l)),
                    ),
                    ToggleTile(
                      title: 'Faixas 2.39:1',
                      subtitle: 'Widescreen de cinema, sem cortar a imagem',
                      icon: Icons.crop_7_5_rounded,
                      value: options.cinemaBars,
                      onChanged: (v) => controller.updateOptions(
                        options.copyWith(cinemaBars: v),
                      ),
                    ),
                    const SectionLabel('Limpeza e detalhe'),
                    FineSlider(
                      label: 'Nitidez',
                      bipolar: false,
                      value: options.sharpness,
                      onChanged: (v) => controller.updateOptions(
                        options.copyWith(sharpness: v),
                      ),
                    ),
                    ToggleTile(
                      title: 'Reduzir ruído',
                      subtitle: 'Tira o grão de pouca luz e o banding',
                      icon: Icons.grain_rounded,
                      value: options.denoise,
                      onChanged: (v) => controller.updateOptions(
                        options.copyWith(denoise: v),
                      ),
                    ),
                    if (state.hasVideo) ...[
                      ToggleTile(
                        title: 'Estabilizar',
                        subtitle: 'Suaviza a tremida de câmera na mão',
                        icon: Icons.control_camera_rounded,
                        value: options.stabilize,
                        onChanged: (v) => controller.updateOptions(
                          options.copyWith(stabilize: v),
                        ),
                      ),
                      ToggleTile(
                        title: 'Áudio limpo',
                        subtitle: 'Menos chiado e volume no padrão das redes',
                        icon: Icons.graphic_eq_rounded,
                        value: options.cleanAudio,
                        onChanged: (v) => controller.updateOptions(
                          options.copyWith(cleanAudio: v),
                        ),
                      ),
                    ],
                    SectionLabel(
                      'Cor',
                      trailing: options.hasColorAdjust
                          ? GestureDetector(
                              onTap: () => controller.updateOptions(
                                options.resetColor(),
                              ),
                              child: const Text(
                                'ZERAR',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  letterSpacing: 1.4,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null,
                    ),
                    FineSlider(
                      label: 'Exposição',
                      value: options.brightness,
                      onChanged: (v) => controller.updateOptions(
                        options.copyWith(brightness: v),
                      ),
                    ),
                    FineSlider(
                      label: 'Contraste',
                      value: options.contrast,
                      onChanged: (v) => controller.updateOptions(
                        options.copyWith(contrast: v),
                      ),
                    ),
                    FineSlider(
                      label: 'Saturação',
                      value: options.saturation,
                      onChanged: (v) => controller.updateOptions(
                        options.copyWith(saturation: v),
                      ),
                    ),
                    FineSlider(
                      label: 'Temperatura',
                      value: options.warmth,
                      onChanged: (v) =>
                          controller.updateOptions(options.copyWith(warmth: v)),
                    ),
                  ],
                ],
              ),
            ),
            if (state.hasSources) _ActionBar(state: state),
          ],
        ),
      ),
    );
  }

  static String _resolutionHint(EnhanceOptions options, MediaAsset source) {
    final size = EnhanceRecipe.outputSize(options, source);
    if (!source.hasSize || size == null) return '';
    final from = '${source.width}×${source.height}';
    final to = '${size.$1}×${size.$2}';
    return from == to ? from : '$from  ›  $to';
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.hasSources,
    required this.busy,
    required this.onClear,
  });

  final bool hasSources;
  final bool busy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('QUALIDADE · LOOK · COR', style: AppTheme.label),
                const SizedBox(height: 4),
                Text(
                  'Aprimorar',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          if (hasSources && !busy)
            TextButton(onPressed: onClear, child: const Text('Limpar')),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

/// Prévia instantânea: um quadro real, processado pela mesma receita do
/// export final, comparado lado a lado com o original. Cada ajuste gera um
/// quadro novo em fração de segundo — o cliente vê o resultado antes de
/// gastar minutos de render.
class _LivePreview extends ConsumerStatefulWidget {
  const _LivePreview({required this.source, required this.options});

  final MediaAsset source;
  final EnhanceOptions options;

  @override
  ConsumerState<_LivePreview> createState() => _LivePreviewState();
}

class _LivePreviewState extends ConsumerState<_LivePreview> {
  String? _before;
  String? _after;
  bool _loading = false;
  Timer? _debounce;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _schedule(immediate: true, withBefore: true);
  }

  @override
  void didUpdateWidget(covariant _LivePreview old) {
    super.didUpdateWidget(old);
    final sourceChanged = old.source.path != widget.source.path;
    if (sourceChanged) {
      _before = null;
      _after = null;
    }
    if (sourceChanged || old.options != widget.options) {
      _schedule(
        immediate: sourceChanged,
        withBefore:
            sourceChanged ||
            old.options.resolution != widget.options.resolution,
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Duration get _at {
    final d = widget.source.duration;
    if (d == null || d <= Duration.zero) return const Duration(seconds: 1);
    return Duration(milliseconds: (d.inMilliseconds * 0.35).round());
  }

  void _schedule({required bool immediate, required bool withBefore}) {
    _debounce?.cancel();
    setState(() => _loading = true);
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 280),
      () => _render(withBefore: withBefore),
    );
  }

  Future<void> _render({required bool withBefore}) async {
    final generation = ++_generation;
    final grabber = ref.read(frameGrabberProvider);
    final source = widget.source;
    final options = widget.options;
    final isImage = source.isImage;

    final before = withBefore || _before == null
        ? grabber.grab(
            inputPath: source.path,
            at: _at,
            isImage: isImage,
            filters: EnhanceRecipe.previewBefore(options, source),
            lane: 'enhance-before',
            prefix: 'previa_antes',
          )
        : Future.value(_before);
    final after = grabber.grab(
      inputPath: source.path,
      at: _at,
      isImage: isImage,
      filters: EnhanceRecipe.preview(options, source),
      lane: 'enhance-after',
      prefix: 'previa_depois',
    );

    final results = await Future.wait([before, after]);
    if (!mounted || generation != _generation) return;
    setState(() {
      _before = results[0] ?? _before;
      _after = results[1] ?? _after;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final ratio = (source.aspectRatio ?? 16 / 9).clamp(0.62, 1.78);
    final size = EnhanceRecipe.outputSize(widget.options, source);
    final target = size == null
        ? source.tierLabel
        : source.copyWith(width: size.$1, height: size.$2).tierLabel;

    return AspectRatio(
      aspectRatio: ratio,
      child: Viewfinder(
        topLeft: HudText(
          source.isVideo ? 'PREVIEW' : 'FOTO',
          dot: AppColors.accent,
        ),
        topRight: HudText(
          source.tierLabel == target
              ? target
              : '${source.tierLabel}  ›  $target',
          color: AppColors.primary,
        ),
        child: _before == null && _after == null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  MediaThumb(asset: source, fit: BoxFit.contain),
                  const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            : BeforeAfter(before: _before, after: _after, loading: _loading),
      ),
    );
  }
}

class _SourceStrip extends StatelessWidget {
  const _SourceStrip({
    required this.sources,
    required this.selected,
    required this.onSelect,
    required this.onRemove,
    required this.onAdd,
    required this.enabled,
  });

  final List<MediaAsset> sources;
  final int selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<MediaAsset> onRemove;
  final VoidCallback onAdd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final current = sources[selected.clamp(0, sources.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                current.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (sources.length > 1)
              Text(
                '${selected + 1}/${sources.length}',
                style: AppTheme.timecode,
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          techLine(current),
          style: AppTheme.timecode.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sources.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == sources.length) {
                return _Tile(
                  onTap: enabled ? onAdd : null,
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.textSecondary,
                  ),
                );
              }
              final asset = sources[index];
              return _Tile(
                active: index == selected,
                onTap: () => onSelect(index),
                onLongPress: enabled ? () => onRemove(asset) : null,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MediaThumb(asset: asset),
                    if (asset.isVideo)
                      const Positioned(
                        right: 3,
                        bottom: 2,
                        child: Icon(
                          Icons.videocam_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (sources.length > 1)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Segure uma miniatura para tirar do lote.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.active = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 56,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: active ? 1.6 : 1,
          ),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.state});

  final EnhanceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(enhanceControllerProvider.notifier);
    final count = state.sources.length;
    final Widget content;

    if (state.isRunning) {
      final eta = state.etaSeconds;
      content = RenderProgressPanel(
        fraction: state.progress,
        title: count > 1
            ? '${state.stage.label} · ${state.currentIndex + 1} de $count'
            : state.stage.label,
        detail: eta == null
            ? 'Processando no aparelho'
            : 'Faltam ~${_eta(eta)}',
        onCancel: controller.cancel,
      );
    } else if (state.status == EnhanceStatus.done && state.results.isNotEmpty) {
      content = ResultPanel(
        assets: state.results,
        feature: 'Aprimorar',
        onAgain: controller.run,
        againLabel: 'Refazer',
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.errorMessage != null) ...[
            InlineError(state.errorMessage!),
            const SizedBox(height: 10),
          ],
          Text(
            state.options.activeFilters.isEmpty
                ? 'Sem ajustes: cópia fiel'
                : state.options.activeFilters.join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTheme.timecode.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: count > 1 ? 'Aprimorar $count arquivos' : 'Aprimorar',
            icon: Icons.auto_awesome_rounded,
            onPressed: controller.run,
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: content,
      ),
    );
  }

  static String _eta(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '${m}min' : '${m}min ${s}s';
  }
}
