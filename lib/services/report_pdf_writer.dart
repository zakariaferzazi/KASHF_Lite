import 'dart:async';
import 'dart:io';

import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:bidi/bidi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/investigation_result.dart';
import '../models/saved_investigation.dart';

// ============================================================================
// Cached Arabic-capable TrueType fonts.
//
// Loaded once at app startup via [preLoadPdfFont] (called from
// `main()`). The `pdf` package embeds the TrueType subset into every PDF,
// so Arabic glyphs render on every viewer without depending on system
// fonts.
// ============================================================================

ByteData? _cachedRegFont;
ByteData? _cachedBoldFont;
ByteData? _cachedLatinFont;

/// Pre-loads every TrueType the PDF needs from the asset
/// bundle. Run once at app startup so the first PDF is
/// generated with zero `await` on the hot path.
///
/// The font stack is intentionally split:
///
///   * `NotoSansArabic-*` covers the Arabic block plus basic
///     Latin glyphs. It carries the OpenType GSUB/GPOS tables
///     that perform Arabic contextual shaping (initial /
///     medial / final / isolated forms) — that is what makes
///     letters connect correctly in the PDF.
///
///   * `NotoSans-*` covers Latin Extended, punctuation,
///     symbols, and the digits / em-dash / arrows used in the
///     English brand strings and section metadata. We need
///     this fallback because `NotoSansArabic` does not ship
///     many Latin punctuation glyphs — without the fallback
///     every arrow, middle-dot, em-dash, ellipsis, ampersand,
///     parenthesis would render as the missing-glyph box.
Future<void> preLoadPdfFont() async {
  if (_cachedRegFont != null) return;
  try {
    _cachedRegFont =
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
    _cachedBoldFont =
      await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
    try {
      _cachedLatinFont =
          await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    } catch (_) {/* optional */}
    debugPrint(
      '[Kashf/PDFWriter] fonts loaded — '
      'arabic=${_cachedRegFont!.lengthInBytes}B '
      'arabic-bold=${_cachedBoldFont!.lengthInBytes}B '
      'latin=${_cachedLatinFont?.lengthInBytes ?? 0}B',
    );
  } catch (e, st) {
    debugPrint('[Kashf/PDFWriter] font load FAILED: $e');
    debugPrint('[Kashf/PDFWriter] STACK: $st');
    _cachedRegFont = null;
    _cachedBoldFont = null;
    _cachedLatinFont = null;
  }
}

pw.Font get _regularFont =>
    _cachedRegFont != null ? pw.Font.ttf(_cachedRegFont!) : pw.Font.helvetica();

pw.Font get _boldFont =>
    _cachedBoldFont != null
        ? pw.Font.ttf(_cachedBoldFont!)
        : pw.Font.helveticaBold();

pw.Font? get _latinFallback =>
    _cachedLatinFont != null ? pw.Font.ttf(_cachedLatinFont!) : null;

// ============================================================================
// Brand palette (kept in sync with `theme.dart` so the PDF matches the UI).
// ============================================================================

const _brandGold = PdfColor.fromInt(0xFFF4C542);
const _brandGoldDeep = PdfColor.fromInt(0xFFB8861B);
const _brandGoldLight = PdfColor.fromInt(0xFFFFE08A);
const _navy900 = PdfColor.fromInt(0xFF0F1421);
const _navy800 = PdfColor.fromInt(0xFF1A2032);
const _navy700 = PdfColor.fromInt(0xFF252B40);
const _slate600 = PdfColor.fromInt(0xFF64748B);
const _slate500 = PdfColor.fromInt(0xFF94A3B8);
const _slate200 = PdfColor.fromInt(0xFFE2E8F0);
const _slate100 = PdfColor.fromInt(0xFFF1F5F9);
const _white = PdfColor.fromInt(0xFFFFFFFF);
const _green600 = PdfColor.fromInt(0xFF059669);
const _red600 = PdfColor.fromInt(0xFFDC2626);

// ============================================================================
// Public API.
// ============================================================================

/// PDF writer for a single investigation report.
///
/// Uses the `pdf` package with `NotoSansArabic` loaded from
/// `assets/fonts/` so Arabic text renders correctly on every
/// platform. Call [preLoadPdfFont] at app startup to avoid any
/// async delay on the first PDF generated.
class ReportPdfWriter {
  ReportPdfWriter();

  /// Renders [result] into a PDF byte stream.
  Future<Uint8List> buildBytes({
    required InvestigationResult result,
    SavedInvestigation? saved,
  }) async {
    return _build(result: result, saved: saved);
  }

