import 'package:ling/src/features/membership/models/membership_models.dart';

class MembershipState {
  const MembershipState({
    this.summary,
    this.catalog = const <MembershipCatalogProduct>[],
    this.isLoadingSummary = false,
    this.summaryLoadFailed = false,
    this.isLoadingCatalog = false,
    this.hasLoadedCatalog = false,
    this.catalogLoadFailed = false,
    this.isPurchasing = false,
    this.isRestoring = false,
  });

  final MembershipSummary? summary;
  final List<MembershipCatalogProduct> catalog;
  final bool isLoadingSummary;
  final bool summaryLoadFailed;
  final bool isLoadingCatalog;
  final bool hasLoadedCatalog;
  final bool catalogLoadFailed;
  final bool isPurchasing;
  final bool isRestoring;

  MembershipState copyWith({
    MembershipSummary? summary,
    bool clearSummary = false,
    List<MembershipCatalogProduct>? catalog,
    bool? isLoadingSummary,
    bool? summaryLoadFailed,
    bool? isLoadingCatalog,
    bool? hasLoadedCatalog,
    bool? catalogLoadFailed,
    bool? isPurchasing,
    bool? isRestoring,
  }) {
    return MembershipState(
      summary: clearSummary ? null : (summary ?? this.summary),
      catalog: catalog ?? this.catalog,
      isLoadingSummary: isLoadingSummary ?? this.isLoadingSummary,
      summaryLoadFailed: summaryLoadFailed ?? this.summaryLoadFailed,
      isLoadingCatalog: isLoadingCatalog ?? this.isLoadingCatalog,
      hasLoadedCatalog: hasLoadedCatalog ?? this.hasLoadedCatalog,
      catalogLoadFailed: catalogLoadFailed ?? this.catalogLoadFailed,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isRestoring: isRestoring ?? this.isRestoring,
    );
  }
}
