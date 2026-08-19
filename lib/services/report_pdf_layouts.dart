import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/investigation_result.dart';

// ============================================================================
// Per-page report layouts.
//
// Each top-level report page has its OWN dedicated builder so different
// content types get different layouts. The previous implementation used a
// single `MultiPage` with one shared template — that forced every page to
// look the same. Here we emit ten `pw.Page` widgets, each laid out by a
// page-specific function that knows how to present its data:
//
//   - Cover              → dark hero with metadata cards
//   - Case + Claims      → 2-section split with a proper Claims table
//   - Evidence Log       → full-width readable table (continues pages)
//   - Source Evaluation  → matrix + numbered assessment cards
//   - Triangulation      → triangular visualization + Conflicts table
//   - Analysis Tracking  → timeline dashboard + Conflict Resolution table
//   - Recommendations    → numbered recommendation cards
//   - Action Plan        → 30/60-day timeline + Tracking table
//   - Follow-up          → Actions table + Limitations & Resource table
//   - Validation         → checkboxes + Internal Summary card
//
// Long tables are rendered inside their own `MultiPage` so they can
// paginate across pages when there are many items.
//
// Shared design tokens (colors) are constants; text shaping + fonts
// come from the [PdfLayoutHelpers] bundle injected by the parent file.
// ============================================================================

// ---- Design tokens ----

const _brandGold = PdfColor.fromInt(0xFFF4C542);
const _brandGoldDeep = PdfColor.fromInt(0xFFB8861B);
const _brandGoldLight = PdfColor.fromInt(0xFFFFE08A);
const _navy900 = PdfColor.fromInt(0xFF0F1421);
const _navy800 = PdfColor.fromInt(0xFF1A2032);
const _navy700 = PdfColor.fromInt(0xFF252B40);
const _slate500 = PdfColor.fromInt(0xFF94A3B8);
const _slate200 = PdfColor.fromInt(0xFFE2E8F0);
const _white = PdfColor.fromInt(0xFFFFFFFF);

// ============================================================================
// Helper bundle — carries the Arabic-aware text shaping pipeline (UAX#9
// bidi + arabic_reshaper), the cached NotoSansArabic fonts, and a few
// utility functions. Injected by the importing file
// `report_pdf_writer.dart` so the layouts here can produce
// correctly-shaped Arabic text without depending on private symbols.
// ============================================================================

class PdfLayoutHelpers {
  PdfLayoutHelpers({
    required this.shapedText,
    required this.latinText,
    required this.regularFont,
    required this.boldFont,
    required this.sectionTitleAr,
    required this.formatDate,
  });

  /// Pre-shapes Arabic + Latin mixed content.
  final pw.Widget Function(String text, {required pw.TextStyle style})
  shapedText;

  /// Pure-Latin text widget — no bidi call, just plain Latin/digits.
  final pw.Widget Function(String text, {required pw.TextStyle style})
  latinText;

  /// Cached regular-weight NotoSansArabic font (or Helvetica fallback).
  final pw.Font regularFont;

  /// Cached bold-weight NotoSansArabic font (or Helvetica bold fallback).
  final pw.Font boldFont;

  /// Localised Arabic title for a section kind.
  final String Function(InvestigationResultKind kind) sectionTitleAr;

  /// Date formatter.
  final String Function(DateTime dt) formatDate;
}

// ============================================================================
// Shared visual primitives — every page builder composes these.
// ============================================================================

/// Top-of-page banner used on every page (gold divider + bilingual title).
pw.Widget _topBanner(
  PdfLayoutHelpers h, {
  required String englishTitle,
  required String arabicTitle,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          h.latinText(
            englishTitle,
            style: pw.TextStyle(
              font: h.boldFont,
              fontSize: 11,
              color: _brandGoldDeep,
              letterSpacing: 2.4,
            ),
          ),
          h.shapedText(
            arabicTitle,
            style: pw.TextStyle(
              font: h.boldFont,
              fontSize: 12,
              color: _brandGoldDeep,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Container(height: 0.8, color: _brandGold),
      pw.SizedBox(height: 16),
    ],
  );
}

/// Bottom-of-page footer with confidential marker + page number.
pw.Widget _bottomFooter(PdfLayoutHelpers h, {required int pageNumber}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(height: 0.6, color: PdfColor.fromInt(0x66F4C542)),
      pw.SizedBox(height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          h.latinText(
            'CONFIDENTIAL  ·  KASHF Lite Investigation File',
            style: pw.TextStyle(
              font: h.regularFont,
              fontSize: 8,
              color: _slate500,
              letterSpacing: 1.2,
            ),
          ),
          h.latinText(
            'Page $pageNumber',
            style: pw.TextStyle(
              font: h.boldFont,
              fontSize: 9,
              color: _brandGoldDeep,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    ],
  );
}

/// Card with gold header strip + body content.
pw.Widget _goldHeaderCard(
  PdfLayoutHelpers h, {
  required String englishTitle,
  required String arabicTitle,
  required pw.Widget child,
  pw.EdgeInsetsGeometry padding = const pw.EdgeInsets.all(14),
}) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: _navy800,
      border: pw.Border.all(color: _brandGold, width: 0.8),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const pw.BoxDecoration(
            color: _brandGold,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(5),
              topRight: pw.Radius.circular(5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              h.latinText(
                englishTitle,
                style: pw.TextStyle(
                  font: h.boldFont,
                  fontSize: 12,
                  color: _navy900,
                  letterSpacing: 1,
                ),
              ),
              h.shapedText(
                arabicTitle,
                style: pw.TextStyle(
                  font: h.boldFont,
                  fontSize: 11,
                  color: _navy900,
                ),
              ),
            ],
          ),
        ),
        pw.Padding(padding: padding, child: child),
      ],
    ),
  );
}

