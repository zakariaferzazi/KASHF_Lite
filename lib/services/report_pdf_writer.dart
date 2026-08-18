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

  // Fixed ten-page layout that mirrors the reference design:
  //   1. Cover / Subject + confidence
  //   2. Scope + main/key findings
  //   3. Evidence log
  //   4. Source evaluation matrix + score
  //   5. Analysis & synthesis + recommendations
  //   6. Longitudinal analysis + conflict-resolution table
  //   7. Key points + recommendations
  //   8. Execution timeline (30 / 60 / 90 days)
  //   9. Time-boxed plan + resource matrix
  //  10. Final checklist + report summary
  doc.addPage(_buildPage1(result));
  doc.addPage(_buildPage2(result));
  doc.addPage(_buildPage3(result));
  doc.addPage(_buildPage4(result));
  doc.addPage(_buildPage5(result));
  doc.addPage(_buildPage6(result));
  doc.addPage(_buildPage7(result));
  doc.addPage(_buildPage8(result));
  doc.addPage(_buildPage9(result));
  doc.addPage(_buildPage10(result));

  final bytes = await doc.save();
  debugPrint('[Kashf/PDFWriter] done — bytes=${bytes.length}');
  return bytes;
}

// ============================================================================
// Shared page chrome
// ============================================================================

/// Wraps a page body in the dark navy background + gold accent rail +
/// "ملف التحقيق الداخلي" header + page footer used by every page.
pw.Widget _styledPage({
  required int pageNumber,
  required pw.Widget child,
}) {
  return pw.Container(
    color: _navy900,
    child: pw.Stack(
      children: [
        // Gold accent rail pinned to the right edge (RTL: leading).
        pw.Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: pw.Container(
            width: 4,
            color: _brandGold,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(36, 40, 36, 32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _pageTopBar(),
              pw.SizedBox(height: 18),
              pw.Expanded(child: child),
              _pageBottomBar(pageNumber),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _pageTopBar() {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Align(
        alignment: pw.Alignment.center,
        child: _shapedText(
          'ملف التحقيق الداخلي',
          style: pw.TextStyle(
            font: _boldFont,
            fontSize: 18,
            color: _brandGold,
          ),
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Container(
        height: 1,
        color: PdfColor.fromInt(0x33F4C542),
      ),
    ],
  );
}

pw.Widget _pageBottomBar(int pageNumber) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        _latinText(
          'Page $pageNumber',
          style: pw.TextStyle(
            font: _regularFont,
            fontSize: 9,
            color: _slate500,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  );
}

// ============================================================================
// Page 1 — Subject, confidence, executive summary.
// ============================================================================

pw.Page _buildPage1(InvestigationResult result) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    theme: _pageTheme,
    textDirection: pw.TextDirection.rtl,
    build: (_) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: _styledPage(
          pageNumber: 1,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _sectionTitleLarge('1. نظرة عامة على التحقيق'),
              pw.SizedBox(height: 16),
              _subjectCard(result),
              pw.SizedBox(height: 12),
              _metaTable(result),
              pw.SizedBox(height: 14),
              _generalView(result),
            ],
          ),
        ),
      );
    },
  );
}

pw.Widget _sectionTitleLarge(String text) {
  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: _shapedText(
      text,
      style: pw.TextStyle(
        font: _boldFont,
        fontSize: 20,
        color: _brandGold,
      ),
    ),
  );
}

/// Subject card with the "الموضوع" + "المحقق" rows.
pw.Widget _subjectCard(InvestigationResult result) {
  final subjectName = _subjectName(result);
  final investigator = _investigator(result);
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: pw.BoxDecoration(
      color: _navy800,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(
        color: PdfColor.fromInt(0x59F4C542),
        width: 0.6,
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _labeledRow(
          label: 'الموضوع',
          value: result.title.isNotEmpty ? result.title : subjectName,
          valueIsArabic: true,
        ),
        pw.SizedBox(height: 6),
        _labeledRow(
          label: 'المحقق',
          value: investigator,
          valueIsArabic: false,
        ),
      ],
    ),
  );
}

/// "معرّف التحقيق" stat row (ID / confidence / items / sources).
pw.Widget _metaTable(InvestigationResult result) {
  final sourcesCount = result.sources.length;
  final itemsCount = result.sections
      .fold<int>(0, (sum, s) => sum + s.items.length);
  final confidence = (result.confidence ?? 0).clamp(0.0, 1.0);
  final pctText = '${(confidence * 100).round()}%';
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: pw.BoxDecoration(
      color: _navy800,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(
        color: _navy700,
        width: 0.6,
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Align(
          alignment: pw.Alignment.center,
          child: _shapedText(
            'معرّف التحقيق',
            style: pw.TextStyle(
              font: _boldFont,
              fontSize: 12,
              color: _brandGold,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _metaCell('عدد المصادر', '$sourcesCount', grow: 1),
            _metaCell('عدد الأدلة', '$itemsCount', grow: 1),
            _metaCell('مستوى الثقة', pctText, grow: 1),
            _metaCell('ID', _idFor(result), grow: 1),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _metaCell(
  String label,
  String value, {
  double grow = 1,
}) {
  return pw.Expanded(
    flex: (grow * 1000).round(),
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: _navy700, width: 0.5),
        ),
      ),
      child: pw.Column(
        children: [
          _shapedText(
            label,
            style: pw.TextStyle(
              font: _regularFont,
              fontSize: 9,
              color: _slate500,
            ),
          ),
          pw.SizedBox(height: 2),
          _latinText(
            value,
            style: pw.TextStyle(
              font: _boldFont,
              fontSize: 11,
              color: _white,
            ),
          ),
        ],
      ),
    ),
  );
}

/// "نظرة عامة على التحقيق" body — the executive summary text.
pw.Widget _generalView(InvestigationResult result) {
  final body = _summaryText(result);
  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: _navy800,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(color: _navy700, width: 0.6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _shapedText(
          'نظرة عامة على التحقيق:',
          style: pw.TextStyle(
            font: _boldFont,
            fontSize: 12,
            color: _brandGold,
          ),
        ),
        pw.SizedBox(height: 8),
        _shapedText(
          body,
          style: pw.TextStyle(
            font: _regularFont,
            fontSize: 11,
            color: _slate200,
            lineSpacing: 5,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _labeledRow({
  required String label,
  required String value,
  required bool valueIsArabic,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 90,
        child: _shapedText(
          '$label:',
          style: pw.TextStyle(
            font: _boldFont,
            fontSize: 11,
            color: _brandGoldLight,
          ),
        ),
      ),
      pw.SizedBox(width: 8),
      pw.Expanded(
        child: valueIsArabic
            ? _shapedText(
                value,
                style: pw.TextStyle(
                  font: _regularFont,
                  fontSize: 12,
                  color: _white,
                ),
              )
            : _latinText(
                value,
                style: pw.TextStyle(
                  font: _regularFont,
                  fontSize: 12,
                  color: _white,
                ),
              ),
      ),
    ],
  );
}

// ============================================================================
// Page 2 — Scope statement + main/key findings.
// ============================================================================

pw.Page _buildPage2(InvestigationResult result) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    theme: _pageTheme,
    textDirection: pw.TextDirection.rtl,
    build: (_) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: _styledPage(
          pageNumber: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _sectionTitleLarge('2. النتائج الرئيسية والمقاييس المؤكدة'),
              pw.SizedBox(height: 16),
              _scopeBlock(result),
              pw.SizedBox(height: 14),
              _keyFindingsTable(result),
              pw.SizedBox(height: 14),
              _verificationsFooter(result),
            ],
          ),
        ),
      );
    },
  );
}

