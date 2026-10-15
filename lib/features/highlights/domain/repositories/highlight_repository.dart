import '../../../../core/media/media_asset.dart';
import '../../../../core/media/render_settings.dart';
import '../entities/analysis.dart';
import '../entities/highlight_plan.dart';

abstract interface class HighlightRepository {
  /// Lê o vídeo uma vez e devolve os sinais no último evento.
  Stream<AnalysisProgress> analyze(MediaAsset source);

  /// Exporta os momentos do plano, emitindo progresso de 0 a 1.
  Stream<double> export(
    MediaAsset source,
    HighlightPlan plan,
    RenderSettings settings,
  );

  Future<MediaAsset> buildResult(HighlightPlan plan);

  void cancel();
}