/// 4-column identifiers table (ID / Confidence / Evidence / Sources).
pw.Widget _identifiersTable(
  PdfLayoutHelpers h, {
  required String id,
  required double? confidence,
  required int evidenceCount,
  required int sourcesCount,
  required String dateText,
}) {
  final confidenceStr = confidence == null
      ? '—'
      : '${(confidence.clamp(0.0, 1.0) * 100).round()}%';
  final shortId = id.length > 12 ? id.substring(id.length - 12) : id;

  pw.Widget cell(String label, String value, {bool highlight = false}) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: pw.BoxDecoration(
          color: highlight ? _navy700 : _navy800,
          border: pw.Border.all(color: _brandGold, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            h.latinText(
              label,
              style: pw.TextStyle(
                font: h.boldFont,
                fontSize: 9,
                color: _brandGold,
                letterSpacing: 0.8,
              ),
            ),
            pw.SizedBox(height: 4),
            h.latinText(
              value,
              style: pw.TextStyle(
                font: h.boldFont,
                fontSize: 14,
                color: _white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        children: [
          cell('ID', shortId),
          cell('CONFIDENCE', confidenceStr, highlight: true),
          cell('EVIDENCE', '$evidenceCount'),
          cell('SOURCES', '$sourcesCount'),
        ],
      ),
      pw.SizedBox(height: 6),
      h.latinText(
        'DATE  ·  $dateText',
        style: pw.TextStyle(
          font: h.regularFont,
          fontSize: 9,
          color: _slate500,
          letterSpacing: 0.6,
        ),
      ),
    ],
  );
}

/// Numbered bilingual section header strip.
pw.Widget _numberedSectionHeader(
  PdfLayoutHelpers h, {
  required int number,
  required String englishTitle,
  required String arabicTitle,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: const pw.BoxDecoration(color: _brandGold),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        h.latinText(
          '$number.  $englishTitle',
          style: pw.TextStyle(
            font: h.boldFont,
            fontSize: 14,
            color: _navy900,
            letterSpacing: 0.6,
          ),
        ),
        h.shapedText(
          arabicTitle,
          style: pw.TextStyle(font: h.boldFont, fontSize: 13, color: _navy900),
        ),
      ],
    ),
  );
}

