import 'package:vangogh/features/highlights/domain/entities/moment.dart';
import 'package:vangogh/features/highlights/domain/entities/target_duration.dart';
import 'package:vangogh/features/highlights/domain/services/highlight_planner.dart';
import 'package:flutter_test/flutter_test.dart';

Moment _moment(String id, int startSec, int endSec, double score) => Moment(
  id: id,
  start: Duration(seconds: startSec),
  end: Duration(seconds: endSec),
  score: score,
  signals: const [MomentSignal.audioPico],
);

void main() {
  group('TargetDuration', () {
    test('cobre os cinco tamanhos pedidos', () {
      expect(TargetDuration.values.length, 5);
      expect(
        TargetDuration.values.map((t) => t.duration.inSeconds).toList(),
        [30, 45, 60, 90, 120],
      );
    });
  });

  group('Moment', () {
    test('detecta sobreposição', () {
      final a = _moment('a', 0, 20, 0.9);
      final b = _moment('b', 15, 35, 0.8);
      final c = _moment('c', 20, 40, 0.7);

      expect(a.overlaps(b), isTrue);
      expect(a.overlaps(c), isFalse);
    });
  });

  group('HighlightPlanner', () {
    final source = const Duration(minutes: 3);
    final candidates = [
      _moment('a', 0, 20, 0.95),
      _moment('b', 25, 45, 0.80),
      _moment('c', 50, 70, 0.60),
      _moment('d', 80, 100, 0.40),
    ];

    test('respeita o orçamento de 30 segundos', () {
      final plan = HighlightPlanner.build(
        sourceDuration: source,
        target: TargetDuration.seg30,
        candidates: candidates,
      );

      expect(plan.totalLength.inSeconds, lessThanOrEqualTo(30));
      expect(plan.moments, isNotEmpty);
    });

    test('prioriza os melhores momentos', () {
      final plan = HighlightPlanner.build(
        sourceDuration: source,
        target: TargetDuration.seg30,
        candidates: candidates,
      );

      expect(plan.moments.first.id, 'a');
    });

    test('respeita o orçamento de 1 minuto e meio', () {
      final plan = HighlightPlanner.build(
        sourceDuration: source,
        target: TargetDuration.min1e30,
        candidates: candidates,
      );

      expect(plan.totalLength.inSeconds, lessThanOrEqualTo(90));
      expect(plan.moments.length, greaterThan(1));
    });

    test('nunca estoura o alvo de 2 minutos', () {
      final plan = HighlightPlanner.build(
        sourceDuration: source,
        target: TargetDuration.min2,
        candidates: candidates,
      );

      expect(plan.totalLength.inSeconds, lessThanOrEqualTo(120));
    });

    test('respeita exclusões do usuário', () {
      final plan = HighlightPlanner.build(
        sourceDuration: source,
        target: TargetDuration.min2,
        candidates: candidates,
        excluded: {'a'},
      );

      expect(plan.moments.map((m) => m.id), isNot(contains('a')));
    });

    test('devolve momentos em ordem cronológica', () {
      final plan = HighlightPlanner.build(
        sourceDuration: source,
        target: TargetDuration.min2,
        candidates: [
          _moment('z', 120, 140, 0.99),
          _moment('x', 10, 25, 0.50),
        ],
      );

      expect(plan.moments.map((m) => m.id), ['x', 'z']);
      for (var i = 1; i < plan.moments.length; i++) {
        expect(
          plan.moments[i].start >= plan.moments[i - 1].end,
          isTrue,
          reason: 'momentos não podem se sobrepor nem voltar no tempo',
        );
      }
    });

    test('não escolhe trechos sobrepostos', () {
      final plan = HighlightPlanner.build(
        sourceDuration: source,
        target: TargetDuration.min2,
        candidates: [
          _moment('a', 0, 60, 0.99),
          _moment('b', 30, 90, 0.95),
        ],
      );

      expect(plan.moments.length, 1);
    });

    test('planilha fica vazia sem candidatos', () {
      final plan = HighlightPlanner.build(
        sourceDuration: source,
        target: TargetDuration.seg30,
        candidates: const [],
      );

      expect(plan.moments, isEmpty);
      expect(plan.totalLength, Duration.zero);
      expect(plan.fillRatio, 0);
    });

    test('relata o tempo removido', () {
      final plan = HighlightPlanner.build(
        sourceDuration: source,
        target: TargetDuration.seg30,
        candidates: candidates,
      );

      expect(plan.secondsRemoved, source.inSeconds - plan.totalLength.inSeconds);
      expect(plan.compressionRatio, lessThan(0.5));
    });
  });
}
