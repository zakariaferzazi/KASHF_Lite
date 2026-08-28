import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/saved_investigation.dart';
import '../../models/investigation_result.dart';
import '../../services/investigation_archive_service.dart';
import '../../services/script_studio/script_draft.dart';
import '../../services/script_studio/script_generator_service.dart';
import '../settings/settings_scaffold.dart';
import '../../theme.dart';

/// Result viewer for the admin-only Content Studio. Pulls the
/// source [SavedInvestigation] (passed in by the picker screen),
/// hydrates the underlying [InvestigationResult], generates a
/// script via [ScriptGeneratorService], and exposes a polished,
/// editable UI with copy / share / regenerate / export actions.
class AdminScriptViewerScreen extends StatefulWidget {
  const AdminScriptViewerScreen({
    super.key,
    required this.investigation,
    required this.kind,
  });

  final SavedInvestigation investigation;
  final ScriptKind kind;

  @override
  State<AdminScriptViewerScreen> createState() =>
      _AdminScriptViewerScreenState();
}

class _AdminScriptViewerScreenState extends State<AdminScriptViewerScreen> {
  ScriptDraft? _draft;
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isRegenerating = false;
  String? _error;

  /// Holds the controller used by the editable script body. Only
  /// populated AFTER [_draft] is set so the field doesn't flicker
  /// on rebuilds.
  TextEditingController? _bodyController;

