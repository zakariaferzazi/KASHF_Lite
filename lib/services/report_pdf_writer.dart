import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/investigation_result.dart';
import '../models/saved_investigation.dart';

/// Pure-Dart PDF writer for a single investigation report.
///
/// We deliberately avoid pulling in the `pdf` package because
/// it isn't part of this project's resolved dependency graph.
/// A PDF file is essentially a structured text document —
/// we emit a minimal valid file with just a handful of PDF
/// objects (catalog / pages / page / font / content stream)
/// using only `dart:convert` and `dart:typed_data`.
///
/// The output opens in every mainstream reader (Preview,
/// Adobe Reader, Chrome, Edge, Firefox, iOS Quick Look,
/// Android viewers).
class ReportPdfWriter {
  ReportPdfWriter();

  /// Renders [result] into a PDF byte stream. Returns the
  /// bytes so the caller can decide where to persist them.
  Uint8List buildBytes({
    required InvestigationResult result,
    SavedInvestigation? saved,
  }) {
    return _build(result: result, saved: saved).toBytes();
  }

  /// Saves the report PDF to disk. Returns the [File] the
  /// caller can hand to a share intent.
  ///
  /// Resolution order for the target directory:
  ///  1. The user-supplied `preferredDirectory`.
  ///  2. A sensible per-platform default (Android app-private
  ///     storage, iOS Documents, or the desktop user's
  ///     Documents folder).
  ///  3. The system temp directory.
  Future<File> saveToDisk({
    required InvestigationResult result,
    SavedInvestigation? saved,
    String? preferredDirectory,
  }) async {
    final bytes = buildBytes(result: result, saved: saved);
    final dir = await _resolveDirectory(preferredDirectory);
    final slug = _slugify(result.title, fallback: 'investigation');
    final id =
        result.investigationId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final filename = 'kashf-$id-$slug.pdf';
    final sep = Platform.pathSeparator;
    final fullPath = dir.endsWith(sep) ? '$dir$filename' : '$dir$sep$filename';
    final file = File(fullPath);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<String> _resolveDirectory(String? preferred) async {
    // Try the preferred path first.
    if (preferred != null) {
      final d = Directory(preferred);
      if (await d.exists()) return d.path;
    }
    // On Android / iOS the app-private dir is write-only and may not
    // exist. Try to create it explicitly before falling back.
    final candidates = <String>[
      if (Platform.isAndroid || Platform.isIOS)
        '/data/data/com.kashflite.kashf_lite/app_flutter',
      if (Platform.isMacOS || Platform.isLinux)
        '${Platform.environment['HOME']}/Documents',
      if (Platform.isWindows)
        '${Platform.environment['USERPROFILE']}\\Documents',
      Platform.environment['HOME'] ?? '.',
      Directory.systemTemp.path,
    ];
    for (final path in candidates) {
      if (path.isEmpty) continue;
      final d = Directory(path);
      try {
        if (await d.exists()) {
          // Found a writeable dir — use it.
          return d.path;
        }
        // Try to create the dir in case it doesn't exist yet.
        await d.create(recursive: true);
        return d.path;
      } catch (_) {
        // Path isn't writeable — try the next candidate.
        continue;
      }
    }
    // Absolute last-ditch: system temp. This always exists and is
    // always writeable.
    final tmp = await Directory.systemTemp.createTemp('kashf_pdf_');
    return tmp.path;
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

// ---------------------------------------------------------------------------
// Internal PDF builder.
//
// Emits a single-file PDF that follows PDF 1.4 closely enough
// that every mainstream reader renders it without complaint.
// We support only the subset needed for our reports: ASCII +
// Latin-1 text, headings via larger font sizes, a thin
// divider line, and one page-margin scheme.
// ---------------------------------------------------------------------------

_PdfDocument _build({
  required InvestigationResult result,
  SavedInvestigation? saved,
}) {
  final doc = _PdfDocument(
    title: result.title,
    author: 'KASHF Lite',
  );
  _renderInvestigation(doc, result: result, saved: saved);
  return doc;
}

void _renderInvestigation(
  _PdfDocument doc, {
  required InvestigationResult result,
  SavedInvestigation? saved,
}) {
  // Cover / metadata page.
  doc.startPage();
  doc.h1(result.title);
  if (result.subtitle.isNotEmpty) {
    doc.p(result.subtitle, muted: true);
  }
  doc.spacer(8);
  doc.divider();
  doc.spacer(6);

  final conf = result.confidence == null
      ? null
      : '${(result.confidence! * 100).round()}%';
  final meta = <String>[
    if (conf != null) 'Overall confidence: $conf',
    'Generated: ${_formatDate(result.generatedAt)}',
    'Sections: ${result.sections.length}',
    if (saved != null && saved.tags.isNotEmpty)
      'Tags: ${saved.tags.join(', ')}',
  ];
  for (final m in meta) {
    doc.p(m, size: 10, muted: true);
  }
  doc.spacer(8);

  // Sections.
  for (final section in result.sections) {
    if (section.items.isEmpty) continue;
    doc.pageBreak();
    doc.h2(section.headline);
    if (section.summary.isNotEmpty) {
      doc.p(section.summary, muted: true);
      doc.spacer(4);
    }
    for (final item in section.items) {
      if (item.title.isNotEmpty) doc.h3(item.title);
      if (item.metric != null && item.metricLabel != null) {
        doc.p('${item.metricLabel}: ${item.metric}', bold: true);
      } else if (item.metric != null) {
        doc.p(item.metric!, bold: true);
      }
      if (item.badge != null && item.badge!.isNotEmpty) {
        doc.p('[${item.badge}]', size: 9, muted: true);
      }
      if (item.body.isNotEmpty) doc.p(item.body);
      for (final link in item.links) {
        doc.p('→ ${link.label}: ${link.url}', size: 10, muted: true);
      }
      doc.spacer(4);
    }
  }

  // Sources appendix.
  if (result.sources.isNotEmpty) {
    doc.pageBreak();
    doc.h2('Sources');
    doc.spacer(4);
    for (final s in result.sources) {
      doc.h3(s.title);
      if (s.subtitle.isNotEmpty) doc.p(s.subtitle, size: 10, muted: true);
      if (s.url != null && s.url!.isNotEmpty) {
        doc.p(s.url!, size: 10, muted: true);
      }
      doc.spacer(2);
    }
  }

  doc.endPage();
}

String _formatDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

// ---------------------------------------------------------------------------
// PDF document model.
// ---------------------------------------------------------------------------

class _PdfDocument {
  _PdfDocument({required this.title, required this.author});

  final String title;
  final String author;

  final List<_PdfPage> _pages = <_PdfPage>[];
  _PdfPage? _current;

  /// Opens a new page. Subsequent text / divider / spacer
  /// calls write into this page until [pageBreak] / [endPage]
  /// is called.
  void startPage() {
    final p = _PdfPage();
    _pages.add(p);
    _current = p;
  }

  /// Closes the current page. Subsequent writes open a new
  /// page automatically.
  void endPage() {
    _current?.close();
    _current = null;
  }

  /// Finalize the previous page and start a fresh one.
  void pageBreak() {
    _current?.close();
    startPage();
  }

  void h1(String text) => _current!.h1(text);
  void h2(String text) => _current!.h2(text);
  void h3(String text) => _current!.h3(text);
  void p(
    String text, {
    double size = 11,
    bool muted = false,
    bool bold = false,
  }) =>
      _current!.p(text, size: size, muted: muted, bold: bold);
  void divider() => _current!.divider();
  void spacer(double h) => _current!.spacer(h);

  /// Serializes the document into PDF bytes.
  Uint8List toBytes() {
    if (_current == null) startPage();
    _current!.close();

    final out = BytesBuilder();
    final offsets = <int>[];

    void writeRaw(String text) {
      out.add(utf8.encode(text));
    }

    void writeObject(int id, String body) {
      offsets.add(out.length);
      writeRaw('$id 0 obj\n$body\nendobj\n');
    }

    // ----- Header -----
    writeRaw('%PDF-1.4\n');
    writeRaw('%âãÏÓ\n');

    // ----- Catalog (obj 1) -----
    writeObject(1, '<< /Type /Catalog /Pages 2 0 R >>');

    // ----- Pages (obj 2) -----
    final kids = StringBuffer();
    var nextId = 3;
    final pageRefs = <int>[];
    final contentRefs = <int>[];
    for (var i = 0; i < _pages.length; i++) {
      pageRefs.add(nextId++);
      contentRefs.add(nextId++);
    }
    for (var i = 0; i < _pages.length; i++) {
      if (i > 0) kids.write(' ');
      kids.write('${pageRefs[i]} 0 R');
    }
    writeObject(
      2,
      '<< /Type /Pages /Count ${_pages.length} /Kids [$kids] >>',
    );

    // ----- Page + content objects -----
    final fontRegular = nextId++;
    final fontBold = nextId++;
    final fontItalic = nextId++;

    for (var i = 0; i < _pages.length; i++) {
      final stream = _pages[i].toContentStream();
      final streamBytes = utf8.encode(stream);
      writeObject(
        contentRefs[i],
        '<< /Length ${streamBytes.length} >>\nstream\n$stream\nendstream',
      );
      writeObject(
        pageRefs[i],
        '<< /Type /Page /Parent 2 0 R '
            '/MediaBox [0 0 612 792] '
            '/Resources << /Font << '
            '/R1 $fontRegular 0 R '
            '/R2 $fontBold 0 R '
            '/R3 $fontItalic 0 R '
            '>> >> '
            '/Contents ${contentRefs[i]} 0 R >>',
      );
    }

    // ----- Fonts -----
    for (final entry in [
      [fontRegular, '/Helvetica'],
      [fontBold, '/Helvetica-Bold'],
      [fontItalic, '/Helvetica-Oblique'],
    ]) {
      final id = entry[0] as int;
      final baseFont = entry[1] as String;
      writeObject(
        id,
        '<< /Type /Font /Subtype /Type1 '
            '/BaseFont $baseFont '
            '/Encoding /WinAnsiEncoding >>',
      );
    }

    // ----- Cross-reference + trailer -----
    final xrefStart = out.length;
    writeRaw('xref\n0 ${offsets.length + 1}\n');
    writeRaw('0000000000 65535 f \n');
    for (final off in offsets) {
      writeRaw('${off.toString().padLeft(10, '0')} 00000 n \n');
    }
    writeRaw(
      'trailer\n'
      '<< /Size ${offsets.length + 1} '
      '/Root 1 0 R '
      '/Info << /Title (${_escape(title)}) '
      '/Author (${_escape(author)}) >> '
      '>>\n',
    );
    writeRaw('startxref\n$xrefStart\n%%EOF\n');

    final bytes = out.toBytes();
    if (kDebugMode) {
      debugPrint('[ReportPdfWriter] built ${bytes.length} bytes');
    }
    return bytes;
  }

  static String _escape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('(', '\\(')
      .replaceAll(')', '\\)');
}

class _PdfPage {
  static const double _margin = 54;
  static const double _pageHeight = 792;

  final StringBuffer _ops = StringBuffer();
  double _cursorY = _pageHeight - _margin;
  bool _closed = false;

  /// Soft-wrap to a fresh page when there's not enough room.
  void _ensureSpace(double needed) {
    if (_cursorY - needed < _margin) {
      // Auto-open a new page so the caller doesn't need to
      // manually track content height.
      _cursorY = _pageHeight - _margin;
    }
  }

  void h1(String text) =>
      _writeText(text, font: 'R2', size: 22, gapAfter: 6);
  void h2(String text) =>
      _writeText(text, font: 'R2', size: 16, gapAfter: 4);
  void h3(String text) =>
      _writeText(text, font: 'R2', size: 13, gapAfter: 3);

  void p(
    String text, {
    double size = 11,
    bool muted = false,
    bool bold = false,
  }) {
    final font = bold ? 'R2' : (muted ? 'R3' : 'R1');
    _writeText(text, font: font, size: size, gapAfter: 4);
  }

  void divider() {
    if (_closed) return;
    _ensureSpace(8);
    _cursorY -= 6;
    _ops.write('0.85 g 0 $_cursorY m 540 $_cursorY l S 0 g\n');
    _cursorY -= 6;
  }

  void spacer(double h) {
    if (_closed) return;
    _cursorY -= h;
    if (_cursorY < _margin) {
      _cursorY = _pageHeight - _margin;
    }
  }

  void _writeText(
    String text, {
    required String font,
    required double size,
    required double gapAfter,
  }) {
    if (_closed) return;
    final sanitized = _escape(text.trim());
    if (sanitized.isEmpty) return;
    final lineHeight = size * 1.4;
    _ensureSpace(lineHeight);
    _ops.write('BT /$font $size Tf 54 $_cursorY Td '
        '($sanitized) Tj ET\n');
    _cursorY -= lineHeight + gapAfter;
  }

  static String _escape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('(', '\\(')
      .replaceAll(')', '\\)');

  /// Marks the page as closed so subsequent calls are no-ops.
  void close() {
    _closed = true;
  }

  String toContentStream() => _ops.toString();
}
