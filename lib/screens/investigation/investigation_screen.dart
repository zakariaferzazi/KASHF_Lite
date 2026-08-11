import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../l10n/app_strings.dart';
import '../../models/entity_type.dart';
import '../../models/evidence.dart';
import '../../models/investigation.dart';
import '../../models/investigation_action.dart';
import '../../services/investigation_archive_service.dart';
import '../../services/investigation_service.dart';
import '../../state/investigation_controller.dart';
import '../../theme.dart';
import 'investigation_results_screen.dart';

/// "تحقيق جديد" / "New Investigation" — fully wired-up version of
/// the original demo screen. Each section is now backed by an
/// [InvestigationController] and tapping the CTA spins up an
/// [InvestigationService] run, which renders the results screen.
///
/// Visual order (left → right as drawn):
///
///   ┌─ top bar ────────────────────────────────────┐
///   │ [X] ····················· [🧠  تحقيق جديد]  │
///   └──────────────────────────────────────────────┘
///   ┌─ Smart search card (purple border) ─────────┐
///   │  🧠  البحث الذكي                              │
///   │  ابحث عن أي شيء يثير اهتمامك…              │
///   │  ┌──────────── search field ────────────┐    │
///   │  │ 🔍 ابحث عن شركة أو منتج…           │    │
///   │  └──────────────────────────────────────┘    │
///   │  Entity-type selector + chips                  │
///   │  ┌──────────┐  ┌──────────┐                  │
///   │  │ ✦ Nike   │  │ ✦ Dior  │                  │
///   │  └──────────┘  └──────────┘                  │
///   │  ┌──────────┐  ┌──────────┐                  │
///   │  │ ✦ منتج X │  │ ✦ مؤثرين │                  │
///   │  └──────────┘  └──────────┘                  │
///   │  ┌────────────  ابدأ التحقيق  ────────────┐  │
///   │  └────────────────────────────────────────┘  │
///   └──────────────────────────────────────────────┘
///   ┌─ Or upload evidence card ───────────────────┐
///   │  📎 أو ابدأ برفع الأدلة                     │
///   │  أضف ملفات بأنواعها ومصادرها…               │
///   │  ┌──┐ ┌──┐ ┌──┐ ┌──┐                         │
///   │  │PD│ │Im│ │Vi│ │Li│                         │
///   │  └──┘ └──┘ └──┘ └──┘                         │
///   │  [list of attached evidence rows]              │
///   │  ┌──── اسحب الملفات هنا أو انقر ─────────┐  │
///   │  └────────────────────────────────────────┘  │
///   │  ┌──── أضف رابط  ────────────┐                │
///   │  └────────────────────────────┘                │
///   └──────────────────────────────────────────────┘
///   ┌─ Quick actions card ────────────────────────┐
///   │  ⚡ الإجراءات السريعة                         │
///   │  ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐                   │
///   │  └──┘ └──┘ └──┘ └──┘ └──┘                   │
///   └──────────────────────────────────────────────┘
class InvestigationScreen extends StatefulWidget {
  const InvestigationScreen({super.key});

  @override
  State<InvestigationScreen> createState() => _InvestigationScreenState();
}

class _InvestigationScreenState extends State<InvestigationScreen> {
  final InvestigationController _ctrl = InvestigationController();
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _urlCtrl = TextEditingController();
  final InvestigationArchiveService _archive =
      InvestigationArchiveService();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _ctrl.query = _searchCtrl.text;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _onStart() async {
    final l = AppLocalizations.of(context);
    final err = _ctrl.validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.t(err)),
          backgroundColor: KashfColors.gold,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Snapshot the result from the service before we pop the loading
    // sheet — once we navigate, the controller is reset and the
    // result would be cleared.
    final l10n = l;
    try {
      await _ctrl.start(l10n);
    } catch (e) {
      if (!mounted) return;
      final kind = investigationErrorKind(e);
      final key = 'ir_error_$kind';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.t(key)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = _ctrl.progress.result;
    if (!mounted || result == null) return;

    // Capture the form snapshot so the archive call survives the
    // upcoming `acknowledgeCompletion()` which clears the form.
    final entityTypeAtRun = _ctrl.entityType;
    final evidenceCountAtRun = _ctrl.evidence.length;
    final queryAtRun = _ctrl.query;

    _ctrl.acknowledgeCompletion();

    Navigator.of(context).push(
      kashfRoute(
        InvestigationResultsScreen(result: result),
      ),
    );

    // Persist to Firestore (+ local cache). Fire-and-forget so the
    // navigation is never blocked on the network write; failures
    // are already logged inside the service.
    unawaited(
      _archive.save(
        result: result,
        entityType: entityTypeAtRun,
        evidenceCount: evidenceCountAtRun,
        tags: _tagsForQuery(queryAtRun, entityTypeAtRun),
      ),
    );
  }

