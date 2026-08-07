import 'dart:async';

import 'package:flutter/material.dart';

// ===================== Brand Colors =====================
/// A palette for a brightness. Light / Dark / Main (== dark with the
/// brand gold accent) are picked by the [ThemeController].
class KashfPalette {
  const KashfPalette({
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.cardBorder,
    required this.fieldFill,
    required this.fieldBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.brightness,
  });

  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color cardBorder;
  final Color fieldFill;
  final Color fieldBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Brightness brightness;

  static const KashfPalette dark = KashfPalette(
    background: Color(0xFF14151A),
    surface: Color(0xFF1C1E2A),
    surfaceLight: Color(0xFF1C1E2A),
    cardBorder: Color(0xFF2D3142),
    fieldFill: Color(0xFF1C1E2A),
    fieldBorder: Color(0xFF31344A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9CA3B0),
    divider: Color(0xFF31344A),
    brightness: Brightness.dark,
  );

  static const KashfPalette main = KashfPalette(
    background: Color(0xFF050608),
    surface: Color(0xFF0C0D14),
    surfaceLight: Color(0xFF0C0D14),
    cardBorder: Color(0xFF1A1C28),
    fieldFill: Color(0xFF0C0D14),
    fieldBorder: Color(0xFF1A1C28),
    textPrimary: Color(0xFFF1E2B0),
    textSecondary: Color(0xFF8A8273),
    divider: Color(0xFF1A1C28),
    brightness: Brightness.dark,
  );

  static const KashfPalette light = KashfPalette(
    background: Color(0xFFF6F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceLight: Color(0xFFF1F2F8),
    cardBorder: Color(0xFFE3E6F0),
    fieldFill: Color(0xFFFFFFFF),
    fieldBorder: Color(0xFFD3D8E5),
    textPrimary: Color(0xFF0F1116),
    textSecondary: Color(0xFF5A6273),
    divider: Color(0xFFE3E6F0),
    brightness: Brightness.light,
  );

  /// The active palette, set by [KashfApp] when the user changes mode.
  static KashfPalette _active = KashfPalette.main;

  static KashfPalette get active => _active;

  static void setActive(KashfPalette palette) {
    _active = palette;
  }
}

/// Brand colors. The default palette is [KashfPalette.dark]; legacy
/// code can keep using the static const fields below. New code should
/// resolve colors from [KashfPalette.active] to react to the picked
/// theme mode.
class KashfColors {
  // Dark palette constants (original brand colors).
  static const Color background = Color(0xFF14151A);
  static const Color backgroundTop = background;
  static const Color backgroundBottom = background;
  static const Color surface = Color(0xFF1C1E2A);
  static const Color surfaceLight = Color(0xFF1C1E2A);
  static const Color cardBorder = Color(0xFF2D3142);

  // Brand gold palette stays the same across themes.
  static const Color gold = Color(0xFFF4C542);
  static const Color goldDeep = Color(0xFFB8861B);
  static const Color goldLight = Color(0xFFFFE08A);
  static const Color goldShadow = Color(0xFF7A5A0F);

  // Success state (used by the post-auth confirmation popup).
  static const Color success = Color(0xFF22C55E);
  static const Color successDark = Color(0xFF15803D);

  static const Color fieldFill = Color(0xFF1C1E2A);
  static const Color fieldBorder = Color(0xFF31344A);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3B0);
  static const Color divider = Color(0xFF31344A);
}

// ===================== Success Popup =====================
// A green confirmation popup that animates in over the current screen.
// Lives on the root navigator overlay so it survives auth-screen
// transitions (the auth gate swaps to HomeShell as soon as Firebase
// reports a logged-in user, but the popup is rendered above every
// route and stays visible until the user dismisses it or the timer
// expires).
class SuccessPopup {
  SuccessPopup._();

  /// Shows a green success popup over the root navigator. Returns
  /// when the popup has been fully dismissed.
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? message,
    Duration duration = const Duration(milliseconds: 1400),
  }) {
    final overlay = Overlay.of(context);
    final completer = _SuccessCompleter();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayCtx) => _SuccessPopupWidget(
        title: title,
        message: message,
        duration: duration,
        onDismiss: entry.remove,
        onSettled: completer.complete,
      ),
    );
    overlay.insert(entry);
    return completer.future;
  }
}

class _SuccessCompleter {
  final Completer<void> _c = Completer<void>();
  Future<void> get future => _c.future;
  void complete() {
    if (_c.isCompleted) return;
    _c.complete();
  }
}

class _SuccessPopupWidget extends StatefulWidget {
  const _SuccessPopupWidget({
    required this.title,
    required this.message,
    required this.duration,
    required this.onDismiss,
    required this.onSettled,
  });

