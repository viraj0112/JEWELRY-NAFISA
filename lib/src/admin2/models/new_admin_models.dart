class DashboardSnapshot {
  const DashboardSnapshot({
    required this.totalUsers,
    required this.totalQuotes,
    required this.pendingApprovals,
    required this.totalAssets,
  });

  final int totalUsers;
  final int totalQuotes;
  final int pendingApprovals;
  final int totalAssets;
}

class CurationFeedItem {
  const CurationFeedItem({
    required this.id,
    required this.title,
    required this.sourceTable,
    required this.priceLabel,
    required this.imageUrl,
    required this.quoteRequests,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String sourceTable;
  final String priceLabel;
  final String? imageUrl;
  final int quoteRequests;
  final DateTime? createdAt;
}

class AppraisalQueueItem {
  const AppraisalQueueItem({
    required this.id,
    required this.title,
    required this.sourceTable,
    required this.uploaderUserId,
    required this.uploaderName,
    required this.uploaderEmail,
    required this.imageUrl,
    required this.createdAt,
    required this.priceLabel,
  });

  final String id;
  final String title;
  final String sourceTable;
  final String uploaderUserId;
  final String uploaderName;
  final String uploaderEmail;
  final String? imageUrl;
  final DateTime? createdAt;
  final String priceLabel;
}

class DashboardViewData {
  const DashboardViewData({
    required this.snapshot,
    required this.curationFeed,
    required this.appraisalQueue,
    required this.marketPulse,
    required this.metalTypeInsights,
    required this.metalColorInsights,
  });

  final DashboardSnapshot snapshot;
  final List<CurationFeedItem> curationFeed;
  final List<AppraisalQueueItem> appraisalQueue;
  final MarketPulse marketPulse;
  final List<MetalInsight> metalTypeInsights;
  final List<MetalInsight> metalColorInsights;
}

class MetalInsight {
  const MetalInsight({
    required this.label,
    required this.count,
    required this.sourceTable,
  });

  final String label;
  final int count;
  final String sourceTable;
}

class MetalPricePoint {
  const MetalPricePoint({
    required this.symbol,
    required this.label,
    required this.priceUsd,
    required this.changePercent,
  });

  final String symbol;
  final String label;
  final double priceUsd;
  final double changePercent;
}

class MarketPulse {
  const MarketPulse({
    required this.gold,
    required this.silver,
    required this.updatedAt,
    required this.source,
  });

  final MetalPricePoint gold;
  final MetalPricePoint silver;
  final DateTime updatedAt;
  final String source;
}

class ModerationItem {
  const ModerationItem({
    required this.id,
    required this.title,
    required this.status,
    required this.category,
    required this.thumbUrl,
    required this.mediaUrl,
    required this.source,
    required this.tags,
    required this.ownerId,
    required this.ownerName,
    required this.ownerLocation,
    required this.ownerEmail,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String status;
  final String category;
  final String? thumbUrl;
  final String? mediaUrl;
  final String source;
  final List<String> tags;
  final String ownerId;
  final String ownerName;
  final String ownerLocation;
  final String ownerEmail;
  final DateTime? createdAt;
}

class VerificationRequest {
  const VerificationRequest({
    required this.userId,
    required this.name,
    required this.subtitle,
    required this.email,
    required this.role,
    required this.country,
    required this.hasGst,
    required this.hasAddress,
    required this.hasBusinessType,
    required this.createdAt,
  });

  final String userId;
  final String name;
  final String subtitle;
  final String email;
  final String role;
  final String country;
  final bool hasGst;
  final bool hasAddress;
  final bool hasBusinessType;
  final DateTime? createdAt;
}

class UserLedgerRow {
  const UserLedgerRow({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isMember,
    required this.creditsRemaining,
    required this.approvalStatus,
    required this.lastCreditRefresh,
    required this.createdAt,
    this.lastActivityAt,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final bool isMember;
  final int creditsRemaining;
  final String approvalStatus;
  final DateTime? lastCreditRefresh;
  final DateTime? createdAt;
  final DateTime? lastActivityAt;
}

class QuoteRecord {
  const QuoteRecord({
    required this.id,
    required this.userName,
    required this.userEmail,
    required this.productTitle,
    required this.productTable,
    required this.createdAt,
    this.status = 'pending',
    this.productId = '',
    this.userId = '',
    this.creatorName = '',
    this.metalType = '',
    this.metalPurity = '',
    this.goldWeight = '',
    this.metalColor = '',
    this.metalFinish = '',
    this.stoneType = const [],
    this.stoneColor = const [],
    this.stoneCount = const [],
    this.stonePurity = const [],
    this.stoneCut = const [],
    this.stoneUsed = const [],
    this.stoneWeight = const [],
    this.stoneSetting = const [],
    this.additionalNotes = '',
    this.productUrl = '',
    this.phoneNumber = '',
    this.metalWeight = '',
    this.netWeight = '',
    this.dimension = '',
    this.designType = '',
    this.artForm = '',
    this.plating = '',
    this.enamelWork = const [],
    this.customizable = const [],
    this.category = '',
    this.subCategory = '',
    this.plain = '',
    this.studded = const [],
  });

  final String id;
  final String userName;
  final String userEmail;
  final String productTitle;
  final String productTable;
  final DateTime? createdAt;
  // Enhanced fields for Quote Tracking screen
  final String status; // 'pending' | 'responded' | 'closed'
  final String productId;
  final String userId; // UUID of the user who requested the quote
  final String creatorName; // resolved from product uploader
  final String metalType;
  final String metalPurity;
  final String goldWeight;
  final String metalColor;
  final String metalFinish;
  final List<String> stoneType;
  final List<String> stoneColor;
  final List<String> stoneCount;
  final List<String> stonePurity;
  final List<String> stoneCut;
  final List<String> stoneUsed;
  final List<String> stoneWeight;
  final List<String> stoneSetting;
  final String additionalNotes;
  final String productUrl;
  final String phoneNumber;
  final String metalWeight;
  final String netWeight;
  final String dimension;
  final String designType;
  final String artForm;
  final String plating;
  final List<String> enamelWork;
  final List<String> customizable;
  final String category;
  final String subCategory;
  final String plain;
  final List<String> studded;
}

class DailyAnalyticsPoint {
  const DailyAnalyticsPoint({
    required this.date,
    required this.views,
    required this.likes,
    required this.saves,
    required this.quotesRequested,
  });

  final DateTime date;
  final int views;
  final int likes;
  final int saves;
  final int quotesRequested;
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.source,
    required this.thumbUrl,
    required this.mediaUrl,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.createdAt,
    this.likesCount = 0,
    this.viewsCount = 0,
    this.sharesCount = 0,
    this.creditsUsed = 0,
    this.productType,
  });

  final String id;
  final String title;
  final String category;
  final String status;
  final String source;
  final String? thumbUrl;
  final String? mediaUrl;
  final String ownerId;
  final String ownerName;
  final String ownerEmail;
  final DateTime? createdAt;
  final int likesCount;
  final int viewsCount;
  final int sharesCount;
  final int creditsUsed;
  final String? productType;
}

class SystemSetting {
  const SystemSetting({
    required this.key,
    required this.value,
    required this.description,
    required this.updatedAt,
  });

  final String key;
  final String value;
  final String description;
  final DateTime? updatedAt;
}

class JewelryPricingMasterData {
  const JewelryPricingMasterData({
    required this.rateGold,
    required this.rateSilver,
    required this.ratePlatinum,
    required this.makingGroups,
    required this.stoneGroups,
    required this.whatsappTarget,
  });

  final double rateGold;
  final double rateSilver;
  final double ratePlatinum;
  final Map<String, double> makingGroups;
  final Map<String, double> stoneGroups;
  final String whatsappTarget;

  factory JewelryPricingMasterData.empty() => const JewelryPricingMasterData(
        rateGold: 0,
        rateSilver: 0,
        ratePlatinum: 0,
        makingGroups: {},
        stoneGroups: {},
        whatsappTarget: '918879018801',
      );
}
