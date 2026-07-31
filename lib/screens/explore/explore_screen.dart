import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme.dart';

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
  _OutputFilter _outputFilter = _OutputFilter.all;

  // --- Workspace history (in-memory for demo) ---
  final List<_HistoryEntry> _history = <_HistoryEntry>[];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _linkCtrl.dispose();
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
    _ProgressTicker(
      onTick: (v) {
        if (!mounted) return;
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
    );
    setState(() => _generation = _CompleteState(outputs));
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
      setState(() {
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
          content: Text(AppLocalizations.of(context).t('mi_save_button')),
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
                    filter: _outputFilter,
                    onFilterChanged: (f) => setState(() => _outputFilter = f),
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
  });
  final _OutputType type;
  final String title;
  final String subtitle;
  final String metricValue;
  final String metricSub;
  final List<_OutputItem> items;
  final Color color;
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
  }) {
    final name = entity.trim().isEmpty ? 'الجهة' : entity.trim();
    final list = <_OutputBucket>[];
    if (outputs.contains(_OutputType.investigation)) {
      list.add(
        _OutputBucket(
          type: _OutputType.investigation,
          title: 'تقرير تحقيق لـ «$name»',
          subtitle: 'مصادر موثّقة ونتائج رئيسية',
          metricValue: '١٢',
          metricSub: 'مصدر',
          color: _OutputType.investigation.color,
          items: [
            _OutputItem('مصادر موثّقة', '٨ / ١٢'),
            _OutputItem('نتائج رئيسية', '٥ أبرز'),
            _OutputItem('نبرة الجمهور', '+٤٢٪ إيجابية'),
            _OutputItem('مؤشر المخاطرة', 'منخفض · ١٨/١٠٠'),
          ],
        ),
      );
    }
    if (outputs.contains(_OutputType.social)) {
      list.add(
        _OutputBucket(
          type: _OutputType.social,
          title: 'روابط ومقاييس التفاعل',
          subtitle: 'منشورات مختارة حول «$name»',
          metricValue: '٢٨٫٤ ألف',
          metricSub: 'ذكر',
          color: _OutputType.social.color,
          items: [
            _OutputItem('نشطاء إنستغرام', '١٧٢'),
            _OutputItem('نشطاء تيك توك', '٨٤'),
            _OutputItem('أعلى تفاعل', '@abeer.s · ١٫٢م'),
            _OutputItem('هاشتاقات', '#$name · ٤٫١ك'),
          ],
        ),
      );
    }
    if (outputs.contains(_OutputType.insights)) {
      list.add(
        _OutputBucket(
          type: _OutputType.insights,
          title: 'رؤى السوق',
          subtitle: 'اتجاهات، نمو، فرص',
          metricValue: '+٢٤٪',
          metricSub: 'نمو (٩٠ يوم)',
          color: _OutputType.insights.color,
          items: [
            _OutputItem('الاتجاه الأبرز', 'العطور الخشبية في الخليج'),
            _OutputItem('فرصة مقترحة', 'إطلاق خط «$name» في الربع الثالث'),
            _OutputItem('التوقع', '١٢٪ حصة سوقية بنهاية الربع الرابع'),
          ],
        ),
      );
    }
    if (outputs.contains(_OutputType.competitive)) {
      list.add(
        _OutputBucket(
          type: _OutputType.competitive,
          title: 'تحليل المنافسين',
          subtitle: 'أين يقف «$name» مقارنة بالسوق',
          metricValue: '#٣',
          metricSub: 'ترتيب السوق',
          color: _OutputType.competitive.color,
          items: [
            _OutputItem('مقارنة بـ Dior Sauvage', '-١٢٪'),
            _OutputItem('مقارنة بـ Lattafa Asad', '+٢٨٪'),
            _OutputItem('مقارنة بـ Chanel BLEU', '-٥٪'),
          ],
        ),
      );
    }
    if (outputs.contains(_OutputType.monitoring)) {
      list.add(
        _OutputBucket(
          type: _OutputType.monitoring,
          title: 'تحديثات المتابعة',
          subtitle: 'تتبع جديد التطورات حول «$name»',
          metricValue: '٧ أيام',
          metricSub: 'نشاط حديث',
          color: _OutputType.monitoring.color,
          items: [
            _OutputItem('ارتفاعات', '٣ تم رصدها'),
            _OutputItem('قنوات مراقبة', '٥ قنوات'),
            _OutputItem('المزامنة القادمة', 'خلال ١٤ ساعة'),
          ],
        ),
      );
    }
    if (outputs.contains(_OutputType.content)) {
      list.add(
        _OutputBucket(
          type: _OutputType.content,
          title: 'أفكار محتوى',
          subtitle: 'أفكار استراتيجية لجمهور «$name»',
          metricValue: '٩',
          metricSub: 'فكرة',
          color: _OutputType.content.color,
          items: [
            _OutputItem('سكريبت ريلز', '"من الغسق إلى $name"'),
            _OutputItem('بودكاست', 'سباق العطور في الخليج'),
            _OutputItem('ميكرو بيتش', 'لانطلاق حملة Q3'),
          ],
        ),
      );
    }
    return list;
  }
}