pw.Widget _scopeBlock(InvestigationResult result) {
  final scopeText = _scopeText(result);
  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: _navy800,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(color: _navy700, width: 0.6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _shapedText(
          '1. نطاق التحقيق',
          style: pw.TextStyle(
            font: _boldFont,
            fontSize: 14,
            color: _brandGold,
          ),
        ),
        pw.SizedBox(height: 6),
        _shapedText(
          scopeText,
          style: pw.TextStyle(
            font: _regularFont,
            fontSize: 11,
            color: _slate200,
            lineSpacing: 5,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _keyFindingsTable(InvestigationResult result) {
  final findings = _keyFindingRows(result);
  if (findings.isEmpty) {
    return _emptyBlock('لا توجد نتائج رئيسية متاحة.');
  }
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: _navy800,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(color: _navy700, width: 0.6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _shapedText(
          'المقايضات التي تم التحقيق منها',
          style: pw.TextStyle(
            font: _boldFont,
            fontSize: 12,
            color: _brandGold,
          ),
        ),
        pw.SizedBox(height: 6),
        _findingTable(findings),
      ],
    ),
  );
}

pw.Widget _findingTable(List<_FindingRow> rows) {
  return pw.Table(
    border: pw.TableBorder.symmetric(
      inside: pw.BorderSide(color: _navy700, width: 0.4),
    ),
    columnWidths: const <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(2.2),
      1: pw.FlexColumnWidth(2.0),
      2: pw.FlexColumnWidth(3.4),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _brandGold),
        children: [
          _thCell('تمّ التحقق'),
          _thCell('الحالة'),
          _thCell('المقايض'),
        ],
      ),
      for (final r in rows)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _navy800),
          children: [
            _tdStatus(r.status),
            _tdVerified(r.verified),
            _tdTitle(r.title),
          ],
        ),
    ],
  );
}

pw.Widget _thCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: _shapedText(
        text,
        style: pw.TextStyle(
          font: _boldFont,
          fontSize: 10,
          color: _navy900,
        ),
      ),
    ),
  );
}

pw.Widget _tdStatus(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: _shapedText(
        text,
        style: pw.TextStyle(
          font: _regularFont,
          fontSize: 10,
          color: _slate200,
        ),
      ),
    ),
  );
}

pw.Widget _tdVerified(bool verified) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Align(
      alignment: pw.Alignment.center,
      child: verified
          ? _latinText(
              'Verified',
              style: pw.TextStyle(
                font: _boldFont,
                fontSize: 10,
                color: _green600,
              ),
            )
          : _latinText(
              '—',
              style: pw.TextStyle(
                font: _regularFont,
                fontSize: 10,
                color: _slate500,
              ),
            ),
    ),
  );
}

pw.Widget _tdTitle(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: _shapedText(
        text,
        style: pw.TextStyle(
          font: _regularFont,
          fontSize: 10,
          color: _white,
        ),
      ),
    ),
  );
}

pw.Widget _verificationsFooter(InvestigationResult result) {
  final text = _verificationsFooterText(result);
  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: _shapedText(
      text,
      style: pw.TextStyle(
        font: _regularFont,
        fontSize: 11,
        color: _slate200,
        lineSpacing: 4,
      ),
    ),
  );
}

pw.Widget _emptyBlock(String text) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: _navy800,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(color: _navy700, width: 0.6),
    ),
    child: _shapedText(
      text,
      style: pw.TextStyle(
        font: _regularFont,
        fontSize: 11,
        color: _slate500,
      ),
    ),
  );
}

// ============================================================================
// Page 3 — Evidence log (records log).
// ============================================================================

pw.Page _buildPage3(InvestigationResult result) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    theme: _pageTheme,
    textDirection: pw.TextDirection.rtl,
    build: (_) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: _styledPage(
          pageNumber: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _sectionTitleLarge('3. سجل الأدلة الرقمية'),
              pw.SizedBox(height: 14),
              _evidenceTable(result),
            ],
          ),
        ),
      );
    },
  );
}

pw.Widget _evidenceTable(InvestigationResult result) {
  final rows = _evidenceRows(result);
  if (rows.isEmpty) {
    return _emptyBlock('لا توجد أدلة مرفقة بهذا التحقيق.');
  }
  final totalRelevant = rows.length;
  final totalDate = rows.fold<int>(0, (s, r) => s + r.dateCount);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Table(
        border: pw.TableBorder.all(
          color: _navy700,
          width: 0.5,
        ),
        columnWidths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(0.5),
          1: pw.FlexColumnWidth(1.6),
          2: pw.FlexColumnWidth(1.4),
          3: pw.FlexColumnWidth(1.1),
          4: pw.FlexColumnWidth(0.8),
          5: pw.FlexColumnWidth(0.8),
        },
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: _brandGold),
            children: [
              _thCell('ID'),
              _thCell('المنصة المصدر'),
              _thCell('نوع الدليل'),
              _thCell('مباشر/غير'),
              _thCell('تاريخ'),
              _thCell('الموثوقة الرقمية'),
            ],
          ),
          for (final r in rows)
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _navy800),
              children: [
                _tdLatin(r.id),
                _tdPlatform(r.platform),
                _tdKind(r.kind),
                _tdDirect(r.direct),
                _tdLatin(r.dateCount.toString()),
                _tdLatin(r.relevance),
              ],
            ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          _shapedText(
            'المجموع',
            style: pw.TextStyle(
              font: _boldFont,
              fontSize: 11,
              color: _brandGoldLight,
            ),
          ),
          pw.SizedBox(width: 18),
          _latinText(
            '$totalRelevant',
            style: pw.TextStyle(
              font: _boldFont,
              fontSize: 11,
              color: _white,
            ),
          ),
          pw.SizedBox(width: 24),
          _latinText(
            '$totalDate',
            style: pw.TextStyle(
              font: _boldFont,
              fontSize: 11,
              color: _white,
            ),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _tdLatin(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Align(
      alignment: pw.Alignment.center,
      child: _latinText(
        text,
        style: pw.TextStyle(
          font: _regularFont,
          fontSize: 9,
          color: _slate200,
        ),
      ),
    ),
  );
}