  /// Derives 0..3 short tags from the raw query so the saved
  /// document has something meaningful to show on the home card.
  /// Splits on whitespace, lowercases, drops very short tokens.
  List<String> _tagsForQuery(String raw, EntityType entityType) {
    final tokens = raw
        .toLowerCase()
        .split(RegExp(r'[\s,;.!?]+'))
        .where((s) => s.length >= 3 && s.length <= 18)
        .toSet()
        .take(3)
        .toList();
    if (tokens.isEmpty) {
      return [entityType.l10nKey];
    }
    return tokens;
  }

  void _onQuickQuestion(String text) {
    _searchCtrl.text = text;
    _ctrl.query = text;
    // Reveal the cursor / focus to give the user feedback that the
    // tap was registered.
    FocusScope.of(context).requestFocus(FocusNode());
  }

  Future<void> _pickFiles(EvidenceKind kind) async {
    final l = AppLocalizations.of(context);

    // Map each evidence kind to the file picker's type constant.
    FileType fileType;
    List<String>? allowedExtensions;

    switch (kind) {
      case EvidenceKind.pdf:
        fileType = FileType.custom;
        allowedExtensions = ['pdf'];
      case EvidenceKind.image:
        fileType = FileType.image;
        allowedExtensions = null;
      case EvidenceKind.video:
        fileType = FileType.video;
        allowedExtensions = null;
      case EvidenceKind.url:
        // URLs are handled separately via _addUrl().
        return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      for (final file in result.files) {
        // On web, `path` is null — use the name as a placeholder.
        final path = file.path ?? '';
        final evidence = Evidence.fromFile(
          name: file.name,
          path: path,
          sizeBytes: file.size,
        );
        if (evidence != null) {
          setState(() => _ctrl.addEvidence(evidence));
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.t('inv_files_added')),
          backgroundColor: KashfColors.gold,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.t('inv_files_error')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _addUrl() {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) return;
    if (!Uri.tryParse(raw)!.hasAbsolutePath) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t('inv_url_invalid')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final evidence = Evidence(
      id: 'ev-${DateTime.now().microsecondsSinceEpoch}',
      kind: EvidenceKind.url,
      displayName: raw,
      status: EvidenceStatus.pending,
      uploadedAt: DateTime.now(),
      url: raw,
    );
    setState(() {
      _ctrl.addEvidence(evidence);
      _urlCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: SafeArea(
          bottom: false,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return Stack(
                children: [
                  ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                    children: [
                      _TopBar(l: l),
                      const SizedBox(height: 8),
                      _SmartSearchCard(
                        l: l,
                        searchCtrl: _searchCtrl,
                        onQuickQuestion: _onQuickQuestion,
                      ),
                      const SizedBox(height: 8),
                      _UploadEvidenceCard(
                        l: l,
                        evidence: _ctrl.evidence,
                        urlCtrl: _urlCtrl,
                        onPick: _pickFiles,
                        onAddUrl: _addUrl,
                        onRemove: (id) =>
                            setState(() => _ctrl.removeEvidence(id)),
                      ),
                      const SizedBox(height: 8),
                      _QuickActionsCard(
                        l: l,
                        selectedActionId: _ctrl.selectedActionId,
                        onSelect: (action) => _ctrl.selectAction(action),
                      ),
                    ],
                  ),
                  if (_ctrl.isRunning || _ctrl.isCompleted || _ctrl.hasFailed)
                    _ProcessingOverlay(
                      progress: _ctrl.progress,
                      l: l,
                      onFailedDismissed: _ctrl.dismissFailure,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Top bar — [X] (close) on the LEFT · [title + brain icon] on the RIGHT.
// ============================================================================
class _TopBar extends StatelessWidget {
  const _TopBar({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: KashfPalette.active.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: KashfPalette.active.cardBorder),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.close,
                  color: KashfPalette.active.textPrimary,
                  size: 16,
                ),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    l.t('inv_title'),
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: KashfColors.gold, width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.gps_fixed,
                    color: KashfColors.gold,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Section card wrapper — provides the rounded border surface every
// section shares in the reference.
// ============================================================================
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.borderColor,
  });

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? KashfPalette.active.cardBorder,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

// ============================================================================
// Section header — icon visually on the RIGHT (start in RTL), title +
// subtitle flow right-to-left.
// ============================================================================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    title,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                subtitle,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Smart search section — search field + entity-type chips + gold CTA.
// ============================================================================
class _SmartSearchCard extends StatelessWidget {
  const _SmartSearchCard({
    required this.l,
    required this.searchCtrl,
    required this.onQuickQuestion,
  });

  final AppLocalizations l;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onQuickQuestion;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionHeader(
            icon: Icons.smart_toy_sharp,
            iconColor: KashfColors.gold,
            title: l.t('inv_section_smart'),
            subtitle: l.t('inv_section_smart_sub'),
          ),
          _SearchField(hint: l.t('inv_search_hint'), controller: searchCtrl),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l.t('inv_quick_label'),
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _QuickQuestionGrid(
            questions: [
              l.t('inv_q1'),
              l.t('inv_q2'),
              l.t('inv_q3'),
              l.t('inv_q4'),
            ],
            onTap: onQuickQuestion,
          ),
          const SizedBox(height: 8),
          _StartInvestigationButton(
            label: l.t('inv_cta_start'),
            onTap: () => _onStart(context),
          ),
        ],
      ),
    );
  }

  void _onStart(BuildContext context) {
    // Delegate up to the screen via an inherited callback.
    final state =
        context.findAncestorStateOfType<_InvestigationScreenState>();
    state?._onStart();
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.controller});
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 12, 0),
      decoration: BoxDecoration(
        color: KashfPalette.active.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KashfPalette.active.fieldFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.search,
              color: KashfColors.gold,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: TextField(
                controller: controller,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickQuestionGrid extends StatelessWidget {
  const _QuickQuestionGrid({
    required this.questions,
    required this.onTap,
  });
  final List<String> questions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _QuestionChip(
                text: questions[0],
                onTap: () => onTap(questions[0]),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _QuestionChip(
                text: questions[1],
                onTap: () => onTap(questions[1]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _QuestionChip(
                text: questions[2],
                onTap: () => onTap(questions[2]),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _QuestionChip(
                text: questions[3],
                onTap: () => onTap(questions[3]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuestionChip extends StatelessWidget {
  const _QuestionChip({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 10, 6),
        decoration: BoxDecoration(
          color: KashfPalette.active.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KashfPalette.active.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: KashfColors.gold, size: 13),
            const SizedBox(width: 6),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartInvestigationButton extends StatelessWidget {
  const _StartInvestigationButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFFF8C24A), Color(0xFFF5B92E)],
          ),
          boxShadow: [
            BoxShadow(
              color: KashfColors.gold.withValues(alpha: 0.30),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, color: Colors.black, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Upload evidence card. Reduced from 6 tiles to 4 (PDF, image,
// video, link). The link tile opens an inline text field instead
// of a file picker so URL evidence doesn't need a third-party
// plugin.
// ============================================================================
class _UploadEvidenceCard extends StatelessWidget {
  const _UploadEvidenceCard({
    required this.l,
    required this.evidence,
    required this.urlCtrl,
    required this.onPick,
    required this.onAddUrl,
    required this.onRemove,
  });

  final AppLocalizations l;
  final List<Evidence> evidence;
  final TextEditingController urlCtrl;
  final ValueChanged<EvidenceKind> onPick;
  final VoidCallback onAddUrl;
  final ValueChanged<String> onRemove;

  static const purple = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    final tiles = <_EvidenceTileData>[
      _EvidenceTileData(
        kind: EvidenceKind.pdf,
        icon: EvidenceKind.pdf.icon,
        label: l.t(EvidenceKind.pdf.l10nKey),
        sub: l.t(EvidenceKind.pdf.l10nSubKey),
      ),
      _EvidenceTileData(
        kind: EvidenceKind.image,
        icon: EvidenceKind.image.icon,
        label: l.t(EvidenceKind.image.l10nKey),
        sub: l.t(EvidenceKind.image.l10nSubKey),
      ),
      _EvidenceTileData(
        kind: EvidenceKind.video,
        icon: EvidenceKind.video.icon,
        label: l.t(EvidenceKind.video.l10nKey),
        sub: l.t(EvidenceKind.video.l10nSubKey),
      ),
      _EvidenceTileData(
        kind: EvidenceKind.url,
        icon: EvidenceKind.url.icon,
        label: l.t(EvidenceKind.url.l10nKey),
        sub: l.t(EvidenceKind.url.l10nSubKey),
      ),
    ];
    return _SectionCard(
      borderColor: purple.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionHeader(
            icon: Icons.attach_file_outlined,
            iconColor: purple,
            title: l.t('inv_section_upload'),
            subtitle: l.t('inv_section_upload_sub'),
          ),
          _EvidenceTypeGrid(
            tiles: tiles,
            onPick: onPick,
          ),
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            _EvidenceList(
              evidence: evidence,
              l: l,
              onRemove: onRemove,
            ),
          ],
          const SizedBox(height: 10),
          _UrlInputRow(
            controller: urlCtrl,
            hint: l.t('inv_url_hint'),
            button: l.t('inv_url_add'),
            onSubmit: onAddUrl,
          ),
        ],
      ),
    );
  }
}

class _EvidenceTileData {
  const _EvidenceTileData({
    required this.kind,
    required this.icon,
    required this.label,
    required this.sub,
  });
  final EvidenceKind kind;
  final IconData icon;
  final String label;
  final String sub;
}

class _EvidenceTypeGrid extends StatelessWidget {
  const _EvidenceTypeGrid({
    required this.tiles,
    required this.onPick,
  });
  final List<_EvidenceTileData> tiles;
  final ValueChanged<EvidenceKind> onPick;

  @override
  Widget build(BuildContext context) {
    // 4 tiles => 2 rows × 2 columns.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _EvidenceTile(
                  data: tiles[i],
                  onTap: () => onPick(tiles[i].kind),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 2; i < 4; i++) ...[
              if (i > 2) const SizedBox(width: 6),
              Expanded(
                child: _EvidenceTile(
                  data: tiles[i],
                  onTap: () => onPick(tiles[i].kind),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.data, required this.onTap});
  final _EvidenceTileData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF8B5CF6);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: KashfPalette.active.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KashfPalette.active.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, color: purple, size: 20),
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                data.sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KashfPalette.active.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceList extends StatelessWidget {
  const _EvidenceList({
    required this.evidence,
    required this.l,
    required this.onRemove,
  });

  final List<Evidence> evidence;
  final AppLocalizations l;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in evidence) ...[
          _EvidenceRow(evidence: e, l: l, onRemove: () => onRemove(e.id)),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.evidence,
    required this.l,
    required this.onRemove,
  });
  final Evidence evidence;
  final AppLocalizations l;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF8B5CF6);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 6, 6),
      decoration: BoxDecoration(
        color: KashfPalette.active.fieldFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        children: [
          Icon(evidence.kind.icon, size: 16, color: purple),
          const SizedBox(width: 8),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                evidence.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _EvidenceStatusBadge(status: evidence.status, l: l),
          IconButton(
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 14),
            color: KashfPalette.active.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _EvidenceStatusBadge extends StatelessWidget {
  const _EvidenceStatusBadge({required this.status, required this.l});
  final EvidenceStatus status;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final (color, label, showSpinner) = _styleFor(status, l);
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            SizedBox(
              width: 9,
              height: 9,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(width: 4),
          ] else
            Icon(_iconFor(status), size: 9, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(EvidenceStatus s) {
    switch (s) {
      case EvidenceStatus.processed:
        return Icons.check_circle;
      case EvidenceStatus.failed:
        return Icons.error_outline;
      case EvidenceStatus.pending:
        return Icons.schedule;
      case EvidenceStatus.uploading:
      case EvidenceStatus.processing:
        return Icons.cloud_sync_outlined;
    }
  }

  (Color, String, bool) _styleFor(EvidenceStatus s, AppLocalizations l) {
    switch (s) {
      case EvidenceStatus.processed:
        return (Colors.green, l.t('ir_evidence_status_processed'), false);
      case EvidenceStatus.failed:
        return (Colors.redAccent, l.t('ir_evidence_status_failed'), false);
      case EvidenceStatus.uploading:
        return (KashfColors.gold, l.t('ir_evidence_status_uploading'), true);
      case EvidenceStatus.processing:
        return (KashfColors.gold, l.t('ir_evidence_status_processing'), true);
      case EvidenceStatus.pending:
        return (
          KashfPalette.active.textSecondary,
          l.t('ir_evidence_status_pending'),
          false,
        );
    }
  }
}

class _UrlInputRow extends StatelessWidget {
  const _UrlInputRow({
    required this.controller,
    required this.hint,
    required this.button,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final String button;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: KashfPalette.active.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 16, color: KashfColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: TextField(
                controller: controller,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: KashfPalette.active.textPrimary,
                  fontSize: 11,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 11,
                  ),
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onSubmit,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: KashfColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: KashfColors.gold.withValues(alpha: 0.45),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                button,
                style: const TextStyle(
                  color: KashfColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Quick actions card — 5 mode tiles (compare / monitor / match /
// campaign / influencer). Tapping a tile selects that action mode;
// it does NOT touch the search field. The selected mode becomes
// the "lens" injected into the prompt sent to the AI.
// ============================================================================
class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.l,
    required this.selectedActionId,
    required this.onSelect,
  });
  final AppLocalizations l;
  final String? selectedActionId;
  final ValueChanged<InvestigationAction?> onSelect;

  @override
  Widget build(BuildContext context) {
    final tiles = <_ActionTileData>[
      _ActionTileData(
        action: InvestigationAction.compare,
        label: l.t(InvestigationAction.compare.l10nLabelKey),
        sub: l.t(InvestigationAction.compare.l10nSubKey),
      ),
      _ActionTileData(
        action: InvestigationAction.monitor,
        label: l.t(InvestigationAction.monitor.l10nLabelKey),
        sub: l.t(InvestigationAction.monitor.l10nSubKey),
      ),
      _ActionTileData(
        action: InvestigationAction.match,
        label: l.t(InvestigationAction.match.l10nLabelKey),
        sub: l.t(InvestigationAction.match.l10nSubKey),
      ),
      _ActionTileData(
        action: InvestigationAction.campaign,
        label: l.t(InvestigationAction.campaign.l10nLabelKey),
        sub: l.t(InvestigationAction.campaign.l10nSubKey),
      ),
      _ActionTileData(
        action: InvestigationAction.influencer,
        label: l.t(InvestigationAction.influencer.l10nLabelKey),
        sub: l.t(InvestigationAction.influencer.l10nSubKey),
      ),
    ];
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionHeader(
            icon: Icons.bolt_outlined,
            iconColor: KashfColors.gold,
            title: l.t('inv_section_actions'),
            subtitle: l.t('inv_section_actions_sub'),
          ),
          _ActionGrid(
            tiles: tiles,
            selectedId: selectedActionId,
            onSelect: onSelect,
          ),
        ],
      ),
    );
  }
}

class _ActionTileData {
  const _ActionTileData({
    required this.action,
    required this.label,
    required this.sub,
  });
  final InvestigationAction action;
  final String label;
  final String sub;
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.tiles,
    required this.selectedId,
    required this.onSelect,
  });
  final List<_ActionTileData> tiles;
  final String? selectedId;
  final ValueChanged<InvestigationAction?> onSelect;

  @override
  Widget build(BuildContext context) {
    // 5 tiles ⇒ first row has 3, second row has 2.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _ActionTile(
                  data: tiles[i],
                  selected: tiles[i].action.id == selectedId,
                  onSelect: onSelect,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 3; i < 5; i++) ...[
              if (i > 3) const SizedBox(width: 6),
              Expanded(
                child: _ActionTile(
                  data: tiles[i],
                  selected: tiles[i].action.id == selectedId,
                  onSelect: onSelect,
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.data,
    required this.selected,
    required this.onSelect,
  });

  final _ActionTileData data;
  final bool selected;
  final ValueChanged<InvestigationAction?> onSelect;

  @override
  Widget build(BuildContext context) {
    // Selected tile → bold gold accents, raised feel.
    // Unselected  → muted grey-out so the selected tile pops.
    final borderColor = selected
        ? KashfColors.gold
        : KashfPalette.active.textSecondary.withValues(alpha: 0.35);
    final borderWidth = selected ? 1.6 : 1.0;
    final fillColor = selected
        ? KashfColors.gold.withValues(alpha: 0.10)
        : KashfPalette.active.textSecondary.withValues(alpha: 0.10);
    final iconColor = selected
        ? KashfColors.gold
        : KashfPalette.active.textSecondary.withValues(alpha: 0.55);
    final labelColor = selected
        ? KashfPalette.active.textPrimary
        : KashfPalette.active.textSecondary.withValues(alpha: 0.65);
    final subColor = selected
        ? KashfPalette.active.textSecondary
        : KashfPalette.active.textSecondary.withValues(alpha: 0.45);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        // Push the action's query into the search field so the user
        // can tap "Start investigation" without re-typing.
        final state =
            context.findAncestorStateOfType<_InvestigationScreenState>();
        if (state == null) return;

        // Toggling: tapping the same tile again clears it.
        final isCurrentlySelected = state._ctrl.selectedActionId == data.action.id;
        onSelect(isCurrentlySelected ? null : data.action);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).t(
              isCurrentlySelected
                  ? 'inv_action_cleared'
                  : 'inv_action_selected',
            )),
            backgroundColor: KashfColors.gold,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: KashfColors.gold.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Small check mark in the top-right corner so the user
            // can clearly see the tile is selected. Hidden when the
            // tile is at rest.
            if (selected)
              const PositionedDirectional(
                top: 0,
                end: 0,
                child: _SelectedDot(),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  data.action.icon,
                  color: iconColor,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    data.sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDot extends StatelessWidget {
  const _SelectedDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: KashfColors.gold,
        shape: BoxShape.circle,
        border: Border.all(color: KashfPalette.active.background, width: 1.4),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.check,
        size: 10,
        color: Colors.black,
      ),
    );
  }
}

// ============================================================================
// Processing overlay — full-bleed sheet that covers the form while
// the InvestigationService is running. Shows a smooth double-ring
// spinner, the current phase, an animated progress bar, and the
// status message. Auto-dismisses with a fade when the service
// reports completion **or** failure (so a failed investigation
// never gets stuck on the loading sheet).
// ============================================================================
class _ProcessingOverlay extends StatefulWidget {
  const _ProcessingOverlay({
    required this.progress,
    required this.l,
    required this.onFailedDismissed,
  });

  final InvestigationProgress progress;
  final AppLocalizations l;

  /// Fired after the failed-state fade-out animation has finished.
  /// The screen-level handler resets the controller back to draft
  /// so the overlay is removed from the Stack without clearing the
  /// user's form (so they can retry the same query).
  final VoidCallback onFailedDismissed;

  @override
  State<_ProcessingOverlay> createState() => _ProcessingOverlayState();
}

class _ProcessingOverlayState extends State<_ProcessingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _exitCtrl;
  late final AnimationController _barCtrl;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    // Continuous spin for the outer ring.
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    // Subtle pulse for the inner ring + soft halo (not strictly
    // required, makes the spinner feel alive without being loud).
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    // Drives the card's entrance + exit fade / scale.
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1,
    );
    // Smoothly eases the value used in the progress bar so it does
    // not jump between phases.
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: widget.progress.percent.clamp(0.0, 1.0),
    );
  }

  @override
  void didUpdateWidget(covariant _ProcessingOverlay old) {
    super.didUpdateWidget(old);
    final wasFailed = old.progress.phase == InvestigationPhase.failed;
    final isFailed = widget.progress.phase == InvestigationPhase.failed;
    final isDone = widget.progress.phase == InvestigationPhase.completed;

    // Smoothly chase the reported progress value.
    if (_barCtrl.value != widget.progress.percent.clamp(0.0, 1.0)) {
      _barCtrl.animateTo(
        widget.progress.percent.clamp(0.0, 1.0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }

    // Trigger the auto-dismiss + fade when we transition into the
    // failed or completed state from anything else.
    if ((isFailed || isDone) && !wasFailed) {
      _autoDismissTimer?.cancel();
      _autoDismissTimer = Timer(
        Duration(milliseconds: isFailed ? 320 : 0),
        () async {
          if (!mounted) return;
          await _exitCtrl.reverse();
          if (!mounted) return;
          // Hand control back to the screen so it can collapse the
          // overlay out of the Stack. Skip when completed (the
          // screen already called `acknowledgeCompletion()` which
          // navigated us away).
          if (isFailed) {
            widget.onFailedDismissed();
          }
        },
      );
    }

    // If we transitioned back to running (e.g. user retried)
    // make sure the overlay is fully visible again.
    if (widget.progress.phase != InvestigationPhase.failed &&
        widget.progress.phase != InvestigationPhase.completed &&
        old.progress.phase == InvestigationPhase.failed) {
      _exitCtrl.forward();
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    _exitCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final l = widget.l;
    final isFailed = progress.phase == InvestigationPhase.failed;
    final isRunning =
        !isFailed && progress.phase != InvestigationPhase.completed;
    final palette = KashfPalette.active;

    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: isRunning,
        child: AnimatedBuilder(
          animation: Listenable.merge([_exitCtrl, _barCtrl]),
          builder: (context, _) {
            final fade = _exitCtrl.value.clamp(0.0, 1.0);
            return Opacity(
              opacity: fade,
              child: IgnorePointer(
                ignoring: fade < 0.05,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.62),
                  child: Center(
                    child: Transform.scale(
                      scale: 0.9 + 0.1 * fade,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: KashfColors.gold.withValues(alpha: 0.45),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ProSpinner(
                              spin: _spinCtrl,
                              pulse: _pulseCtrl,
                              isFailed: isFailed,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isFailed
                                  ? l.t('ir_processing_failed_title')
                                  : l.t('ir_processing_title'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                isFailed
                                    ? (progress.message.isNotEmpty
                                        ? progress.message
                                        : l.t('ir_processing_failed'))
                                    : progress.message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _AnimatedProgressBar(
                              value: _barCtrl.value.clamp(0.0, 1.0),
                              failed: isFailed,
                            ),
                            if (isFailed) ...[
                              const SizedBox(height: 12),
                              _RetryHint(text: l.t('ir_processing_failed_hint')),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A custom-painted double-ring spinner with a soft pulsing halo.
/// Drives a smooth, professional loading feel instead of the
/// default Material indeterminate spinner.
class _ProSpinner extends StatelessWidget {
  const _ProSpinner({
    required this.spin,
    required this.pulse,
    required this.isFailed,
  });

  final Animation<double> spin;
  final Animation<double> pulse;
  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: AnimatedBuilder(
        animation: Listenable.merge([spin, pulse]),
        builder: (context, _) {
          return CustomPaint(
            painter: _SpinnerPainter(
              rotation: spin.value,
              pulse: pulse.value,
              failed: isFailed,
              accent: isFailed ? Colors.redAccent : KashfColors.gold,
            ),
            size: const Size(72, 72),
          );
        },
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({
    required this.rotation,
    required this.pulse,
    required this.failed,
    required this.accent,
  });

  /// 0..1, drives the outer ring's rotation.
  final double rotation;

  /// 0..1, drives the halo + inner ring scale / opacity.
  final double pulse;

  final bool failed;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    // --- Soft halo (pulses)
    final haloPaint = Paint()
      ..color = accent.withValues(alpha: 0.16 + 0.10 * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 4 * pulse);
    canvas.drawCircle(center, radius * (0.55 + 0.10 * pulse), haloPaint);

    // --- Static track ring (background)
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = accent.withValues(alpha: 0.18);
    canvas.drawCircle(center, radius * 0.78, trackPaint);

    // --- Rotating arc (the spinning bit)
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = accent;
    final arcRect = Rect.fromCircle(center: center, radius: radius * 0.78);
    final start = rotation * 6.28318; // 0..2π
    canvas.drawArc(
      arcRect,
      start,
      1.4, // ~80° arc length — feels lively without being busy
      false,
      arcPaint,
    );

    // --- Inner counter-rotating arc (subtle second motion)
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = accent.withValues(alpha: 0.55);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.52),
      -start * 1.2 + 3.14,
      1.0,
      false,
      innerPaint,
    );

    // --- Center dot (scaled by the pulse)
    final dotPaint = Paint()..color = accent;
    canvas.drawCircle(
      center,
      3 + 1.5 * pulse,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter old) =>
      old.rotation != rotation ||
      old.pulse != pulse ||
      old.failed != failed ||
      old.accent != accent;
}

/// A progress bar whose [value] is driven by an [AnimationController]
/// so transitions between phases look smooth instead of snapping.
class _AnimatedProgressBar extends StatelessWidget {
  const _AnimatedProgressBar({required this.value, required this.failed});

  final double value;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final accent = failed ? Colors.redAccent : KashfColors.gold;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            // Track
            Container(color: palette.fieldFill),
            // Animated fill
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.65),
                      accent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small "Tap to retry" hint shown briefly while the failed-state
/// overlay fades away.
class _RetryHint extends StatelessWidget {
  const _RetryHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.refresh, size: 12, color: palette.textSecondary),
        const SizedBox(width: 6),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
