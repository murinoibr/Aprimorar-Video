enum EnhanceStage {
  idle('Pronto'),
  preparing('Preparando'),
  processing('Aprimorando'),
  encoding('Codificando'),
  saving('Finalizando'),
  done('Concluído');

  const EnhanceStage(this.label);

  final String label;
}

class EnhanceProgress {
  const EnhanceProgress({
    required this.stage,
    required this.percent,
    this.etaSeconds,
    this.index = 0,
    this.total = 1,
  });

  final EnhanceStage stage;

  /// Progresso do lote inteiro, de 0 a 1.
  final double percent;
  final int? etaSeconds;

  /// Arquivo em processamento (base 0) e tamanho do lote.
  final int index;
  final int total;
}