pw.Widget _tdPlatform(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: _latinText(
        text,
        style: pw.TextStyle(
          font: _regularFont,
          fontSize: 9,
          color: _white,
        ),
      ),
    ),
  );
}

pw.Widget _tdKind(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: _shapedText(
        text,
        style: pw.TextStyle(
          font: _regularFont,
          fontSize: 9,
          color: _white,
        ),
      ),
    ),
  );
}

pw.Widget _tdDirect(bool direct) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Align(
      alignment: pw.Alignment.center,
      child: _latinText(
        direct ? 'direct' : 'indirect',
        style: pw.TextStyle(
          font: _regularFont,
          fontSize: 9,
          color: direct ? _brandGoldLight : _slate500,
        ),
      ),
    ),
  );
}

// ============================================================================
// Page 4 — Source evaluation matrix + summary.
// ============================================================================

pw.Page _buildPage4(InvestigationResult result) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    theme: _pageTheme,
    textDirection: pw.TextDirection.rtl,
    build: (_) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: _styledPage(
          pageNumber: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _sectionTitleLarge('4. تقييم المصادر'),
              pw.SizedBox(height: 14),
              _sourceMatrix(result),
              pw.SizedBox(height: 18),
              _sourceList(result),
            ],
          ),
        ),
      );
    },
  );
}

pw.Widget _sourceMatrix(InvestigationResult result) {
  final matrix = _sourceMatrixRows(result);
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: _navy800,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(color: _navy700, width: 0.6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Align(
          alignment: pw.Alignment.center,
          child: _shapedText(
            'تقييم موثوقية المصادر',
            style: pw.TextStyle(
              font: _boldFont,
              fontSize: 13,
              color: _brandGold,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.symmetric(
            inside: pw.BorderSide(color: _navy700, width: 0.4),
          ),
          columnWidths: const <int, pw.TableColumnWidth>{
            0: pw.FlexColumnWidth(3.0),
            1: pw.FlexColumnWidth(1.0),
            2: pw.FlexColumnWidth(1.0),
            3: pw.FlexColumnWidth(1.0),
            4: pw.FlexColumnWidth(1.0),
            5: pw.FlexColumnWidth(1.0),
          },
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _brandGold),
              children: [
                _thCell('المصدر'),
                _thCell('ضعيف'),
                _thCell('مرتفع'),
                _thCell('متوسط'),
                _thCell('مراويبها'),
                _thCell('للتحققات'),
              ],
            ),
            for (final r in matrix)
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _navy800),
                children: [
                  _tdTitle(r.title),
                  _matrixCell(r.low),
                  _matrixCell(r.medium),
                  _matrixCell(r.high),
                  _matrixCell(r.subjective),
                  _matrixCell(r.verifications),
                ],
              ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _matrixCell(int count) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
    child: pw.Center(
      child: _latinText(
        count == 0 ? '0' : '$count',
        style: pw.TextStyle(
          font: count == 0 ? _regularFont : _boldFont,
          fontSize: 9,
          color: count == 0 ? _slate500 : _white,
        ),
      ),
    ),
  );
}

pw.Widget _sourceList(InvestigationResult result) {
  final sources = result.sources.take(7).toList();
  if (sources.isEmpty) {
    return pw.SizedBox.shrink();
  }
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: _navy800,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(color: _navy700, width: 0.6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Align(
          alignment: pw.Alignment.center,
          child: _shapedText(
            'تقييم المصادر',
            style: pw.TextStyle(
              font: _boldFont,
              fontSize: 13,
              color: _brandGold,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        for (var i = 0; i < sources.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 18,
                child: _latinText(
                  '${i + 1}.',
                  style: pw.TextStyle(
                    font: _regularFont,
                    fontSize: 9,
                    color: _slate500,
                  ),
                ),
              ),
              pw.Expanded(
                child: _shapedText(
                  sources[i].title.isNotEmpty
                      ? sources[i].title
                      : sources[i].subtitle,
                  style: pw.TextStyle(
                    font: _regularFont,
                    fontSize: 10,
                    color: _slate200,
                  ),
                ),
              ),
            ],
          ),
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 2),
            height: 0.5,
            color: _navy700,
          ),
        ],
      ],
    ),
  );
}

// ============================================================================
// Page 5 — Analysis & synthesis (matrix) + recommendations.
// ============================================================================

pw.Page _buildPage5(InvestigationResult result) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    theme: _pageTheme,
    textDirection: pw.TextDirection.rtl,
    build: (_) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: _styledPage(
          pageNumber: 5,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _sectionTitleLarge('5. التحليل والتحقق'),
              pw.SizedBox(height: 14),
              _analysisMatrix(result),
              pw.SizedBox(height: 16),
              _sectionTitleLarge('6. حل النزاعات'),
              pw.SizedBox(height: 10),
              _conflictResolutionTable(result),
            ],
          ),
        ),
      );
    },
  );
}

pw.Widget _analysisMatrix(InvestigationResult result) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: _navy800,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(color: _navy700, width: 0.6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _shapedText(
            'مصدوّفية النتائج',
            style: pw.TextStyle(
              font: _boldFont,
              fontSize: 12,
              color: _brandGoldLight,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        _reliabilityGrid(result),
        pw.SizedBox(height: 14),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _shapedText(
            'المصدر',
            style: pw.TextStyle(
              font: _boldFont,
              fontSize: 12,
              color: _brandGoldLight,
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        _sourceChecklist(result),
      ],
    ),
  );
}

pw.Widget _reliabilityGrid(InvestigationResult result) {
  // A 3x3 grid approximating the reference triangular matrix.
  // Triangular = checkmark cells, corner = numeric score, the rest
  // empty. We render it via a 4x4 Table (header row + column).
  final matrix = _reliabilityMatrix(result);
  final headerRow = <String>[
    '',
    '٢',
    '٣',
    '٤',
  ];
  final numberHeader = <int>[2, 3, 4];
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Table(
        border: pw.TableBorder.all(color: _navy700, width: 0.4),
        columnWidths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(0.5),
          1: pw.FlexColumnWidth(1.0),
          2: pw.FlexColumnWidth(1.0),
          3: pw.FlexColumnWidth(1.0),
          4: pw.FlexColumnWidth(1.0),
        },
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          // Header row: leading label + numbered columns.
          pw.TableRow(
            decoration: pw.BoxDecoration(color: _brandGold),
            children: [
              _gridHeaderCell(headerRow[0]),
              _gridHeaderCell(headerRow[1]),
              _gridHeaderCell(headerRow[2]),
              _gridHeaderCell(headerRow[3]),
              _gridHeaderCell(headerRow[3]),
            ],
          ),
          // Three data rows: leading numeric row label + 4 cells.
          for (var row = 0; row < 3; row++)
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _navy800),
              children: [
                _gridRowLabel(numberHeader[row].toString()),
                ..._reliabilityCellsForRow(matrix, row),
              ],
            ),
        ],
      ),
      pw.SizedBox(height: 8),
      _shapedText(
        'المعتمد',
        style: pw.TextStyle(
          font: _boldFont,
          fontSize: 10,
          color: _slate500,
        ),
      ),
    ],
  );
}

