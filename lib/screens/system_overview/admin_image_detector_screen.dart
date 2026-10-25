import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_strings.dart';
import '../../services/ai/image_detector_service.dart';
import '../../theme.dart';

/// Admin-only forensic tool that analyzes images via OpenRouter with
/// the vision AI model to detect whether an image is AI generated,
/// calculate the probability percentage, and identify the AI model/engine
/// used to create it.
class AdminImageDetectorScreen extends StatefulWidget {
  const AdminImageDetectorScreen({super.key});

  @override
  State<AdminImageDetectorScreen> createState() =>
      _AdminImageDetectorScreenState();
}

class _AdminImageDetectorScreenState extends State<AdminImageDetectorScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  String? _imageName;
  int _imageSize = 0;

  bool _isAnalyzing = false;
  String? _errorMessage;
  ImageAiDetectionResult? _result;

  late final AnimationController _scanAnimController;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scanAnimation = CurvedAnimation(
      parent: _scanAnimController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scanAnimController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (xfile == null) return;

      final bytes = await xfile.readAsBytes();
      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _imageName = xfile.name;
        _imageSize = bytes.lengthInBytes;
        _result = null;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _startScan() async {
    if (_imageBytes == null) return;
    final l = AppLocalizations.of(context);

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final res = await ImageAiDetectorService.instance.detectImage(
        imageBytes: _imageBytes!,
        fileName: _imageName ?? 'image.jpg',
        language: l.language.code,
      );

      if (!mounted) return;
      setState(() {
        _result = res;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.t('ai_img_scan_error')}: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
      _imageSize = 0;
      _result = null;
      _errorMessage = null;
      _isAnalyzing = false;
    });
  }

  void _copyReportToClipboard(AppLocalizations l) {
    if (_result == null) return;
    final r = _result!;
    final buf = StringBuffer();
    buf.writeln('=== KASHF Lite - AI Image Forensics Report ===');
    buf.writeln('Verdict: ${r.verdictLabel} (${r.verdict})');
    buf.writeln('AI Probability: ${r.aiPercentage}%');
    buf.writeln('Authentic Probability: ${r.realPercentage}%');
    buf.writeln('Suspected AI Engine: ${r.aiModel} (Confidence: ${r.modelConfidence}%)');
    if (r.modelReasoning.isNotEmpty) {
      buf.writeln('Model Reasoning: ${r.modelReasoning}');
    }
    buf.writeln('\nSummary:\n${r.summary}');
    if (r.artifacts.isNotEmpty) {
      buf.writeln('\nDetected Indicators:');
      for (final a in r.artifacts) {
        buf.writeln('• [${a.indicatesAi ? "AI Indicator" : "Authentic Sign"}] (${a.type}): ${a.description}');
      }
    }
    buf.writeln('\nTimestamp: ${r.scannedAt.toIso8601String()}');

    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.t('ai_img_copied')),
        backgroundColor: KashfColors.gold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: palette.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('ai_img_scanner_title'),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l.t('ai_img_scanner_subtitle'),
              style: TextStyle(
                color: KashfColors.gold,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsetsDirectional.only(end: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, color: Color(0xFF8B5CF6), size: 14),
                SizedBox(width: 4),
                Text(
                  'AI Vision',
                  style: TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Upload or Preview Card
            _buildImageCard(palette, l),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _buildErrorBanner(palette),
            ],

            if (_isAnalyzing) ...[
              const SizedBox(height: 20),
              _buildAnalyzingState(palette, l),
            ],

            if (_result != null && !_isAnalyzing) ...[
              const SizedBox(height: 20),
              _buildResultsDashboard(palette, l, _result!),
            ],
          ],
        ),
      ),
    );
  }

  // ============================ Image Selection & Preview ============================

  Widget _buildImageCard(KashfPalette palette, AppLocalizations l) {
    if (_imageBytes == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: palette.cardBorder,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: KashfColors.gold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: KashfColors.gold.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.image_search_rounded,
                color: KashfColors.gold,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.t('ai_img_upload_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.t('ai_img_upload_sub'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(l.t('ai_img_btn_gallery')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.surfaceLight,
                      foregroundColor: palette.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: palette.cardBorder),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text(l.t('ai_img_btn_camera')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.surfaceLight,
                      foregroundColor: palette.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: palette.cardBorder),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Preview with scan animation overlay if analyzing
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: Image.memory(
                    _imageBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Top Overlay Bar: Info badge + Close button
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '${_imageName ?? "image"} • ${_formatFileSize(_imageSize)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _isAnalyzing ? null : _clearImage,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              // Laser / Scan line when analyzing
              if (_isAnalyzing)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, _) {
                      return Stack(
                        children: [
                          Container(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          ),
                          Align(
                            alignment: Alignment(0, (_scanAnimation.value * 2) - 1),
                            child: Container(
                              height: 3,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: KashfColors.gold,
                                boxShadow: [
                                  BoxShadow(
                                    color: KashfColors.gold.withValues(alpha: 0.8),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),

          // Bottom Bar of Card
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isAnalyzing
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l.t('ai_img_btn_gallery')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.textSecondary,
                    side: BorderSide(color: palette.cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _startScan,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.bolt, size: 18),
                    label: Text(
                      _isAnalyzing
                          ? l.t('ai_img_scanning')
                          : l.t('ai_img_btn_scan'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KashfColors.gold,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingState(KashfPalette palette, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.t('ai_img_scanning'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.t('ai_img_scanning_sub'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(KashfPalette palette) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ============================ Results Dashboard ============================

  Widget _buildResultsDashboard(
    KashfPalette palette,
    AppLocalizations l,
    ImageAiDetectionResult r,
  ) {
    final isAi = r.isAiGenerated;
    final themeColor = isAi ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    final verdictIcon = isAi ? Icons.smart_toy_outlined : Icons.camera_alt_outlined;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Prominent Verdict Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: themeColor.withValues(alpha: 0.45), width: 1.5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: themeColor.withValues(alpha: 0.6)),
                    ),
                    child: Icon(verdictIcon, color: themeColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.verdictLabel,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAi
                              ? '${r.aiPercentage}% ${l.t("ai_img_prob_ai")}'
                              : '${r.realPercentage}% ${l.t("ai_img_prob_real")}',
                          style: TextStyle(
                            color: themeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dual comparative percentage visual bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${l.t("ai_img_prob_ai")}: ${r.aiPercentage}%',
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${l.t("ai_img_prob_real")}: ${r.realPercentage}%',
                        style: const TextStyle(
                          color: Color(0xFF22C55E),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          Expanded(
                            flex: r.aiPercentage.clamp(1, 99),
                            child: Container(color: const Color(0xFFEF4444)),
                          ),
                          Expanded(
                            flex: r.realPercentage.clamp(1, 99),
                            child: Container(color: const Color(0xFF22C55E)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Identified AI Model Card (Primary Requirement)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.memory_outlined,
                      color: Color(0xFF8B5CF6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.t('ai_img_model_identified'),
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.aiModel,
                          style: const TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${r.modelConfidence}%',
                      style: const TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              if (r.modelReasoning.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    r.modelReasoning,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. Forensic Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, color: KashfColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    l.t('ai_img_summary_title'),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                r.summary,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        if (r.artifacts.isNotEmpty) ...[
          const SizedBox(height: 14),
          // 4. Detected Visual Indicators & Artifacts
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF3B82F6), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      l.t('ai_img_artifacts_title'),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final a in r.artifacts) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: palette.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: a.indicatesAi
                            ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                            : const Color(0xFF22C55E).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          a.indicatesAi ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                          color: a.indicatesAi ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.type.toUpperCase().replaceAll('_', ' '),
                                style: TextStyle(
                                  color: a.indicatesAi
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF22C55E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                a.description,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        if (r.technicalDetails.isNotEmpty) ...[
          const SizedBox(height: 14),
          // 5. Technical Assessments Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_outlined, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      l.t('ai_img_tech_title'),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final entry in r.technicalDetails.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ${entry.key.replaceAll('_', ' ')}: ',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Action Buttons: Copy Report & Re-scan
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copyReportToClipboard(l),
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: Text(l.t('ai_img_copy_report')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.textPrimary,
                  side: BorderSide(color: palette.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _clearImage,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(l.t('ai_img_scan_another')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KashfColors.gold,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