  /// Saves the report PDF to disk.
  Future<File> saveToDisk({
    required InvestigationResult result,
    SavedInvestigation? saved,
    String? preferredDirectory,
  }) async {
    final bytes = await buildBytes(result: result, saved: saved);
    final dir = await _resolveDirectory(preferredDirectory);
    final slug = _slugify(result.title, fallback: 'investigation');
    final id =
        result.investigationId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final filename = 'kashf-$id-$slug.pdf';
    final sep = Platform.pathSeparator;
    final fullPath =
        dir.endsWith(sep) ? '$dir$filename' : '$dir$sep$filename';
    final file = File(fullPath);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Returns the deterministic file name for a report.
  Future<String> fileNameFor(
      {required InvestigationResult result}) async {
    final slug = _slugify(result.title, fallback: 'investigation');
    final id =
        result.investigationId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return 'kashf-$id-$slug.pdf';
  }

  /// Writes [bytes] to disk and returns the [File].
  Future<File> writeBytesToDisk({
    required InvestigationResult result,
    required Uint8List bytes,
    String? preferredDirectory,
  }) async {
    final dir = await _resolveDirectory(preferredDirectory);
    final filename = await fileNameFor(result: result);
    final sep = Platform.pathSeparator;
    final fullPath = dir.endsWith(sep)
        ? '$dir$filename'
        : '$dir$sep$filename';
    final file = File(fullPath);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<String> _resolveDirectory(String? preferred) async {
    if (preferred != null) {
      final d = Directory(preferred);
      try {
        await d.create(recursive: true);
        return d.path;
      } catch (_) {/* fall through */}
    }

    String? downloadDir;
    if (Platform.isAndroid) {
      downloadDir = await tryUseDir(
        '/storage/emulated/0/Download/KASHF Lite',
      );
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        downloadDir = await tryUseDir('$home/Downloads');
      }
    } else if (Platform.isWindows) {
      final winHome = Platform.environment['USERPROFILE'];
      if (winHome != null && winHome.isNotEmpty) {
        downloadDir = await tryUseDir('$winHome\\Downloads');
      }
    }
    if (downloadDir != null) return downloadDir;

    final iosHome = Platform.environment['HOME'];
    if (iosHome != null && iosHome.isNotEmpty) {
      final sandboxDir = await tryUseDir('$iosHome/Documents');
      if (sandboxDir != null) return sandboxDir;
    }

    if (Platform.isAndroid) {
      final privateDir = await tryUseDir(
        '/data/data/com.aidata.kashfLite/files',
      );
      if (privateDir != null) return privateDir;
      final privateDir2 = await tryUseDir(
        '/data/user/0/com.aidata.kashfLite/files',
      );
      if (privateDir2 != null) return privateDir2;
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      final docsDir = await tryUseDir('$home/Documents');
      if (docsDir != null) return docsDir;
    }

    final tmp = await Directory.systemTemp.createTemp('kashf_pdf_');
    return tmp.path;
  }

  static Future<String?> tryUseDir(String path) async {
    if (path.isEmpty) return null;
    final d = Directory(path);
    try {
      if (!await d.exists()) {
        await d.create(recursive: true);
      }
      final probe = File(
        '${d.path}${Platform.pathSeparator}.kashf_write_test',
      );
      await probe.writeAsBytes(const <int>[]);
      await probe.delete();
      return d.path;
    } catch (_) {
      return null;
    }
  }

  String _slugify(String text, {required String fallback}) {
    final lower = text.toLowerCase();
    final cleaned = lower.replaceAll(
      RegExp(r'[^a-z0-9\u0600-\u06FF]+'),
      '-',
    );
    final trimmed = cleaned.replaceAll(RegExp(r'^-+|-+$'), '');
    if (trimmed.isEmpty) return fallback;
    return trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed;
  }
}

// ============================================================================
// Document builder.
//
// Architecture
// ------------
// Every text widget in this file routes through [_shape] before
// reaching `pw.Text`. [_shape] drives the UAX#9 Unicode Bidirectional
// Algorithm ourselves via `bidi.logicalToVisual2` and then strips the
// chars known to crash `dart_bidi` 2.0.13 (`Normalize._compose`)
// *before* we hand the string to the library.
//
// The result is a visually-ordered, single-script string that we hand
// to `pw.Text(..., textDirection: pw.TextDirection.ltr)`. Because the
// package's bidi shaper only fires when `textDirection == rtl`, this
// bypasses the package's broken re-shaper entirely — the visual
// string we already produced is rendered glyph-for-glyph left-to-
// right, which is exactly the correct visual order on the page.
//
// Mixed Arabic + English content is handled correctly because UAX#9
// preserves EN/AN runs inside RTL paragraphs (numbers stay LTR,
// Latin words stay LTR, only the *runs* are swapped). URLs,
// `@usernames`, percentages, dates, and Latin brand names never
// become reversed because they are themselves LTR runs.
//
// Whole pages are wrapped in `pw.Directionality(textDirection: rtl,
// ...)` so layout-level direction (column main axis, row cross axis,
// alignment resolution, `Padding.resolve`, etc.) flows RTL. This is
// the only place RTL is set at the layout level — text widgets stay
// explicitly LTR because the bidi re-ordering is already baked into
// the string we pass them.
//
// Content sizing: every text-bearing container is sized by its
// intrinsic content (no fixed heights on text). `pw.MultiPage` is
// used for the body so cards flow across pages and never get sliced
// mid-content.
// ============================================================================

pw.ThemeData get _pageTheme => pw.ThemeData.withFont(
      base: _regularFont,
      bold: _boldFont,
      fontFallback: [
        ?_latinFallback,
      ],
    );

/// Returns `true` when [input] contains at least one Arabic-block
/// character. Used to decide whether a string needs bidi reordering
/// at all — pure-Latin/numeric text is passed through unchanged so
/// we don't pay the cost of running UAX#9 on it.
bool _isArabic(String input) =>
    RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-'
            r'\uFEFF]')
        .hasMatch(input);