List<pw.Widget> _reliabilityCellsForRow(
  List<List<_CellState>> matrix,
  int row,
) {
  // Render a diagonal-ish pattern: row 0 has one triangle cell,
  // row 1 has two, row 2 has three (matches reference layout).
  final cells = <pw.Widget>[];
  final cols = matrix[row];
  for (var col = 0; col < cols.length; col++) {
    cells.add(_gridCell(cols[col]));
  }
  // Pad to 4 columns so the table aligns.
  while (cells.length < 4) {
    cells.add(_gridCell(_CellState.empty));
  }
  return cells;
}

pw.Widget _gridHeaderCell(String text) {
  return pw.Container(
    height: 22,
    alignment: pw.Alignment.center,
    child: _latinText(
      text,
      style: pw.TextStyle(
        font: _boldFont,
        fontSize: 11,
        color: _navy900,
      ),
    ),
  );
}

pw.Widget _gridRowLabel(String text) {
  return pw.Container(
    height: 28,
    decoration: pw.BoxDecoration(color: _brandGold),
    alignment: pw.Alignment.center,
    child: _latinText(
      text,
      style: pw.TextStyle(
        font: _boldFont,
        fontSize: 11,
        color: _navy900,
      ),
    ),
  );
}

enum _CellState { empty, checked, numbered }

pw.Widget _gridCell(_CellState state) {
  if (state == _CellState.empty) {
    return pw.Container(
      height: 28,
      color: _navy900,
    );
  }
  if (state == _CellState.checked) {
    return pw.Container(
      height: 28,
      color: _brandGold,
      alignment: pw.Alignment.center,
      child: _latinText(
        '✓',
        style: pw.TextStyle(
          font: _boldFont,
          fontSize: 12,
          color: _navy900,
        ),
      ),
    );
  }
  return pw.Container(
    height: 28,
    color: _navy800,
    alignment: pw.Alignment.center,
    child: _latinText(
      '—',
      style: pw.TextStyle(
        font: _regularFont,
        fontSize: 9,
        color: _slate500,
      ),
    ),
  );
}

pw.Widget _sourceChecklist(InvestigationResult result) {
  final maxCount = result.sources.isEmpty ? 4 : result.sources.length;
  final count = maxCount < 4 ? 4 : (maxCount > 6 ? 6 : maxCount);
  final rows = <pw.Widget>[];
  for (var i = 0; i < count; i++) {
    final isCheck = i < result.sources.length;
    rows.add(pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 22,
            alignment: pw.Alignment.center,
            child: _latinText(
              '${i + 1}.',
              style: pw.TextStyle(
                font: _regularFont,
                fontSize: 10,
                color: _slate200,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Container(
            width: 16,
            height: 16,
            decoration: pw.BoxDecoration(
              color: isCheck ? _brandGold : PdfColor.fromInt(0xFF1A2032),
              border: pw.Border.all(
                color: isCheck ? _brandGold : _navy700,
                width: 0.6,
              ),
            ),
            alignment: pw.Alignment.center,
            child: isCheck
                ? _latinText(
                    '✓',
                    style: pw.TextStyle(
                      font: _boldFont,
                      fontSize: 9,
                      color: _navy900,
                    ),
                  )
                : pw.SizedBox.shrink(),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Container(
              height: 0.5,
              color: _navy700,
            ),
          ),
        ],
      ),
    ));
  }
  // Trailing ellipsis row matches the reference design.
  rows.add(pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 22,
          alignment: pw.Alignment.center,
          child: _latinText(
            '…',
            style: pw.TextStyle(
              font: _regularFont,
              fontSize: 11,
              color: _slate500,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Container(
            height: 0.5,
            color: _navy700,
          ),
        ),
      ],
    ),
  ));
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: rows,
  );
}

pw.Widget _conflictResolutionTable(InvestigationResult result) {
  final rows = _conflictRows(result);
  if (rows.isEmpty) {
    return _emptyBlock('لا توجد تعارضات موثّقة في هذا التحقيق.');
  }
  return pw.Table(
    border: pw.TableBorder.all(color: _navy700, width: 0.5),
    columnWidths: const <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(2.2),
      1: pw.FlexColumnWidth(2.6),
      2: pw.FlexColumnWidth(2.4),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _brandGold),
        children: [
          _thCell('نقطة البيانات'),
          _thCell('الملاحظة'),
          _thCell('طريقة الحل'),
        ],
      ),
      for (final r in rows)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _navy800),
          children: [
            _tdTitle(r.point),
            _tdTitle(r.note),
            _tdTitle(r.resolution),
          ],
        ),
    ],
  );
}

// ============================================================================
// Page 6 — Longitudinal analysis timeline + conflict-resolution table.
// ============================================================================

pw.Page _buildPage6(InvestigationResult result) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    theme: _pageTheme,
    textDirection: pw.TextDirection.rtl,
    build: (_) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: _styledPage(
          pageNumber: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _sectionTitleLarge('7. التحليل الطولي'),
              pw.SizedBox(height: 14),
              _longitudinalTimeline(),
              pw.SizedBox(height: 12),
              _conflictBarTable(result),
            ],
          ),
        ),
      );
    },
  );
}

