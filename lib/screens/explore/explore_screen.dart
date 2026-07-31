import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/analysis_history.dart';
import '../../state/history_store.dart';
import '../../theme.dart';

/// Converts Latin digits 0–9 into their Arabic-Indic counterparts.
/// Used for inline counts inside Arabic strings so we don't rely on the
/// system to format numbers for us.
String toArabicNumerals(int n) {
  const map = {
    '0': '٠',
    '1': '١',
    '2': '٢',
    '3': '٣',
    '4': '٤',
    '5': '٥',
    '6': '٦',
    '7': '٧',
    '8': '٨',
    '9': '٩',
  };
  return n.toString().split('').map((c) => map[c] ?? c).join();
}

/// AI-powered Market Intelligence Workspace.
///
/// Lets users pick entity types, enter a target name, upload evidence,
/// choose deliverables, and inspect generated output. Built as a series
/// of clearly-numbered steps that mirror the requirements doc.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _linkCtrl = TextEditingController();

  // --- Step state ---
  final Set<_EntityCategory> _selectedCategories = <_EntityCategory>{};
  final List<_Evidence> _evidence = <_Evidence>[];
  final Set<_OutputType> _selectedOutputs = <_OutputType>{};

  // --- Generation state ---
  _GenerationState _generation = const _IdleState();
  // Shared between the loading popup dialog and the underlying state.
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);

  // --- Workspace history (in-memory for demo) ---
  final List<_HistoryEntry> _history = <_HistoryEntry>[];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _linkCtrl.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Validation & actions
  // ---------------------------------------------------------------------------

  String? _validate() {
    final l = AppLocalizations.of(context);
    if (_nameCtrl.text.trim().isEmpty) return l.t('mi_validation_name');
    if (_selectedOutputs.isEmpty) return l.t('mi_validation_outputs');
    return null;
  }

  Future<void> _runAnalysis() async {
    final err = _validate();
    if (err != null) {
      _showError(err);
      return;
    }

    // Unsupported-file validation
    final l = AppLocalizations.of(context);
    final hasInvalid = _evidence.any((e) => !e.isSupported);
    if (hasInvalid) {
      _showError(l.t('mi_validation_unsupported'));
      return;
    }

    setState(() => _generation = const _RunningState(0.0));
    final completer = Completer<void>();

    // Show the loading state as a centered popup so it is always visible
    // instead of being pushed below the page content.
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF1F1810),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: KashfColors.gold.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 24,
          ),
          child: SizedBox(
            width: 320,
            height: 200,
            child: Directionality(
              textDirection:
                  l.isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: ValueListenableBuilder<double>(
                valueListenable: _progressNotifier,
                builder: (_, value, __) =>
                    _LoadingPanel(progress: value, l: l),
              ),
            ),
          ),
        );
      },
    );

    _ProgressTicker(
      onTick: (v) {
        if (!mounted) return;
        _progressNotifier.value = v;
        setState(() => _generation = _RunningState(v));
      },
      onComplete: completer.complete,
      totalMs: 3200,
    ).start();

    await completer.future;

    if (!mounted) return;
    final outputs = _MockOutputs.build(
      entity: _nameCtrl.text.trim(),
      outputs: _selectedOutputs.toList(),
      l: l,
    );
    setState(() => _generation = _CompleteState(outputs));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    await dialogFuture;
    _progressNotifier.value = 0.0;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _saveToHistory() {
    final state = _generation;
    if (state is _CompleteState && state.outputs.isNotEmpty) {
      final l = AppLocalizations.of(context);
      final categoryLabels = _selectedCategories
          .map((c) => c.label(context))
          .toList(growable: false);
      final firstOutputTitle =
          state.outputs.isNotEmpty ? state.outputs.first.title : '';
      HistoryStore.instance.add(
        AnalysisHistoryEntry(
          id: math.Random().nextInt(1 << 31).toString(),
          entity: _nameCtrl.text.trim(),
          categoryLabels: categoryLabels,
          createdAt: DateTime.now(),
          summary: firstOutputTitle,
          outputsCount: state.outputs.length,
        ),
      );
      setState(() {
        // Keep the local mirror in sync so the inline history list also
        // updates immediately.
        _history.insert(
          0,
          _HistoryEntry(
            id: math.Random().nextInt(1 << 31).toString(),
            entity: _nameCtrl.text.trim(),
            categories: _selectedCategories.toList(),
            createdAt: DateTime.now(),
            outputs: state.outputs,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.t('mi_save_button')),
          backgroundColor: KashfColors.gold,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _addLink() {
    final v = _linkCtrl.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _evidence.add(
        _Evidence(
          id: math.Random().nextInt(1 << 31).toString(),
          name: v,
          kind: _EvidenceKind.link,
          isSupported: true,
          sizeKb: 0,
        ),
      );
      _linkCtrl.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Use the natural direction for the active language so Arabic flows
    // right-to-left and English flows left-to-right natively — same as
    // the home screen.
    return Directionality(
      textDirection: l.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: KashfPalette.active.background,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(child: _TopBar(l: l)),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
                sliver: SliverToBoxAdapter(child: _Header(l: l)),
              ),

              // Step 1: category multi-select
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _StepCard(
                    number: '1',
                    title: l.t('mi_step1_title'),
                    hint: l.t('mi_step1_hint'),
                    child: _CategoryMultiSelect(
                      selected: _selectedCategories,
                      onChanged: (next) => setState(
                        () => _selectedCategories
                          ..clear()
                          ..addAll(next),
                      ),
                      l: l,
                    ),
                  ),
                ),
              ),

              // Step 2: target entity text input
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _StepCard(
                    number: '2',
                    title: l.t('mi_step2_title'),
                    hint: l.t('mi_step2_hint'),
                    child: _TargetEntityField(
                      controller: _nameCtrl,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ),

              // Step 3: evidence uploader
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _StepCard(
                    number: '3',
                    title: l.t('mi_step3_title'),
                    hint: l.t('mi_step3_hint'),
                    child: _EvidenceUploader(
                      evidence: _evidence,
                      linkCtrl: _linkCtrl,
                      onAddLink: _addLink,
                      onRemove: (id) => setState(
                        () => _evidence.removeWhere((e) => e.id == id),
                      ),
                      onAddSampleFile: (name, ext) {
                        const supported = [
                          'pdf',
                          'docx',
                          'png',
                          'jpg',
                          'jpeg',
                          'mp3',
                          'mp4',
                          'mov',
                        ];
                        setState(() {
                          _evidence.add(
                            _Evidence(
                              id: math.Random().nextInt(1 << 31).toString(),
                              name: name,
                              kind: _EvidenceKind.fromExt(ext),
                              isSupported: supported.contains(
                                ext.toLowerCase(),
                              ),
                              sizeKb: 48 + math.Random().nextInt(8000),
                            ),
                          );
                        });
                      },
                      l: l,
                    ),
                  ),
                ),
              ),

              // Step 4: outputs selector
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _StepCard(
                    number: '4',
                    title: l.t('mi_step4_title'),
                    hint: l.t('mi_step4_hint'),
                    child: _OutputsSelector(
                      selected: _selectedOutputs,
                      onChanged: (next) => setState(
                        () => _selectedOutputs
                          ..clear()
                          ..addAll(next),
                      ),
                      l: l,
                    ),
                  ),
                ),
              ),

              // Action row: Generate + Save
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 12, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _PrimaryButton(
                          label: l.t('mi_generate_button'),
                          icon: Icons.auto_awesome,
                          busy: _generation is _RunningState,
                          onPressed: _runAnalysis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: _SecondaryButton(
                          label: l.t('mi_save_button'),
                          icon: Icons.bookmark_outline,
                          onPressed: _generation is _CompleteState
                              ? _saveToHistory
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Output preview / loading / empty
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _OutputPanel(
                    state: _generation,
                    onRegenerate: _runAnalysis,
                    l: l,
                  ),
                ),
              ),

              // History section
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Icon(Icons.history, color: KashfColors.gold, size: 14),
                      SizedBox(width: 6),
                      Text(
                        l.t('mi_history_title'),
                        style: TextStyle(
                          color: KashfPalette.active.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
                sliver: SliverToBoxAdapter(
                  child: _HistoryList(entries: _history, l: l),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Top bar + header
// ============================================================================

class _TopBar extends StatelessWidget {
  const _TopBar({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: KashfColors.gold.withValues(alpha: 0.18),
        border: Border.all(color: KashfColors.gold, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/logoprofile.jpeg',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.person, color: KashfColors.gold, size: 20),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        KashfLogo(width: 56),
        SizedBox(width: 10),
        Text(
          l.t('nav_explore'),
          style: TextStyle(
            color: KashfPalette.active.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Spacer(),
        avatar,
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: KashfColors.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: KashfColors.gold, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'AI · BETA',
                    style: TextStyle(
                      color: KashfColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          l.t('mi_title'),
          style: TextStyle(
            color: KashfPalette.active.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          l.t('mi_subtitle'),
          style: TextStyle(
            color: KashfPalette.active.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Step card wrapper
// ============================================================================

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.hint,
    required this.child,
  });
  final String number;
  final String title;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: KashfColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: TextStyle(
                    color: KashfColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      hint,
                      style: TextStyle(
                        color: KashfPalette.active.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ============================================================================
// Step 1 — category multi-select
// ============================================================================

// Local enum kept for the alias above. The public model in
// analysis_history.dart owns the canonical values.
enum _EntityCategory { company, brand, product, influencer, market }

extension on _EntityCategory {
  IconData get icon => switch (this) {
    _EntityCategory.company => Icons.business_outlined,
    _EntityCategory.brand => Icons.label_outline,
    _EntityCategory.product => Icons.inventory_2_outlined,
    _EntityCategory.influencer => Icons.person_outline,
    _EntityCategory.market => Icons.show_chart_outlined,
  };

  Color get color => switch (this) {
    _EntityCategory.company => const Color(0xFF1F5DFF),
    _EntityCategory.brand => const Color(0xFFEC4899),
    _EntityCategory.product => const Color(0xFFFB923C),
    _EntityCategory.influencer => const Color(0xFF6F3AFF),
    _EntityCategory.market => const Color(0xFF1FAE5C),
  };

  String label(BuildContext context) {
    final l = AppLocalizations.of(context);
    return switch (this) {
      _EntityCategory.company => l.t('mi_cat_company'),
      _EntityCategory.brand => l.t('mi_cat_brand'),
      _EntityCategory.product => l.t('mi_cat_product'),
      _EntityCategory.influencer => l.t('mi_cat_influencer'),
      _EntityCategory.market => l.t('mi_cat_market'),
    };
  }
}

class _CategoryMultiSelect extends StatelessWidget {
  const _CategoryMultiSelect({
    required this.selected,
    required this.onChanged,
    required this.l,
  });
  final Set<_EntityCategory> selected;
  final ValueChanged<Set<_EntityCategory>> onChanged;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in _EntityCategory.values)
          _SelectableChip(
            icon: c.icon,
            color: c.color,
            label: c.label(context),
            selected: selected.contains(c),
            onTap: () {
              final next = {...selected};
              if (next.contains(c)) {
                next.remove(c);
              } else {
                next.add(c);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : KashfPalette.active.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : KashfPalette.active.fieldBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? color : KashfPalette.active.textSecondary,
              size: 14,
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : KashfPalette.active.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Step 2 — target entity input
// ============================================================================

class _TargetEntityField extends StatelessWidget {
  const _TargetEntityField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasText = controller.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 50,
          padding: EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: KashfPalette.active.fieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KashfPalette.active.fieldBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: KashfColors.gold, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: l.t('mi_search_hint'),
                    hintStyle: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              if (hasText)
                GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: Icon(
                    Icons.close,
                    color: KashfPalette.active.textSecondary,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
        if (hasText) ...[
          SizedBox(height: 10),
          Text(
            l.t('mi_match_suggested'),
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          _SuggestionRow(query: controller.text.trim()),
        ],
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    const pool = <(String, _EntityCategory)>[
      ('Dior Sauvage', _EntityCategory.product),
      ('Lattafa Asad', _EntityCategory.brand),
      ('Riyadh, KSA', _EntityCategory.market),
      ('@dabora.official', _EntityCategory.influencer),
      ('Guerlain', _EntityCategory.company),
    ];
    final matches = pool.where((p) => p.$1.toLowerCase().contains(q)).toList();
    if (matches.isEmpty) {
      return Text(
        query,
        style: TextStyle(
          color: KashfColors.gold,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final m in matches)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: KashfColors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: KashfColors.gold),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(m.$2.icon, color: KashfColors.gold, size: 12),
                SizedBox(width: 6),
                Text(
                  m.$1,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// Step 3 — Evidence uploader
// ============================================================================

enum _EvidenceKind {
  document,
  image,
  video,
  audio,
  link,
  other;

  static _EvidenceKind fromExt(String ext) {
    final e = ext.toLowerCase();
    if (['pdf', 'docx', 'doc', 'txt', 'csv', 'xlsx'].contains(e)) {
      return _EvidenceKind.document;
    }
    if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(e)) {
      return _EvidenceKind.image;
    }
    if (['mp4', 'mov', 'avi', 'mkv'].contains(e)) {
      return _EvidenceKind.video;
    }
    if (['mp3', 'wav', 'm4a', 'aac'].contains(e)) {
      return _EvidenceKind.audio;
    }
    return _EvidenceKind.other;
  }

  IconData get icon => switch (this) {
    _EvidenceKind.document => Icons.description_outlined,
    _EvidenceKind.image => Icons.image_outlined,
    _EvidenceKind.video => Icons.movie_outlined,
    _EvidenceKind.audio => Icons.audiotrack_outlined,
    _EvidenceKind.link => Icons.link,
    _EvidenceKind.other => Icons.attach_file,
  };

  Color get color => switch (this) {
    _EvidenceKind.document => const Color(0xFF1F5DFF),
    _EvidenceKind.image => const Color(0xFFEC4899),
    _EvidenceKind.video => const Color(0xFFFB923C),
    _EvidenceKind.audio => const Color(0xFF22C55E),
    _EvidenceKind.link => KashfColors.gold,
    _EvidenceKind.other => KashfPalette.active.textSecondary,
  };
}

class _Evidence {
  _Evidence({
    required this.id,
    required this.name,
    required this.kind,
    required this.isSupported,
    required this.sizeKb,
  });
  final String id;
  final String name;
  final _EvidenceKind kind;
  final bool isSupported;
  final int sizeKb;
}

class _EvidenceUploader extends StatelessWidget {
  const _EvidenceUploader({
    required this.evidence,
    required this.linkCtrl,
    required this.onAddLink,
    required this.onRemove,
    required this.onAddSampleFile,
    required this.l,
  });
  final List<_Evidence> evidence;
  final TextEditingController linkCtrl;
  final VoidCallback onAddLink;
  final void Function(String id) onRemove;
  final void Function(String name, String ext) onAddSampleFile;
  final AppLocalizations l;

  void _showSampleFileDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KashfPalette.active.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        const samples = <(String, String)>[
          ('Annual_report.pdf', 'pdf'),
          ('Ad_creative.png', 'png'),
          ('Voice_intro.mp3', 'mp3'),
          ('Promo_reel.mp4', 'mp4'),
          ('Spec.exe', 'exe'), // intentionally invalid
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.t('mi_step3_hint'),
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (final s in samples)
                  ListTile(
                    leading: Icon(
                      Icons.file_present_outlined,
                      color: KashfColors.gold,
                    ),
                    title: Text(s.$1),
                    subtitle: Text('.${s.$2}'),
                    onTap: () {
                      onAddSampleFile(s.$1, s.$2);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drop zone
        GestureDetector(
          onTap: () => _showSampleFileDialog(context),
          child: DottedDropzone(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  color: KashfColors.gold,
                  size: 28,
                ),
                SizedBox(height: 6),
                Text(
                  l.t('mi_drop_hint'),
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  l.t('mi_supported_files'),
                  style: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12),
        // Link input
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: KashfColors.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KashfPalette.active.fieldBorder),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.link, color: KashfColors.gold, size: 18),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 44,
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: KashfPalette.active.fieldFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KashfPalette.active.fieldBorder),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: linkCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'https://…',
                    hintStyle: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            GestureDetector(
              onTap: onAddLink,
              child: Container(
                height: 44,
                padding: EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: KashfColors.gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.add, color: Colors.black),
              ),
            ),
          ],
        ),
        if (evidence.isNotEmpty) ...[
          SizedBox(height: 12),
          for (final e in evidence) _EvidenceTile(item: e, onRemove: onRemove),
        ],
      ],
    );
  }
}

class DottedDropzone extends StatelessWidget {
  const DottedDropzone({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: KashfPalette.active.fieldFill.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const radius = 14.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(radius),
    );
    final paint = Paint()
      ..color = KashfPalette.active.cardBorder
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final path = Path()..addRRect(rrect);
    _drawDashedPath(canvas, path, paint, 8, 4);
  }

  void _drawDashedPath(Canvas c, Path p, Paint paint, double a, double b) {
    for (final metric in p.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final end = math.min(dist + a, metric.length);
        c.drawPath(metric.extractPath(dist, end), paint);
        dist = end + b;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) => false;
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.item, required this.onRemove});
  final _Evidence item;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isSupported
        ? item.kind.color
        : const Color(0xFFEF4444);
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: KashfPalette.active.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KashfPalette.active.fieldBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(item.kind.icon, color: statusColor, size: 18),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: KashfPalette.active.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    item.isSupported
                        ? '${(item.sizeKb / 1024).toStringAsFixed(1)} MB · ${item.kind.name}'
                        : AppLocalizations.of(
                            context,
                          ).t('mi_validation_unsupported'),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: KashfPalette.active.textSecondary,
                size: 18,
              ),
              onPressed: () => onRemove(item.id),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Step 4 — Outputs selector
// ============================================================================

enum _OutputType {
  investigation,
  social,
  insights,
  competitive,
  monitoring,
  content,
}

extension on _OutputType {
  IconData get icon => switch (this) {
    _OutputType.investigation => Icons.assignment_outlined,
    _OutputType.social => Icons.link,
    _OutputType.insights => Icons.lightbulb_outline,
    _OutputType.competitive => Icons.compare_arrows,
    _OutputType.monitoring => Icons.notifications_active_outlined,
    _OutputType.content => Icons.tips_and_updates_outlined,
  };

  Color get color => switch (this) {
    _OutputType.investigation => const Color(0xFF1F5DFF),
    _OutputType.social => const Color(0xFFEC4899),
    _OutputType.insights => const Color(0xFFFB923C),
    _OutputType.competitive => const Color(0xFF6F3AFF),
    _OutputType.monitoring => const Color(0xFF22C55E),
    _OutputType.content => KashfColors.gold,
  };

  String title(BuildContext context) {
    final l = AppLocalizations.of(context);
    return switch (this) {
      _OutputType.investigation => l.t('mi_out_investigation'),
      _OutputType.social => l.t('mi_out_social'),
      _OutputType.insights => l.t('mi_out_insights'),
      _OutputType.competitive => l.t('mi_out_competitive'),
      _OutputType.monitoring => l.t('mi_out_monitoring'),
      _OutputType.content => l.t('mi_out_content'),
    };
  }

  String subtitle(BuildContext context) {
    final l = AppLocalizations.of(context);
    return switch (this) {
      _OutputType.investigation => l.t('mi_out_investigation_sub'),
      _OutputType.social => l.t('mi_out_social_sub'),
      _OutputType.insights => l.t('mi_out_insights_sub'),
      _OutputType.competitive => l.t('mi_out_competitive_sub'),
      _OutputType.monitoring => l.t('mi_out_monitoring_sub'),
      _OutputType.content => l.t('mi_out_content_sub'),
    };
  }
}

class _OutputsSelector extends StatelessWidget {
  const _OutputsSelector({
    required this.selected,
    required this.onChanged,
    required this.l,
  });
  final Set<_OutputType> selected;
  final ValueChanged<Set<_OutputType>> onChanged;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // Two-column grid where each row contains 2 cards, each card taking
    // equal width of the available space. Avoids overflow and keeps a
    // clean organized look.
    final rows = <Widget>[];
    final outputs = _OutputType.values;
    for (var i = 0; i < outputs.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(
              child: _OutputOptionCard(
                output: outputs[i],
                selected: selected.contains(outputs[i]),
                onTap: () {
                  final next = {...selected};
                  if (next.contains(outputs[i])) {
                    next.remove(outputs[i]);
                  } else {
                    next.add(outputs[i]);
                  }
                  onChanged(next);
                },
              ),
            ),
            if (i + 1 < outputs.length) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _OutputOptionCard(
                  output: outputs[i + 1],
                  selected: selected.contains(outputs[i + 1]),
                  onTap: () {
                    final next = {...selected};
                    if (next.contains(outputs[i + 1])) {
                      next.remove(outputs[i + 1]);
                    } else {
                      next.add(outputs[i + 1]);
                    }
                    onChanged(next);
                  },
                ),
              ),
            ],
          ],
        ),
      );
      if (i + 2 < outputs.length) rows.add(const SizedBox(height: 10));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}

class _OutputOptionCard extends StatelessWidget {
  const _OutputOptionCard({
    required this.output,
    required this.selected,
    required this.onTap,
  });
  final _OutputType output;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = output.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : KashfPalette.active.fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : KashfPalette.active.fieldBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(output.icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    output.title(context),
                    style: TextStyle(
                      color: selected ? color : KashfPalette.active.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    output.subtitle(context),
                    style: TextStyle(
                      color: KashfPalette.active.textSecondary,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Action buttons (primary / secondary)
// ============================================================================

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: busy
                ? [
                    const Color(0xFFF8C24A).withValues(alpha: 0.7),
                    const Color(0xFFF5B92E).withValues(alpha: 0.7),
                  ]
                : [const Color(0xFFF8C24A), const Color(0xFFF5B92E)],
          ),
          boxShadow: [
            BoxShadow(
              color: KashfColors.gold.withValues(alpha: busy ? 0.15 : 0.4),
              blurRadius: busy ? 8 : 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(Colors.black54),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: Colors.black),
                  SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: enabled
              ? KashfColors.gold.withValues(alpha: 0.18)
              : KashfPalette.active.fieldFill.withValues(alpha: 0.5),
          border: Border.all(
            color: enabled ? KashfColors.gold : KashfPalette.active.cardBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled
                  ? KashfColors.gold
                  : KashfPalette.active.textSecondary,
              size: 16,
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: enabled
                      ? KashfColors.gold
                      : KashfPalette.active.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Generation state
// ============================================================================

sealed class _GenerationState {
  const _GenerationState();
}

class _IdleState extends _GenerationState {
  const _IdleState();
}

class _RunningState extends _GenerationState {
  const _RunningState(this.progress);
  final double progress;
}

class _CompleteState extends _GenerationState {
  const _CompleteState(this.outputs);
  final List<_OutputBucket> outputs;
}

// ============================================================================
// Output model + mock data
// ============================================================================

class _OutputBucket {
  _OutputBucket({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.metricValue,
    required this.metricSub,
    required this.items,
    required this.color,
    this.summary,
    this.socialLinks = const <_SocialLink>[],
  });
  final _OutputType type;
  final String title;
  final String subtitle;
  final String metricValue;
  final String metricSub;
  final List<_OutputItem> items;
  final Color color;
  /// Optional paragraph shown inside the card body (investigation).
  final String? summary;
  /// Optional list of platform buttons (social).
  final List<_SocialLink> socialLinks;
}

class _SocialLink {
  const _SocialLink({
    required this.label,
    required this.handle,
    required this.icon,
    required this.color,
    required this.url,
  });
  final String label;
  final String handle;
  final IconData icon;
  final Color color;
  final String url;
}

class _OutputItem {
  _OutputItem(this.label, this.value);
  final String label;
  final String value;
}

class _MockOutputs {
  static List<_OutputBucket> build({
    required String entity,
    required List<_OutputType> outputs,
    required AppLocalizations l,
  }) {
    final rawName = entity.trim();
    final name =
        rawName.isEmpty ? (l.isRtl ? 'الجهة' : 'the entity') : rawName;
    final list = <_OutputBucket>[];
    if (outputs.contains(_OutputType.investigation)) {
      list.add(
        _OutputBucket(
          type: _OutputType.investigation,
          title: l.tp('mi_res_inv_title', {'name': name}),
          subtitle: l.t('mi_res_inv_sub'),
          metricValue: l.isRtl ? '٢٠١٤' : '2014',
          metricSub: l.t('mi_res_inv_founded'),
          color: _OutputType.investigation.color,
          summary: l.t('mi_res_inv_summary'),
          items: [
            _OutputItem(
              l.t('mi_res_inv_hq'),
              l.t('mi_res_inv_hq_v'),
            ),
            _OutputItem(
              l.t('mi_res_inv_industry'),
              l.t('mi_res_inv_industry_v'),
            ),
            _OutputItem(
              l.t('mi_res_inv_audience'),
              l.t('mi_res_inv_audience_v'),
            ),
            _OutputItem(
              l.t('mi_res_inv_item3'),
              l.t('mi_res_inv_item3_v'),
            ),
          ],
        ),
      );
    }
    if (outputs.contains(_OutputType.social)) {
      final ig = _SocialLink(
        label: l.t('mi_res_soc_platform_ig'),
        handle: l.t('mi_res_soc_handle_ig'),
        icon: Icons.camera_alt_outlined,
        color: const Color(0xFFE1306C),
        url: 'https://instagram.com/kashf.lab',
      );
      final fb = _SocialLink(
        label: l.t('mi_res_soc_platform_fb'),
        handle: l.t('mi_res_soc_handle_fb'),
        icon: Icons.facebook,
        color: const Color(0xFF1877F2),
        url: 'https://facebook.com/kashf.lab',
      );
      final x = _SocialLink(
        label: l.t('mi_res_soc_platform_x'),
        handle: l.t('mi_res_soc_handle_x'),
        icon: Icons.alternate_email,
        color: const Color(0xFF1D9BF0),
        url: 'https://x.com/kashf_lab',
      );
      final tt = _SocialLink(
        label: l.t('mi_res_soc_platform_tt'),
        handle: l.t('mi_res_soc_handle_tt'),
        icon: Icons.music_note_outlined,
        color: const Color(0xFF25F4EE),
        url: 'https://tiktok.com/@kashf.lab',
      );
      final yt = _SocialLink(
        label: l.t('mi_res_soc_platform_yt'),
        handle: l.t('mi_res_soc_handle_yt'),
        icon: Icons.play_circle_outline,
        color: const Color(0xFFFF0000),
        url: 'https://youtube.com/@kashflab',
      );
      final sc = _SocialLink(
        label: l.t('mi_res_soc_platform_sc'),
        handle: l.t('mi_res_soc_handle_sc'),
        icon: Icons.photo_camera_back_outlined,
        color: const Color(0xFFFFFC00),
        url: 'https://snapchat.com/add/kashf',
      );
      list.add(
        _OutputBucket(
          type: _OutputType.social,
          title: l.tp('mi_res_soc_title', {'name': name}),
          subtitle: l.tp('mi_res_soc_sub', {'name': name}),
          metricValue: l.isRtl ? '٤٦٥ ألف متابع' : '465K',
          metricSub: l.t('mi_res_soc_followers'),
          color: _OutputType.social.color,
          socialLinks: [ig, fb, x, tt, yt, sc],
          items: [
            _OutputItem(
              ig.label,
              l.t('mi_res_soc_followers_ig'),
            ),
            _OutputItem(
              fb.label,
              l.t('mi_res_soc_followers_fb'),
            ),
            _OutputItem(
              x.label,
              l.t('mi_res_soc_followers_x'),
            ),
          ],
        ),
      );
    }
    if (outputs.contains(_OutputType.insights)) {
      list.add(
        _OutputBucket(
          type: _OutputType.insights,
          title: l.t('mi_res_ins_title'),
          subtitle: l.t('mi_res_ins_sub'),
          metricValue: l.t('mi_res_ins_metric'),
          metricSub: l.t('mi_res_ins_metric_sub'),
          color: _OutputType.insights.color,
          items: [
            _OutputItem(
              l.t('mi_res_ins_item1'),
              l.t('mi_res_ins_item1_v'),
            ),
            _OutputItem(
              l.t('mi_res_ins_item2'),
              l.tp('mi_res_ins_item2_v', {'name': name}),
            ),
            _OutputItem(
              l.t('mi_res_ins_item3'),
              l.t('mi_res_ins_item3_v'),
            ),
          ],
        ),
      );
    }
    if (outputs.contains(_OutputType.competitive)) {
      list.add(
        _OutputBucket(
          type: _OutputType.competitive,
          title: l.t('mi_res_cmp_title'),
          subtitle: l.tp('mi_res_cmp_sub', {'name': name}),
          metricValue: l.t('mi_res_cmp_metric'),
          metricSub: l.t('mi_res_cmp_metric_sub'),
          color: _OutputType.competitive.color,
          items: [
            _OutputItem(
              l.t('mi_res_cmp_item1'),
              l.t('mi_res_cmp_item1_v'),
            ),
            _OutputItem(
              l.t('mi_res_cmp_item2'),
              l.t('mi_res_cmp_item2_v'),
            ),
            _OutputItem(
              l.t('mi_res_cmp_item3'),
              l.t('mi_res_cmp_item3_v'),
            ),
          ],
        ),
      );
    }
    if (outputs.contains(_OutputType.monitoring)) {
      list.add(
        _OutputBucket(
          type: _OutputType.monitoring,
          title: l.t('mi_res_mon_title'),
          subtitle: l.tp('mi_res_mon_sub', {'name': name}),
          metricValue: l.t('mi_res_mon_metric'),
          metricSub: l.t('mi_res_mon_metric_sub'),
          color: _OutputType.monitoring.color,
          items: [
            _OutputItem(
              l.t('mi_res_mon_item1'),
              l.t('mi_res_mon_item1_v'),
            ),
            _OutputItem(
              l.t('mi_res_mon_item2'),
              l.t('mi_res_mon_item2_v'),
            ),
            _OutputItem(
              l.t('mi_res_mon_item3'),
              l.t('mi_res_mon_item3_v'),
            ),
          ],
        ),
      );
    }
    if (outputs.contains(_OutputType.content)) {
      list.add(
        _OutputBucket(
          type: _OutputType.content,
          title: l.t('mi_res_cnt_title'),
          subtitle: l.tp('mi_res_cnt_sub', {'name': name}),
          metricValue: l.t('mi_res_cnt_metric'),
          metricSub: l.t('mi_res_cnt_metric_sub'),
          color: _OutputType.content.color,
          items: [
            _OutputItem(
              l.t('mi_res_cnt_item1'),
              l.tp('mi_res_cnt_item1_v', {'name': name}),
            ),
            _OutputItem(
              l.t('mi_res_cnt_item2'),
              l.t('mi_res_cnt_item2_v'),
            ),
            _OutputItem(
              l.t('mi_res_cnt_item3'),
              l.t('mi_res_cnt_item3_v'),
            ),
          ],
        ),
      );
    }
    return list;
  }
}

class _OutputPanel extends StatefulWidget {
  const _OutputPanel({
    required this.state,
    required this.onRegenerate,
    required this.l,
  });
  final _GenerationState state;
  final VoidCallback onRegenerate;
  final AppLocalizations l;

  @override
  State<_OutputPanel> createState() => _OutputPanelState();
}

class _OutputPanelState extends State<_OutputPanel> {
  bool _modalShown = false;

  @override
  void didUpdateWidget(covariant _OutputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasComplete = oldWidget.state is _CompleteState;
    final isComplete = widget.state is _CompleteState;
    if (isComplete && !wasComplete && !_modalShown) {
      _modalShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showResultsSheet();
      });
    }
    if (!isComplete && wasComplete) {
      _modalShown = false;
    }
  }

  Future<void> _showResultsSheet() async {
    final s = widget.state as _CompleteState;
    final l = widget.l;
    final dir = l.isRtl ? TextDirection.rtl : TextDirection.ltr;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        return Directionality(
          textDirection: dir,
          child: DraggableScrollableSheet(
            initialChildSize: 0.92,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, controller) => Container(
              decoration: BoxDecoration(
                color: KashfPalette.active.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(
                  color: KashfColors.gold.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: _ResultsScaffold(
                outputs: s.outputs,
                controller: controller,
                onClose: () => Navigator.of(ctx).pop(),
                l: l,
              ),
            ),
          ),
        );
      },
    );
    if (mounted) _modalShown = false;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    if (s is _RunningState) {
      // The centered popup already shows the loading state. Keep this slot
      // empty so the user only sees one loading UI at a time.
      return const SizedBox.shrink();
    }
    if (s is _CompleteState) {
      // Show a small "View results" banner inline; the modal is already open.
      return _ResultsBanner(l: widget.l, count: s.outputs.length);
    }
    return _EmptyState(l: widget.l);
  }
}

class _ResultsBanner extends StatelessWidget {
  const _ResultsBanner({required this.l, required this.count});
  final AppLocalizations l;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F1810), Color(0xFF2D2418)],
        ),
        border: Border.all(
          color: KashfColors.gold.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: KashfColors.gold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.auto_awesome, color: KashfColors.gold, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('mi_results_ready_title'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  count == 1
                      ? l.t('mi_results_ready_count_one')
                      : l.tp('mi_results_ready_count_other', {
                          'count': l.isRtl ? '$count' : '$count',
                        }),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.expand_more, color: KashfColors.gold, size: 26),
        ],
      ),
    );
  }
}

class _ResultsScaffold extends StatelessWidget {
  const _ResultsScaffold({
    required this.outputs,
    required this.controller,
    required this.onClose,
    required this.l,
  });
  final List<_OutputBucket> outputs;
  final ScrollController controller;
  final VoidCallback onClose;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (ctx, setState) {
        return Column(
          children: [
            // Sticky header
            Container(
              padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: KashfPalette.active.background,
                border: Border(
                  bottom: BorderSide(color: KashfPalette.active.cardBorder),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: KashfPalette.active.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: KashfColors.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: KashfColors.gold,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              outputs.length == 1
                                  ? l.t('mi_results_badge_one')
                                  : l.tp('mi_results_badge_other', {
                                      'count': l.isRtl
                                          ? toArabicNumerals(outputs.length)
                                          : '${outputs.length}',
                                    }),
                              style: TextStyle(
                                color: KashfColors.gold,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Spacer(),
                      GestureDetector(
                        onTap: onClose,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: KashfPalette.active.fieldFill,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: KashfPalette.active.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // List of cards
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 32),
                itemCount: outputs.length,
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: _OutputBucketCard(bucket: outputs[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KashfColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_awesome,
                  color: KashfColors.gold,
                  size: 18,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.t('mi_empty_outputs'),
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatefulWidget {
  const _LoadingPanel({required this.progress, required this.l});
  final double progress;
  final AppLocalizations l;

  @override
  State<_LoadingPanel> createState() => _LoadingPanelState();
}

class _LoadingPanelState extends State<_LoadingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F1810), Color(0xFF2D2418)],
        ),
        border: Border.all(
          color: KashfColors.gold.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top header row: AI badge + scanning status.
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 14, 14, 8),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, _) => Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: KashfColors.gold.withValues(
                        alpha: 0.16 + _pulse.value * 0.18,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              KashfColors.gold.withValues(
                                alpha: 0.6 + _pulse.value * 0.4,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          widget.l.isRtl ? 'مباشر · ذكاء اصطناعي' : 'AI · LIVE',
                          style: TextStyle(
                            color: KashfColors.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Spacer(),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final delay = i * 0.25;
                      final v = ((_pulse.value + delay) % 1.0);
                      final opacity = (1.0 - v).clamp(0.2, 1.0);
                      return Padding(
                        padding: EdgeInsetsDirectional.only(start: 3),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: KashfColors.gold.withValues(alpha: opacity),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          // Title + spinner row.
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 4, 14, 6),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: KashfColors.gold,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.l.t('mi_loading_title'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        widget.l.t('mi_loading_subtitle'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Animated progress bar.
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 8, 14, 8),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 8,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 200),
                      tween: Tween(begin: 0, end: widget.progress),
                      builder: (_, v, __) => LinearProgressIndicator(
                        value: v,
                        minHeight: 8,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          KashfColors.gold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Progress and stage info.
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 0, 14, 14),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, _) => Text(
                    '${(widget.progress * 100).toStringAsFixed(0)} %',
                    style: TextStyle(
                      color: KashfColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Spacer(),
                Text(
                  _stageFor(widget.progress),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _stageFor(double p) {
    final l = widget.l;
    final isRtl = l.isRtl;
    if (isRtl) {
      if (p < 0.25) return 'جمع البيانات…';
      if (p < 0.5) return 'تحليل المصادر…';
      if (p < 0.75) return 'مطابقة الاتجاهات…';
      if (p < 1.0) return 'إنهاء الرؤى…';
      return 'تم';
    }
    if (p < 0.25) return 'Gathering data…';
    if (p < 0.5) return 'Analyzing sources…';
    if (p < 0.75) return 'Cross-referencing trends…';
    if (p < 1.0) return 'Finalizing insights…';
    return 'Done';
  }
}

class _OutputBucketCard extends StatelessWidget {
  const _OutputBucketCard({required this.bucket});
  final _OutputBucket bucket;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: bucket.color.withValues(alpha: 0.30),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: bucket.color.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: gradient strip with icon + type + close chip area.
          Container(
            padding: EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [
                  bucket.color.withValues(alpha: 0.18),
                  bucket.color.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(17),
              ),
              border: Border(
                bottom: BorderSide(
                  color: bucket.color.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: bucket.color.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: bucket.color.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    bucket.type.icon,
                    color: bucket.color,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bucket.title,
                        style: TextStyle(
                          color: KashfPalette.active.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        bucket.subtitle,
                        style: TextStyle(
                          color: KashfPalette.active.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: KashfPalette.active.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: bucket.color.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        bucket.metricValue,
                        style: TextStyle(
                          color: bucket.color,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        bucket.metricSub,
                        style: TextStyle(
                          color: KashfPalette.active.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body: optional summary paragraph + social grid + items list.
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bucket.summary != null) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bucket.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: bucket.color.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Text(
                      bucket.summary!,
                      style: TextStyle(
                        color: KashfPalette.active.textPrimary,
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                ],
                if (bucket.socialLinks.isNotEmpty) ...[
                  _SocialLinksGrid(links: bucket.socialLinks),
                  SizedBox(height: 10),
                ],
                for (int i = 0; i < bucket.items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: KashfPalette.active.cardBorder
                          .withValues(alpha: 0.5),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: EdgeInsetsDirectional.only(end: 10),
                          decoration: BoxDecoration(
                            color: bucket.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: bucket.color.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            bucket.items[i].label,
                            style: TextStyle(
                              color: KashfPalette.active.textSecondary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: bucket.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            bucket.items[i].value,
                            style: TextStyle(
                              color: bucket.color,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
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
      ),
    );
  }
}

class _SocialLinksGrid extends StatelessWidget {
  const _SocialLinksGrid({required this.links});
  final List<_SocialLink> links;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 columns on phone widths, 3 columns on wider sheets.
        final crossAxisCount = constraints.maxWidth >= 520 ? 3 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.6,
          children: [
            for (final link in links) _SocialLinkTile(link: link),
          ],
        );
      },
    );
  }
}

class _SocialLinkTile extends StatelessWidget {
  const _SocialLinkTile({required this.link});
  final _SocialLink link;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: KashfPalette.active.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: link.color.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: link.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(link.icon, size: 16, color: link.color),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  link.label,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1),
                Text(
                  link.handle,
                  style: TextStyle(
                    color: KashfPalette.active.textSecondary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
// History
// ============================================================================

class _HistoryEntry {
  _HistoryEntry({
    required this.id,
    required this.entity,
    required this.categories,
    required this.createdAt,
    required this.outputs,
  });
  final String id;
  final String entity;
  final List<_EntityCategory> categories;
  final DateTime createdAt;
  final List<_OutputBucket> outputs;
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.entries, required this.l});
  final List<_HistoryEntry> entries;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KashfPalette.active.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KashfPalette.active.cardBorder),
        ),
        child: Row(
          children: [
            Icon(
              Icons.history_toggle_off,
              color: KashfPalette.active.textSecondary,
            ),
            SizedBox(width: 10),
            Text(
              l.t('mi_empty_history'),
              style: TextStyle(
                color: KashfPalette.active.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final entry in entries) ...[
          _HistoryRow(entry: entry),
          SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});
  final _HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KashfPalette.active.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KashfPalette.active.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: KashfColors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.auto_awesome, color: KashfColors.gold, size: 18),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.entity,
                  style: TextStyle(
                    color: KashfPalette.active.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final c in entry.categories)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: c.color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          c.label(context),
                          style: TextStyle(
                            color: c.color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: KashfPalette.active.textSecondary,
            size: 18,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Progress ticker (simulated AI generation)
// ============================================================================

class _ProgressTicker {
  _ProgressTicker({
    required this.onTick,
    required this.onComplete,
    this.totalMs = 4500,
    this.tickMs = 16,
  });
  final ValueChanged<double> onTick;
  final VoidCallback onComplete;
  final int totalMs;
  final int tickMs;
  Timer? _timer;

  void start() {
    final start = DateTime.now();
    _timer = Timer.periodic(Duration(milliseconds: tickMs), (t) {
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final p = (elapsed / totalMs).clamp(0.0, 1.0);
      onTick(p);
      if (p >= 1.0) {
        t.cancel();
        onComplete();
      }
    });
  }
}