/// Strips the input characters known to crash the `bidi` package
/// or render as garbage. Kept conservative — anything inside the
/// Arabic block, basic Latin, Latin-1 supplement, digits, and the
/// punctuation we actually emit survives; everything else becomes
/// a space so we never feed an unknown char to the bidi shaper.
String _stripForBidi(String input) {
  if (input.isEmpty) return input;
  var s = input;
  // Unpaired surrogates.
  s = s.replaceAll(RegExp(r'[\uD800-\uDBFF](?![\uDC00-\uDFFF])'), '');
  s = s.replaceAll(RegExp(r'(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]'), '');
  // Bidi control chars (LRM, RLM, embeddings, isolates, ZWJ, ZWNJ).
  s = s.replaceAll(
    RegExp('[\u200E\u200F\u202A-\u202E\u2066-\u2069\u200D\u200C]'),
    '',
  );
  // Arabic combining marks + TATWEEL + variation selectors — the
  // primary trigger of the `Normalize._compose` crash.
  s = s.replaceAll(
    RegExp(
      '[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640\uFE00-\uFE0F]',
    ),
    '',
  );
  // Whitelist every other char we expect; everything else becomes a
  // space (we keep the position so word boundaries don't collapse).
  s = s.replaceAll(
    RegExp(
      '[^'
      '\u0020-\u007E'
      '\u00A0-\u00FF'
      '\u0600-\u0603'
      '\u060C-\u060F'
      '\u0621-\u063A'
      '\u0641-\u064A'
      '\u0660-\u066D'
      '\u00B7'
      '\u2010-\u2027'
      '\u2030-\u205F'
      '\u2190-\u2193'
      ']',
    ),
    ' ',
  );
  return s;
}

/// Pre-shapes [input] for `pw.Text` with `textDirection: ltr`.
///
/// The shaping pipeline is the core of the Arabic rendering:
///
///   1. **Strip** — drop combining marks, bidi control chars, and
///      other characters that crash `bidi.logicalToVisual2` on
///      `Normalize._compose`. See [_stripForBidi] for the exact
///      set.
///
///   2. **Isolate LTR runs** — wrap URLs, `@usernames`,
///      digit-blocks (dates, percentages), and other
///      never-reverse content in Unicode LRO + PDF overrides so
///      the bidi shaper treats them as opaque LTR runs.
///
///   3. **Reshape Arabic** — run [ArabicReshaper.reshape] on the
///      isolated string. The `bidi` package (v2.0.13) only emits
///      **isolated** forms for short words — it doesn't apply
///      proper contextual shaping (initial / medial / final).
///      That makes every Arabic letter render as a standalone
///      glyph in the PDF (the `pdf` package's TTF renderer only
///      knows basic-to-isolated substitution, so it can't fix
///      this itself). `arabic_reshaper` performs the full Unicode
///      Arabic shaping algorithm — initial / medial / final /
///      isolated forms plus standard ligatures (Lam-Alef, etc.)
///      — so every Arabic letter comes out as the right
///      contextual codepoint, which `NotoSansArabic` maps to the
///      right contextual glyph.
///
///   4. **Reorder runs** — run `bidi.logicalToVisual2` on the
///      reshaped string to flip the run order so RTL paragraphs
///      read right-to-left visually. The URL / username /
///      percentage / date runs are isolated in step 2 so they
///      survive reordering intact.
///
/// `pw.Text` then receives the visual string with
/// `textDirection: ltr`; the package's bidi shaper is bypassed so
/// we never double-shape the string.
String _shape(String input) {
  final sanitized = _stripForBidi(input);
  if (!_isArabic(sanitized)) return sanitized;
  final isolated = _wrapLtrRuns(sanitized);
  // Reshape first (basic letters -> presentation forms).
  final reshaped = ArabicReshaper.instance.reshape(isolated);
  // Then reorder runs (visual order).
  try {
    final indexes = <int>[];
    final lengths = <int>[];
    return logicalToVisual2(reshaped, indexes, lengths);
  } catch (e) {
    debugPrint('[Kashf/PDFWriter] bidi shape failed: $e');
    return reshaped;
  }
}

