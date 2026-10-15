import '../../../../core/media/media_asset.dart';
import '../entities/enhance_job.dart';
import '../entities/enhance_options.dart';

abstract interface class EnhanceRepository {
  /// Aprimora cada fonte em sequência, emitindo o progresso do lote.
  Stream<EnhanceProgress> enhance(
    List<MediaAsset> sources,
    EnhanceOptions options,
  );

  /// Arquivos produzidos pelo último `enhance` concluído.
  List<MediaAsset> get results;

  void cancel();
}
