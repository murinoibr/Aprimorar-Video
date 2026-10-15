import 'dart:math' as math;

import '../entities/moment.dart';
import '../entities/target_duration.dart';

/// Uma leitura de sinal no tempo: nível de áudio (dB) ou score de cena (0..1).
class SignalSample {
  const SignalSample(this.seconds, this.value);

  final double seconds;
  final double value;
}

/// Lê o formato do filtro `metadata=print` / `ametadata=print` do FFmpeg:
///
/// ```text
/// frame:3    pts:46080   pts_time:3
/// lavfi.scene_score=0.440097
/// ```
abstract final class MetadataParser {
  static List<SignalSample> parse(String text, String key) {
    final out = <SignalSample>[];
    double? time;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('frame:')) {
        final index = line.indexOf('pts_time:');
        time = index < 0
            ? null
            : double.tryParse(
                line.substring(index + 9).trim().split(RegExp(r'\s')).first,
              );
        continue;
      }
      if (time == null || !line.startsWith('$key=')) continue;
      final value = _value(line.substring(key.length + 1));
      if (value != null) out.add(SignalSample(time, value));
    }
    return out;
  }

  static double? _value(String raw) {
    final text = raw.trim().toLowerCase();
    if (text == '-inf') return double.negativeInfinity;
    if (text == 'inf') return double.infinity;
    final value = double.tryParse(text);
    return value == null || value.isNaN ? null : value;
  }
}

/// Encontra os melhores momentos de um vídeo a partir de dois sinais baratos
/// que uma única passada do FFmpeg entrega: **energia do áudio** (picos,
/// fala, explosão depois de silêncio) e **variação visual** entre
/// quadros-chave (movimento e cortes de cena).
///
/// Sem modelo de IA, sem rede, sem custo: matemática de sinais em Dart puro,
/// testável sem aparelho. Os trechos começam em cortes de cena quando há um
/// por perto e terminam no ponto mais silencioso da vizinhança — o que evita
/// cortar no meio de uma palavra.
abstract final class MomentDetector {
  static const double _bin = 0.5;

