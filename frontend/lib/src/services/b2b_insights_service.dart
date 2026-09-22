import 'package:supabase_flutter/supabase_flutter.dart';

/// Event counts for one period.
class InsightCounts {
  const InsightCounts({
    this.views = 0,
    this.uniqueViewers = 0,
    this.likes = 0,
    this.shares = 0,
    this.saves = 0,
    this.quoteRequests = 0,
  });

  final int views;
  final int uniqueViewers;
  final int likes;
  final int shares;
  final int saves;
  final int quoteRequests;

  /// Likes + saves + shares: the "engaged" reactions beyond a view.
  int get engagements => likes + saves + shares;

  factory InsightCounts.fromJson(Map<String, dynamic>? j) => InsightCounts(
        views: _int(j?['views']),
        uniqueViewers: _int(j?['unique_viewers']),
        likes: _int(j?['likes']),
        shares: _int(j?['shares']),
        saves: _int(j?['saves']),
        quoteRequests: _int(j?['quote_requests']),
      );
}

class InsightLocation {
  const InsightLocation(this.name, this.count);
  final String name;
  final int count;
}

class InsightProduct {
  const InsightProduct({
    required this.id,
    required this.title,
    this.image,
    this.views = 0,
    this.likes = 0,
    this.saves = 0,
    this.shares = 0,
    this.quoteRequests = 0,
  });

  final String id;
  final String title;
  final String? image;
  final int views;
  final int likes;
  final int saves;
  final int shares;
  final int quoteRequests;
}

class InsightActivity {
  const InsightActivity({
    required this.kind,
    required this.title,
    required this.at,
    this.location,
  });

  /// view | like | share | save | quote
  final String kind;
  final String title;
  final DateTime at;
  final String? location;
}

class InsightDay {
  const InsightDay(this.day, this.views);
  final DateTime day;
  final int views;
}

/// The seller's performance report from the `b2b_insights` database function.
class InsightsReport {
  const InsightsReport({
    required this.productCount,
    required this.totals,
    required this.current,
    required this.previous,
    required this.windowFrom,
    required this.windowTo,
    required this.dailyViews,
    required this.topLocations,
    required this.topProducts,
    required this.recentActivity,
  });

  final int productCount;

  /// The selected range (all time when none).
  final InsightCounts totals;

  /// The comparison window (the range, or the last 30 days) and the equally
  /// long window before it.
  final InsightCounts current;
  final InsightCounts previous;
  final DateTime windowFrom;
  final DateTime windowTo;
  final List<InsightDay> dailyViews;
  final List<InsightLocation> topLocations;
  final List<InsightProduct> topProducts;
  final List<InsightActivity> recentActivity;

  /// Length of the comparison window in whole days (at least 1).
  int get windowDays {
    final days = (windowTo.difference(windowFrom).inHours / 24).round();
    return days < 1 ? 1 : days;
  }

  /// Percent change of [current] vs [previous]; null when there's no base.
  static double? change(int current, int previous) {
    if (previous == 0) return null;
    return (current - previous) / previous * 100;
  }