/// Wraps runs that must stay visually LTR (URLs, `@usernames`,
/// dates, percentages, dotted / hyphenated numbers) in Unicode
/// bidi OVERRIDE pairs (`U+202D` LRO + `U+202C` PDF).
///
/// Why this matters: without isolation, UAX#9's neutral-character
/// resolution can pull neutral chars like `%`, `@`, `-`, `/` away
/// from their Latin/digit neighbours and pin them to the visual
/// edge of the surrounding RTL paragraph. The result for
/// `معدل التفاعل 3.71%` is `%3.71 …`, and for
/// `@dnashemas` is `dnashemas@ …`. Wrapping the whole LTR run in
/// LRO/PDF forces every character inside the run to resolve as
/// LTR — so the URL never gets visually reversed, and neutral
/// characters like `%` / `@` / `-` stay glued to their
/// neighbouring Latin/digit run instead of being pulled to the
/// visual edge of the RTL paragraph.
///
/// We use `String.fromCharCode` for the bidi control markers so
/// the source file stays free of the directionality-changing
/// glyphs (they would otherwise trip the analyzer's
/// text-direction lint).
String _wrapLtrRuns(String input) {
  final lro = String.fromCharCode(0x202D); // LRO — Left-to-Right Override
  final pdf = String.fromCharCode(0x202C); // PDF — Pop Directional Formatting
  // URL pattern (http / https / www prefix).
  final urlRe =
      RegExp(r'(?:https?://|www\.)[^\s\u0600-\u06FF]+', dotAll: true);
  // @username pattern. Allow common username chars (letters, digits,
  // _, ., -).
  final userRe = RegExp(r'@[A-Za-z0-9_.\-]+');
  // A contiguous run of digits + separators (-, /, :, .) and an
  // optional trailing %. Matches dates (2026-08-17), percentages
  // (3.71%), decimals (1.5), and times.
  final dateRe = RegExp(r'\d[\d\-/:.\s]*\d%?|\d+%');
  // Apply each pattern, wrapping every match in LRO/PDF. We sort
  // matches by start offset so overlapping regexes don't fight.
  final matches = <_LtrMatch>[];
  for (final re in [urlRe, userRe, dateRe]) {
    matches.addAll(re.allMatches(input).map(_LtrMatch.fromMatch));
  }
  matches.sort((a, b) => a.start.compareTo(b.start));
  // Build the output by walking the matches and splicing in the
  // LRO/PDF markers around each one.
  final buf = StringBuffer();
  var cursor = 0;
  for (final m in matches) {
    if (m.start < cursor) continue; // overlap; skip.
    buf.write(input.substring(cursor, m.start));
    buf.write(lro);
    buf.write(input.substring(m.start, m.end));
    buf.write(pdf);
    cursor = m.end;
  }
  buf.write(input.substring(cursor));
  return buf.toString();
}

class _LtrMatch {
  _LtrMatch(this.start, this.end);
  factory _LtrMatch.fromMatch(Match m) => _LtrMatch(m.start, m.end);
  final int start;
  final int end;
}

Future<Uint8List> _build({
  required InvestigationResult result,
  SavedInvestigation? saved,
}) async {
  debugPrint(
    '[Kashf/PDFWriter] start — sections=${result.sections.length}',
  );

  final doc = pw.Document(
    title: result.title,
    author: 'KASHF Lite',
    subject: 'Investigation Report',
  );

  // Cover: single page, RTL layout direction, all-text pre-shaped.
  doc.addPage(_buildCoverPage(result));

  // Body: a single MultiPage that flows every section + sources
  // through one adaptive layout. The package's `MultiPage` is the
  // canonical way to get automatic page breaks that don't slice
  // cards in half — when a card no longer fits, the whole card
  // moves to the next page. `footer` is bound to every emitted
  // page so the page-number footer tracks the actual page count.
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 56, 48, 56),
      theme: _pageTheme,
      textDirection: pw.TextDirection.rtl,
      maxPages: 200,
      footer: _pageFooter,
      build: (ctx) => _buildBody(result),
    ),
  );

  final bytes = await doc.save();
  debugPrint('[Kashf/PDFWriter] done — bytes=${bytes.length}');
  return bytes;
}

/// Body content for the MultiPage. Returns a list of widgets that
/// will flow across pages automatically. Every text widget is
/// pre-shaped via [_shape] and rendered with explicit LTR so the
/// package's bidi shaper never re-reverses the string.
List<pw.Widget> _buildBody(InvestigationResult result) {
  final widgets = <pw.Widget>[];
  widgets.add(_buildSummarySection(result));
  for (final section in result.sections) {
    if (section.items.isEmpty) continue;
    widgets.add(_buildSectionBlock(result, section));
  }
  if (result.sources.isNotEmpty) {
    widgets.add(_buildSourcesBlock(result));
  }
  return widgets;
}