  /// Active lookup so the viewer can rebuild the in-memory
  /// controller if [kind] / investigation change.
  String get _draftKey =>
      '${widget.investigation.id}:${widget.kind.name}:${_draft?.generatedAt.microsecondsSinceEpoch ?? 0}';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _bodyController?.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Pull the full result from the archive. The picker screen
      // already filtered out rows without an embedded report,
      // but a defensive null-check here keeps the viewer robust
      // if the row was modified mid-flight (e.g. auto-refresh
      // just overwrote it with an incomplete payload).
      final result =
          await InvestigationArchiveService.instance.loadResult(
        widget.investigation.id,
      );
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _isLoading = false;
          _error = 'no_result';
        });
        return;
      }

      final draft = widget.kind == ScriptKind.reel
          ? await ScriptGeneratorService.instance
              .generateReelScript(result: result)
          : await ScriptGeneratorService.instance
              .generatePodcastScript(result: result);
      if (!mounted) return;

      _bodyController?.dispose();
      _bodyController = TextEditingController(text: _buildEditableText(draft));

      setState(() {
        _draft = draft;
        _isLoading = false;
      });
    } on ScriptGenerationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  /// Composes the editable plain-text the admin can edit in the
  /// text field. Re-deriving from sections on every edit would be
  /// expensive (and lossy), so we mirror the structural pieces
  /// once and let the user freely rewrite them.
  String _buildEditableText(ScriptDraft draft) {
    final buf = StringBuffer();
    if (draft.title.isNotEmpty) {
      buf
        ..writeln(draft.title.toUpperCase())
        ..writeln('');
    }
    if (draft.hook.isNotEmpty) {
      buf
        ..writeln('HOOK')
        ..writeln(draft.hook)
        ..writeln('');
    }
    for (final s in draft.sections) {
      if (s.label.isNotEmpty) {
        buf.writeln(s.label.toUpperCase());
      }
      buf.writeln(s.body);
      buf.writeln('');
    }
    if (draft.callToAction.isNotEmpty) {
      buf
        ..writeln('CTA')
        ..writeln(draft.callToAction);
    }
    return buf.toString().trimRight();
  }

  // -----------------------------------------------------------------
  // Action handlers
  // -----------------------------------------------------------------

  Future<void> _copyToClipboard() async {
    final text = _draft?.toPlainText() ?? _bodyController?.text ?? '';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.t('adm_script_copied'))),
    );
  }

  Future<void> _regenerate() async {
    if (_isRegenerating) return;
    setState(() => _isRegenerating = true);
    try {
      await _generate();
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  /// Writes the current draft to a .txt file in the user's
  /// Documents / Downloads directory and copies the path to the
  /// clipboard so the admin can paste it anywhere (file explorer,
  /// messaging app, etc.).
  Future<void> _exportTxt() async {
    if (_isExporting) return;
    final l = AppLocalizations.of(context);
    setState(() => _isExporting = true);
    try {
      final dir = await _exportDir();
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filename =
          'kashf_${widget.kind.name}_${widget.investigation.id}_$stamp.txt';
      final file = File('${dir.path}/$filename');
      final text = _draft?.toPlainText() ?? _bodyController?.text ?? '';
      await file.writeAsString(text);

      // Copy the path so the admin can grab it even on platforms
      // that don't surface the Documents folder in the system
      // file picker.
      await Clipboard.setData(ClipboardData(text: file.path));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.t('adm_script_exported')}: ${file.path}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.t('adm_script_export_failed')}: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Resolves a sensible export directory across platforms. Falls
  /// back to the temporary directory when neither Documents nor
  /// Downloads is available (very old Android / unusual setups).
  Future<Directory> _exportDir() async {
    // path_provider always exposes getApplicationDocumentsDirectory
    // so we prefer it; on iOS / macOS it maps to the user-visible
    // Files app location. On Android we get the app-private
    // external storage which is still addressable from the file
    // picker via "Show internal storage".
    final docs = await getApplicationDocumentsDirectory();
    return docs;
  }

  // -----------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = widget.kind == ScriptKind.reel
        ? l.t('adm_script_reel_title')
        : l.t('adm_script_podcast_title');

    return SettingsScaffold(
      title: title,
      padding: EdgeInsets.zero,
      actions: [
        if (_draft != null && !_isLoading)
          IconButton(
            tooltip: l.t('adm_script_copy'),
            icon: const Icon(Icons.copy_outlined),
            onPressed: _copyToClipboard,
          ),
        if (_draft != null && !_isLoading)
          IconButton(
            tooltip: l.t('adm_script_export'),
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: KashfColors.gold,
                    ),
                  )
                : const Icon(Icons.download_outlined),
            onPressed: _isExporting ? null : _exportTxt,
          ),
      ],
      child: _buildBody(l),
    );
  }

  Widget _buildBody(AppLocalizations l) {
    if (_isLoading) {
      return _LoadingState(label: l.t('adm_script_generating'));
    }
    if (_error != null) {
      return _ErrorState(
        message: _error!,
        retryLabel: l.t('adm_script_retry'),
        onRetry: _regenerate,
      );
    }
    final draft = _draft;
    if (draft == null || _bodyController == null) {
      return _ErrorState(
        message: l.t('adm_script_unknown_error'),
        retryLabel: l.t('adm_script_retry'),
        onRetry: _regenerate,
      );
    }

    return Column(
      key: ValueKey(_draftKey),
      children: [
        _buildHeader(l, draft),
        const Divider(height: 1, color: Color(0xFF3A4055)),
        Expanded(child: _buildEditableBody(l)),
        _buildBottomBar(l),
      ],
    );
  }

  Widget _buildHeader(AppLocalizations l, ScriptDraft draft) {
    final accent = widget.kind == ScriptKind.reel
        ? const Color(0xFFEF4444)
        : const Color(0xFF8B5CF6);
    final durationLabel = widget.kind == ScriptKind.reel
        ? '~${draft.durationSeconds}s'
        : '~${(draft.durationSeconds / 60).round()} min';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.kind == ScriptKind.reel
                          ? Icons.movie_creation_outlined
                          : Icons.mic_none_outlined,
                      size: 14,
                      color: accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${draft.kind.displayName.toUpperCase()} · $durationLabel',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _isRegenerating ? null : _regenerate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: KashfColors.gold,
                  side: const BorderSide(color: KashfColors.gold),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                ),
                icon: _isRegenerating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: KashfColors.gold,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: Text(l.t('adm_script_regenerate')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l.t('adm_script_source_label'),
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            draft.sourceInvestigationTitle,
            style: TextStyle(
              color: KashfPalette.active.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEditableBody(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: TextField(
        controller: _bodyController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        style: TextStyle(
          color: KashfPalette.active.textPrimary,
          fontSize: 14,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: l.t('adm_script_edit_hint'),
          hintStyle: TextStyle(
            color: KashfPalette.active.textSecondary,
            fontSize: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: KashfPalette.active.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: KashfPalette.active.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: KashfColors.gold, width: 1.4),
          ),
          filled: true,
          fillColor: KashfPalette.active.surface,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: KashfPalette.active.surface,
          border: Border(
            top: BorderSide(color: KashfPalette.active.cardBorder),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyToClipboard,
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: Text(l.t('adm_script_copy')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: KashfColors.gold,
                  side: const BorderSide(color: KashfColors.gold),
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
                onPressed: _isExporting ? null : _exportTxt,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(l.t('adm_script_export')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KashfColors.gold,
                  foregroundColor: Colors.black,
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
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: KashfColors.gold),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: KashfPalette.active.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFEF4444),
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: KashfColors.gold,
                side: const BorderSide(color: KashfColors.gold),
              ),
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