enum _OutputFilter { all, summary, sources }

class _OutputPanel extends StatefulWidget {
  const _OutputPanel({
    required this.state,
    required this.filter,
    required this.onFilterChanged,
    required this.onRegenerate,
    required this.l,
  });
  final _GenerationState state;
  final _OutputFilter filter;
  final ValueChanged<_OutputFilter> onFilterChanged;
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
      return _LoadingPanel(progress: s.progress, l: widget.l);
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
                  l.isRtl ? 'الكشوفات جاهزة' : 'Insights ready',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  l.isRtl
                      ? 'تم تجهيز $count نتيجة كشف · اعرضها أدناه'
                      : '$count insight items ready · view below',
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
    _OutputFilter filter = _OutputFilter.all;
    return StatefulBuilder(
      builder: (ctx, setState) {
        final filtered = switch (filter) {
          _OutputFilter.all => outputs,
          _OutputFilter.summary =>
            outputs.where((o) => o.items.length <= 4).toList(),
          _OutputFilter.sources =>
            outputs
                .where(
                  (o) =>
                      o.type == _OutputType.investigation ||
                      o.type == _OutputType.competitive ||
                      o.type == _OutputType.monitoring,
                )
                .toList(),
        };
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
                              l.isRtl
                                  ? 'AI · ${outputs.length} نتائج كشف'
                                  : 'AI · ${outputs.length} insights',
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
            // Action bar: filters + exports
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _FilterPillInline(
                    label: l.t('mi_filter_all'),
                    selected: filter == _OutputFilter.all,
                    onTap: () => setState(() => filter = _OutputFilter.all),
                  ),
                  _FilterPillInline(
                    label: l.t('mi_filter_summary'),
                    selected: filter == _OutputFilter.summary,
                    onTap: () => setState(() => filter = _OutputFilter.summary),
                  ),
                  _FilterPillInline(
                    label: l.t('mi_filter_sources'),
                    selected: filter == _OutputFilter.sources,
                    onTap: () => setState(() => filter = _OutputFilter.sources),
                  ),
                  // Spacer-equivalent gap, then exports on the right.
                  SizedBox(width: 4),
                  _ExportIconButton(
                    icon: Icons.picture_as_pdf_outlined,
                    onPressed: () {},
                  ),
                  _ExportIconButton(
                    icon: Icons.table_view_outlined,
                    onPressed: () {},
                  ),
                  _ExportIconButton(icon: Icons.link, onPressed: () {}),
                ],
              ),
            ),
            // List of cards
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 32),
                itemCount: filtered.length,
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: _OutputBucketCard(bucket: filtered[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterPillInline extends StatelessWidget {
  const _FilterPillInline({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? KashfColors.gold.withValues(alpha: 0.18)
              : KashfPalette.active.fieldFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? KashfColors.gold : KashfPalette.active.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? KashfColors.gold
                : KashfPalette.active.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ExportIconButton extends StatelessWidget {
  const _ExportIconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: KashfPalette.active.fieldFill,
          shape: BoxShape.circle,
          border: Border.all(color: KashfPalette.active.cardBorder),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: KashfColors.gold, size: 16),
      ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bucket.color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top colored bar (matches the AI accent).
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bucket.color.withValues(alpha: 0.2), bucket.color],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: bucket.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        bucket.type.icon,
                        color: bucket.color,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bucket.title,
                            style: TextStyle(
                              color: KashfPalette.active.textPrimary,
                              fontSize: 14,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          bucket.metricValue,
                          style: TextStyle(
                            color: bucket.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          bucket.metricSub,
                          style: TextStyle(
                            color: KashfPalette.active.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                for (final item in bucket.items)
                  Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: EdgeInsetsDirectional.only(end: 8),
                          decoration: BoxDecoration(
                            color: bucket.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: KashfPalette.active.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Text(
                          item.value,
                          style: TextStyle(
                            color: KashfPalette.active.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
  });
  final ValueChanged<double> onTick;
  final VoidCallback onComplete;
  final int totalMs;
  late final int tickMs;
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
