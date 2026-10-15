import 'package:flutter/material.dart';

/// Paleta "sala escura": preto de projeção, branco quente e um único acento
/// tungstênio (a luz de set). Inspirada em visores de câmera de cinema e em
/// suítes de color grading — quase monocromática, para a imagem do cliente ser
/// a única coisa colorida na tela.
abstract final class AppColors {
  static const Color background = Color(0xFF050506);
  static const Color surface = Color(0xFF0E0E11);
  static const Color surfaceHigh = Color(0xFF16161A);
  static const Color surfaceTop = Color(0xFF202026);
  static const Color border = Color(0xFF1F1F25);
  static const Color borderStrong = Color(0xFF2E2E36);

  /// Tungstênio: acento principal, ações e seleção.
  static const Color primary = Color(0xFFF5B942);
  static const Color primaryDim = Color(0xFF6B5221);

  /// Vermelho REC: playhead, gravação, destaque de tempo.
  static const Color accent = Color(0xFFFF4A3D);

  /// Luz do dia: informação técnica secundária.
  static const Color teal = Color(0xFF7FD4FF);

  static const Color textPrimary = Color(0xFFF3F2EE);
  static const Color textSecondary = Color(0xFFA3A3A8);
  static const Color textMuted = Color(0xFF5F5F68);

  static const Color success = Color(0xFF3DDC84);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF453A);

  static const LinearGradient brand = LinearGradient(
    colors: [Color(0xFFF5B942), Color(0xFFFF7A3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cool = LinearGradient(
    colors: [Color(0xFF7FD4FF), Color(0xFF4F7BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get softShadow => const [
    BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 12)),
  ];
}