// ============================================================================
// Cover page — dark hero with gold accent and confidence meter.
// ============================================================================

pw.Page _buildCoverPage(InvestigationResult result) {
  final confidence = result.confidence;
  final dateText = _formatDate(result.generatedAt);

  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    theme: _pageTheme,
    textDirection: pw.TextDirection.rtl,
    build: (ctx) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Container(
          color: _navy900,
          child: pw.Stack(
            children: [
              // Gold accent rail on the *right* edge (RTL: leading).
              pw.Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: pw.Container(
                  width: 6,
                  color: _brandGold,
                ),
              ),
              // Decorative rotated tag at top-right (visually leading
              // edge under RTL).
              pw.Positioned(
                top: 80,
                right: 40,
                child: pw.Transform.rotateBox(
                  angle: 1.5708, // 90 degrees
                  child: _latinText(
                    'KASHF · LITE',
                    style: pw.TextStyle(
                      font: _boldFont,
                      fontSize: 10,
                      color: _brandGold,
                      letterSpacing: 8,
                    ),
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(48, 80, 60, 48),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.SizedBox(height: 40),
                    // Brand row — pinned to the leading (right) edge
                    // under RTL via `mainAxisAlignment: start` resolved
                    // by Directionality.
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.start,
                      children: [
                        _brandMark(),
                        pw.SizedBox(width: 12),
                        _latinText(
                          'KASHF Lite',
                          style: pw.TextStyle(
                            font: _boldFont,
                            fontSize: 14,
                            color: _white,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    pw.Spacer(flex: 1),
                    _goldDivider(),
                    pw.SizedBox(height: 14),
                    _eyebrow('INVESTIGATION REPORT', color: _brandGoldLight),
                    pw.SizedBox(height: 18),
                    _shapedText(
                      result.title,
                      style: pw.TextStyle(
                        font: _boldFont,
                        fontSize: 36,
                        color: _white,
                        lineSpacing: 2,
                      ),
                    ),
                    pw.SizedBox(height: 14),
                    if (result.subtitle.isNotEmpty)
                      _shapedText(
                        result.subtitle,
                        style: pw.TextStyle(
                          font: _regularFont,
                          fontSize: 14,
                          color: _slate200,
                          lineSpacing: 2,
                        ),
                      ),
                    pw.Spacer(flex: 2),
                    if (confidence != null) ...[
                      _confidenceMeter(confidence),
                      pw.SizedBox(height: 28),
                    ],
                    // Metadata footer. `spaceBetween` resolves under
                    // RTL so the two chips go to the visual edges.
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 18,
                      ),
                      decoration: pw.BoxDecoration(
                        color: _navy800,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(8),
                        ),
                        border: pw.Border.all(
                          color: _navy700,
                          width: 0.5,
                        ),
                      ),
                      child: pw.Row(
                        mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                        children: [
                          _latinText(
                            'ID  ·  ${result.investigationId}',
                            style: pw.TextStyle(
                              font: _regularFont,
                              fontSize: 9,
                              color: _slate500,
                              letterSpacing: 1,
                            ),
                          ),
                          _latinText(
                            'GENERATED  ·  $dateText',
                            style: pw.TextStyle(
                              font: _regularFont,
                              fontSize: 9,
                              color: _slate500,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

pw.Widget _brandMark() {
  return pw.Container(
    width: 36,
    height: 36,
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFF4C542),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Center(
      child: _latinText(
        'K',
        style: pw.TextStyle(
          font: _boldFont,
          fontSize: 22,
          color: _navy900,
        ),
      ),
    ),
  );
}

pw.Widget _goldDivider() {
  return pw.Container(
    width: 56,
    height: 3,
    decoration: pw.BoxDecoration(
      color: _brandGold,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
    ),
  );
}

pw.Widget _eyebrow(String text, {required PdfColor color}) {
  return _latinText(
    text,
    style: pw.TextStyle(
      font: _boldFont,
      fontSize: 11,
      color: color,
      letterSpacing: 4,
    ),
  );
}

pw.Widget _confidenceMeter(double confidence) {
  final pct = (confidence * 100).round();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _eyebrow('OVERALL CONFIDENCE', color: _slate200),
          _latinText(
            '$pct%',
            style: pw.TextStyle(
              font: _boldFont,
              fontSize: 24,
              color: _brandGold,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        height: 6,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: _navy700,
          borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        // Under RTL, `centerLeft` resolves to the leading edge
        // (right), so the gold progress fill grows rightward.
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width:
                400 * confidence.clamp(0.0, 1.0).toDouble(),
            height: 6,
            decoration: pw.BoxDecoration(
              color: _brandGold,
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
          ),
        ),
      ),
    ],
  );
}

// ============================================================================
// Executive summary section. Lives inside the body's `pw.MultiPage`
// — its height is intrinsic; the package flows it onto pages
// automatically.
// ============================================================================

pw.Widget _buildSummarySection(InvestigationResult result) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _pageHeader(
        eyebrow: 'EXECUTIVE SUMMARY',
        title: 'نظرة عامة على التحقيق',
        subtitle: result.subtitle,
      ),
      pw.SizedBox(height: 24),
      // Three stat cards in a row. `pw.Wrap` lets the cards re-flow
      // on narrow pages; the row itself is sized by content.
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _statCard(
              value: '${result.sections.length}',
              label: 'الأقسام',
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: _statCard(
              value:
                  '${result.sections.fold<int>(0, (sum, s) => sum + s.items.length)}',
              label: 'النتائج',
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: _statCard(
              value: '${result.sources.length}',
              label: 'المصادر',
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 24),
      // Contents card. Auto-grows vertically per row; rows are
      // shaped so the gold number badge sits on the right (leading)
      // edge under RTL and the Arabic headline flows from it.
      pw.Container(
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: _slate100,
          borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(10)),
          border: pw.Border.all(color: _slate200, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _shapedText(
              'المحتويات',
              style: pw.TextStyle(
                font: _boldFont,
                fontSize: 13,
                color: _navy800,
                letterSpacing: 2,
              ),
            ),
            pw.SizedBox(height: 10),
            ...result.sections.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final s = entry.value;
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 26,
                      height: 26,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        color: _brandGold,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(13),
                        ),
                      ),
                      child: _latinText(
                        '$i',
                        style: pw.TextStyle(
                          font: _boldFont,
                          fontSize: 11,
                          color: _navy900,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: _shapedText(
                        s.headline.isNotEmpty
                            ? s.headline
                            : s.kind.l10nKey,
                        style: pw.TextStyle(
                          font: _boldFont,
                          fontSize: 12,
                          color: _navy800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      pw.SizedBox(height: 32),
    ],
  );
}

pw.Widget _statCard({required String value, required String label}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    decoration: pw.BoxDecoration(
      color: _navy900,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _latinText(
          value,
          style: pw.TextStyle(
            font: _boldFont,
            fontSize: 32,
            color: _brandGold,
          ),
        ),
        pw.SizedBox(height: 4),
        _shapedText(
          label,
          style: pw.TextStyle(
            font: _regularFont,
            fontSize: 11,
            color: _slate200,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  );
}

// ============================================================================
// Per-section block. Returns a `pw.Widget` that flows inside the
// body's `pw.MultiPage`. Items are rendered as `KeepTogether`
// cards so a single item is never split across pages — if the
// card no longer fits on the current page, `MultiPage` moves
// the whole card to the next page.
// ============================================================================

pw.Widget _buildSectionBlock(
  InvestigationResult result,
  InvestigationResultSection section,
) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _pageHeader(
        eyebrow: section.kind.l10nKey.toUpperCase(),
        title: section.headline,
        subtitle: section.summary,
      ),
      pw.SizedBox(height: 20),
      ...section.items.map(
        (item) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Inseparable(child: _itemCard(item)),
        ),
      ),
      pw.SizedBox(height: 24),
    ],
  );
}

pw.Widget _itemCard(InvestigationResultItem item) {
  // The card auto-grows vertically based on its content. We don't
  // set a fixed height — text wraps and pushes the card taller.
  return pw.Container(
    padding: const pw.EdgeInsets.all(18),
    decoration: pw.BoxDecoration(
      color: _white,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      border: pw.Border.all(color: _slate200, width: 0.6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Title row: Arabic title on the right (leading), metric
        // badge pinned to the trailing edge (left) under RTL. The
        // row's textDirection resolves the `Row` children order.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _shapedText(
                item.title,
                style: pw.TextStyle(
                  font: _boldFont,
                  fontSize: 14,
                  color: _navy900,
                  lineSpacing: 2,
                ),
              ),
            ),
            if (item.metric != null) pw.SizedBox(width: 12),
            if (item.metric != null) _metricBadge(item),
          ],
        ),
        if (item.badge != null && item.badge!.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: _badge(item.badge!),
          ),
        ],
        if (item.body.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _shapedText(
            item.body,
            style: pw.TextStyle(
              font: _regularFont,
              fontSize: 11,
              color: PdfColor.fromInt(0xFF1F2937),
              lineSpacing: 4,
            ),
          ),
        ],
        if (item.links.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          ...item.links.map((link) => _linkRow(link)),
        ],
      ],
    ),
  );
}

pw.Widget _metricBadge(InvestigationResultItem item) {
  final pct = item.metric!.contains('%')
      ? item.metric
      : null;
  final isPositive = item.metric!.startsWith('+') ||
      pct != null ||
      (double.tryParse(item.metric!.replaceAll('%', '')) ?? 0) > 0;
  final color = isPositive ? _green600 : _red600;
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFF1F5F9),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(color: color, width: 1),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _latinText(
          item.metric!,
          style: pw.TextStyle(
            font: _boldFont,
            fontSize: 14,
            color: color,
          ),
        ),
        if (item.metricLabel != null) ...[
          pw.SizedBox(height: 2),
          _shapedText(
            item.metricLabel!,
            style: pw.TextStyle(
              font: _regularFont,
              fontSize: 8,
              color: _slate600,
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    ),
  );
}

pw.Widget _badge(String text) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: pw.BoxDecoration(
      color: _brandGoldLight,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: _shapedText(
      text,
      style: pw.TextStyle(
        font: _boldFont,
        fontSize: 8,
        color: _brandGoldDeep,
        letterSpacing: 1.5,
      ),
    ),
  );
}

/// One link inside an item card.
///
/// UAX#9 keeps the URL glyphs in their original LTR order inside an
/// otherwise-RTL paragraph, so the URL always reads left-to-right as
/// written — even when the surrounding text is Arabic. We pre-shape
/// each run independently:
///   * the bold "Label:" run goes through [_shape] so an Arabic label
///     is correctly visually ordered;
///   * the URL is wrapped in an LTR-isolated span (Unicode LRI +
///     PDI) so the bidi algorithm treats it as an opaque LTR run
///     regardless of what surrounding paragraphs do.
pw.Widget _linkRow(InvestigationResultLink link) {
  // Wrap the URL in Unicode bidi isolates so it stays LTR even if
  // the bidi shaper is later called by another renderer / viewer.
  // We use String.fromCharCode for the isolate markers (U+2066 LRI
  // and U+2069 PDI) so the source code stays readable without
  // embedding directionality-changing characters that would trip
  // the analyzer's text-direction lint.
  final lri = String.fromCharCode(0x2066);
  final pdi = String.fromCharCode(0x2069);
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 6, left: 8),
          width: 6,
          height: 6,
          decoration: pw.BoxDecoration(
            color: _brandGold,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
        ),
        pw.Expanded(
          child: _richTextRuns(
            label: '${link.label}: ',
            url: '$lri${link.url}$pdi',
            labelStyle: pw.TextStyle(
              font: _boldFont,
              fontSize: 10,
              color: _navy800,
            ),
            urlStyle: pw.TextStyle(
              font: _regularFont,
              fontSize: 10,
              color: _slate600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Two-run RichText helper. The label is pre-shaped (so an Arabic
/// label renders correctly), the URL is wrapped in Unicode LRI/PDI
/// isolates AND additionally enclosed in a dedicated span with
/// `pw.TextDirection.ltr` so the package's renderer keeps the URL
/// glyphs in their original order.
pw.Widget _richTextRuns({
  required String label,
  required String url,
  required pw.TextStyle labelStyle,
  required pw.TextStyle urlStyle,
}) {
  // Label is pre-shaped Arabic (already visual-ordered, no RTL
  // shaper needs to run). URL is left untouched so its characters
  // appear exactly as written. We hand each to `pw.Text` with
  // explicit LTR direction so the package's bidi shaper never
  // reverses anything we've already arranged.
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Text(
          _shape(label),
          style: labelStyle,
          softWrap: true,
          textDirection: pw.TextDirection.ltr,
        ),
      ),
      pw.SizedBox(width: 4),
      pw.Text(
        url,
        style: urlStyle,
        softWrap: true,
        textDirection: pw.TextDirection.ltr,
      ),
    ],
  );
}

// ============================================================================
// Sources appendix. Flows inside the body's `pw.MultiPage`; each
// source is wrapped in `pw.KeepTogether` so a single card can't be
// split across pages.
// ============================================================================

pw.Widget _buildSourcesBlock(InvestigationResult result) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _pageHeader(
        eyebrow: 'APPENDIX',
        title: 'المصادر',
        subtitle: 'قائمة المصادر والمراجع التي استند إليها التحقيق.',
      ),
      pw.SizedBox(height: 20),
      ...result.sources.asMap().entries.map(
        (entry) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Inseparable(
            child: _sourceCard(entry.key + 1, entry.value),
          ),
        ),
      ),
    ],
  );
}