  final String title;
  final String? message;
  final Duration duration;
  final VoidCallback onDismiss;
  final VoidCallback onSettled;

  @override
  State<_SuccessPopupWidget> createState() => _SuccessPopupWidgetState();
}

class _SuccessPopupWidgetState extends State<_SuccessPopupWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _autoDismiss();
  }

  Future<void> _autoDismiss() async {
    await Future.delayed(widget.duration);
    if (!mounted) return;
    await _runDismiss();
  }

  Future<void> _runDismiss() async {
    if (_removing) return;
    _removing = true;
    await _ctrl.reverse();
    if (!mounted) return;
    widget.onDismiss();
    widget.onSettled();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          return Stack(
            children: [
              IgnorePointer(
                child: Opacity(
                  opacity: _fade.value * 0.55,
                  child: Container(color: Colors.black),
                ),
              ),
              Center(
                child: Transform.scale(
                  scale: _scale.value,
                  child: Opacity(opacity: _fade.value, child: child),
                ),
              ),
            ],
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: KashfColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: KashfColors.success.withValues(alpha: 0.55),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: KashfColors.success.withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        KashfColors.success,
                        KashfColors.successDark,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF9CA3B0),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== Directional Chevron =====================
// A tiny helper that auto-mirrors a chevron icon based on the
// current [Directionality]. Use this anywhere you'd otherwise drop
// a plain `Icons.chevron_right` so the arrow always points forward
// (toward the destination) in both LTR and RTL layouts.
class DirectionalChevron extends StatelessWidget {
  const DirectionalChevron({
    super.key,
    this.size = 20,
    this.color = KashfColors.textSecondary,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Transform(
      alignment: Alignment.center,
      transform: isRtl
          ? (Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0))
          : Matrix4.identity(),
      child: Icon(Icons.chevron_right, size: size, color: color),
    );
  }
}

// ===================== Kashf Logo =====================
// Displays the project logo asset directly — no card, no shadow,
// no async processing. The PNG background (#14151A) matches the
// Scaffold so it blends seamlessly.
class KashfLogo extends StatelessWidget {
  const KashfLogo({super.key, this.width = 140});

  final double width;

  /// Single logo width used on every screen so the brand mark stays
  /// consistent across the welcome / sign-in / sign-up / phone flows.
  static const double welcomeWidth = 150;
  static const double innerWidth = 150;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/kashf_logo.png',
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
  }
}

// ===================== Brand Header =====================
class KashfBrandHeader extends StatelessWidget {
  const KashfBrandHeader({super.key, this.logoWidth});

  /// Override the logo width. Defaults to the welcome-screen size.
  final double? logoWidth;

  @override
  Widget build(BuildContext context) {
    // Logo image already contains "KASHF" and "Lite" — display only the
    // asset. No duplicate text, no dividers.
    final w = logoWidth ?? KashfLogo.welcomeWidth;
    return Center(child: KashfLogo(width: w));
  }
}

// ===================== Background =====================
// Flat reference background — no gradients, no circles, no decorations.
class BackgroundDecorations extends StatelessWidget {
  const BackgroundDecorations({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: KashfColors.background);
  }
}

// ===================== Shared Auth Spacing Tokens =====================
// One spacing system used by every authentication screen. 8-point grid.
class AuthSpacing {
  /// Logo width used everywhere.
  static const double logoWidth = 150;

  /// Horizontal page padding used by all buttons, fields, and dividers.
  static const double pagePaddingX = 20;

  /// Logo -> Title
  static const double gapLogoTitle = 32;

  /// Title -> Subtitle
  static const double gapTitleSubtitle = 12;

  /// Subtitle -> First field/button
  static const double gapSubtitleFirst = 36;

  /// Between fields/buttons
  static const double gapBetweenItems = 16;

  /// Divider -> Apple button
  static const double gapDividerApple = 24;

  /// Apple button -> bottom text
  static const double gapAppleFooter = 0;
}

