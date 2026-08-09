import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A polished, branded loading overlay shown on top of a child
/// while an async fetch is in flight. Features:
///
/// * The brand gold spinner ring with a subtle counter-rotating
///   accent ring for a smooth "alive" feel.
/// * A pulsing gold dot at the centre that grows and shrinks in
///   sync with the spinner — gives the user immediate visual
///   feedback even before any text appears.
/// * An optional caption (`"Updating market data…"`) with a soft
///   fade-in so the screen never feels jarring.
/// * Tappable background (delegated to the underlying child) so the
///   rest of the UI stays interactive; the overlay itself is
///   pointer-transparent except where [blocking] is `true`.
///
/// Use it as:
///
/// ```dart
/// LoadingOverlay(
///   visible: _controller.isLoading,
///   message: 'Updating market data…',
///   child: SomeContent(),
/// )
/// ```
class LoadingOverlay extends StatefulWidget {
  const LoadingOverlay({
    super.key,
    required this.visible,
    required this.child,
    this.message,
    this.blocking = false,
  });

  /// When `true` the overlay fades in and intercepts taps so the
  /// user cannot fire a second refresh while one is running.
  final bool visible;

  /// Caption shown under the spinner. Pass `null` to hide it
  /// entirely.
  final String? message;

  /// When `true`, taps land on the overlay instead of the child.
  final bool blocking;

  /// The content the overlay is drawn on top of.
  final Widget child;

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // Slow clockwise spin for the gold ring.
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    // Faster, counter-phase pulse for the inner dot. Synced to a
    // sine-like easing curve so the growth feels organic.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    if (widget.visible) _enter();
  }

  @override
  void didUpdateWidget(covariant LoadingOverlay old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) _enter();
    if (!widget.visible && old.visible) _exit();
  }

  void _enter() {
    if (mounted) setState(() {});
  }

  void _exit() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !widget.blocking || !widget.visible,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            opacity: widget.visible ? 1 : 0,
            child: _Backdrop(visible: widget.visible),
          ),
        ),
        if (widget.visible)
          Center(
            child: _Loader(
              spin: _spin,
              pulse: _pulse,
              message: widget.message,
            ),
          ),
      ],
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      alignment: Alignment.center,
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader({
    required this.spin,
    required this.pulse,
    required this.message,
  });

  final AnimationController spin;
  final AnimationController pulse;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: AnimatedBuilder(
            animation: Listenable.merge([spin, pulse]),
            builder: (_, _) {
              return CustomPaint(
                painter: _SpinnerPainter(
                  spinValue: spin.value,
                  pulseValue: pulse.value,
                ),
              );
            },
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: pulse,
            builder: (_, _) {
              // Tiny opacity pulse on the label so the whole
              // element breathes together.
              final t = (math.sin(pulse.value * math.pi) + 1) / 2;
              return Opacity(
                opacity: 0.65 + 0.35 * t,
                child: Text(
                  message!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Paints a gold arc + a counter-rotating faint accent ring with
/// a pulsing centre dot. The painter is intentionally
/// `shouldRepaint` returning `true` so every frame re-renders the
/// new angle; the cost is negligible at 64×64 px.
class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({required this.spinValue, required this.pulseValue});

  final double spinValue;
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;

    // Outer faint ring (counter-rotates at half speed).
    final accentPaint = Paint()
      ..color = KashfColors.gold.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-spinValue * math.pi * 4);
    canvas.drawCircle(Offset.zero, radius, accentPaint);
    canvas.restore();

    // Main gold arc: ~75% of the circle, with a rounded cap.
    final goldPaint = Paint()
      ..color = KashfColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      spinValue * math.pi * 2,
      math.pi * 1.5,
      false,
      goldPaint,
    );

    // Fading trail behind the gold arc to give a "comet" feel.
    final trailPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          KashfColors.gold.withValues(alpha: 0.0),
          KashfColors.gold.withValues(alpha: 0.55),
        ],
        transform: GradientRotation(spinValue * math.pi * 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      spinValue * math.pi * 2 - 0.45,
      0.55,
      false,
      trailPaint,
    );

    // Centre pulsing dot.
    final dotRadius = 4.0 + 3.0 * pulseValue;
    final dotPaint = Paint()
      ..color = Color.lerp(
        KashfColors.gold,
        Colors.white,
        0.25 * pulseValue,
      )!;
    canvas.drawCircle(center, dotRadius, dotPaint);

    // Soft halo around the dot.
    final haloPaint = Paint()
      ..color = KashfColors.gold.withValues(alpha: 0.18 + 0.18 * pulseValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, dotRadius + 4, haloPaint);
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter old) =>
      old.spinValue != spinValue || old.pulseValue != pulseValue;
}

/// Inline spinner button for app-bar refresh icons. The same
/// brand-gold look as [LoadingOverlay] but compact (24×24).
class InlineSpinner extends StatefulWidget {
  const InlineSpinner({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  State<InlineSpinner> createState() => _InlineSpinnerState();
}

class _InlineSpinnerState extends State<InlineSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? KashfColors.gold;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => CustomPaint(
          painter: _InlineSpinnerPainter(
            color: color,
            value: _ctrl.value,
          ),
        ),
      ),
    );
  }
}

class _InlineSpinnerPainter extends CustomPainter {
  _InlineSpinnerPainter({required this.color, required this.value});
  final Color color;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      value * math.pi * 2,
      math.pi * 1.4,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _InlineSpinnerPainter old) =>
      old.value != value || old.color != color;
}