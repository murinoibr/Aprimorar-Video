import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/media/cinema_look.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Rótulo técnico em caixa alta, estilo menu de câmera.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding});

  final String text;
  final Widget? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(2, 28, 2, 12),
      child: Row(
        children: [
          Text(text.toUpperCase(), style: AppTheme.label),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1)),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

/// Mantido para telas antigas: agora é um [SectionLabel].
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SectionLabel(title, trailing: trailing);
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.gradient,
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    final content = Ink(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? AppColors.surface : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(
          color: highlighted
              ? AppColors.primary.withValues(alpha: 0.6)
              : AppColors.border,
        ),
      ),
      child: child,
    );
    return Material(
      color: Colors.transparent,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}

class PillLabel extends StatelessWidget {
  const PillLabel({
    super.key,
    required this.text,
    this.color = AppColors.primary,
    this.icon,
  });

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              fontFeatures: AppTheme.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão principal: tungstênio sólido, texto preto. Um por tela.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onPressed != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: active ? 1 : 0.35,
      child: SizedBox(
        height: compact ? 40 : 56,
        child: FilledButton(
          onPressed: active
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }
              : null,
          style: FilledButton.styleFrom(
            minimumSize: Size(compact ? 0 : double.infinity, compact ? 40 : 56),
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
            disabledBackgroundColor: AppColors.primary,
            disabledForegroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(compact ? 12 : 16),
            ),
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 16 : 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compatibilidade com o nome antigo.
class PrimaryGradientButton extends StatelessWidget {
  const PrimaryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient? gradient;
  final bool enabled;

  @override
  Widget build(BuildContext context) => PrimaryButton(
    label: label,
    onPressed: onPressed,
    icon: icon,
    enabled: enabled,
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: AppColors.textMuted),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// Cantoneiras de visor de câmera por cima de qualquer conteúdo.
class Viewfinder extends StatelessWidget {
  const Viewfinder({
    super.key,
    required this.child,
    this.topLeft,
    this.topRight,
    this.bottomLeft,
    this.bottomRight,
    this.color = Colors.white,
    this.radius = 18,
    this.background = Colors.black,
  });

  final Widget child;
  final Widget? topLeft;
  final Widget? topRight;
  final Widget? bottomLeft;
  final Widget? bottomRight;
  final Color color;
  final double radius;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: background,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            child,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CornersPainter(color.withValues(alpha: 0.55)),
                ),
              ),
            ),
            if (topLeft != null) Positioned(left: 14, top: 12, child: topLeft!),
            if (topRight != null)
              Positioned(right: 14, top: 12, child: topRight!),
            if (bottomLeft != null)
              Positioned(left: 14, bottom: 12, child: bottomLeft!),
            if (bottomRight != null)
              Positioned(right: 14, bottom: 12, child: bottomRight!),
          ],
        ),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const inset = 8.0;
    const arm = 14.0;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(inset, inset + arm)
      ..lineTo(inset, inset)
      ..lineTo(inset + arm, inset)
      ..moveTo(w - inset - arm, inset)
      ..lineTo(w - inset, inset)
      ..lineTo(w - inset, inset + arm)
      ..moveTo(inset, h - inset - arm)
      ..lineTo(inset, h - inset)
      ..lineTo(inset + arm, h - inset)
      ..moveTo(w - inset - arm, h - inset)
      ..lineTo(w - inset, h - inset)
      ..lineTo(w - inset, h - inset - arm);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornersPainter old) => old.color != color;
}

/// Texto técnico pequeno sobre a imagem (timecode, resolução, REC).
class HudText extends StatelessWidget {
  const HudText(this.text, {super.key, this.dot, this.color = Colors.white});

