import 'package:flutter/material.dart';

/// The five top-level entity types the user can investigate.
enum EntityType {
  company(Icons.business_outlined, Icons.business),
  brand(Icons.label_outline, Icons.label),
  product(Icons.inventory_2_outlined, Icons.inventory_2),
  influencer(Icons.person_outline, Icons.person),
  market(Icons.show_chart_outlined, Icons.show_chart);

  const EntityType(this.outlineIcon, this.filledIcon);

  final IconData outlineIcon;
  final IconData filledIcon;

  /// Localization key — matches the `entity_*` keys in [AppLocalizations].
  String get l10nKey {
    switch (this) {
      case EntityType.company:
        return 'entity_company';
      case EntityType.brand:
        return 'entity_brand';
      case EntityType.product:
        return 'entity_product';
      case EntityType.influencer:
        return 'entity_influencer';
      case EntityType.market:
        return 'entity_market';
    }
  }
}
