import 'package:flutter/painting.dart';

/// Looks de color grading inspirados nas estéticas mais marcantes do cinema
/// recente — tudo com filtros nativos do FFmpeg (curves, colorbalance, eq,
/// noise, vignette), sem LUT externa nem modelo de IA: zero download, zero
/// custo, roda em qualquer aparelho.
enum CinemaLook {
  natural('Natural', 'Cor fiel, só limpeza', [
    Color(0xFF1C1C1F),
    Color(0xFF77777D),
    Color(0xFFE9E9E6),
  ], []),
  blockbuster(
    'Teal & Orange',
    'Pele quente, sombras frias',
    [Color(0xFF0E3B4A), Color(0xFF3F7F8C), Color(0xFFF2A65A)],
    [
      'colorbalance=rs=-0.08:gs=-0.02:bs=0.10:rm=0.02:bm=-0.02:rh=0.08:gh=0.02:bh=-0.08',
      'eq=contrast=1.08:saturation=1.12',
    ],
  ),
  deserto(
    'Deserto',
    'Épico, quente e contido',
    [Color(0xFF3B2716), Color(0xFFB07A45), Color(0xFFF1D3A2)],
    [
      'colorbalance=rs=0.06:gs=0.02:bs=-0.06:rm=0.08:gm=0.03:bm=-0.08:rh=0.05:bh=-0.05',
      'eq=contrast=1.04:saturation=0.82:gamma=1.02',
      "curves=all='0/0.04 0.5/0.5 1/0.96'",
    ],
  ),
  neon(
    'Neon Noir',
    'Noite futurista, ciano e magenta',
    [Color(0xFF1A0B2E), Color(0xFF3A2C8C), Color(0xFFFF4FA3)],
    [
      'colorbalance=rs=-0.04:bs=0.14:rm=0.06:bm=0.08:rh=0.10:gh=-0.04:bh=0.06',
      'eq=contrast=1.15:saturation=1.2:gamma=0.95',
    ],
  ),
  pelicula(
    'Película 35mm',
    'Pretos lavados, grão e vinheta',
    [Color(0xFF2A2620), Color(0xFF8C7B62), Color(0xFFF0E2C4)],
    [
      "curves=all='0/0.06 0.25/0.22 0.75/0.8 1/0.94'",
      'colorbalance=rs=0.03:bs=-0.02:rh=0.04:bh=-0.04',
      'eq=saturation=0.9',
      'noise=alls=7:allf=t',
      'vignette=PI/5',
    ],
  ),
  noir(
    'Noir Prata',
    'Preto e branco de alto contraste',
    [Color(0xFF0A0A0A), Color(0xFF6E6E6E), Color(0xFFF2F2F2)],
    [
      'hue=s=0',
      'eq=contrast=1.28:gamma=0.95',
      'noise=alls=5:allf=t',
      'vignette=PI/4',
    ],
  ),
  pastel(
    'Pastel',
    'Simétrico, doce e luminoso',
    [Color(0xFFF3C6C9), Color(0xFFBFE3E0), Color(0xFFF7E7B4)],
    [
      'eq=contrast=0.92:saturation=1.1:brightness=0.03',
      'colorbalance=rs=0.05:gs=0.01:bs=0.02:rh=0.04:gh=0.03',
      "curves=all='0/0.08 1/0.97'",
    ],
  );

  const CinemaLook(this.label, this.hint, this.palette, this.filters);

  final String label;
  final String hint;

  /// Sombra, meio-tom e luz — usado para desenhar a amostra do look.
  final List<Color> palette;

  /// Cadeia de filtros FFmpeg do look, na ordem de aplicação.
  final List<String> filters;

  bool get isNeutral => filters.isEmpty;

  static CinemaLook? byName(String? name) {
    for (final look in values) {
      if (look.name == name) return look;
    }
    return null;
  }
}

/// Faixas pretas 2.39:1 (scope) sem cortar a imagem nem mudar a resolução.
///
/// Em vídeo vertical a conta dá altura negativa; o `max(0, …)` faz o filtro
/// virar no-op em vez de abortar o render.
const List<String> cinemaBarsFilters = [
  "drawbox=x=0:y=0:w=iw:h='max(0,(ih-iw/2.39)/2)':color=black:t=fill",
  "drawbox=x=0:y=ih-'max(0,(ih-iw/2.39)/2)':w=iw:h='max(0,(ih-iw/2.39)/2)':color=black:t=fill",
];
