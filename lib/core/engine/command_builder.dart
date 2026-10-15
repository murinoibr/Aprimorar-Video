import '../media/render_settings.dart';
import 'media_range.dart';

/// Codec de vídeo de saída.
///
/// A build Full **não-GPL** do FFmpegKit não traz `libx264`/`libx265`. Para
/// publicar na Play Store sem obrigações de GPL, o encode é feito pelos encoders
/// de hardware do sistema — que também são ordens de magnitude mais rápidos:
///
/// - Android: `MediaCodec` (presente em qualquer aparelho com encoder H.264)
/// - iOS/macOS: `VideoToolbox`
/// - Sem nenhum deles: `mpeg4` por software, sempre disponível
///
/// Consequência prática: encoders de hardware não aceitam CRF, e sim taxa de
/// bits. Por isso [RenderQuality] é convertido em taxa de bits alvo por
/// [FfmpegCommand.targetBitrateKbps].
enum HwCodec {
  mediaCodec('h264_mediacodec', 'MediaCodec'),
  videoToolbox('h264_videotoolbox', 'VideoToolbox'),
  software('mpeg4', 'software');

  const HwCodec(this.encoder, this.label);

  final String encoder;
  final String label;

  bool get isHardware => this != HwCodec.software;
}

/// Monta argumentos de linha de comando do FFmpeg.
///
/// Deliberadamente **Dart puro**: nenhuma plataforma, nenhum plugin, nenhum
/// `dart:io`. Cada feature vira uma `List<String>` testável unitariamente e o
/// motor só executa. Se essa lógica vaza para o motor, perde-se a única parte
/// do pipeline que dá para testar sem aparelho conectado.
abstract final class FfmpegCommand {
  /// Argumentos globais comuns a toda execução.
  static List<String> base() => const [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
  ];

  /// Corta [ranges] de um único input e concatena o resultado, aplicando
  /// formato, fps e áudio.
  ///
  /// Com **um** trecho, o corte é um *seek* de entrada (`-ss`/`-t` antes do
  /// `-i`), bem mais rápido porque não decodifica o que vem antes, e os filtros
  /// de vídeo/áudio vão em `-vf`/`-af`. Com **vários** trechos, tudo acontece em
  /// um único passe de `-filter_complex` (`trim`/`atrim` + `concat`), sem
  /// arquivos intermediários.
  ///
  /// `-ss` e `-t` ficam **antes** do `-i`, ou seja, incidem sobre o arquivo e
  /// não sobre a rede. Isso evita reconstruir índices e preserva a sincronia A/V.
  static List<String> concatenate({
    required String inputPath,
    required String outputPath,
    required List<MediaRange> ranges,
    required RenderSettings settings,
    HwCodec codec = HwCodec.mediaCodec,
    bool normalizeAudio = false,
    bool sourceHasAudio = true,
  }) {
    final valid = ranges.where((range) => !range.isEmpty).toList();
    if (valid.isEmpty) {
      throw ArgumentError(
        'concatenate exige ao menos um trecho com duração > 0',
      );
    }

    final audioOut = settings.keepAudio && sourceHasAudio;
    final videoChain = <String>[
      if (settings.format.width != null && settings.format.height != null)
        ..._fitToBox(settings.format.width!, settings.format.height!),
      if (settings.fps != null) 'fps=${settings.fps}',
      ...settings.styleFilters,
    ];
    final audioChain = <String>[
      if (normalizeAudio) 'loudnorm=I=-16:TP=-1.5:LRA=11',
    ];

    final single = valid.length == 1;

    return [
      ...base(),
      if (single) ..._inputSeek(valid.single),
      '-i',
      inputPath,
      if (single)
        ..._simpleFilters(videoChain, audioChain, withAudio: audioOut)
      else
        ..._complexFilters(valid, videoChain, audioChain, withAudio: audioOut),
      ..._encodeVideo(
        codec: codec,
        width: settings.format.width,
        height: settings.format.height,
        fps: settings.fps,
        quality: settings.quality,
      ),
      if (audioOut) ..._encodeAudio(),
      // `faststart` move o índice para o começo: o vídeo abre antes de baixar
      // inteiro e o player não mostra um retângulo preto inicial.
      '-movflags',
      '+faststart',
      outputPath,
    ];
  }

