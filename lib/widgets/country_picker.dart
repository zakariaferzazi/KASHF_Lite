import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme.dart';

/// A curated set of dial codes used by the country picker.
///
/// Covers the Gulf, MENA, Europe, North America and South Asia
/// regions that the app primarily serves. A production app would
/// back this with a JSON dataset, but a curated list keeps the
/// dependency surface flat.
class CountryInfo {
  const CountryInfo({
    required this.dial,
    required this.name,
    required this.arabicName,
  });

  /// E.164 dial code, e.g. `+966`.
  final String dial;

  /// English display name, e.g. `Saudi Arabia`.
  final String name;

  /// Arabic display name, e.g. `السعودية`.
  final String arabicName;
}

const List<CountryInfo> kSupportedCountries = [
  CountryInfo(dial: '+966', name: 'Saudi Arabia', arabicName: 'السعودية'),
  CountryInfo(dial: '+971', name: 'United Arab Emirates', arabicName: 'الإمارات'),
  CountryInfo(dial: '+965', name: 'Kuwait', arabicName: 'الكويت'),
  CountryInfo(dial: '+973', name: 'Bahrain', arabicName: 'البحرين'),
  CountryInfo(dial: '+974', name: 'Qatar', arabicName: 'قطر'),
  CountryInfo(dial: '+968', name: 'Oman', arabicName: 'عُمان'),
  CountryInfo(dial: '+962', name: 'Jordan', arabicName: 'الأردن'),
  CountryInfo(dial: '+961', name: 'Lebanon', arabicName: 'لبنان'),
  CountryInfo(dial: '+963', name: 'Syria', arabicName: 'سوريا'),
  CountryInfo(dial: '+964', name: 'Iraq', arabicName: 'العراق'),
  CountryInfo(dial: '+967', name: 'Yemen', arabicName: 'اليمن'),
  CountryInfo(dial: '+970', name: 'Palestine', arabicName: 'فلسطين'),
  CountryInfo(dial: '+20', name: 'Egypt', arabicName: 'مصر'),
  CountryInfo(dial: '+212', name: 'Morocco', arabicName: 'المغرب'),
  CountryInfo(dial: '+213', name: 'Algeria', arabicName: 'الجزائر'),
  CountryInfo(dial: '+216', name: 'Tunisia', arabicName: 'تونس'),
  CountryInfo(dial: '+218', name: 'Libya', arabicName: 'ليبيا'),
  CountryInfo(dial: '+249', name: 'Sudan', arabicName: 'السودان'),
  CountryInfo(dial: '+1', name: 'United States / Canada', arabicName: 'الولايات المتحدة / كندا'),
  CountryInfo(dial: '+44', name: 'United Kingdom', arabicName: 'المملكة المتحدة'),
  CountryInfo(dial: '+33', name: 'France', arabicName: 'فرنسا'),
  CountryInfo(dial: '+49', name: 'Germany', arabicName: 'ألمانيا'),
  CountryInfo(dial: '+34', name: 'Spain', arabicName: 'إسبانيا'),
  CountryInfo(dial: '+39', name: 'Italy', arabicName: 'إيطاليا'),
  CountryInfo(dial: '+31', name: 'Netherlands', arabicName: 'هولندا'),
  CountryInfo(dial: '+46', name: 'Sweden', arabicName: 'السويد'),
  CountryInfo(dial: '+47', name: 'Norway', arabicName: 'النرويج'),
  CountryInfo(dial: '+45', name: 'Denmark', arabicName: 'الدنمارك'),
  CountryInfo(dial: '+41', name: 'Switzerland', arabicName: 'سويسرا'),
  CountryInfo(dial: '+43', name: 'Austria', arabicName: 'النمسا'),
  CountryInfo(dial: '+48', name: 'Poland', arabicName: 'بولندا'),
  CountryInfo(dial: '+90', name: 'Turkey', arabicName: 'تركيا'),
  CountryInfo(dial: '+91', name: 'India', arabicName: 'الهند'),
  CountryInfo(dial: '+92', name: 'Pakistan', arabicName: 'باكستان'),
  CountryInfo(dial: '+880', name: 'Bangladesh', arabicName: 'بنغلاديش'),
  CountryInfo(dial: '+62', name: 'Indonesia', arabicName: 'إندونيسيا'),
  CountryInfo(dial: '+60', name: 'Malaysia', arabicName: 'ماليزيا'),
  CountryInfo(dial: '+65', name: 'Singapore', arabicName: 'سنغافورة'),
  CountryInfo(dial: '+81', name: 'Japan', arabicName: 'اليابان'),
  CountryInfo(dial: '+82', name: 'South Korea', arabicName: 'كوريا الجنوبية'),
  CountryInfo(dial: '+86', name: 'China', arabicName: 'الصين'),
  CountryInfo(dial: '+852', name: 'Hong Kong', arabicName: 'هونغ كونغ'),
  CountryInfo(dial: '+61', name: 'Australia', arabicName: 'أستراليا'),
  CountryInfo(dial: '+64', name: 'New Zealand', arabicName: 'نيوزيلندا'),
  CountryInfo(dial: '+27', name: 'South Africa', arabicName: 'جنوب أفريقيا'),
  CountryInfo(dial: '+234', name: 'Nigeria', arabicName: 'نيجيريا'),
  CountryInfo(dial: '+254', name: 'Kenya', arabicName: 'كينيا'),
];