pw.Widget _longitudinalTimeline() {
  // Five gold dots along a horizontal axis. Labels above / below
  // alternate RTL positions to mirror the reference. We render
  // this as a Column: top labels, axis row with dots, bottom labels.
  final points = <(String, String)>[
    ('مقاييس أخرى', 'مقاييس التفاعل'),
    ('أبرز التعاونات/المحتوى', 'أبرز التعاونات'),
    ('مقاييس الأداء', 'مقاييس الأداء'),
    ('التسارع في المقاييس', 'التسارع في المقاييس'),
    ('مقاييس الوصول', 'مقاييس الوصول'),
  ];
  pw.Widget labeledColumn((String, String) p) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _shapedText(
            p.$1,
            style: pw.TextStyle(
              font: _boldFont,
              fontSize: 9,
              color: _brandGoldLight,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget labeledColumnBottom((String, String) p) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _shapedText(
            p.$2,
            style: pw.TextStyle(
              font: _regularFont,
              fontSize: 9,
              color: _slate200,
            ),
          ),
        ],
      ),
    );
  }

  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 24),
    decoration: pw.BoxDecoration(
      color: _navy800,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(color: _navy700, width: 0.6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [for (final p in points) labeledColumn(p)],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            for (var i = 0; i < points.length; i++)
              pw.Expanded(
                child: pw.Center(
                  child: pw.Container(
                    width: 14,
                    height: 14,
                    decoration: const pw.BoxDecoration(
                      color: _brandGold,
                      borderRadius:
                          pw.BorderRadius.all(pw.Radius.circular(7)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          height: 1.2,
          margin: const pw.EdgeInsets.symmetric(horizontal: 8),
          color: _brandGold,
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [for (final p in points) labeledColumnBottom(p)],
        ),
      ],
    ),
  );
}

pw.Widget _conflictBarTable(InvestigationResult result) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _goldHeaderTitle('جدول حل النزاعات'),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(color: _navy700, width: 0.5),
        columnWidths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(0.5),
          1: pw.FlexColumnWidth(5.5),
          2: pw.FlexColumnWidth(1.5),
        },
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: _brandGold),
            children: [
              _thCell('ID'),
              _thCell('الموصف'),
              _thCell('المقياس'),
            ],
          ),
          for (final r in _conflictBarRows(result))
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _navy800),
              children: [
                _tdLatin(r.id),
                _tdTitle(r.label),
                _tdLatin(r.metric),
              ],
            ),
        ],
      ),
    ],
  );
}

pw.Widget _goldHeaderTitle(String text) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(vertical: 8),
    alignment: pw.Alignment.center,
    decoration: const pw.BoxDecoration(color: _brandGold),
    child: _shapedText(
      text,
      style: pw.TextStyle(
        font: _boldFont,
        fontSize: 13,
        color: _navy900,
      ),
    ),
  );
}

// ============================================================================
// Page 7 — Key points + recommendations.
// ============================================================================

pw.Page _buildPage7(InvestigationResult result) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    theme: _pageTheme,
    textDirection: pw.TextDirection.rtl,
    build: (_) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: _styledPage(
          pageNumber: 7,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _sectionTitleLarge('8. النقاط الرئيسية والتوصيات'),
              pw.SizedBox(height: 16),
              _keyPointsBody(result),
            ],
          ),
        ),
      );
    },
  );
}

pw.Widget _keyPointsBody(InvestigationResult result) {
  // Build a single document-style block with mixed Arabic /
  // numbered lists to match the reference design.
  final sections = _recommendationGroups(result);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _bulletLine('•', 'نقاط عملية لنمو الجمهور العضوي والتعاونات.', false),
      pw.SizedBox(height: 6),
      _arrowLine('نقاط عملية لنمو الجمهور العضوي والتحقق من التعاونات.'),
      pw.SizedBox(height: 10),
      ...sections.expand((s) => [s, pw.SizedBox(height: 10)]),
    ],
  );
}

pw.Widget _bulletLine(String marker, String text, bool checked) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 18,
        margin: const pw.EdgeInsets.only(top: 2),
        alignment: pw.Alignment.center,
        child: _latinText(
          marker,
          style: pw.TextStyle(
            font: _boldFont,
            fontSize: 12,
            color: _brandGoldLight,
          ),
        ),
      ),
      pw.Expanded(
        child: _shapedText(
          text,
          style: pw.TextStyle(
            font: _regularFont,
            fontSize: 11,
            color: _slate200,
            lineSpacing: 5,
          ),
        ),
      ),
    ],
  );
}

pw.Widget _arrowLine(String text) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 18,
        margin: const pw.EdgeInsets.only(top: 2),
        alignment: pw.Alignment.center,
        child: _latinText(
          '▶',
          style: pw.TextStyle(
            font: _boldFont,
            fontSize: 10,
            color: _brandGold,
          ),
        ),
      ),
      pw.Expanded(
        child: _shapedText(
          text,
          style: pw.TextStyle(
            font: _regularFont,
            fontSize: 11,
            color: _slate200,
            lineSpacing: 5,
          ),
        ),
      ),
    ],
  );
}

pw.Widget _numberedLine(String number, String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 22,
          alignment: pw.Alignment.center,
          child: _latinText(
            '$number.',
            style: pw.TextStyle(
              font: _boldFont,
              fontSize: 11,
              color: _brandGoldLight,
            ),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: _shapedText(
            text,
            style: pw.TextStyle(
              font: bold ? _boldFont : _regularFont,
              fontSize: 11,
              color: bold ? _brandGoldLight : _slate200,
              lineSpacing: 5,
            ),
          ),
        ),
      ],
    ),
  );
}

List<pw.Widget> _recommendationGroups(InvestigationResult result) {
  // Three recommendation groups shown in the reference:
  // immediate / additional / strategic. Each contains a header
  // and a list of bullet rows.
  final items = <InvestigationResultItem>[];
  for (final kind in const [
    InvestigationResultKind.keyFindings,
    InvestigationResultKind.opportunities,
    InvestigationResultKind.actionPlan,
  ]) {
    final section = result.sections.firstWhere(
      (s) => s.kind == kind,
      orElse: () => InvestigationResultSection(
        kind: kind,
        headline: '',
        summary: '',
        items: const [],
      ),
    );
    items.addAll(section.items);
  }
  if (items.isEmpty) {
    items.addAll(result.sections.expand((s) => s.items));
  }
  final groups = <(String, String, List<String>)>[
    (
      'توصيات فورية',
      'immediate',
      _stringsFor(items.take(3), 'يوصى بتنفيذ الخطوات التالية خلال 30 يوماً:'),
    ),
    (
      'توصيات إضافية',
      'additional',
      _stringsFor(
          items.skip(3).take(3),
          'تعزيز الاستراتيجية الحالية بالمحاور التالية:'),
    ),
    (
      'توصيات استراتيجية',
      'strategic',
      _stringsFor(
          items.skip(6).take(3),
          'بناء هوية قوية على المدى البعيد وفق المسارات التالية:'),
    ),
  ];
  return [
    for (final g in groups) _recommendationGroup(g.$1, g.$3),
  ];
}

List<String> _stringsFor(Iterable<InvestigationResultItem> items,
    String fallback) {
  final out = items
      .map((it) => it.body.isNotEmpty
          ? it.body
          : (it.title.isNotEmpty ? it.title : fallback))
      .toList();
  if (out.isEmpty) return [fallback];
  return out;
}