  /// Junta clipes já codificados com os mesmos parâmetros, sem re-encode.
  ///
  /// É o segundo passo da montagem segmentada: cada trecho é renderizado com
  /// seek de entrada (só decodifica o que vai para o corte) e aqui tudo vira um
  /// arquivo só por cópia de pacotes — segundos, mesmo para vídeos longos.
  static List<String> joinCopy({
    required String listPath,
    required String outputPath,
  }) => [
    ...base(),
    '-f',
    'concat',
    '-safe',
    '0',
    '-i',
    listPath,
    '-c',
    'copy',
    '-movflags',
    '+faststart',
    outputPath,
  ];

  /// Conteúdo do arquivo de lista do demuxer `concat`.
  static String concatList(List<String> paths) =>
      paths.map((path) => "file '${path.replaceAll("'", r"'\''")}'").join('\n');

  /// Aprimora um vídeo inteiro: [videoFilters] e [audioFilters] já vêm
  /// montados pela receita da feature, aqui só se encaixa no encode.
  static List<String> enhanceVideo({
    required String inputPath,
    required String outputPath,
    required List<String> videoFilters,
    List<String> audioFilters = const [],
    int? width,
    int? height,
    int? fps,
    RenderQuality quality = RenderQuality.maxima,
    HwCodec codec = HwCodec.mediaCodec,
    bool sourceHasAudio = true,
  }) => [
    ...base(),
    '-i',
    inputPath,
    if (videoFilters.isNotEmpty) ...['-vf', videoFilters.join(',')],
    if (sourceHasAudio && audioFilters.isNotEmpty) ...[
      '-af',
      audioFilters.join(','),
    ],
    '-map',
    '0:v:0',
    if (sourceHasAudio) ...['-map', '0:a:0?'],
    ..._encodeVideo(
      codec: codec,
      width: width,
      height: height,
      fps: fps,
      quality: quality,
    ),
    if (sourceHasAudio) ..._encodeAudio(),
    '-movflags',
    '+faststart',
    outputPath,
  ];

  /// Aprimora uma foto: um quadro só, JPEG de qualidade máxima com croma
  /// completo (4:4:4) — sem a perda de cor que o 4:2:0 de vídeo traria.
  static List<String> enhanceImage({
    required String inputPath,
    required String outputPath,
    required List<String> filters,
  }) => [
    ...base(),
    '-i',
    inputPath,
    '-vf',
    [...filters, 'format=yuvj444p'].join(','),
    '-frames:v',
    '1',
    '-q:v',
    '1',
    '-update',
    '1',
    outputPath,
  ];

  /// Um quadro em [at], com [filters] aplicados — base da prévia instantânea
  /// (antes/depois) e das miniaturas da biblioteca.
  static List<String> frame({
    required String inputPath,
    required String outputPath,
    Duration at = Duration.zero,
    List<String> filters = const [],
    bool isImage = false,
  }) => [
    ...base(),
    if (!isImage && at > Duration.zero) ...['-ss', seconds(at)],
    '-i',
    inputPath,
    if (filters.isNotEmpty) ...['-vf', filters.join(',')],
    '-frames:v',
    '1',
    '-q:v',
    '2',
    '-update',
    '1',
    outputPath,
  ];

