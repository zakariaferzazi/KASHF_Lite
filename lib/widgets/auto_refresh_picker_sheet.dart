import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/saved_investigation.dart';
import '../services/auto_refresh_service.dart';
import '../theme.dart';

/// Bottom-sheet picker that asks the user how long they want
/// KASHF Lite to keep an investigation fresh — Off / 30 days /
/// 60 days. The choice is persisted on the saved-investigation
/// document and handed to [AutoRefreshService] so the
/// background scheduler can re-run the report every 72h until
/// the expiry window closes.
///
/// Returns the chosen value (in days) when the user
/// confirms, or `null` when they dismiss.
Future<int?> showAutoRefreshPicker(
  BuildContext context, {
  required SavedInvestigation saved,
}) {
  return showModalBottomSheet<int>(
    context: context,
    // Let the sheet grow with the keyboard so the confirm
    // button stays tappable while the user is composing a
    // custom note (future-proofing for the search field).
    isScrollControlled: true,
    backgroundColor: KashfPalette.active.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AutoRefreshPickerSheet(saved: saved),
  );
}

class _AutoRefreshPickerSheet extends StatefulWidget {
  const _AutoRefreshPickerSheet({required this.saved});
  final SavedInvestigation saved;

  @override
  State<_AutoRefreshPickerSheet> createState() =>
      _AutoRefreshPickerSheetState();
}

class _AutoRefreshPickerSheetState extends State<_AutoRefreshPickerSheet> {
  /// Currently-highlighted choice. Defaults to the saved value
  /// (or `0` if the saved investigation has no auto-refresh).
  late int _selected = widget.saved.autoRefreshDays == 0
      ? 0
      : (widget.saved.autoRefreshDays == 30 ||
              widget.saved.autoRefreshDays == 60)
          ? widget.saved.autoRefreshDays
          : 0;

  /// Brief shimmer shown after the user confirms so the
  /// bottom sheet doesn't snap shut before the user sees
  /// their pick "saved".
  bool _saving = false;

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await AutoRefreshService.instance.setAutoRefreshFor(
        saved: widget.saved,
        days: _selected,
      );
      if (!mounted) return;
      Navigator.of(context).pop(_selected);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // Best-effort: keep the sheet open and toast the error.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: KashfPalette.active.surface,
          content: Text(
            e.toString(),
            style: TextStyle(color: KashfPalette.active.textPrimary),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = KashfPalette.active;
    final isRtl = l.isRtl;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        8,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle.
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.t('ir_auto_refresh_title'),
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.t('ir_auto_refresh_sub'),
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          for (final days in kAutoRefreshDayChoices) ...[
            _OptionTile(
              days: days,
              l: l,
              selected: _selected == days,
              onTap: _saving ? null : () => setState(() => _selected = days),
              isRtl: isRtl,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.textPrimary,
                    side: BorderSide(color: palette.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l.t('common_cancel'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KashfColors.gold,
                    disabledBackgroundColor:
                        KashfColors.gold.withValues(alpha: 0.4),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.black),
                          ),
                        )
                      : Text(
                          l.t('ir_auto_refresh_confirm'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
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
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.days,
    required this.selected,
    required this.onTap,
    required this.l,
    required this.isRtl,
  });

  /// `0` means Off. `30` / `60` are the supported windows.
  final int days;
  final bool selected;
  final VoidCallback? onTap;
  final AppLocalizations l;
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final String title;
    final String sub;
    final IconData icon;
    switch (days) {
      case 0:
        title = l.t('ir_auto_refresh_off');
        sub = l.t('ir_auto_refresh_off_sub');
        icon = Icons.power_settings_new_rounded;
        break;
      case 30:
        title = l.t('ir_auto_refresh_30');
        sub = l.t('ir_auto_refresh_30_sub');
        icon = Icons.calendar_view_month_rounded;
        break;
      case 60:
        title = l.t('ir_auto_refresh_60');
        sub = l.t('ir_auto_refresh_60_sub');
        icon = Icons.calendar_view_month_rounded;
        break;
      default:
        title = '$days';
        sub = '';
        icon = Icons.refresh_rounded;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? KashfColors.gold.withValues(alpha: 0.10)
                : palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? KashfColors.gold
                  : palette.cardBorder,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? KashfColors.gold.withValues(alpha: 0.18)
                      : palette.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? KashfColors.gold
                      : palette.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? KashfColors.gold
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? KashfColors.gold
                        : palette.cardBorder,
                    width: 1.6,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.black,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