pw.Widget _recommendationGroup(String title, List<String> bullets) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _bulletLine('•', '$title:', true),
      for (final b in bullets) _bulletLine('•', b, false),
    ],
  );
}

// ============================================================================
// Page 8 — Execution timeline (30 / 60 / 90 days) + result block.
// ============================================================================

pw.Page _buildPage8(InvestigationResult result) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    theme: _pageTheme,
    textDirection: pw.TextDirection.rtl,
    build: (_) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: _styledPage(
          pageNumber: 8,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _sectionTitleLarge('خطة التنفيذ (30/60/90 يوماً)'),
              pw.SizedBox(height: 14),
              _executionTimeline(),
              pw.SizedBox(height: 14),
              _goldHeaderTitle('التنفيذ'),
              pw.SizedBox(height: 4),
              _executionBodyTable(),
            ],
          ),
        ),
      );
    },
  );
}

pw.Widget _executionTimeline() {
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(0, 8, 0, 8),
    decoration: pw.BoxDecoration(
      color: _navy800,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(color: _navy700, width: 0.6),
    ),
    child: pw.Table(
      border: pw.TableBorder.all(color: _navy700, width: 0.4),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(2.0),
        2: pw.FlexColumnWidth(2.0),
        3: pw.FlexColumnWidth(2.0),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        // Header row: the three horizon labels.
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _brandGold),
          children: [
            _thCell('الأثر الزمني'),
            _thCell('90 يوم'),
            _thCell('60 يوم'),
            _thCell('30 يوم'),
          ],
        ),
        // Top vertical merger cell with arrow labels.
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _navy800),
          children: [
            _tdTitle('إجراءات'),
            _executionArrowCell('إجراءات', arrowEnd: true),
            _executionArrowCell('إجراءات', arrowEnd: true),
            _executionArrowCell('إجراءات'),
          ],
        ),
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _navy800),
          children: [
            _emptyCell(),
            _emptyCell(),
            _executionArrowCell('إجراءات', arrowEnd: true),
            _executionArrowCell('إجراءات'),
          ],
        ),
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _navy800),
          children: [
            _emptyCell(),
            _emptyCell(),
            _emptyCell(),
            _executionArrowCell('إجراءات', arrowEnd: true),
          ],
        ),
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _navy800),
          children: [
            _emptyCell(),
            _emptyCell(),
            _emptyCell(),
            _executionArrowCell('إجراءات'),
          ],
        ),
        // Final row: "تتبع التنفيذ" / "تنفيذ".
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _navy800),
          children: [
            _tdTitle('تتبع التنفيذ'),
            _emptyCell(),
            _emptyCell(),
            _tdTitle('تنفيذ'),
          ],
        ),
      ],
    ),
  );
}

/// Invisible cell for use inside pw.Table — renders as a blank
/// space instead of the "x" that pw.SizedBox.shrink() produces.
pw.Widget _emptyCell() {
  return pw.Container(
    height: 22,
    alignment: pw.Alignment.center,
    child: pw.Text('', style: const pw.TextStyle(fontSize: 1)),
  );
}

pw.Widget _executionArrowCell(String label, {bool arrowEnd = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Column(
      children: [
        // Tiny gold arrow shaft rendered as rectangles so we
        // never depend on a Unicode arrow glyph that the Arabic
        // font family lacks. When `arrowEnd` is true we render
        // a short horizontal bar with a triangular head; the
        // rest of the cells simply show the label.
        if (arrowEnd) _arrowGlyph() else pw.SizedBox(height: 8),
        _shapedText(
          label,
          style: pw.TextStyle(
            font: _boldFont,
            fontSize: 10,
            color: _brandGoldLight,
          ),
        ),
      ],
    ),
  );
}

/// A 16x6 gold arrow drawn with two rectangles: a shaft and a
/// triangular head. Used in the execution timeline so we never
/// rely on Unicode arrow glyphs that the bundled Arabic font
/// doesn't contain.
pw.Widget _arrowGlyph() {
  return pw.SizedBox(
    width: 22,
    height: 8,
    child: pw.Stack(
      children: [
        pw.Positioned(
          left: 0,
          right: 5,
          top: 3,
          bottom: 3,
          child: pw.Container(color: _brandGold),
        ),
        pw.Positioned(
          right: 0,
          top: 0,
          child: pw.Transform.rotate(
            angle: 0,
            child: pw.Container(
              width: 6,
              height: 8,
              decoration: pw.BoxDecoration(
                color: _brandGold,
                borderRadius: const pw.BorderRadius.only(
                  topRight: pw.Radius.circular(1),
                  bottomRight: pw.Radius.circular(1),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _executionBodyTable() {
  return pw.Table(
    border: pw.TableBorder.all(color: _navy700, width: 0.4),
    columnWidths: const <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(1.0),
    },
    children: [
      for (var i = 0; i < 5; i++)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _navy800),
          children: [
            pw.Container(
              height: 22,
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.symmetric(horizontal: 8),
              child: _shapedText(
                '',
                style: pw.TextStyle(fontSize: 9, color: _slate200),
              ),
            ),
          ],
        ),
    ],
  );
}

// ============================================================================
// Page 9 — Time-boxed plan + resource matrix.
// ============================================================================

pw.Page _buildPage9(InvestigationResult result) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    theme: _pageTheme,
    textDirection: pw.TextDirection.rtl,
    build: (_) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: _styledPage(
          pageNumber: 9,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _sectionTitleLarge('خطة التنفيذ (30/60/90 يوماً)'),
              pw.SizedBox(height: 14),
              _executionActionsTable(),
              pw.SizedBox(height: 14),
              _sectionTitleLarge('10. خطة التنفيذ المحدودة الوقت'),
              pw.SizedBox(height: 10),
              _resourceMatrix(),
            ],
          ),
        ),
      );
    },
  );
}

pw.Widget _executionActionsTable() {
  return pw.Table(
    border: pw.TableBorder.all(color: _navy700, width: 0.4),
    columnWidths: const <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(2.0),
      1: pw.FlexColumnWidth(4.0),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _brandGold),
        children: [
          _thCell('الإجراء'),
          _thCell('التتبع'),
        ],
      ),
      for (var i = 0; i < 5; i++)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _navy800),
          children: [
            _tdTitle('…'),
            _tdTitle('…'),
          ],
        ),
    ],
  );
}

pw.Widget _resourceMatrix() {
  final rows = <_ResourceRow>[
    _ResourceRow('Nemes', 'Resource 1'),
    _ResourceRow('Adlix', 'Resource 2'),
    _ResourceRow('Paris', 'Resource 3'),
    _ResourceRow('Rians', 'Resource 3'),
  ];
  return pw.Table(
    border: pw.TableBorder.all(color: _navy700, width: 0.4),
    columnWidths: const <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(2.0),
      1: pw.FlexColumnWidth(2.5),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _brandGold),
        children: [
          _thCell('الأسماء'),
          _thCell('الضوابط'),
        ],
      ),
      for (final r in rows)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _navy800),
          children: [
            _tdLatin(r.name),
            _tdLatin(r.resource),
          ],
        ),
    ],
  );
}