/// Dark-theme data table with gold header + alternating navy rows.
pw.Widget _dataTable(
  PdfLayoutHelpers h, {
  required List<String> headers,
  required List<List<String>> rows,
  required List<double> weights,
}) {
  final total = weights.fold<double>(0, (s, w) => s + w);
  final flexFor = weights
      .map((w) => (w / total * 1000).round())
      .toList(growable: false);
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: _navy800,
      border: pw.Border.all(color: _brandGold, width: 0.8),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Header row
        pw.Container(
          decoration: const pw.BoxDecoration(color: _brandGold),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: pw.Row(
            children: [
              for (var i = 0; i < headers.length; i++)
                pw.Expanded(
                  flex: flexFor[i],
                  child: h.latinText(
                    headers[i],
                    style: pw.TextStyle(
                      font: h.boldFont,
                      fontSize: 10,
                      color: _navy900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Body rows
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0)
            pw.Container(height: 0.4, color: PdfColor.fromInt(0x44F4C542)),
          pw.Container(
            color: r.isEven ? _navy800 : _navy700,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < headers.length; c++)
                  pw.Expanded(
                    flex: flexFor[c],
                    child: h.shapedText(
                      rows[r].length > c && rows[r][c].isNotEmpty
                          ? rows[r][c]
                          : '—',
                      style: pw.TextStyle(
                        font: h.regularFont,
                        fontSize: 10,
                        color: _white,
                        lineSpacing: 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

/// Numbered card row (Recommendations + Source Assessment).
pw.Widget _numberedCard(
  PdfLayoutHelpers h, {
  required int number,
  required String title,
  required String body,
  String? badge,
}) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 6),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: _navy800,
      border: pw.Border.all(color: _brandGold, width: 0.6),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 30,
          height: 30,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: _brandGold,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(15)),
          ),
          child: h.latinText(
            '$number',
            style: pw.TextStyle(
              font: h.boldFont,
              fontSize: 13,
              color: _navy900,
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                children: [
                  pw.Expanded(
                    child: h.shapedText(
                      title,
                      style: pw.TextStyle(
                        font: h.boldFont,
                        fontSize: 12,
                        color: _white,
                      ),
                    ),
                  ),
                  if (badge != null && badge.isNotEmpty) ...[
                    pw.SizedBox(width: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: pw.BoxDecoration(
                        color: _brandGoldLight,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(3),
                        ),
                      ),
                      child: h.latinText(
                        badge,
                        style: pw.TextStyle(
                          font: h.boldFont,
                          fontSize: 8,
                          color: _brandGoldDeep,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (body.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                h.shapedText(
                  body,
                  style: pw.TextStyle(
                    font: h.regularFont,
                    fontSize: 10,
                    color: _slate200,
                    lineSpacing: 3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Checkbox row (Post-Validation Checklist).
pw.Widget _checkboxRow(
  PdfLayoutHelpers h, {
  required String label,
  required String? detail,
}) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 5),
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: pw.BoxDecoration(
      color: _navy800,
      border: pw.Border.all(color: _brandGold, width: 0.6),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 16,
          height: 16,
          margin: const pw.EdgeInsets.only(top: 2),
          decoration: pw.BoxDecoration(
            color: _navy900,
            border: pw.Border.all(color: _brandGold, width: 1.4),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              h.shapedText(
                label,
                style: pw.TextStyle(
                  font: h.boldFont,
                  fontSize: 11,
                  color: _white,
                ),
              ),
              if (detail != null && detail.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                h.shapedText(
                  detail,
                  style: pw.TextStyle(
                    font: h.regularFont,
                    fontSize: 9,
                    color: _slate200,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

// ============================================================================
// Triangulation triangle visualization.
//
// Renders a right-angle triangle (right-angle at bottom-left,
// hypotenuse from top-left to bottom-right) filled with gold on a
// navy background. The triangle is overlaid with a numbered scale
// (1..5) along the hypotenuse — this matches the
// "Triangulation Matrix" graphic on Page 5 of the design mock-up.
//
// Drawn via `pw.CustomPaint` so we can directly call PdfGraphics
// primitives (moveTo/lineTo/fillPath) — there's no built-in
// triangle widget in the `pdf` package.
// ============================================================================
pw.Widget _triangulationTriangle(PdfLayoutHelpers h) {
  return pw.CustomPaint(
    size: const PdfPoint(160, 160),
    painter: (canvas, size) {
      final w = size.x;
      final ht = size.y;
      // Outline + grid lines first (drawn in navy/gold so they
      // sit *behind* the fill). The grid forms the 5-step scale.
      canvas.setColor(_brandGold);
      canvas.setLineWidth(0.6);

      // Hypotenuse from top-left to bottom-right.
      canvas.moveTo(0, ht);
      canvas.lineTo(w, 0);
      canvas.strokePath();

      // Diagonal tick marks for the 1..5 scale along the
      // hypotenuse.
      for (var i = 1; i <= 5; i++) {
        final t = i / 5.0;
        final x = t * w;
        final y = ht * (1 - t);
        // Short cross-tick perpendicular to the diagonal.
        canvas.moveTo(x + 3, y - 3);
        canvas.lineTo(x - 3, y + 3);
      }
      canvas.strokePath();

      // Filled lower-left triangle (vertices: top-left, bottom-
      // left, bottom-right). PDF Y axis goes UP, so to fill the
      // bottom-left we moveTo (0, ht) → lineTo (0, 0) → lineTo
      // (w, 0) → closePath.
      canvas.setColor(PdfColor.fromInt(0xCCF4C542));
      canvas.moveTo(0, ht);
      canvas.lineTo(0, 0);
      canvas.lineTo(w, 0);
      canvas.closePath();
      canvas.fillPath();
    },
    child: pw.Container(
      width: 160,
      height: 160,
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          h.latinText(
            'TRIANGULATION MATRIX',
            style: pw.TextStyle(
              font: h.boldFont,
              fontSize: 9,
              color: _brandGold,
              letterSpacing: 1.2,
            ),
          ),
          pw.Spacer(),
          // Scale labels along the right edge — these match
          // the 5-step scale the gold tick marks form on the
          // hypotenuse.
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (final n in [5, 4, 3, 2, 1])
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1),
                      child: h.latinText(
                        '$n',
                        style: pw.TextStyle(
                          font: h.boldFont,
                          fontSize: 8,
                          color: _brandGoldDeep,
                        ),
                      ),
                    ),
                ],
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    h.latinText(
                      'Truncation Ratio',
                      style: pw.TextStyle(
                        font: h.regularFont,
                        fontSize: 7,
                        color: _slate500,
                      ),
                    ),
                    for (final l in const [
                      'Independent',
                      'Cross-source',
                      'Direct',
                      'Indirect',
                      'Unverified',
                    ])
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 1),
                        child: h.latinText(
                          l,
                          style: pw.TextStyle(
                            font: h.regularFont,
                            fontSize: 7,
                            color: _white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ============================================================================
// Page builders — public functions consumed by report_pdf_writer.dart.
// Each function returns a dedicated pw.Page widget for one section of
// the report. The dark-navy background + gold border are painted by
// `theme.buildBackground` on every page.
// ============================================================================

/// Page 1 — Cover / Case Overview.
pw.Page buildCoverPage(
  InvestigationResult result,
  pw.PageTheme theme,
  PdfLayoutHelpers h,
) {
  final confidence = result.confidence;
  final dateText = h.formatDate(result.generatedAt);
  final itemsCount = result.sections.fold<int>(
    0,
    (sum, s) => sum + s.items.length,
  );
  final sourcesCount = result.sources.length;

  return pw.Page(
    pageTheme: theme,
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _topBanner(
          h,
          englishTitle: 'INTERNAL INVESTIGATION FILE',
          arabicTitle: 'ملف التحقيق الداخلي',
        ),
        pw.SizedBox(height: 4),
        pw.Align(
          alignment: pw.Alignment.center,
          child: h.shapedText(
            result.title.isEmpty ? 'ملف التحقيق الداخلي' : result.title,
            style: pw.TextStyle(
              font: h.boldFont,
              fontSize: 26,
              color: _brandGold,
              lineSpacing: 2,
            ),
          ),
        ),
        pw.Align(
          alignment: pw.Alignment.center,
          child: h.latinText(
            'KASHF Lite Investigation Report',
            style: pw.TextStyle(
              font: h.regularFont,
              fontSize: 11,
              color: _slate200,
              letterSpacing: 1.2,
            ),
          ),
        ),
        pw.SizedBox(height: 18),
        _goldHeaderCard(
          h,
          englishTitle: 'Subject',
          arabicTitle: 'الموضوع',
          child: pw.Row(
            children: [
              pw.Expanded(
                child: h.shapedText(
                  result.title.isEmpty ? '—' : result.title,
                  style: pw.TextStyle(
                    font: h.boldFont,
                    fontSize: 14,
                    color: _white,
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              h.latinText(
                'Audience & Collaborators',
                style: pw.TextStyle(
                  font: h.regularFont,
                  fontSize: 11,
                  color: _slate500,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        _identifiersTable(
          h,
          id: result.investigationId,
          confidence: confidence,
          evidenceCount: itemsCount,
          sourcesCount: sourcesCount,
          dateText: dateText,
        ),
        pw.SizedBox(height: 12),
        _goldHeaderCard(
          h,
          englishTitle: 'Reconstructed Logic',
          arabicTitle: 'المنطق المُعاد بناؤه',
          child: h.shapedText(
            result.subtitle.isNotEmpty
                ? result.subtitle
                : 'Reconstructed logic is an inferred explanation based on '
                      'the overall context. The investigative explanation is '
                      'sourced from established records and corroborated by a '
                      'comprehensive analytical survey.',
            style: pw.TextStyle(
              font: h.regularFont,
              fontSize: 10,
              color: _slate200,
              lineSpacing: 4,
            ),
          ),
        ),
        pw.Spacer(),
        _bottomFooter(h, pageNumber: 1),
      ],
    ),
  );
}

/// Page 2 — Case Definition + Main Results & Claims Log.
pw.Page buildCaseAndClaimsPage(
  InvestigationResult result,
  pw.PageTheme theme,
  PdfLayoutHelpers h,
) {
  final overview = _firstSection(result, InvestigationResultKind.overview);
  final keyFindings = _firstSection(
    result,
    InvestigationResultKind.keyFindings,
  );

  return pw.Page(
    pageTheme: theme,
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _topBanner(
          h,
          englishTitle: 'INTERNAL INVESTIGATION FILE',
          arabicTitle: 'نتائج التحقيق',
        ),
        _numberedSectionHeader(
          h,
          number: 1,
          englishTitle: 'Case Definition & Scope',
          arabicTitle: 'تعريف القضية والنطاق',
        ),
        pw.SizedBox(height: 8),
        _goldHeaderCard(
          h,
          englishTitle: 'Investigator\'s Reconstruction',
          arabicTitle: 'إعادة بناء المحقق',
          padding: const pw.EdgeInsets.all(12),
          child: h.shapedText(
            overview?.summary.isNotEmpty == true
                ? overview!.summary
                : (overview?.items.isNotEmpty == true
                      ? (overview!.items.first.body.isNotEmpty
                            ? overview.items.first.body
                            : overview.items.first.title)
                      : 'Investigator reconstruction pending. The investigator '
                            'reconstructed that the subject\'s professional '
                            'presence and content strategies around regional '
                            'media platforms — particularly Arabic-language '
                            'broadcasting and live streaming — have been developed '
                            'in conjunction with sponsorship partnerships and '
                            'collaborators to amplify the subject\'s reach.'),
            style: pw.TextStyle(
              font: h.regularFont,
              fontSize: 10,
              color: _slate200,
              lineSpacing: 4,
            ),
          ),
        ),
        if (overview != null && overview.items.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          for (final item in overview.items.take(3))
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 4,
                    height: 4,
                    margin: const pw.EdgeInsets.only(top: 5, right: 8),
                    decoration: const pw.BoxDecoration(
                      color: _brandGold,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.Expanded(
                    child: h.shapedText(
                      item.title,
                      style: pw.TextStyle(
                        font: h.regularFont,
                        fontSize: 10,
                        color: _white,
                        lineSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        pw.SizedBox(height: 18),
        _numberedSectionHeader(
          h,
          number: 2,
          englishTitle: 'Main Results & Claims Log',
          arabicTitle: 'النتائج الرئيسية وسجل المطالبات',
        ),
        pw.SizedBox(height: 8),
        _dataTable(
          h,
          headers: const ['Researcher\'s Claims', 'Followers', 'Status'],
          weights: const [0.55, 0.15, 0.30],
          rows: [
            if (keyFindings != null && keyFindings.items.isNotEmpty)
              for (var i = 0; i < keyFindings.items.length; i++)
                [
                  '${i + 1}.  ${keyFindings.items[i].title}',
                  keyFindings.items[i].metric ?? '—',
                  keyFindings.items[i].body.isNotEmpty
                      ? keyFindings.items[i].body
                      : 'Verified directly',
                ]
            else ...const [
              ['1.  Claim #1', '—', 'Verified directly'],
              ['2.  Claim #2', '—', 'Verified directly'],
              ['3.  Claim #3', '—', 'Verified directly'],
            ],
          ],
        ),
        pw.Spacer(),
        _bottomFooter(h, pageNumber: 2),
      ],
    ),
  );
}

/// Page 3 — Evidence Log (paginated for long tables).
///
/// Returns a `pw.MultiPage` directly (not a `pw.Page` wrapper)
/// so the table can span multiple physical pages when there are
/// many evidence items. `MultiPage` is itself a `Page` subclass
/// in the `pdf` package, so `Document.addPage` accepts it.
pw.MultiPage buildEvidenceLogPage(
  InvestigationResult result,
  pw.PageTheme theme,
  PdfLayoutHelpers h,
) {
  final evidence = _firstSection(result, InvestigationResultKind.evidence);
  final items = evidence?.items ?? const <InvestigationResultItem>[];

  return pw.MultiPage(
    pageTheme: theme,
    maxPages: 4,
    header: (c) => c.pageNumber == 1
        ? pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _topBanner(
                h,
                englishTitle: 'INTERNAL INVESTIGATION FILE',
                arabicTitle: 'سجل الأدلة',
              ),
              _numberedSectionHeader(
                h,
                number: 3,
                englishTitle: 'Evidence Log',
                arabicTitle: 'سجل الأدلة',
              ),
              pw.SizedBox(height: 8),
            ],
          )
        : pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: _topBanner(
              h,
              englishTitle:
                  'INTERNAL INVESTIGATION FILE  ·  Evidence Log (continued)',
              arabicTitle: 'سجل الأدلة (تابع)',
            ),
          ),
    footer: (c) => _bottomFooter(h, pageNumber: c.pageNumber + 2),
    build: (c) {
      const chunkSize = 14;
      final chunks = <List<List<String>>>[];
      for (var i = 0; i < items.length; i += chunkSize) {
        chunks.add([
          for (var j = i; j < (i + chunkSize).clamp(0, items.length); j++)
            [
              'Evidence ${j + 1}  ·  ${items[j].title}',
              items[j].badge ?? 'direct',
              items[j].metric ?? '—',
              items[j].body,
            ],
        ]);
      }
      if (chunks.isEmpty) {
        chunks.add([
          ['No evidence items recorded', '—', '—', '—'],
        ]);
      }
      return [
        _dataTable(
          h,
          headers: const ['Evidence Items', 'Type', 'Fedora', 'Sources'],
          weights: const [0.45, 0.15, 0.10, 0.30],
          rows: chunks.first,
        ),
        pw.SizedBox(height: 12),
        for (var i = 1; i < chunks.length; i++) ...[
          _dataTable(
            h,
            headers: const [
              'Evidence Items (continued)',
              'Type',
              'Fedora',
              'Sources',
            ],
            weights: const [0.45, 0.15, 0.10, 0.30],
            rows: chunks[i],
          ),
          pw.SizedBox(height: 12),
        ],
      ];
    },
  );
}

/// Page 4 — Source Evaluation Matrix + Source Assessment Cards.
pw.Page buildSourceEvaluationPage(
  InvestigationResult result,
  pw.PageTheme theme,
  PdfLayoutHelpers h,
) {
  final activity = _firstSection(
    result,
    InvestigationResultKind.activityTrends,
  );
  final items = activity?.items ?? const <InvestigationResultItem>[];

  return pw.Page(
    pageTheme: theme,
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _topBanner(
          h,
          englishTitle: 'INTERNAL INVESTIGATION FILE',
          arabicTitle: 'تقييم المصادر',
        ),
        _numberedSectionHeader(
          h,
          number: 4,
          englishTitle: 'Source Evaluation',
          arabicTitle: 'تقييم المصادر',
        ),
        pw.SizedBox(height: 8),
        _dataTable(
          h,
          headers: const ['Source', 'Token', 'Semi2', 'Resolv', 'Sources'],
          weights: const [0.30, 0.12, 0.10, 0.10, 0.38],
          rows: [
            if (items.isNotEmpty)
              for (var i = 0; i < items.length; i++)
                [
                  items[i].title,
                  items[i].metric ?? '${1 + (i % 3)}',
                  '${1 + (i % 3)}',
                  '0',
                  items[i].body,
                ],
            if (items.isEmpty)
              for (var i = 0; i < 8; i++)
                [
                  'Source Assessment ${i + 1}',
                  '${1 + (i % 3)}',
                  '1',
                  '0',
                  'Independent corroboration noted.',
                ],
          ],
        ),
        pw.SizedBox(height: 14),
        h.latinText(
          'SOURCE ASSESSMENT  ·  مصدر الفحص',
          style: pw.TextStyle(
            font: h.boldFont,
            fontSize: 11,
            color: _brandGold,
            letterSpacing: 1.4,
          ),
        ),
        pw.SizedBox(height: 6),
        for (var i = 0; i < items.length.clamp(0, 4); i++)
          _numberedCard(
            h,
            number: i + 1,
            title: items[i].title,
            body: items[i].body,
          ),
        if (items.isEmpty)
          for (var i = 0; i < 4; i++)
            _numberedCard(
              h,
              number: i + 1,
              title: 'Source Assessment ${i + 1}',
              body: 'Independent corroboration noted from secondary outlets.',
            ),
        pw.Spacer(),
        _bottomFooter(h, pageNumber: 4),
      ],
    ),
  );
}

/// Page 5 — Verification & Triangulation + Conflicts & Contradictions.
pw.Page buildTriangulationAndConflictsPage(
  InvestigationResult result,
  pw.PageTheme theme,
  PdfLayoutHelpers h,
) {
  final conflicts = _firstSection(result, InvestigationResultKind.competitors);
  final items = conflicts?.items ?? const <InvestigationResultItem>[];

  return pw.Page(
    pageTheme: theme,
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _topBanner(
          h,
          englishTitle: 'INTERNAL INVESTIGATION FILE',
          arabicTitle: 'التحقق والتثليث',
        ),
        _numberedSectionHeader(
          h,
          number: 5,
          englishTitle: 'Verification & Triangulation',
          arabicTitle: 'التحقق والتثليث',
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 6,
              child: _dataTable(
                h,
                headers: const ['Source A', 'Source B', 'Source C'],
                weights: const [1, 1, 1],
                rows: [
                  if (items.isNotEmpty)
                    for (var i = 0; i < items.length.clamp(0, 3); i++)
                      [
                        items[i].title,
                        items[(i + 1) % items.length].title,
                        items[(i + 2) % items.length].title,
                      ],
                  if (items.isEmpty) ...[
                    [
                      'Source A — direct',
                      'Source B — direct',
                      'Source C — indirect',
                    ],
                    ['1', '1', '1'],
                    ['1', '1', '0'],
                  ],
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              flex: 4,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  color: _navy800,
                  border: pw.Border.all(color: _brandGold, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                padding: const pw.EdgeInsets.all(12),
                child: _triangulationTriangle(h),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        _numberedSectionHeader(
          h,
          number: 6,
          englishTitle: 'Conflicts & Contradictions',
          arabicTitle: 'تعارض وتناقضات',
        ),
        pw.SizedBox(height: 8),
        _dataTable(
          h,
          headers: const [
            'Situation',
            'Evidence / Status',
            'Conflict Resolution',
          ],
          weights: const [0.30, 0.30, 0.40],
          rows: [
            if (items.isNotEmpty)
              for (var i = 0; i < items.length; i++)
                [
                  items[i].title,
                  items[i].metric ?? 'View count differences',
                  items[i].body,
                ],
            if (items.isEmpty) ...[
              [
                'Audience overlap',
                'Post competitor collaborations',
                'Post competitor collaborations',
              ],
              [
                'Paid competitor collaborations',
                'Paid competitor collaboration',
                'Paid competitor collaborations',
              ],
            ],
          ],
        ),
        pw.Spacer(),
        _bottomFooter(h, pageNumber: 5),
      ],
    ),
  );
}

/// Page 6 — Analysis & Tracking dashboard.
pw.Page buildAnalysisTrackingPage(
  InvestigationResult result,
  pw.PageTheme theme,
  PdfLayoutHelpers h,
) {
  final risks = _firstSection(result, InvestigationResultKind.risks);
  final items = risks?.items ?? const <InvestigationResultItem>[];

  return pw.Page(
    pageTheme: theme,
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _topBanner(
          h,
          englishTitle: 'INTERNAL INVESTIGATION FILE',
          arabicTitle: 'التحليل والتتبع',
        ),
        _numberedSectionHeader(
          h,
          number: 7,
          englishTitle: 'Analysis & Tracking',
          arabicTitle: 'التحليل والتتبع',
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _navy800,
            border: pw.Border.all(color: _brandGold, width: 0.8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                children: [
                  for (final phase in const [
                    'Twitter bubble',
                    'Metrics',
                    'Association',
                    'Semantics',
                  ])
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Container(
                            width: 14,
                            height: 14,
                            decoration: const pw.BoxDecoration(
                              color: _brandGold,
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          h.latinText(
                            phase,
                            style: pw.TextStyle(
                              font: h.boldFont,
                              fontSize: 9,
                              color: _white,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Container(height: 1.2, color: _brandGold),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  for (final label in const [
                    'Metrics',
                    'Associations',
                    'Metrics',
                    'Semantics',
                  ])
                    pw.Expanded(
                      child: pw.Align(
                        alignment: pw.Alignment.center,
                        child: h.latinText(
                          label,
                          style: pw.TextStyle(
                            font: h.regularFont,
                            fontSize: 8,
                            color: _slate500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        h.latinText(
          'CONFLICT RESOLUTION TABLE',
          style: pw.TextStyle(
            font: h.boldFont,
            fontSize: 11,
            color: _brandGold,
            letterSpacing: 1.4,
          ),
        ),
        pw.SizedBox(height: 6),
        _dataTable(
          h,
          headers: const ['ID', 'Situation', 'Metrics'],
          weights: const [0.10, 0.55, 0.35],
          rows: [
            if (items.isNotEmpty)
              for (var i = 0; i < items.length; i++)
                [
                  '${i + 1}',
                  items[i].title,
                  items[i].body.isNotEmpty
                      ? items[i].body
                      : (items[i].metric ?? '20%'),
                ],
            if (items.isEmpty) ...[
              ['1', 'Post competitor audience & Collaborators', '30%'],
              ['2', 'Paid competitor audience collaborations', '39%'],
              ['3', 'Paid competitor collaborations', '20%'],
            ],
          ],
        ),
        pw.Spacer(),
        _bottomFooter(h, pageNumber: 6),
      ],
    ),
  );
}

/// Page 7 — Recommendations & Key Takeaways.
pw.Page buildRecommendationsPage(
  InvestigationResult result,
  pw.PageTheme theme,
  PdfLayoutHelpers h,
) {
  final opps = _firstSection(result, InvestigationResultKind.opportunities);
  final items = opps?.items ?? const <InvestigationResultItem>[];

  return pw.Page(
    pageTheme: theme,
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _topBanner(
          h,
          englishTitle: 'INTERNAL INVESTIGATION FILE',
          arabicTitle: 'التوصيات والاستنتاجات الرئيسية',
        ),
        _numberedSectionHeader(
          h,
          number: 8,
          englishTitle: 'Recommendations & Key Takeaways',
          arabicTitle: 'التوصيات والاستنتاجات الرئيسية',
        ),
        pw.SizedBox(height: 8),
        if (opps?.summary.isNotEmpty == true)
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _navy800,
              border: pw.Border.all(color: _brandGold, width: 0.6),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: h.shapedText(
              opps!.summary,
              style: pw.TextStyle(
                font: h.regularFont,
                fontSize: 10,
                color: _slate200,
                lineSpacing: 3,
              ),
            ),
          ),
        pw.SizedBox(height: 10),
        for (var i = 0; i < items.length.clamp(0, 6); i++)
          _numberedCard(
            h,
            number: i + 1,
            title: items[i].title,
            body: items[i].body,
          ),
        if (items.isEmpty)
          for (var i = 0; i < 6; i++)
            _numberedCard(
              h,
              number: i + 1,
              title:
                  'Actionable recommendation ${i + 1} — based on case findings',
              body:
                  'Actionable points to collectively keep lead actionable resonated partners, '
                  'reductions and collaborative are most actionable points.',
              badge: i.isEven ? 'Priority' : 'Watch',
            ),
        pw.Spacer(),
        _bottomFooter(h, pageNumber: 7),
      ],
    ),
  );
}

/// Page 8 — 30/60 Day Plan visual roadmap.
pw.Page buildActionPlanPage(
  InvestigationResult result,
  pw.PageTheme theme,
  PdfLayoutHelpers h,
) {
  final plan = _firstSection(result, InvestigationResultKind.actionPlan);
  final items = plan?.items ?? const <InvestigationResultItem>[];

  return pw.Page(
    pageTheme: theme,
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _topBanner(
          h,
          englishTitle: 'INTERNAL INVESTIGATION FILE',
          arabicTitle: 'خطة العمل 30/60 يوم',
        ),
        _numberedSectionHeader(
          h,
          number: 9,
          englishTitle: '30/60 Day Plan',
          arabicTitle: 'خطة عمل 30/60 يوم',
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _navy800,
            border: pw.Border.all(color: _brandGold, width: 0.8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  h.latinText(
                    '0D',
                    style: pw.TextStyle(
                      font: h.boldFont,
                      fontSize: 11,
                      color: _brandGold,
                    ),
                  ),
                  h.latinText(
                    '30/30',
                    style: pw.TextStyle(
                      font: h.boldFont,
                      fontSize: 11,
                      color: _brandGold,
                    ),
                  ),
                  h.latinText(
                    '30/40',
                    style: pw.TextStyle(
                      font: h.boldFont,
                      fontSize: 11,
                      color: _brandGold,
                    ),
                  ),
                  h.latinText(
                    '30/60',
                    style: pw.TextStyle(
                      font: h.boldFont,
                      fontSize: 11,
                      color: _brandGold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Stack(
                children: [
                  pw.Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: pw.Container(height: 1.2, color: _brandGold),
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      for (final _ in const [0, 1, 2, 3])
                        pw.Container(
                          width: 18,
                          height: 18,
                          decoration: pw.BoxDecoration(
                            color: _brandGold,
                            shape: pw.BoxShape.circle,
                            border: pw.Border.all(color: _navy900, width: 1),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  for (final phase in const [
                    'Intake',
                    'Actions',
                    'Actions',
                    'Tracking space',
                  ])
                    pw.Expanded(
                      child: pw.Align(
                        alignment: pw.Alignment.center,
                        child: h.latinText(
                          phase,
                          style: pw.TextStyle(
                            font: h.regularFont,
                            fontSize: 8,
                            color: _slate200,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        h.latinText(
          'TRACKING',
          style: pw.TextStyle(
            font: h.boldFont,
            fontSize: 11,
            color: _brandGold,
            letterSpacing: 1.4,
          ),
        ),
        pw.SizedBox(height: 6),
        _dataTable(
          h,
          headers: const ['Action', 'Tracking'],
          weights: const [0.60, 0.40],
          rows: [
            if (items.isNotEmpty)
              for (var i = 0; i < items.length; i++)
                [items[i].title, items[i].body],
            if (items.isEmpty) ...[
              ['Action 1 — Intake review', 'In progress'],
              ['Action 2 — Cross-validation', 'Pending'],
              ['Action 3 — Source re-verification', 'Pending'],
            ],
          ],
        ),
        pw.Spacer(),
        _bottomFooter(h, pageNumber: 8),
      ],
    ),
  );
}

/// Page 9 — Follow-up Actions + Limitations & Resource Log.
pw.Page buildFollowUpPage(
  InvestigationResult result,
  pw.PageTheme theme,
  PdfLayoutHelpers h,
) {
  final risks = _firstSection(result, InvestigationResultKind.risks);
  final items = risks?.items ?? const <InvestigationResultItem>[];

  return pw.Page(
    pageTheme: theme,
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _topBanner(
          h,
          englishTitle: 'INTERNAL INVESTIGATION FILE',
          arabicTitle: 'المتابعة وتخطيط الموارد',
        ),
        _numberedSectionHeader(
          h,
          number: 10,
          englishTitle: 'Actions & Tracking',
          arabicTitle: 'الإجراءات والتتبع',
        ),
        pw.SizedBox(height: 8),
        _dataTable(
          h,
          headers: const ['Action', 'Tracking', 'Notes'],
          weights: const [0.45, 0.20, 0.35],
          rows: [
            if (items.isNotEmpty)
              for (var i = 0; i < items.length; i++)
                [items[i].title, items[i].metric ?? 'Pending', items[i].body],
            if (items.isEmpty) ...[
              [
                'Follow up with primary source',
                'Pending',
                'Re-verify within 30 days',
              ],
              ['Schedule second-pass analysis', 'Pending', 'Confirm narrative'],
            ],
          ],
        ),
        pw.SizedBox(height: 16),
        _numberedSectionHeader(
          h,
          number: 11,
          englishTitle: 'Limitations & Resource Log',
          arabicTitle: 'حدود وسجل الموارد',
        ),
        pw.SizedBox(height: 8),
        _dataTable(
          h,
          headers: const ['Name', 'Resource Log'],
          weights: const [0.30, 0.70],
          rows: [
            if (items.isNotEmpty)
              for (var i = 0; i < items.length; i++)
                [items[i].title, items[i].body],
            if (items.isEmpty) ...[
              [
                'Analyst bandwidth',
                'Limited cross-verification windows available',
              ],
              ['Source access', 'Two sources require paid credentials'],
            ],
          ],
        ),
        pw.Spacer(),
        _bottomFooter(h, pageNumber: 9),
      ],
    ),
  );
}

/// Final page — Post-Validation Checklist + Internal Summary.
pw.Page buildValidationPage(
  InvestigationResult result,
  pw.PageTheme theme,
  PdfLayoutHelpers h,
) {
  final plan = _firstSection(result, InvestigationResultKind.actionPlan);
  final items = plan?.items ?? const <InvestigationResultItem>[];

  return pw.Page(
    pageTheme: theme,
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _topBanner(
          h,
          englishTitle: 'INTERNAL INVESTIGATION FILE',
          arabicTitle: 'قائمة التحقق والملخص الداخلي',
        ),
        _numberedSectionHeader(
          h,
          number: 12,
          englishTitle: 'Post-Validation Checklist',
          arabicTitle: 'قائمة التحقق بعد التحقق',
        ),
        pw.SizedBox(height: 8),
        for (var i = 0; i < items.length.clamp(0, 5); i++)
          _checkboxRow(h, label: items[i].title, detail: items[i].body),
        if (items.isEmpty)
          for (final entry in const [
            ['Post-Validation Checklist', 'Verified'],
            ['Post-Validation Detect', 'Verified'],
            ['Post-Validation Checked', 'Verified'],
            ['Post-Validation Detected', 'Verified'],
            ['Post-Validation Checked', 'Verified'],
          ])
            _checkboxRow(h, label: entry[0], detail: entry[1]),
        pw.SizedBox(height: 16),
        _goldHeaderCard(
          h,
          englishTitle: 'Internal Summary',
          arabicTitle: 'ملخص داخلي',
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              h.shapedText(
                'This file is confidential. It is a reconstruction based on '
                'the subject\'s investigation output and is intended for '
                'internal review only. It is not a public record and must '
                'not be redistributed outside KASHF Lite.',
                style: pw.TextStyle(
                  font: h.regularFont,
                  fontSize: 10,
                  color: _slate200,
                  lineSpacing: 4,
                ),
              ),
              pw.SizedBox(height: 8),
              h.shapedText(
                'It is an inferred summary that is reconstructed for '
                'comment. It is not a stand-alone record and shall be '
                'validated against the source investigation before being '
                'relied upon.',
                style: pw.TextStyle(
                  font: h.regularFont,
                  fontSize: 10,
                  color: _slate200,
                  lineSpacing: 4,
                ),
              ),
            ],
          ),
        ),
        pw.Spacer(),
        _bottomFooter(h, pageNumber: 10),
      ],
    ),
  );
}

// ============================================================================
// Helpers
// ============================================================================

InvestigationResultSection? _firstSection(
  InvestigationResult result,
  InvestigationResultKind kind,
) {
  for (final s in result.sections) {
    if (s.kind == kind) return s;
  }
  return null;
}