// ===================== Shared Auth Scaffold =====================
// Provides identical layout proportions for every authentication screen.
// Only the body content changes between Login / Sign Up / Phone flows.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.footerPrompt,
    required this.footerAction,
    required this.onFooterActionTap,
    this.showBackButton = true,
    this.compact = false,
    this.logoWidth,
  });

  final String title;
  final String subtitle;

  /// The screen-specific content (buttons, text fields, etc.).
  final Widget body;

  final String footerPrompt;
  final String footerAction;
  final VoidCallback onFooterActionTap;

  /// Sign-up/email/phone screens have a back button; welcome screen hides it.
  final bool showBackButton;

  /// When true, the footer is placed directly below the body without a
  /// flexible spacer. Use for short screens like the welcome screen.
  final bool compact;

  /// Optional override for the logo width. Defaults to [AuthSpacing.logoWidth].
  final double? logoWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KashfColors.background,
      body: Stack(
        children: [
          const BackgroundDecorations(),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuthSpacing.pagePaddingX,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (showBackButton) ...[
                            const SizedBox(height: 4),
                            const Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: CircleBackButton(),
                            ),
                            const SizedBox(height: 4),
                          ] else
                            const SizedBox(height: 8),
                          KashfBrandHeader(
                            logoWidth: logoWidth ?? AuthSpacing.logoWidth,
                          ),
                          const SizedBox(height: AuthSpacing.gapLogoTitle),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: KashfColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AuthSpacing.gapTitleSubtitle),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: KashfColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AuthSpacing.gapSubtitleFirst),
                          body,
                          if (compact)
                            const SizedBox(height: AuthSpacing.gapBetweenItems)
                          else
                            const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // The action ("Sign up" / "إنشاء حساب")
                              // is placed first so that, in RTL, it
                              // appears on the right — i.e. the first
                              // word the user reads in Arabic.
                             
                              Text(
                                footerPrompt,
                                style: const TextStyle(
                                  color: KashfColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                               GestureDetector(
                                onTap: onFooterActionTap,
                                child: Text(
                                  footerAction,
                                  style: const TextStyle(
                                    color: KashfColors.gold,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AuthSpacing.gapAppleFooter),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Reusable Inputs =====================
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.controller,
    this.textInputAction,
    this.onSubmitted,
  });

  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KashfColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfColors.fieldBorder),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: KashfColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: KashfColors.textSecondary),
          prefixIcon: Icon(icon, color: KashfColors.gold, size: 22),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

// ===================== Reusable Back Button =====================
class CircleBackButton extends StatelessWidget {
  const CircleBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: KashfColors.fieldFill,
              shape: BoxShape.circle,
              border: Border.all(color: KashfColors.fieldBorder),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 14,
              color: KashfColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ===================== Animated Primary Button =====================
class KashfPrimaryButton extends StatefulWidget {
  const KashfPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final Future<void> Function()? onPressed;

  /// Whether the button is interactive. Ignored while [loading] is true.
  final bool enabled;

  /// Whether the button is currently performing an async action. When
  /// true, the spinner is shown, taps are ignored, and the gradient
  /// stays gold (so the user gets clear feedback that the button is
  /// working). The parent is expected to flip this flag manually via
  /// a StatefulBuilder / setState around the call to [onPressed].
  final bool loading;

  @override
  State<KashfPrimaryButton> createState() => _KashfPrimaryButtonState();
}

class _KashfPrimaryButtonState extends State<KashfPrimaryButton> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (!widget.enabled || widget.loading || _loading || widget.onPressed == null) {
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // While the parent flips `loading: true` we still want the button
    // to look "active" (gold gradient) so the user knows the action
    // is in progress, just not interactive.
    final showSpinner = widget.loading || _loading;
    final isInteractive =
        widget.enabled && widget.onPressed != null && !showSpinner;
    return GestureDetector(
      onTap: isInteractive ? _handleTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: (isInteractive || showSpinner)
                ? const [Color(0xFFF8C24A), Color(0xFFF5B92E)]
                : [
                    KashfColors.gold.withValues(alpha: 0.45),
                    KashfColors.gold.withValues(alpha: 0.45),
                  ],
          ),
          boxShadow: (isInteractive || showSpinner)
              ? [
                  BoxShadow(
                    color: KashfColors.gold.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: showSpinner
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(Colors.black),
                ),
              )
            : Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
      ),
    );
  }
}

// ===================== Option Tile =====================
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1E2A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2D3142)),
          ),
          child: Row(
            children: [
              Icon(icon, color: KashfColors.gold, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: KashfColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const DirectionalChevron(
                color: KashfColors.textPrimary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Or Divider =====================
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: KashfColors.divider, height: 1)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: TextStyle(color: KashfColors.textSecondary, fontSize: 13),
          ),
        ),
        const Expanded(child: Divider(color: KashfColors.divider, height: 1)),
      ],
    );
  }
}

// ===================== Apple Button =====================
class AppleButton extends StatefulWidget {
  const AppleButton({super.key, required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  State<AppleButton> createState() => _AppleButtonState();
}

class _AppleButtonState extends State<AppleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) async {
        await _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          final t = _ctrl.value / 0.05;
          return Transform.scale(scale: 1 - t, child: child);
        },
        child: Container(
          width: double.infinity,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.apple, size: 22, color: Colors.black),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Slide-in Route Transition =====================
PageRouteBuilder<T> kashfRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final offset = Tween<Offset>(
        begin: const Offset(0.15, 0),
        end: Offset.zero,
      ).animate(curved);
      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
      return SlideTransition(
        position: offset,
        child: FadeTransition(opacity: fade, child: child),
      );
    },
  );
}
