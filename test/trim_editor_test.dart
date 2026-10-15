import 'package:vangogh/features/trim/domain/entities/clip_segment.dart';
import 'package:vangogh/features/trim/domain/entities/trim_plan.dart';
import 'package:vangogh/features/trim/domain/services/trim_editor.dart';
import 'package:flutter_test/flutter_test.dart';

const source = Duration(minutes: 2);

ClipSegment _segment(String id, int startSec, int endSec) => ClipSegment(
  id: id,
  start: Duration(seconds: startSec),
  end: Duration(seconds: endSec),
);

List<ClipSegment> _one() => TrimEditor.initial(sourceDuration: source, id: 'seg0');

void main() {
  group('ClipSegment', () {
    test('calcula a duração', () {
      expect(_segment('a', 5, 12).length, const Duration(seconds: 7));
    });

    test('detecta sobreposição', () {
      final a = _segment('a', 0, 20);
      expect(a.overlaps(_segment('b', 15, 30)), isTrue);
      expect(a.overlaps(_segment('b', 20, 30)), isFalse);
    });

    test('encontra a posição dentro do trecho', () {
      final segment = _segment('a', 10, 20);
      expect(segment.contains(const Duration(seconds: 10)), isTrue);
      expect(segment.contains(const Duration(seconds: 19)), isTrue);
      expect(segment.contains(const Duration(seconds: 20)), isFalse);
    });
  });

  group('TrimEditor.snap', () {
    test('encaixa no quadro mais próximo', () {
      expect(
        TrimEditor.snap(const Duration(milliseconds: 1010), fps: 30),
        const Duration(milliseconds: 1000),
      );
      expect(
        TrimEditor.snap(const Duration(milliseconds: 1030), fps: 30),
        const Duration(milliseconds: 1033),
      );
    });

    test('não mexe no valor quando fps é nulo', () {
      const position = Duration(milliseconds: 1234);
      expect(TrimEditor.snap(position), position);
    });
  });

  group('TrimEditor.indexOfSegmentAt', () {
    test('acha o trecho pela posição', () {
      final segments = [_segment('a', 0, 10), _segment('b', 20, 30)];
      expect(
        TrimEditor.indexOfSegmentAt(segments, const Duration(seconds: 25)),
        1,
      );
      expect(
        TrimEditor.indexOfSegmentAt(segments, const Duration(seconds: 15)),
        isNull,
      );
    });

    test('usa tolerância para pegar a borda', () {
      final segments = [_segment('a', 0, 10), _segment('b', 20, 30)];
      expect(
        TrimEditor.indexOfSegmentAt(
          segments,
          const Duration(seconds: 12),
          tolerance: const Duration(seconds: 10),
        ),
        1,
      );
    });
  });

  group('TrimEditor.split', () {
    test('divide o trecho em dois', () {
      final result = TrimEditor.split(
        segments: _one(),
        position: const Duration(seconds: 40),
        sourceDuration: source,
        idFor: () => 'seg1',
      );

      expect(result.segments.length, 2);
      expect(result.segments.first.start, Duration.zero);
      expect(result.segments.first.end, const Duration(seconds: 40));
      expect(result.segments.last.start, const Duration(seconds: 40));
      expect(result.segments.last.end, source);
      expect(result.activeIndex, 1);
    });

    test('soma dos trechos continua o tamanho do original', () {
      final result = TrimEditor.split(
        segments: _one(),
        position: const Duration(seconds: 40),
        sourceDuration: source,
        idFor: () => 'seg1',
      );
      final plan = TrimPlan(
        sourceDuration: source,
        segments: result.segments,
      );
      expect(plan.totalLength, source);
      expect(plan.cutCount, 1);
    });

    test('recusa cortar em cima da borda', () {
      final result = TrimEditor.split(
        segments: _one(),
        position: Duration.zero,
        sourceDuration: source,
        idFor: () => 'seg1',
      );
      expect(result.segments.length, 1);
      expect(result.activeIndex, -1);
    });

    test('recusa cortar fora dos trechos', () {
      final segments = [_segment('a', 0, 10), _segment('b', 30, 40)];
      final result = TrimEditor.split(
        segments: segments,
        position: const Duration(seconds: 20),
        sourceDuration: source,
        idFor: () => 'seg2',
      );
      expect(result.segments.length, 2);
      expect(result.activeIndex, -1);
    });

    test('não deixa trecho menor que o mínimo', () {
      final segments = [_segment('a', 0, 1)];
      final result = TrimEditor.split(
        segments: segments,
        position: const Duration(milliseconds: 100),
        sourceDuration: source,
        idFor: () => 'seg1',
      );
      expect(result.segments.length, 1);
    });

    test('encaixa o corte no quadro', () {
      final result = TrimEditor.split(
        segments: _one(),
        position: const Duration(milliseconds: 2030),
        sourceDuration: source,
        idFor: () => 'seg1',
        fps: 30,
      );
      expect(result.segments.first.end, const Duration(milliseconds: 2033));
    });
  });

  group('TrimEditor.updateEdges', () {
    test('move a borda de entrada', () {
      final updated = TrimEditor.updateEdges(
        segments: _one(),
        index: 0,
        sourceDuration: source,
        start: const Duration(seconds: 10),
      );
      expect(updated.single.start, const Duration(seconds: 10));
      expect(updated.single.end, source);
    });

    test('move a borda de saída', () {
      final updated = TrimEditor.updateEdges(
        segments: _one(),
        index: 0,
        sourceDuration: source,
        end: const Duration(seconds: 30),
      );
      expect(updated.single.end, const Duration(seconds: 30));
    });

    test('nunca passa do fim do vídeo', () {
      final updated = TrimEditor.updateEdges(
        segments: _one(),
        index: 0,
        sourceDuration: source,
        end: const Duration(minutes: 10),
      );
      expect(updated.single.end, source);
    });

    test('ignora cruzamento de bordas', () {
      final segments = [_segment('a', 10, 40)];
      final crossed = TrimEditor.updateEdges(
        segments: segments,
        index: 0,
        sourceDuration: source,
        start: const Duration(seconds: 50),
        end: const Duration(seconds: 20),
      );
      expect(crossed.single.start, const Duration(seconds: 20));
      expect(crossed.single.end, const Duration(seconds: 50));
    });

    test('recusa trecho menor que o mínimo', () {
      final segments = [_segment('a', 10, 40)];
      final updated = TrimEditor.updateEdges(
        segments: segments,
        index: 0,
        sourceDuration: source,
        start: const Duration(seconds: 20),
        end: const Duration(milliseconds: 20050),
      );
      expect(updated, segments);
    });

    test('inverte quando a borda cruza a outra', () {
      final segments = [_segment('a', 10, 40)];
      final updated = TrimEditor.updateEdges(
        segments: segments,
        index: 0,
        sourceDuration: source,
        end: const Duration(seconds: 5),
      );
      expect(updated.single.start, const Duration(seconds: 5));
      expect(updated.single.end, const Duration(seconds: 10));
    });
  });

  group('TrimEditor.normalize', () {
    test('ordena e junta trechos sobrepostos', () {
      final normalized = TrimEditor.normalize(
        segments: [_segment('b', 30, 50), _segment('a', 0, 40)],
        sourceDuration: source,
      );
      expect(normalized.length, 1);
      expect(normalized.single.start, Duration.zero);
      expect(normalized.single.end, const Duration(seconds: 50));
    });

    test('mantém trechos colados separados para poder remover um só', () {
      final normalized = TrimEditor.normalize(
        segments: [_segment('a', 0, 10), _segment('b', 10, 20)],
        sourceDuration: source,
      );
      expect(normalized.map((s) => s.id), ['a', 'b']);
    });

    test('descarta trechos vazios', () {
      final normalized = TrimEditor.normalize(
        segments: [_segment('a', 10, 10), _segment('b', 20, 30)],
        sourceDuration: source,
      );
      expect(normalized.map((s) => s.id), ['b']);
    });

    test('prende trechos nas bordas do vídeo', () {
      final normalized = TrimEditor.normalize(
        segments: const [
          ClipSegment(
            id: 'a',
            start: Duration(seconds: -10),
            end: Duration(minutes: 9),
          ),
        ],
        sourceDuration: source,
      );
      expect(normalized.single.start, Duration.zero);
      expect(normalized.single.end, source);
    });

    test('mantém trechos separados com folga entre eles', () {
      final normalized = TrimEditor.normalize(
        segments: [_segment('a', 0, 10), _segment('b', 30, 40)],
        sourceDuration: source,
      );
      expect(normalized.map((s) => s.id), ['a', 'b']);
    });
  });

  group('TrimEditor.removeAt / keepOnly', () {
    test('remove o trecho pedido', () {
      final segments = [_segment('a', 0, 10), _segment('b', 30, 40)];
      expect(
        TrimEditor.removeAt(
          segments: segments,
          index: 0,
          sourceDuration: source,
        ).map((s) => s.id),
        ['b'],
      );
    });

    test('ignora índice inválido', () {
      final segments = [_segment('a', 0, 10)];
      expect(
        TrimEditor.removeAt(
          segments: segments,
          index: 5,
          sourceDuration: source,
        ),
        segments,
      );
    });

    test('mantém só o trecho escolhido', () {
      final segments = [_segment('a', 0, 10), _segment('b', 30, 40)];
      expect(
        TrimEditor.keepOnly(segments: segments, index: 1).map((s) => s.id),
        ['b'],
      );
    });
  });

  group('TrimPlan', () {
    test('relata cortes e tempo removido', () {
      final plan = TrimPlan(
        sourceDuration: source,
        segments: [_segment('a', 0, 10), _segment('b', 30, 40)],
      );
      expect(plan.cutCount, 1);
      expect(plan.totalLength, const Duration(seconds: 20));
      expect(plan.secondsRemoved, source.inSeconds - 20);
      expect(plan.keptRatio, closeTo(0.166, 0.01));
    });

    test('planilha vazia não quebra', () {
      const plan = TrimPlan(sourceDuration: source, segments: []);
      expect(plan.isEmpty, isTrue);
      expect(plan.totalLength, Duration.zero);
      expect(plan.keptRatio, 0);
      expect(plan.cutCount, 0);
    });
  });
}