  final String text;
  final Color? dot;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              fontFeatures: AppTheme.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Seleção única em linha, rolável, minimalista.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.hint,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final String Function(T)? hint;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final value in values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Choice(
                label: label(value),
                hint: hint?.call(value),
                selected: value == selected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(value);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: hint == null ? 10 : 9,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Liga/desliga com título e explicação curta.
class ToggleTile extends StatelessWidget {
  const ToggleTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: value ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Ajuste fino com valor visível. [bipolar] centra o zero (-100..+100).
class FineSlider extends StatelessWidget {
  const FineSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.bipolar = true,
    this.onChangeEnd,
  });

  final String label;
  final double value;
  final bool bipolar;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final shown = (value * 100).round();
    final text = bipolar && shown > 0 ? '+$shown' : '$shown';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: GestureDetector(
              onDoubleTap: () {
                final reset = bipolar ? 0.0 : 0.5;
                onChanged(reset);
                onChangeEnd?.call(reset);
              },
              child: Slider(
                value: value,
                min: bipolar ? -1 : 0,
                max: 1,
                // No bipolar a trilha não "enche" da esquerda: o zero é o meio.
                activeColor: bipolar ? AppColors.surfaceTop : null,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: AppTheme.timecode.copyWith(
                color: value == (bipolar ? 0 : -1)
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carrossel de looks de cinema com amostra de cor.
class LookStrip extends StatelessWidget {
  const LookStrip({super.key, required this.selected, required this.onChanged});

  final CinemaLook selected;
  final ValueChanged<CinemaLook> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: CinemaLook.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final look = CinemaLook.values[index];
          final active = look == selected;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(look);
            },
            child: SizedBox(
              width: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 64,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? AppColors.primary : AppColors.border,
                        width: active ? 1.6 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: LookSwatch(look: look),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    look.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    look.hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Amostra abstrata de um look: céu, horizonte e chão nas cores do grading.
class LookSwatch extends StatelessWidget {
  const LookSwatch({super.key, required this.look});

  final CinemaLook look;

  @override
  Widget build(BuildContext context) {
    final p = look.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p[1], p[2], p[0]],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.45, 0.05),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p[2],
            boxShadow: [
              BoxShadow(color: p[2].withValues(alpha: 0.8), blurRadius: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// Comparação antes/depois com divisor arrastável.
class BeforeAfter extends StatefulWidget {
  const BeforeAfter({
    super.key,
    required this.before,
    required this.after,
    this.loading = false,
  });

  final String? before;
  final String? after;
  final bool loading;

  @override
  State<BeforeAfter> createState() => _BeforeAfterState();
}

class _BeforeAfterState extends State<BeforeAfter> {
  double _split = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final x = width * _split;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => setState(
            () => _split = (d.localPosition.dx / width).clamp(0.0, 1.0),
          ),
          onTapDown: (d) => setState(
            () => _split = (d.localPosition.dx / width).clamp(0.0, 1.0),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _image(widget.after ?? widget.before),
              ClipRect(clipper: _LeftClip(x), child: _image(widget.before)),
              Positioned(
                left: x - 0.75,
                top: 0,
                bottom: 0,
                child: Container(width: 1.5, color: Colors.white),
              ),
              Positioned(
                left: x - 15,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.softShadow,
                    ),
                    child: const Icon(
                      Icons.unfold_more_rounded,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const Positioned(left: 12, bottom: 12, child: HudText('ANTES')),
              const Positioned(
                right: 12,
                bottom: 12,
                child: HudText('DEPOIS', color: AppColors.primary),
              ),
              if (widget.loading)
                const Positioned(
                  right: 12,
                  top: 12,
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _image(String? path) {
    if (path == null) return const ColoredBox(color: Colors.black);
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
    );
  }
}

class _LeftClip extends CustomClipper<Rect> {
  const _LeftClip(this.x);

  final double x;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, x, size.height);

  @override
  bool shouldReclip(covariant _LeftClip old) => old.x != x;
}

/// Progresso de render: porcentagem grande, etapa, ETA e cancelar.
class RenderProgressPanel extends StatelessWidget {
  const RenderProgressPanel({
    super.key,
    required this.fraction,
    required this.title,
    this.detail,
    this.onCancel,
  });

  final double fraction;
  final String title;
  final String? detail;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final percent = (fraction * 100).clamp(0, 100).floor();
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HudText('RENDER', dot: AppColors.accent),
                    const SizedBox(height: 10),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w200,
                  color: AppColors.textPrimary,
                  letterSpacing: -1.5,
                  fontFeatures: AppTheme.tabular,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction <= 0 ? null : fraction,
              minHeight: 3,
            ),
          ),
          if (onCancel != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                child: const Text('Cancelar'),
              ),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// Mensagem de erro discreta, sem modal.
class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
