import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_x.dart';
import '../../../shared/widgets/media_widgets.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../application/library_controller.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  Future<void> _actions(
    BuildContext context,
    WidgetRef ref,
    ExportEntry entry,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: const Text('Abrir'),
              onTap: () => Navigator.pop(context, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Salvar na galeria'),
              onTap: () => Navigator.pop(context, 'save'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
              title: const Text(
                'Excluir',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'open':
        openViewer(context, entry.asset);
      case 'save':
        final outcome = await ref.read(gallerySaverProvider).save(entry.asset);
        if (context.mounted) showToast(context, outcome.message);
      case 'delete':
        await ref.read(libraryProvider.notifier).remove(entry.asset);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(libraryProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entries.length} ${entries.length == 1 ? 'ARQUIVO' : 'ARQUIVOS'}',
                      style: AppTheme.label,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Biblioteca',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
            ),
            if (entries.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'Nada por aqui ainda',
                  message: 'Tudo que você exportar e salvar aparece aqui, guardado no aparelho.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final asset = entry.asset;
                    return GestureDetector(
                      onTap: () => openViewer(context, asset),
                      onLongPress: () => _actions(context, ref, entry),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  MediaThumb(asset: asset),
                                  Positioned(
                                    left: 8,
                                    top: 8,
                                    child: HudText(entry.feature.toUpperCase()),
                                  ),
                                  if (asset.isVideo && asset.duration != null)
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: HudText(asset.duration!.clock),
                                    ),
                                  Positioned(
                                    right: 2,
                                    top: 2,
                                    child: IconButton(
                                      onPressed: () =>
                                          _actions(context, ref, entry),
                                      icon: const Icon(
                                        Icons.more_horiz_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            asset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            [asset.tierLabel, asset.sizeLabel].join('  ·  '),
                            style: AppTheme.timecode.copyWith(fontSize: 10.5),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
