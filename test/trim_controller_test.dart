import 'package:vangogh/core/engine/render_job.dart';
import 'package:vangogh/core/media/media_asset.dart';
import 'package:vangogh/core/media/media_probe.dart';
import 'package:vangogh/core/media/media_providers.dart';
import 'package:vangogh/core/media/render_settings.dart';
import 'package:vangogh/features/trim/application/trim_controller.dart';
import 'package:vangogh/features/trim/application/trim_state.dart';
import 'package:vangogh/features/trim/domain/entities/trim_plan.dart';
import 'package:vangogh/features/trim/domain/repositories/trim_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTrimRepository implements TrimRepository {
  int renderCount = 0;
  bool cancelled = false;
  MediaAsset? lastSource;
  TrimPlan? lastPlan;

  /// Quando definido, `render` emite este erro em vez de progredir.
  Object? failure;

  @override
  Stream<double> render(
    MediaAsset source,
    TrimPlan plan,
    RenderSettings settings,
  ) async* {
    renderCount++;
    lastSource = source;
    lastPlan = plan;
    if (failure != null) throw failure!;
    yield 0.5;
    yield 1;
  }

  @override
  Future<MediaAsset> buildResult(RenderSettings settings) async =>
      MediaAsset(
        path: '/saida/teste.mp4',
        name: 'teste.mp4',
        kind: MediaKind.video,
        sizeBytes: 1024,
        duration: lastPlan?.totalLength,
      );

  @override
  void cancel() => cancelled = true;
}

MediaAsset _asset() => MediaAsset(
  path: '/tmp/fake.mp4',
  name: 'fake.mp4',
  kind: MediaKind.video,
  sizeBytes: 2048,
  duration: const Duration(minutes: 2),
);

void main() {
  late ProviderContainer container;
  late _FakeTrimRepository repository;

  TrimController controller() => container.read(trimControllerProvider.notifier);
  TrimState state() => container.read(trimControllerProvider);

  setUp(() {
    repository = _FakeTrimRepository();
    container = ProviderContainer(
      overrides: [
        trimRepositoryProvider.overrideWithValue(repository),
        mediaProbeProvider.overrideWithValue(const MediaProbe()),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('começa sem vídeo', () {
    expect(state().hasSource, isFalse);
    expect(state().isEmpty, isTrue);
    expect(state().plan.totalLength, Duration.zero);
  });

  test('selecionar vídeo cria um trecho único do tamanho inteiro', () async {
    await controller().selectSource(_asset());

    expect(state().hasSource, isTrue);
    expect(state().segments.length, 1);
    expect(state().plan.totalLength, const Duration(minutes: 2));
    expect(state().plan.cutCount, 0);
  });

  test('cortar divide em dois e mantém a duração', () async {
    await controller().selectSource(_asset());
    controller().seekTo(const Duration(seconds: 40));
    controller().splitAtPlayhead();

    expect(state().segments.length, 2);
    expect(state().plan.cutCount, 1);
    expect(state().plan.totalLength, const Duration(minutes: 2));
    expect(state().activeIndex, 1);
  });

  test('não corta em trecho que já foi removido', () async {
    await controller().selectSource(_asset());
    controller().seekTo(const Duration(seconds: 40));
    controller().splitAtPlayhead();
    controller().removeActive();

    controller().seekTo(const Duration(seconds: 60));
    expect(state().canSplit, isFalse);

    controller().splitAtPlayhead();
    expect(state().segments.length, 1);
  });

  test('desfazer e refazer restauram os trechos', () async {
    await controller().selectSource(_asset());
    controller().seekTo(const Duration(seconds: 40));
    controller().splitAtPlayhead();

    expect(state().canUndo, isTrue);
    controller().undo();
    expect(state().segments.length, 1);
    expect(state().canRedo, isTrue);

    controller().redo();
    expect(state().segments.length, 2);
  });

  test('remover trecho atual deixa os outros', () async {
    await controller().selectSource(_asset());
    controller().seekTo(const Duration(seconds: 40));
    controller().splitAtPlayhead();
    controller().removeActive();

    expect(state().segments.length, 1);
    expect(state().segments.single.start, Duration.zero);
    expect(state().segments.single.end, const Duration(seconds: 40));
  });

  test('não deixa o corte vazio', () async {
    await controller().selectSource(_asset());
    controller().removeActive();

    expect(state().segments.length, 1);
    expect(state().errorMessage, isNotNull);
  });

  test('restaurar traz o vídeo inteiro de volta', () async {
    await controller().selectSource(_asset());
    controller().seekTo(const Duration(seconds: 40));
    controller().splitAtPlayhead();
    controller().removeActive();
    controller().restoreAll();

    expect(state().segments.length, 1);
    expect(state().plan.totalLength, const Duration(minutes: 2));
  });

  test('exporta o plano e salva o resultado', () async {
    await controller().selectSource(_asset());
    controller().seekTo(const Duration(seconds: 40));
    controller().splitAtPlayhead();

    await controller().render();
    await Future<void>.delayed(Duration.zero);

    expect(repository.renderCount, 1);
    expect(repository.lastSource?.path, '/tmp/fake.mp4');
    expect(state().status, TrimStatus.done);
    expect(state().progress, 1);
    expect(state().result?.duration, const Duration(minutes: 2));
  });

  test('falha do motor vira mensagem legível, não "Instance of"', () async {
    repository.failure = const RenderFailure('Sem espaço no aparelho.');
    await controller().selectSource(_asset());

    await controller().render();
    await Future<void>.delayed(Duration.zero);

    expect(state().status, TrimStatus.failure);
    expect(state().errorMessage, 'Sem espaço no aparelho.');
  });

  test('cursor nunca sai dos limites do vídeo', () async {
    await controller().selectSource(_asset());
    controller().seekTo(const Duration(minutes: 9));
    expect(state().playhead, const Duration(minutes: 2));

    controller().seekTo(const Duration(seconds: -5));
    expect(state().playhead, Duration.zero);
  });
}
