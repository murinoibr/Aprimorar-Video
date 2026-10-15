/// Etapas visíveis ao usuário durante um render.
enum RenderStage {
  preparing('Preparando'),
  processing('Processando'),
  encoding('Codificando'),
  finalizing('Finalizando'),
  done('Pronto');

  const RenderStage(this.label);

  final String label;
}

/// Progresso de um render em execução.
class RenderProgress {
  const RenderProgress({
    required this.fraction,
    required this.stage,
    this.processedMs = 0,
    this.totalMs = 0,
    this.speed,
    this.sizeBytes = 0,
    this.usedFallback = false,
  });

  const RenderProgress.idle()
    : fraction = 0,
      stage = RenderStage.preparing,
      processedMs = 0,
      totalMs = 0,
      speed = null,
      sizeBytes = 0,
      usedFallback = false;

  /// 0..1, sempre dentro dos limites (FFmpeg pode reportar > total em
  ///BUFFER/CONCAT, onde o tempo de entrada excede o de saída).
  final double fraction;
  final RenderStage stage;
  final int processedMs;
  final int totalMs;

  /// Velocidade de encode relatada pelo FFmpeg (ex.: `1.8x`).
  final double? speed;
  final int sizeBytes;

  /// Verdadeiro quando o encoder de hardware falhou e o render saiu pelo
  /// codec de reserva. Quem monta vários clipes usa isso para manter todos
  /// no mesmo codec (a junção por cópia exige).
  final bool usedFallback;

  int get percent => (fraction * 100).round().clamp(0, 100);

  Duration? get eta {
    if (fraction <= 0.01 || processedMs <= 0) return null;
    final remaining = (1 - fraction) * processedMs / fraction;
    return Duration(milliseconds: remaining.round());
  }

  @override
  String toString() =>
      'RenderProgress($percent%, ${stage.name}, $processedMs ms'
      '${speed == null ? '' : ', ${speed}x'})';
}

/// Uma execução de FFmpeg já descrita como argumentos.
class RenderRequest {
  const RenderRequest({
    required this.arguments,
    required this.outputPath,
    required this.expectedDurationMs,
    this.label = 'Exportar',
    this.cleanupOnFailure = true,
    this.fallbackArguments,
    this.expectsOutput = true,
  });

  final List<String> arguments;

  /// Mesma operação com um codec por software. O motor tenta estes
  /// argumentos se a primeira execução falhar — encoder de hardware ausente
  /// ou recusando a resolução é a falha mais comum em aparelhos Android.
  final List<String>? fallbackArguments;

  /// Falso para passadas de análise, que não geram arquivo em [outputPath].
  final bool expectsOutput;

  /// Caminho absoluto do arquivo a ser produzido.
  final String outputPath;

  /// Duração esperada do resultado, em ms. É a base do progresso: o FFmpeg
  /// reporta tempo já processado, e o plano de corte sabe quanto deve sair.
  final int expectedDurationMs;

  final String label;

  /// Apaga o arquivo parcial se a execução falhar.
  final bool cleanupOnFailure;

  @override
  String toString() => 'RenderRequest($label → $outputPath)';
}

/// Falha de render com diagnóstico já legível.
class RenderFailure implements Exception {
  const RenderFailure(this.message, {this.log});

  final String message;

  /// Trecho do log do FFmpeg, para anexar a relatórios de bug.
  final String? log;

  @override
  String toString() =>
      log == null ? 'RenderFailure: $message' : 'RenderFailure: $message\n$log';
}

/// O usuário cancelou o render.
class RenderCancelled implements Exception {
  const RenderCancelled();

  @override
  String toString() => 'RenderCancelled';
}
