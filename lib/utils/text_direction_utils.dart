import 'package:flutter/material.dart';

/// Small utility to pick a [TextDirection] for AI-generated text.
///
/// The investigation result can come back in Arabic (when the user
/// typed an Arabic query) or in English. We auto-detect the dominant
/// script of the string and pick LTR for Latin, RTL for Arabic —
/// this way each string renders correctly without forcing the
/// whole screen into one direction.
TextDirection detectTextDirection(String text) {
  if (text.isEmpty) return TextDirection.ltr;
  // Match any Arabic (or Hebrew / Persian) codepoint.
  final hasRtl = RegExp(
    r'[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  ).hasMatch(text);
  if (hasRtl) return TextDirection.rtl;
  return TextDirection.ltr;
}

/// Convenience wrapper: wraps [child] in a [Directionality] that
/// matches [text]. Falls back to LTR when [text] is empty.
Widget autoDirection(String text, Widget child) {
  return Directionality(
    textDirection: detectTextDirection(text),
    child: child,
  );
}

/// Whether [text] is dominated by RTL script.
bool isRtlText(String text) =>
    detectTextDirection(text) == TextDirection.rtl;