/// Maps a dial code (e.g. `+966`) to the canonical `CountryInfo`
/// record. Falls back to `null` when the code isn't on the curated
/// list.
CountryInfo? countryByDial(String dial) {
  for (final c in kSupportedCountries) {
    if (c.dial == dial) return c;
  }
  return null;
}

/// Returns the display name (English) for a dial code, falling back
/// to the dial code itself when not found.
String countryNameForDial(String dial) {
  return countryByDial(dial)?.name ?? dial;
}

/// Shows the country picker bottom-sheet and resolves with the
/// chosen [CountryInfo] (or `null` if the user dismissed it).
Future<CountryInfo?> showCountryPicker(
  BuildContext context, {
  String? currentDialCode,
}) {
  return showModalBottomSheet<CountryInfo>(
    context: context,
    backgroundColor: KashfPalette.active.surface,
    // Let the sheet grow with the keyboard so the search field
    // stays visible (and tappable) while the user is typing.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _CountryPickerSheet(currentDialCode: currentDialCode),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({this.currentDialCode});
  final String? currentDialCode;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = KashfPalette.active;
    final l = AppLocalizations.of(context);
    final filtered = kSupportedCountries
        .where((c) => _query.isEmpty
            ? true
            : c.dial.toLowerCase().contains(_query.toLowerCase()) ||
                c.name.toLowerCase().contains(_query.toLowerCase()) ||
                c.arabicName.contains(_query))
        .toList();
    // Constrain the sheet to a usable height so the search field
    // and a healthy chunk of the country list stay on screen even
    // when the soft keyboard is open. Without this the bottom sheet
    // collapses around the keyboard and pushes the search input
    // (and the user's typed text) out of view.
    final media = MediaQuery.of(context);
    final maxSheetHeight = media.size.height - media.viewInsets.top - 24;
    final cappedHeight = maxSheetHeight.clamp(280.0, 560.0);
    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          16,
          12,
          16,
          12 + media.viewInsets.bottom,
        ),
        child: SizedBox(
          height: cappedHeight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 36,
                decoration: BoxDecoration(
                  color: palette.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: palette.fieldFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.fieldBorder),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(color: palette.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: l.t('auth_country_search_hint'),
                    hintStyle: TextStyle(color: palette.textSecondary),
                    prefixIcon: Icon(Icons.search,
                        color: palette.textSecondary, size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final c = filtered[i];
                    final selected = c.dial == widget.currentDialCode;
                    return InkWell(
                      onTap: () => Navigator.of(ctx).pop(c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 56,
                              child: Text(
                                c.dial,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                c.name,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle,
                                  color: KashfColors.gold, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}