pw.Widget _sourceCard(int index, InvestigationSource src) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: _slate100,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(color: _slate200, width: 0.5),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Index badge sits on the leading (right) edge under RTL.
        pw.Container(
          width: 24,
          height: 24,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: _navy800,
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(12)),
          ),
          child: _latinText(
            '$index',
            style: pw.TextStyle(
              font: _boldFont,
              fontSize: 10,
              color: _brandGold,
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _shapedText(
                src.title,
                style: pw.TextStyle(
                  font: _boldFont,
                  fontSize: 12,
                  color: _navy900,
                ),
              ),
              if (src.subtitle.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                _shapedText(
                  src.subtitle,
                  style: pw.TextStyle(
                    font: _regularFont,
                    fontSize: 10,
                    color: _slate600,
                  ),
                ),
              ],
              if (src.url != null && src.url!.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                // URL: wrapped in Unicode LRI/PDI isolates and
                // rendered with explicit LTR direction so it never
                // gets reordered by the bidi algorithm.
                _latinUrl(src.url!),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Renders a URL as an isolated LTR run: Unicode LRI + URL + PDI,
/// with explicit LTR textDirection on the text widget. The LRI/PDI
/// isolates make the URL an opaque LTR run even when the document
/// directionality is RTL — every PDF viewer / renderer that
/// implements UAX#9 will keep the URL glyphs in their original
/// order.
pw.Widget _latinUrl(String url) {
  // Wrap the URL in Unicode bidi isolates (U+2066 LRI, U+2069 PDI)
  // so the URL renders as an isolated LTR run inside the RTL page.
  return pw.Text(
    '${String.fromCharCode(0x2066)}$url${String.fromCharCode(0x2069)}',
    style: pw.TextStyle(
      font: _regularFont,
      fontSize: 9,
      color: _slate600,
    ),
    textDirection: pw.TextDirection.ltr,
  );
}

// ============================================================================
// Shared header / footer primitives.
// ============================================================================

pw.Widget _pageHeader({
  required String eyebrow,
  required String title,
  String? subtitle,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: _goldDivider(),
      ),
      pw.SizedBox(height: 12),
      _eyebrow(eyebrow, color: _brandGoldDeep),
      pw.SizedBox(height: 8),
      _shapedText(
        title,
        style: pw.TextStyle(
          font: _boldFont,
          fontSize: 22,
          color: _navy900,
          lineSpacing: 2,
        ),
      ),
      if (subtitle != null && subtitle.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        _shapedText(
          subtitle,
          style: pw.TextStyle(
            font: _regularFont,
            fontSize: 11,
            color: _slate600,
            lineSpacing: 3,
          ),
        ),
      ],
    ],
  );
}

/// Page footer rendered by `pw.MultiPage`. The package calls
/// this for every page in the body so each footer is bound to
/// its page automatically.
pw.Widget _pageFooter(pw.Context ctx) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      _latinText(
        'KASHF Lite  ·  Investigation Report',
        style: pw.TextStyle(
          font: _regularFont,
          fontSize: 8,
          color: _slate500,
          letterSpacing: 1,
        ),
      ),
      _latinText(
        '${ctx.pageNumber} / ${ctx.pagesCount}',
        style: pw.TextStyle(
          font: _boldFont,
          fontSize: 8,
          color: _brandGold,
        ),
      ),
    ],
  );
}