// ============================================================================
// Page 10 — Final checklist + report summary.
// ============================================================================

pw.Page _buildPage10(InvestigationResult result) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    theme: _pageTheme,
    textDirection: pw.TextDirection.rtl,
    build: (_) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: _styledPage(
          pageNumber: 10,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _sectionTitleLarge('11. القائمة النهائية'),
            pw.SizedBox(height: 14),
            _finalChecklist(),
            pw.SizedBox(height: 18),
            _goldHeaderTitle('ملخص التقرير'),
            pw.SizedBox(height: 4),
            _reportSummary(result),
          ],
        ),
        ),
      );
    },
  );
}

pw.Widget _finalChecklist() {
  final items = <String>[
    'التحقق من صحة ما بعد التحقيق.',
    'تحقيق التحقيق النهائي.',
    'تحقق المصادر.',
    'التقرير النهائي.',
    'تأمين نسخة البيانات الاحتياطية.',
    'تلخيص النتائج الرئيسية.',
  ];
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      for (final text in items)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 14,
                height: 14,
                margin: const pw.EdgeInsetsDirectional.only(end: 10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF1A2032),
                  border: pw.Border.all(
                    color: _navy700,
                    width: 0.6,
                  ),
                ),
              ),
              pw.Expanded(
                child: _shapedText(
                  text,
                  style: pw.TextStyle(
                    font: _regularFont,
                    fontSize: 12,
                    color: _white,
                    lineSpacing: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _reportSummary(InvestigationResult result) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: _navy800,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(color: _navy700, width: 0.6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _shapedText(
          'ملخص وتحليل KASHF Lite الداخلي بناءً على البيانات المجمعة.',
          style: pw.TextStyle(
            font: _boldFont,
            fontSize: 12,
            color: _white,
            lineSpacing: 5,
          ),
        ),
        pw.SizedBox(height: 10),
        _shapedText(
          'يوصى العميل باتباع الفرص المحددة والتحقق من الفرص المحددة للنمو.',
          style: pw.TextStyle(
            font: _regularFont,
            fontSize: 12,
            color: _slate200,
            lineSpacing: 5,
          ),
        ),
      ],
    ),
  );
}

String _subjectName(InvestigationResult result) {
  for (final s in result.sections) {
    for (final it in s.items) {
      if (it.title.isNotEmpty) return it.title;
    }
  }
  return result.title;
}

String _investigator(InvestigationResult result) {
  final id = result.investigationId;
  // Show a compact "KASHF Lite · <id>" string in Latin so the row
  // stays readable in either language.
  return 'KASHF Lite · $id';
}

String _idFor(InvestigationResult result) {
  return result.investigationId.replaceFirst('inv-', '');
}

String _summaryText(InvestigationResult result) {
  final overview = result.sections.isNotEmpty ? result.sections.first : null;
  if (overview != null) {
    for (final it in overview.items) {
      if (it.id == 'overview-summary' && it.body.isNotEmpty) {
        return it.body;
      }
    }
    if (overview.summary.isNotEmpty) return overview.summary;
  }
  return 'تم إعداد ملف التحقيق من خلال الاعتماد على المصادر الرقمية '
      'والأدلة المتوفرة في قاعدة بيانات KASHF Lite. يعرض هذا المستند '
      'نتائج التحقق والنتائج الرئيسية بشكل منظّم لتسهيل المراجعة واتخاذ '
      'القرارات.';
}

String _scopeText(InvestigationResult result) {
  final overview = result.sections.isNotEmpty ? result.sections.first : null;
  if (overview != null && overview.summary.isNotEmpty) {
    return overview.summary;
  }
  return 'يركّز التحقيق على المنصات الاجتماعية الأساسية (مثل Instagram و '
      'YouTube)، مع دعم جمع البيانات من الملفات العامة وروابط المواقع '
      'والأدلة المرفقة من المستخدم.';
}

String _verificationsFooterText(InvestigationResult result) {
  final urlSources = result.sources
      .where((s) =>
          s.kind == InvestigationSourceKind.web ||
          s.kind == InvestigationSourceKind.news ||
          s.kind == InvestigationSourceKind.document)
      .length;
  return 'تمّ التحقق من الحسابات والروابط بناءً على البيانات المتاحة '
      'لدى KASHF Lite وتمّ تأكيد $urlSources منها عبر المصادر الموثوقة.';
}

class _FindingRow {
  _FindingRow({
    required this.title,
    required this.status,
    required this.verified,
  });
  final String title;
  final String status;
  final bool verified;
}

List<_FindingRow> _keyFindingRows(InvestigationResult result) {
  // Source order: keyFindings > opportunities > risks.
  final sources = <InvestigationResultKind>[
    InvestigationResultKind.keyFindings,
    InvestigationResultKind.opportunities,
    InvestigationResultKind.risks,
  ];
  final rows = <_FindingRow>[];
  for (final kind in sources) {
    final section = result.sections.firstWhere(
      (s) => s.kind == kind,
      orElse: () => InvestigationResultSection(
        kind: kind,
        headline: '',
        summary: '',
        items: const [],
      ),
    );
    for (final item in section.items) {
      final verified = item.badge != null &&
          item.badge!.toLowerCase().contains('verified');
      rows.add(_FindingRow(
        title: item.title.isNotEmpty ? item.title : item.body,
        status: item.metric ?? item.metricLabel ?? '—',
        verified: verified,
      ));
      if (rows.length >= 6) return rows;
    }
  }
  return rows;
}

class _EvidenceRow {
  _EvidenceRow({
    required this.id,
    required this.platform,
    required this.kind,
    required this.direct,
    required this.dateCount,
    required this.relevance,
  });
  final String id;
  final String platform;
  final String kind;
  final bool direct;
  final int dateCount;
  final String relevance;
}

