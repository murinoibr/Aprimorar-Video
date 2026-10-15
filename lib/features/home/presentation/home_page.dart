import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/cinema_look.dart';
import '../../../core/media/media_asset.dart';
import '../../../core/media/media_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/media_widgets.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../enhance/application/enhance_controller.dart';
import '../../highlights/application/highlights_controller.dart';
import '../../library/application/library_controller.dart';
import '../../trim/application/trim_controller.dart';
import 'profile_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({
    super.key,
    required this.onGoTrim,
    required this.onGoHighlights,
    required this.onGoEnhance,
    required this.onGoLibrary,
  });

  final VoidCallback onGoTrim;
  final VoidCallback onGoHighlights;
  final VoidCallback onGoEnhance;
  final VoidCallback onGoLibrary;

  /// Importação única: o app entende o que chegou e oferece o caminho certo.
  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final assets = await pickSafely(
      context,
      () => ref.read(mediaPickerProvider).pickMedia(),
    );
    if (assets == null || assets.isEmpty || !context.mounted) return;

    final videos = assets.where((a) => a.isVideo).toList();
    if (videos.isEmpty || assets.length > 1) {
      onGoEnhance();
      await ref.read(enhanceControllerProvider.notifier).addSources(assets);
      return;
    }

    final video = videos.first;
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => _NextStepSheet(asset: video),
    );
    switch (choice) {
      case 0:
        onGoEnhance();
        await ref.read(enhanceControllerProvider.notifier).addSources([video]);
      case 1:
        onGoTrim();
        await ref.read(trimControllerProvider.notifier).selectSource(video);
      case 2:
        onGoHighlights();
        await ref
            .read(highlightsControllerProvider.notifier)
            .selectSource(video);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                const Text(
                  'VANGOGH',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Perfil e apoio',
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfilePage(),
                    ),
                  ),
                  icon: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              'Seu vídeo,\nnível cinema.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Upscale até 4K, looks de cinema, cortes e melhores momentos. '
              'Tudo processado no aparelho — rápido, privado e sem custo.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _import(context, ref),
              child: const AspectRatio(
                aspectRatio: 16 / 10,
                child: _LookReel(),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Importar vídeo ou fotos',
              icon: Icons.add_rounded,
              onPressed: () => _import(context, ref),
            ),
            const SectionLabel('Ferramentas'),
            _ToolRow(
              index: '01',
              title: 'Aprimorar',
              subtitle: 'Resolução, nitidez, ruído, cor e looks',
              icon: Icons.auto_awesome_rounded,
              onTap: onGoEnhance,
            ),
            _ToolRow(
              index: '02',
              title: 'Melhores momentos',
              subtitle: 'O corte de 30 s a 2 min, sozinho',
              icon: Icons.bolt_rounded,
              onTap: onGoHighlights,
            ),
            _ToolRow(
              index: '03',
              title: 'Cortar',
              subtitle: 'Trechos com precisão de quadro',
              icon: Icons.content_cut_rounded,
              onTap: onGoTrim,
            ),
            if (library.isNotEmpty) ...[
              SectionLabel(
                'Recentes',
                trailing: GestureDetector(
                  onTap: onGoLibrary,
                  child: const Text(
                    'VER TUDO',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.4,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: library.length.clamp(0, 10),
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final entry = library[index];
                    return GestureDetector(
                      onTap: () => openViewer(context, entry.asset),
                      child: SizedBox(
                        width: 96,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MediaThumb(asset: entry.asset),
                              Positioned(
                                left: 6,
                                bottom: 6,
                                child: HudText(entry.feature.toUpperCase()),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Visor que alterna os looks de cinema: mostra o que o app faz sem precisar
/// de nenhum vídeo de demonstração embutido (zero MB a mais no APK).
class _LookReel extends StatefulWidget {
  const _LookReel();

  @override
  State<_LookReel> createState() => _LookReelState();
}

class _LookReelState extends State<_LookReel> {
  static final _looks = CinemaLook.values.where((l) => !l.isNeutral).toList();
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _looks.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = _looks[_index];
    return Viewfinder(
      topLeft: const HudText('REC', dot: AppColors.accent),
      topRight: const HudText('4K · 24 FPS'),
      bottomLeft: HudText(look.label.toUpperCase(), color: AppColors.primary),
      bottomRight: const HudText('TOQUE PARA IMPORTAR'),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 900),
        child: Stack(
          key: ValueKey(look),
          fit: StackFit.expand,
          children: [
            LookSwatch(look: look),
            const _Bars(),
          ],
        ),
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final bar = ((c.maxHeight - c.maxWidth / 2.39) / 2).clamp(
          0.0,
          c.maxHeight / 2,
        );
        return Column(
          children: [
            Container(height: bar, color: Colors.black),
            const Spacer(),
            Container(height: bar, color: Colors.black),
          ],
        );
      },
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String index;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
        child: Row(
          children: [
            Text(
              index,
              style: AppTheme.timecode.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(icon, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _NextStepSheet extends StatelessWidget {
  const _NextStepSheet({required this.asset});

  final MediaAsset asset;

  @override
  Widget build(BuildContext context) {
    Widget option(int value, IconData icon, String title, String subtitle) =>
        ListTile(
          onTap: () => Navigator.of(context).pop(value),
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'O que fazer com "${asset.name}"?',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            option(
              0,
              Icons.auto_awesome_rounded,
              'Aprimorar',
              'Mais resolução, nitidez e look de cinema',
            ),
            option(
              2,
              Icons.bolt_rounded,
              'Melhores momentos',
              'Corte automático no tempo que você escolher',
            ),
            option(
              1,
              Icons.content_cut_rounded,
              'Cortar',
              'Escolher os trechos manualmente',
            ),
          ],
        ),
      ),
    );
  }
}