// ============================================================================
// Text primitives — every text widget goes through one of these.
//
//   * [_shapedText] for mixed Arabic + Latin content. Pre-shapes
//     the string with UAX#9 so we get correct visual order without
//     asking the `pdf` package's internal shaper to do it (which
//     produces the reversed English / disconnected Arabic bugs).
//   * [_latinText] for pure-Latin / numeric content. Skips the
//     bidi call entirely (no cost, no risk).
//
// All three return a `pw.Text` with `textDirection: ltr` so the
// package's bidi shaper is bypassed entirely.
// ============================================================================

pw.Widget _shapedText(
  String text, {
  required pw.TextStyle style,
}) {
  // The string we hand to `pw.Text` has already been bidi-shaped
  // by us via `bidi.logicalToVisual2` — Arabic letters are in
  // their presentation forms (U+FE70..U+FEFF), runs are in their
  // final visual order. We pin `textDirection: ltr` so the
  // package's bidi shaper never re-runs (which would reverse the
  // Latin runs we already placed). The font's OpenType GSUB
  // tables pick the right contextual form (initial / medial /
  // final / isolated) for each presentation-form glyph, so the
  // Arabic letters render connected without the package
  // re-shaping them.
  return pw.Text(
    _shape(text),
    style: style,
    softWrap: true,
    textDirection: pw.TextDirection.ltr,
  );
}

pw.Widget _latinText(
  String text, {
  required pw.TextStyle style,
}) {
  final sanitized = _stripForBidi(text);
  // If the text happens to contain Arabic letters (the metric
  // badge label can be an Arabic phrase like "تراجع"), we route
  // it through the shaping pipeline so the letters come back as
  // presentation forms (U+FE70..) and connect properly under the
  // NotoSansArabic font. Pure-Latin / numeric text (the common
  // case for ID, dates, percentages, page numbers) takes the
  // fast LTR path.
  if (_isArabic(sanitized)) {
    return _shapedText(text, style: style);
  }
  return pw.Text(
    sanitized,
    style: style,
    softWrap: true,
    textDirection: pw.TextDirection.ltr,
  );
}

// ============================================================================
// Date formatting helper.
// ============================================================================

String _formatDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}