  /// Tira de quadros (filmstrip) em uma imagem só, para a timeline.
  ///
  /// Decodifica só quadros-chave (`-skip_frame nokey`): em vez de abrir o
  /// vídeo inteiro, lê um quadro a cada ~1–2 s, o que deixa a tira pronta em
  /// fração de segundo mesmo em vídeos longos.
  static List<String> filmstrip({
    required String inputPath,
    required String outputPath,
    required Duration duration,
    int tiles = 12,
    int height = 96,
  }) {
    final secs = duration.inMilliseconds <= 0
        ? 1.0
        : duration.inMilliseconds / 1000;
    final rate = (tiles / secs).clamp(0.0005, 30.0).toStringAsFixed(5);
    return [
      ...base(),
      '-skip_frame',
      'nokey',
      '-i',
      inputPath,
      '-an',
      '-vf',
      'fps=$rate,scale=-2:$height:flags=bilinear,tile=${tiles}x1',
      '-frames:v',
      '1',
      '-q:v',
      '4',
      '-update',
      '1',
      outputPath,
    ];
  }

  /// Uma passada de análise para achar os melhores momentos.
  ///
  /// - Vídeo: só quadros-chave, reduzidos a 160 px, com o `scene score` de
  ///   cada um gravado em [scenesPath] (cortes e movimento).
  /// - Áudio: reamostrado a 16 kHz em blocos de 0,5 s, com o nível RMS de
  ///   cada bloco gravado em [audioPath] (picos, fala, silêncio).
  ///
  /// Nada é codificado: a saída é `null`, então o custo é só de decodificar.
  static List<String> analyze({
    required String inputPath,
    required String scenesPath,
    required String audioPath,
    bool sourceHasAudio = true,
  }) => [
    ...base(),
    '-skip_frame',
    'nokey',
    '-i',
    inputPath,
    '-vf',
    "scale=160:-2:flags=fast_bilinear,select='gte(scene,0)',"
        "metadata=print:key=lavfi.scene_score:file='$scenesPath'",
    '-fps_mode',
    'passthrough',
    if (sourceHasAudio) ...[
      '-af',
      'aresample=16000,asetnsamples=n=8000:p=0,astats=metadata=1:reset=1,'
          "ametadata=print:key=lavfi.astats.Overall.RMS_level:file='$audioPath'",
    ] else
      '-an',
    '-f',
    'null',
    '-',
  ];

  /// Formata duração como decimal fixo para argumentos do FFmpeg.
  ///
  /// Precisão de milissegundos: `trim` e `atrim` aceitam, e evita notação
  /// científica, que o FFmpeg não entende.
  static String seconds(Duration value) =>
      (value.inMilliseconds.clamp(0, 1 << 40) / 1000).toStringAsFixed(3);

  /// Um trecho só: filtros simples em `-vf`/`-af`, sem grafo nomeado.
  static List<String> _simpleFilters(
    List<String> videoChain,
    List<String> audioChain, {
    required bool withAudio,
  }) => [
    if (videoChain.isNotEmpty) ...['-vf', videoChain.join(',')],
    if (withAudio && audioChain.isNotEmpty) ...['-af', audioChain.join(',')],
    '-map',
    '0:v:0',
    // `?` final deixa o FFmpeg seguir sem erro quando a fonte é muda.
    if (withAudio) ...['-map', '0:a:0?'],
  ];

  /// Vários trechos: um grafo com `trim`/`atrim` por segmento e um `concat`.
  static List<String> _complexFilters(
    List<MediaRange> ranges,
    List<String> videoChain,
    List<String> audioChain, {
    required bool withAudio,
  }) {
    final graph = <String>[];
    for (var i = 0; i < ranges.length; i++) {
      final range = ranges[i];
      final videoTail = videoChain.isEmpty ? '' : ',${videoChain.join(',')}';
      graph.add(
        '[0:v]trim=start=${seconds(range.start)}:end=${seconds(range.end)},'
        'setpts=PTS-STARTPTS$videoTail[v$i]',
      );
      if (withAudio) {
        final audioTail = audioChain.isEmpty ? '' : ',${audioChain.join(',')}';
        graph.add(
          '[0:a]atrim=start=${seconds(range.start)}:end=${seconds(range.end)},'
          'asetpts=PTS-STARTPTS$audioTail[a$i]',
        );
      }
    }

    final labels = <String>[];
    for (var i = 0; i < ranges.length; i++) {
      labels.add('[v$i]');
      if (withAudio) labels.add('[a$i]');
    }
    graph.add(
      '${labels.join()}'
      'concat=n=${ranges.length}:v=1:a=${withAudio ? 1 : 0}'
      '[vout]${withAudio ? '[aout]' : ''}',
    );

    return [
      '-filter_complex',
      graph.join(';'),
      '-map',
      '[vout]',
      if (withAudio) ...['-map', '[aout]'],
    ];
  }

