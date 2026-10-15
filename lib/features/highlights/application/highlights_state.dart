import '../../../../core/media/media_asset.dart';
import '../../../../core/media/render_settings.dart';
import '../domain/entities/analysis.dart';
import '../domain/entities/highlight_plan.dart';
import '../domain/entities/moment.dart';
import '../domain/entities/target_duration.dart';
import '../domain/services/highlight_planner.dart';

enum HighlightsStatus { idle, analyzing, ready, exporting, done, failure }

class HighlightsState {
  const HighlightsState({
    this.source,
    this.target = TargetDuration.defaultChoice,
    this.settings = const RenderSettings(format: OutputFormat.vertical),
    this.status = HighlightsStatus.idle,
    this.stage = AnalysisStage.idle,
    this.progress = 0,
    this.signals,
    this.candidates = const [],
    this.excluded = const {},
    this.result,
    this.errorMessage,
  });

  final MediaAsset? source;
  final TargetDuration target;
  final RenderSettings settings;
  final HighlightsStatus status;
  final AnalysisStage stage;
  final double progress;
  final AnalysisSignals? signals;
  final List<Moment> candidates;
  final Set<String> excluded;
  final MediaAsset? result;
  final String? errorMessage;

  bool get hasSource => source != null;

  bool get isAnalyzed => signals != null;

  bool get isBusy =>
      status == HighlightsStatus.analyzing ||
      status == HighlightsStatus.exporting;

  Duration get sourceDuration => source?.duration ?? Duration.zero;

  HighlightPlan get plan => HighlightPlanner.build(
    sourceDuration: sourceDuration,
    target: target,
    candidates: candidates,
    excluded: excluded,
  );

  HighlightsState copyWith({
    MediaAsset? source,
    TargetDuration? target,
    RenderSettings? settings,
    HighlightsStatus? status,
    AnalysisStage? stage,
    double? progress,
    AnalysisSignals? signals,
    List<Moment>? candidates,
    Set<String>? excluded,
    MediaAsset? result,
    String? errorMessage,
    bool clearSignals = false,
    bool clearResult = false,
    bool clearError = false,
  }) => HighlightsState(
    source: source ?? this.source,
    target: target ?? this.target,
    settings: settings ?? this.settings,
    status: status ?? this.status,
    stage: stage ?? this.stage,
    progress: progress ?? this.progress,
    signals: clearSignals ? null : (signals ?? this.signals),
    candidates: candidates ?? this.candidates,
    excluded: excluded ?? this.excluded,
    result: clearResult ? null : (result ?? this.result),
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}