  factory InsightsReport.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String key) =>
        ((j[key] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    final window = Map<String, dynamic>.from((j['window'] as Map?) ?? {});
    return InsightsReport(
      productCount: _int(j['product_count']),
      totals: InsightCounts.fromJson(_map(j['totals'])),
      current: InsightCounts.fromJson(_map(j['current'])),
      previous: InsightCounts.fromJson(_map(j['previous'])),
      windowFrom: DateTime.tryParse('${window['from']}')?.toLocal() ?? DateTime.now(),
      windowTo: DateTime.tryParse('${window['to']}')?.toLocal() ?? DateTime.now(),
      dailyViews: list('daily_views')
          .map((d) => InsightDay(
              DateTime.tryParse('${d['day']}') ?? DateTime.now(), _int(d['views'])))
          .toList(),
      topLocations: list('top_locations')
          .map((l) => InsightLocation(_titleCase('${l['location']}'), _int(l['count'])))
          .toList(),
      topProducts: list('top_products')
          .map((p) => InsightProduct(
                id: '${p['id']}',
                title: (p['title'] as String?) ?? 'Untitled product',
                image: p['image'] as String?,
                views: _int(p['views']),
                likes: _int(p['likes']),
                saves: _int(p['saves']),
                shares: _int(p['shares']),
                quoteRequests: _int(p['quote_requests']),
              ))
          .toList(),
      recentActivity: list('recent_activity')
          .map((a) => InsightActivity(
                kind: '${a['kind']}',
                title: (a['title'] as String?) ?? 'A product',
                at: DateTime.tryParse('${a['at']}')?.toLocal() ?? DateTime.now(),
                location: a['location'] == null ? null : _titleCase('${a['location']}'),
              ))
          .toList(),
    );
  }

  /// Plain-language observations drawn only from the numbers above.
  List<String> keyInsights({bool singleProduct = false}) {
    final out = <String>[];
    final subject = singleProduct ? 'This design' : 'Your catalogue';
    final t = totals;

    if (t.views == 0 && t.engagements == 0 && t.quoteRequests == 0) {
      out.add(singleProduct
          ? 'No activity on this design yet. Complete its details and photos '
              'so it surfaces in search and filters.'
          : 'No activity in this period yet. Products with complete details '
              'and clear photos are found more often.');
      return out;
    }

    // Trend vs the previous window.
    final days = windowDays;
    final c = current.views, p = previous.views;
    if (c > 0 && p == 0) {
      out.add('$subject got $c view${c == 1 ? '' : 's'} in the last $days days, '
          'up from none in the $days days before.');
    } else if (c == 0 && p > 0) {
      out.add('No views in the last $days days (vs $p in the $days days before). '
          'Refreshing photos or details can revive interest.');
    } else if (p > 0) {
      final pct = change(c, p)!;
      out.add(pct.abs() < 5
          ? 'Views are steady: $c in the last $days days vs $p before.'
          : 'Views ${pct > 0 ? 'rose' : 'fell'} ${pct.abs().round()}% '
              'in the last $days days ($c vs $p).');
    }

    // Where the interest comes from.
    final located = topLocations.fold<int>(0, (s, l) => s + l.count);
    if (topLocations.isNotEmpty && located > 0) {
      final top = topLocations.first;
      final share = (top.count / located * 100).round();
      out.add('Most interest comes from ${top.name} '
          '($share% of located activity).');
    }

    // Buying intent.
    if (t.quoteRequests > 0) {
      out.add('${t.quoteRequests} quote request${t.quoteRequests == 1 ? '' : 's'}'
          ' - buyers asking for a price is the strongest sign of demand.');
    } else if (t.views >= 10) {
      out.add('${t.views} views but no quote requests yet. Clear pricing and '
          'full specifications help turn interest into enquiries.');
    }

    // Engagement quality.
    if (t.views > 0) {
      final rate = t.engagements / t.views * 100;
      if (t.engagements > 0) {
        out.add('${rate.toStringAsFixed(rate < 10 ? 1 : 0)}% of views led to a '
            'like, save or share.');
      }
    }

    // Reach.
    if (t.uniqueViewers > 0 && t.views > t.uniqueViewers) {
      out.add('${t.uniqueViewers} signed-in visitor${t.uniqueViewers == 1 ? '' : 's'} '
          'viewed ${singleProduct ? 'it' : 'your designs'} ${t.views} times - '
          'people are coming back for a second look.');
    }

    // Best performer (catalogue view only).
    if (!singleProduct && topProducts.isNotEmpty && topProducts.first.views > 0) {
      out.add('"${topProducts.first.title}" is your best performer with '
          '${topProducts.first.views} view${topProducts.first.views == 1 ? '' : 's'}.');
    }
    return out;
  }
}

class B2BInsightsService {
  B2BInsightsService([SupabaseClient? client])
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Report for the signed-in seller's products in [table], or just
  /// [productId]. [from]/[to] limit the totals (end exclusive).
  Future<InsightsReport> fetch({
    required String table,
    DateTime? from,
    DateTime? to,
    int? productId,
  }) async {
    final data = await _supabase.rpc('b2b_insights', params: {
      'p_table': table,
      if (from != null) 'p_from': from.toUtc().toIso8601String(),
      if (to != null) 'p_to': to.toUtc().toIso8601String(),
      if (productId != null) 'p_item_id': productId,
    });
    return InsightsReport.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

Map<String, dynamic>? _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

/// "mumbai, maharashtra" -> "Mumbai, Maharashtra"
String _titleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');
