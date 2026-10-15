import '../services/moment_detector.dart';

enum AnalysisStage {
  idle('Pronto'),
  abrindo('Abrindo vídeo'),
  lendoAudio('Lendo áudio e cenas'),
  classificandoMomentos('Classificando momentos'),
  concluido('Análise concluída');

  const AnalysisStage(this.label);

  final String label;
}

class AnalysisProgress {
  const AnalysisProgress({
    required this.stage,
    required this.percent,
    this.signals,
  });

  final AnalysisStage stage;
  final double percent;

  /// Sinais brutos, presentes só no evento final.
  final AnalysisSignals? signals;

  bool get isFinished => stage == AnalysisStage.concluido;
}

/// O que uma passada de análise devolve: energia de áudio e variação de cena.
///
/// Guardado no estado para que trocar a duração alvo (30 s → 2 min) só
/// re-rode a detecção em Dart, sem decodificar o vídeo de novo.
class AnalysisSignals {
  const AnalysisSignals({required this.audio, required this.scenes});

  final List<SignalSample> audio;
  final List<SignalSample> scenes;
}
