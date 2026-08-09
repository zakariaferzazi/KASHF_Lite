import 'package:flutter/foundation.dart';

/// A trending item in the carousel.
@immutable
class ExploreTrendingItem {
  const ExploreTrendingItem({
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.subtitleAr,
    this.imageHint,
    this.category,
  });

  final String titleEn;
  final String titleAr;
  final String subtitleEn;
  final String subtitleAr;
  final String? imageHint; // short noun for asset picker
  final String? category; // e.g. "perfume", "electronics", "fashion"
}

/// A discover category tile.
@immutable
class ExploreDiscoverItem {
  const ExploreDiscoverItem({
    required this.type,
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.subtitleAr,
  });

  /// Type identifier: "companies" | "products" | "influencers" | "reports"
  final String type;
  final String titleEn;
  final String titleAr;
  final String subtitleEn;
  final String subtitleAr;
}

/// Status style for recent investigations.
enum ExploreStatusStyle { completed, quickAnswer, analyzing, paused }

/// A recent investigation row.
@immutable
class ExploreRecentItem {
  const ExploreRecentItem({
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.subtitleAr,
    required this.time,
    required this.statusLabelEn,
    required this.statusLabelAr,
    required this.statusStyle,
    this.imageHint,
    this.brandDomain,
  });

  final String titleEn;
  final String titleAr;
  final String subtitleEn;
  final String subtitleAr;
  final String time;
  final String statusLabelEn;
  final String statusLabelAr;
  final ExploreStatusStyle statusStyle;
  final String? imageHint; // short noun for asset picker
  final String? brandDomain; // for logo resolution
}

/// Top-level payload for the Explore screen.
@immutable
class ExploreDetailData {
  const ExploreDetailData({
    required this.trending,
    required this.discover,
    required this.recent,
  });

  final List<ExploreTrendingItem> trending;
  final List<ExploreDiscoverItem> discover;
  final List<ExploreRecentItem> recent;
}
