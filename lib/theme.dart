import 'package:flutter/material.dart';

// ===================== Brand Colors =====================
class KashfColors {
  // Flat reference background
  static const Color background = Color(0xFF14151A);
  static const Color backgroundTop = background;
  static const Color backgroundBottom = background;

  // Button / card surface (dark cards)
  static const Color surface = Color(0xFF1C1E2A);
  static const Color surfaceLight = Color(0xFF1C1E2A);
  static const Color cardBorder = Color(0xFF2D3142);

  // Premium gold palette
  static const Color gold = Color(0xFFF4C542);
  static const Color goldDeep = Color(0xFFB8861B);
  static const Color goldLight = Color(0xFFFFE08A);
  static const Color goldShadow = Color(0xFF7A5A0F);

  // Form fields and dividers
  static const Color fieldFill = Color(0xFF1C1E2A);
  static const Color fieldBorder = Color(0xFF31344A);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3B0);
  static const Color divider = Color(0xFF31344A);
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
  static const double pagePaddingX = 24;

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
  static const double gapAppleFooter = 16;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KashfColors.background,
      body: Stack(
        children: [
          const BackgroundDecorations(),
          SafeArea(
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
                              alignment: Alignment.centerLeft,
                              child: CircleBackButton(),
                            ),
                            const SizedBox(height: 4),
                          ] else
                            const SizedBox(height: 8),
                          const KashfBrandHeader(
                            logoWidth: AuthSpacing.logoWidth,
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
  });

  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KashfColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfColors.fieldBorder),
      ),
      child: TextField(
        obscureText: obscureText,
        keyboardType: keyboardType,
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
  });

  final String label;
  final Future<void> Function()? onPressed;
  final bool enabled;

  @override
  State<KashfPrimaryButton> createState() => _KashfPrimaryButtonState();
}

class _KashfPrimaryButtonState extends State<KashfPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      lowerBound: 0.0,
      upperBound: 0.06,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (!widget.enabled || _loading || widget.onPressed == null) return;
    setState(() => _loading = true);
    await _ctrl.forward();
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) {
        await _ctrl.reverse();
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.enabled && widget.onPressed != null;
    return GestureDetector(
      onTapDown: isActive ? (_) => _ctrl.forward() : null,
      onTapUp: isActive
          ? (_) async {
              await _ctrl.reverse();
              await _handleTap();
            }
          : null,
      onTapCancel: isActive ? () => _ctrl.reverse() : null,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          final t = _ctrl.value / 0.06;
          return Transform.scale(scale: 1 - t, child: child);
        },
        child: Container(
          width: double.infinity,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: isActive
                  ? const [Color(0xFFF8C24A), Color(0xFFF5B92E)]
                  : [
                      KashfColors.gold.withValues(alpha: 0.45),
                      KashfColors.gold.withValues(alpha: 0.45),
                    ],
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: KashfColors.gold.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: _loading
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
              const Icon(
                Icons.chevron_right,
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