  static List<String> _inputSeek(MediaRange range) => [
    '-ss',
    seconds(range.start),
    '-t',
    seconds(range.length),
  ];

  /// Escala preservando proporção e centraliza o excedente (letterbox/pillarbox).
  ///
  /// `x=`/`y=` precisam ser nomeados: misturados com `w=`/`h=` na forma
  /// posicional, o FFmpeg mapeia a expressão para a opção errada e aborta com
  /// "Error when evaluating the expression".
  static List<String> _fitToBox(int width, int height) => [
    'scale=w=$width:h=$height:force_original_aspect_ratio=decrease',
    'pad=w=$width:h=$height:x=(ow-iw)/2:y=(oh-ih)/2:color=black',
    'setsar=1',
  ];

  static List<String> _encodeVideo({
    required HwCodec codec,
    required int? width,
    required int? height,
    required int? fps,
    required RenderQuality quality,
  }) {
    final out = <String>['-c:v', codec.encoder];
    final bitrate = targetBitrateKbps(
      quality: quality,
      width: width,
      height: height,
      fps: fps,
    );
    if (bitrate != null) {
      out.addAll(['-b:v', '${bitrate}k']);
      // VBV: teto de 2x a média evita estouro de buffer em cenas complexas.
      out.addAll(['-maxrate', '${bitrate * 2}k']);
      out.addAll(['-bufsize', '${bitrate * 2}k']);
    }
    if (codec.isHardware) {
      // GOP explícito e perfil alto: sem isso alguns players Android
      // recusam o arquivo ou travam ao buscar o próximo ponto de seek.
      out.addAll(['-profile:v', 'high', '-g', '${(fps ?? 30) * 2}']);
    }
    out.addAll(['-pix_fmt', 'yuv420p']);
    return out;
  }

  static List<String> _encodeAudio() => const [
    '-c:a',
    'aac',
    '-b:a',
    '192k',
    '-ar',
    '48000',
    '-ac',
    '2',
  ];

  /// Converte a escolha de qualidade em taxa de bits alvo, em **kbps**.
  ///
  /// Encoders de hardware não entendem CRF, então o modelo é
  /// `w × h × fps × fator`, com fator por preset — a mesma aproximação usada
  /// por *targeting* de bitrate H.264. Com 1080p30 como referência, o preset
  /// equilibrado gira em torno de 6 Mb/s.
  ///
  /// O cálculo é feito em bits por segundo: o piso de 400 kbps evita arquivo
  /// degenerado em fontes muito pequenas, e o teto de 120 Mbps evita passar do
  /// que o encoder de hardware do aparelho aceita.
  static int? targetBitrateKbps({
    required RenderQuality quality,
    required int? width,
    required int? height,
    required int? fps,
    int fallbackWidth = 1920,
    int fallbackHeight = 1080,
    int fallbackFps = 30,
  }) {
    final w = width ?? fallbackWidth;
    final h = height ?? fallbackHeight;
    final f = fps ?? fallbackFps;
    if (w <= 0 || h <= 0 || f <= 0) return null;
    final factor = switch (quality) {
      RenderQuality.leve => 0.055,
      RenderQuality.equilibrado => 0.10,
      RenderQuality.maxima => 0.18,
    };
    final bps = w * h * f * factor;
    return (bps.clamp(400000, 120000000) / 1000).round();
  }
}