  static List<Moment> detect({
    required Duration duration,
    required List<SignalSample> audio,
    required List<SignalSample> scenes,
    required TargetDuration target,
  }) {
    final total = duration.inMilliseconds / 1000;
    if (total <= 0) return const [];
    final targetSeconds = target.duration.inMilliseconds / 1000;

    // Vídeo já cabe no alvo: o melhor momento é ele inteiro.
    if (total <= targetSeconds * 1.05) {
      return [
        Moment(
          id: 'm1',
          start: Duration.zero,
          end: duration,
          score: 1,
          signals: const [MomentSignal.fala],
        ),
      ];
    }

    final n = (total / _bin).ceil();
    final audioNorm = _normalizeAudio(audio, n);
    final motionNorm = _normalizeMotion(scenes, n);
    final hasAudio = audioNorm != null;
    final hasMotion = motionNorm != null;
    final cuts = _cuts(scenes);

    final interest = List<double>.generate(n, (i) {
      final a = audioNorm?[i];
      final m = motionNorm?[i];
      var value = switch ((a, m)) {
        (final double a, final double m) => 0.6 * a + 0.4 * m,
        (final double a, null) => a,
        (null, final double m) => m,
        _ => 0.5,
      };
      // Logo depois de um corte de cena há novidade visual.
      final t = i * _bin;
      for (final cut in cuts) {
        final since = t - cut;
        if (since >= 0 && since < 2) value += 0.15 * (1 - since / 2);
      }
      // Explosão depois de silêncio: risada, aplauso, o "gol".
      if (a != null && a > 0.6 && _mean(audioNorm!, i - 4, i - 1) < 0.2) {
        value += 0.2;
      }
      return value;
    });
    final smooth = _smooth(interest, 2);

    final clip = (targetSeconds / 6).clamp(3.0, 8.0);
    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) => smooth[b].compareTo(smooth[a]));
    final covered = List<bool>.filled(n, false);
    final picked = <({double start, double end, bool atCut})>[];
    var used = 0.0;

    for (final peak in order) {
      if (covered[peak]) continue;
      if (picked.length >= 40 || used >= targetSeconds * 1.8) break;

      final center = peak * _bin + _bin / 2;
      var start = center - clip * 0.4;
      var end = start + clip;
      if (start < 0) {
        end -= start;
        start = 0;
      }
      if (end > total) {
        start -= end - total;
        end = total;
      }
      start = math.max(0, start);

      var atCut = false;
      final cutStart = _nearest(cuts, start, before: 1.5, after: 1.0);
      if (cutStart != null && end - cutStart >= 2) {
        start = cutStart;
        atCut = true;
      }
      if (hasAudio) {
        end = _quietestEnd(audioNorm, end, total);
      } else {
        final cutEnd = _nearest(cuts, end, before: 1.5, after: 1.0);
        if (cutEnd != null && cutEnd - start >= 2) end = cutEnd;
      }
      end = math.min(end, total);

      final from = (start - 1) / _bin;
      final to = (end + 1) / _bin;
      for (var i = math.max(0, from.floor()); i < math.min(n, to.ceil()); i++) {
        covered[i] = true;
      }
      if (end - start < 1.5) continue;
      if (picked.any((p) => start < p.end + 0.5 && p.start < end + 0.5)) {
        continue;
      }

      picked.add((start: start, end: end, atCut: atCut));
      used += end - start;
    }

    if (picked.isEmpty) return const [];

    final means = [
      for (final p in picked)
        _mean(smooth, (p.start / _bin).floor(), (p.end / _bin).ceil() - 1),
    ];
    final lo = means.reduce(math.min);
    final hi = means.reduce(math.max);

    final moments = <Moment>[];
    for (var k = 0; k < picked.length; k++) {
      final p = picked[k];
      final first = (p.start / _bin).floor();
      final last = math.max(first, (p.end / _bin).ceil() - 1);
      final score = hi - lo < 1e-6
          ? 0.8
          : 0.55 + 0.44 * (means[k] - lo) / (hi - lo);

      final signals = <MomentSignal>[];
      if (hasAudio) {
        final peakAudio = _max(audioNorm, first, last);
        final meanAudio = _mean(audioNorm, first, last);
        if (peakAudio >= 0.85) signals.add(MomentSignal.audioPico);
        if (_mean(audioNorm, first - 4, first - 1) < 0.15 && meanAudio > 0.5) {
          signals.add(MomentSignal.fimSilencio);
        }
        if (signals.isEmpty && meanAudio >= 0.35) {
          signals.add(MomentSignal.fala);
        }
      }
      if (hasMotion && _mean(motionNorm, first, last) >= 0.5) {
        signals.add(MomentSignal.movimento);
      }
      final cutInside = cuts.any((c) => c > p.start && c < p.end);
      if (p.atCut || cutInside) signals.add(MomentSignal.transicao);
      if (signals.isEmpty) {
        signals.add(hasMotion ? MomentSignal.movimento : MomentSignal.fala);
      }

      moments.add(
        Moment(
          id: 'm${k + 1}',
          start: Duration(milliseconds: (p.start * 1000).round()),
          end: Duration(milliseconds: (p.end * 1000).round()),
          score: (score * 100).round() / 100,
          signals: List.unmodifiable(signals),
        ),
      );
    }
    moments.sort((a, b) => a.start.compareTo(b.start));
    return List.unmodifiable(moments);
  }

  /// dB por bloco → 0..1 entre o piso (p10) e o pico típico (p95). Faixa menor
  /// que 3 dB é áudio sem informação (silêncio ou ruído constante).
  static List<double>? _normalizeAudio(List<SignalSample> audio, int n) {
    if (audio.isEmpty) return null;
    final raw = List<double?>.filled(n, null);
    for (final sample in audio) {
      final i = (sample.seconds / _bin).floor();
      if (i < 0 || i >= n) continue;
      final db = sample.value.isFinite ? sample.value.clamp(-90.0, 0.0) : -90.0;
      raw[i] = math.max(raw[i] ?? -90.0, db);
    }
    final known = raw.whereType<double>().toList()..sort();
    if (known.length < 4) return null;
    final lo = _percentile(known, 0.10);
    final hi = _percentile(known, 0.95);
    if (hi - lo < 3) return null;
    var last = lo;
    return List<double>.generate(n, (i) {
      last = raw[i] ?? last;
      return ((last - lo) / (hi - lo)).clamp(0.0, 1.0);
    });
  }

  /// Score de cena de cada quadro-chave espalhado no intervalo até ele.
  static List<double>? _normalizeMotion(List<SignalSample> scenes, int n) {
    if (scenes.length < 3) return null;
    final sorted = [...scenes]..sort((a, b) => a.seconds.compareTo(b.seconds));
    final raw = List<double>.filled(n, 0);
    var previous = 0.0;
    for (final sample in sorted) {
      final value = sample.value.isFinite ? sample.value.clamp(0.0, 1.0) : 0.0;
      final from = (previous / _bin).floor();
      final to = math.max(from, (sample.seconds / _bin).ceil() - 1);
      for (var i = math.max(0, from); i <= math.min(n - 1, to); i++) {
        raw[i] = math.max(raw[i], value);
      }
      previous = sample.seconds;
    }
    final sortedRaw = [...raw]..sort();
    final top = _percentile(sortedRaw, 0.95);
    if (top < 0.005) return null;
    return [for (final v in raw) (v / top).clamp(0.0, 1.0)];
  }

  static List<double> _cuts(List<SignalSample> scenes) {
    final sorted = [...scenes]..sort((a, b) => a.seconds.compareTo(b.seconds));
    final cuts = <double>[];
    for (final sample in sorted) {
      if (sample.value < 0.3) continue;
      if (cuts.isNotEmpty && sample.seconds - cuts.last < 1) continue;
      cuts.add(sample.seconds);
    }
    return cuts;
  }

  static double? _nearest(
    List<double> cuts,
    double t, {
    required double before,
    required double after,
  }) {
    double? best;
    for (final cut in cuts) {
      if (cut < t - before || cut > t + after) continue;
      if (best == null || (cut - t).abs() < (best - t).abs()) best = cut;
    }
    return best;
  }

  /// Fim no bloco mais silencioso a até 1 s do fim pretendido.
  static double _quietestEnd(List<double> audio, double end, double total) {
    final center = (end / _bin).round();
    var best = center;
    var bestValue = double.infinity;
    for (var i = center - 2; i <= center + 2; i++) {
      if (i < 1 || i >= audio.length) continue;
      if (audio[i] < bestValue) {
        bestValue = audio[i];
        best = i;
      }
    }
    return math.min(total, best * _bin + _bin);
  }

  static List<double> _smooth(List<double> values, int radius) => [
    for (var i = 0; i < values.length; i++)
      _mean(values, i - radius, i + radius),
  ];

  static double _mean(List<double> values, int from, int to) {
    final a = math.max(0, from);
    final b = math.min(values.length - 1, to);
    if (b < a) return 0;
    var sum = 0.0;
    for (var i = a; i <= b; i++) {
      sum += values[i];
    }
    return sum / (b - a + 1);
  }

  static double _max(List<double> values, int from, int to) {
    final a = math.max(0, from);
    final b = math.min(values.length - 1, to);
    var best = 0.0;
    for (var i = a; i <= b; i++) {
      best = math.max(best, values[i]);
    }
    return best;
  }

  static double _percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    final index = ((sorted.length - 1) * p).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}