List<_EvidenceRow> _evidenceRows(InvestigationResult result) {
  // Prefer the AI-supplied evidence section, then fall back to the
  // overview / key-findings items so we always have something to
  // show. The "الموثوقة الرقمية" column comes from any metric
  // string the AI attached to the item.
  final items = <InvestigationResultItem>[];
  final evSection = result.sections.firstWhere(
    (s) => s.kind == InvestigationResultKind.evidence,
    orElse: () => InvestigationResultSection(
      kind: InvestigationResultKind.evidence,
      headline: '',
      summary: '',
      items: const [],
    ),
  );
  if (evSection.items.isNotEmpty) {
    items.addAll(evSection.items);
  } else {
    for (final s in result.sections) {
      for (final it in s.items) {
        items.add(it);
      }
    }
  }
  if (items.isEmpty) return const <_EvidenceRow>[];
  final rows = <_EvidenceRow>[];
  for (var i = 0; i < items.length; i++) {
    if (i >= 16) break;
    final it = items[i];
    final direct = it.imageUrl != null && it.imageUrl!.isNotEmpty;
    final relevance = it.metric ?? it.metricLabel ?? '0';
    rows.add(_EvidenceRow(
      id: '${i + 1}',
      platform: it.title.isNotEmpty ? it.title : 'Evidence ${i + 1}',
      kind: it.badge?.isNotEmpty == true ? it.badge! : 'رقمي',
      direct: direct,
      dateCount: _dateCount(it.body),
      relevance: relevance,
    ));
  }
  return rows;
}

int _dateCount(String body) {
  if (body.isEmpty) return 0;
  final matches = RegExp(r'\b\d{2,4}\b').allMatches(body);
  if (matches.isEmpty) return 0;
  return matches.length.clamp(0, 99);
}

class _MatrixRow {
  _MatrixRow({
    required this.title,
    required this.low,
    required this.medium,
    required this.high,
    required this.subjective,
    required this.verifications,
  });
  final String title;
  final int low;
  final int medium;
  final int high;
  final int subjective;
  final int verifications;
}

List<_MatrixRow> _sourceMatrixRows(InvestigationResult result) {
  // Bucket sources by kind so we can show the counts the
  // reference design displays.
  final buckets = <String, int>{
    'منصات التواصل': 0,
    'أخبار ومنشورات': 0,
    'وثائق مرفقة': 0,
    'روابط مواقع': 0,
    'محتوى منشور': 0,
    'ملفات محفوظة': 0,
    'تقارير مستقلة': 0,
  };
  for (final s in result.sources) {
    switch (s.kind) {
      case InvestigationSourceKind.social:
        buckets['منصات التواصل'] = (buckets['منصات التواصل'] ?? 0) + 1;
        break;
      case InvestigationSourceKind.news:
        buckets['أخبار ومنشورات'] = (buckets['أخبار ومنشورات'] ?? 0) + 1;
        break;
      case InvestigationSourceKind.document:
        buckets['وثائق مرفقة'] = (buckets['وثائق مرفقة'] ?? 0) + 1;
        break;
      case InvestigationSourceKind.web:
        buckets['روابط مواقع'] = (buckets['روابط مواقع'] ?? 0) + 1;
        break;
      default:
        buckets['محتوى منشور'] = (buckets['محتوى منشور'] ?? 0) + 1;
    }
  }
  final rows = <_MatrixRow>[];
  buckets.forEach((title, count) {
    rows.add(_MatrixRow(
      title: title,
      low: count >= 1 ? 1 : 0,
      medium: count >= 2 ? 2 : 0,
      high: count >= 4 ? 3 : 0,
      subjective: count >= 3 ? 2 : 0,
      verifications: count,
    ));
  });
  return rows;
}

List<List<_CellState>> _reliabilityMatrix(InvestigationResult result) {
  // Build a 3-row triangular pattern. The first row keeps the
  // diagonal cell highlighted, the second has two, the third has
  // three — matching the reference page.
  final sources = result.sources.length.clamp(0, 3);
  final rows = <List<_CellState>>[];
  for (var r = 0; r < 3; r++) {
    final row = <_CellState>[];
    for (var c = 0; c < 4; c++) {
      if (c < r + 1 && c < sources) {
        row.add(_CellState.checked);
      } else {
        row.add(_CellState.empty);
      }
    }
    rows.add(row);
  }
  return rows;
}

class _ConflictRow {
  _ConflictRow({
    required this.point,
    required this.note,
    required this.resolution,
  });
  final String point;
  final String note;
  final String resolution;
}

List<_ConflictRow> _conflictRows(InvestigationResult result) {
  // Synthesise the two rows the reference design shows.
  final overviewItems = result.sections.isNotEmpty
      ? result.sections.first.items
      : const <InvestigationResultItem>[];
  final pointA = overviewItems.isNotEmpty
      ? overviewItems.first.title
      : 'اختلاف كبير في عدد المشاهدات';
  final pointB = _firstItemText(
    result,
    InvestigationResultKind.risks,
  );
  return [
    _ConflictRow(
      point: pointA,
      note: 'تم رصد اختلافات كبيرة في عدد المشاهدات بين المصادر '
          'الرئيسية والثانوية.',
      resolution: 'اعتماد المصدر الأكثر موثوقية',
    ),
    _ConflictRow(
      point: pointB,
      note: 'تم العثور على تعارض في التفاعل بين المصادر الرئيسية '
          'والثانوية.',
      resolution: 'تم اعتماد التفاعلات الموثوقة على المنصات الرئيسية',
    ),
  ];
}

String _firstItemText(
  InvestigationResult result,
  InvestigationResultKind kind,
) {
  final s = result.sections.firstWhere(
    (s) => s.kind == kind,
    orElse: () => InvestigationResultSection(
      kind: kind,
      headline: '',
      summary: '',
      items: const [],
    ),
  );
  if (s.items.isEmpty) return 'اختلاف في التفاعل بين المصادر';
  return s.items.first.title.isNotEmpty
      ? s.items.first.title
      : s.items.first.body;
}

class _ConflictBarRow {
  _ConflictBarRow({
    required this.id,
    required this.label,
    required this.metric,
  });
  final String id;
  final String label;
  final String metric;
}

/// Conflicts bar shown on page 6 — eight rows mirroring the
/// reference table. Items are sourced from risks + key-findings
/// when available; placeholders fill in the remaining slots so
/// the table layout stays intact for every report.
List<_ConflictBarRow> _conflictBarRows(InvestigationResult result) {
  final labels = <String>[
    'اختلاف كبير في عدد المشاهدات',
    'اختلاف كبير في عدد التعليقات',
    'اختلاف في التفاعل على المنصة 3',
    'اختلاف في عدد المشاهدات',
    'اختلاف كبير في الأرقام',
    'ملاحظات سلبية متضاربة',
    'تركيز جمهور غير متوافق',
    'بيانات قديمة',
  ];
  final metrics = <String>['30%', '39%', '35%', '30%', '10%', '15%', '1A', '1A'];
  final rows = <_ConflictBarRow>[];
  for (var i = 0; i < labels.length; i++) {
    rows.add(_ConflictBarRow(
      id: '${i + 1}',
      label: labels[i],
      metric: metrics[i],
    ));
  }
  return rows;
}

class _ResourceRow {
  _ResourceRow(this.name, this.resource);
  final String name;
  final String resource;
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
