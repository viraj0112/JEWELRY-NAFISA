import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/new_admin_models.dart';

class NewAdminDataService {
  NewAdminDataService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static MarketPulse? _marketPulseCache;
  static DateTime? _marketPulseCacheDate;

  Future<DashboardViewData> fetchDashboardViewData() async {
    final snapshot = await fetchDashboardSnapshot();
    final curationFeed = await fetchCurationFeed();
    final appraisalQueue = await fetchAppraisalQueue();
    final marketPulse = await fetchMarketPulse();
    final metalTypeInsights = await _fetchMetalMetrics('Metal Type');
    final metalColorInsights = await _fetchMetalMetrics('Metal Color');
    return DashboardViewData(
      snapshot: snapshot,
      curationFeed: curationFeed,
      appraisalQueue: appraisalQueue,
      marketPulse: marketPulse,
      metalTypeInsights: metalTypeInsights,
      metalColorInsights: metalColorInsights,
    );
  }

  Future<DashboardSnapshot> fetchDashboardSnapshot() async {
    final users = await _client.from('users').select('id');
    final pending = await _client
        .from('assets')
        .select('id')
        .eq('status', 'pending');
    int totalQuotes = 0;
    try {
      totalQuotes = await _client.from('quote_requests').count();
    } catch (_) {
      totalQuotes = await _countAllRows('quote_requests');
    }
    final designerCount = await _countAllRows('designerproducts');
    final manufacturerCount = await _countAllRows('manufacturerproducts');
    final totalUploadedProducts = designerCount + manufacturerCount;
    return DashboardSnapshot(
      totalUsers: users.length,
      totalQuotes: totalQuotes,
      pendingApprovals: pending.length,
      totalAssets: totalUploadedProducts,
    );
  }

  Future<List<ModerationItem>> fetchModerationQueue({int limit = 20}) async {
    final rows = await _client
        .from('assets')
        .select(
            'id,title,status,category,thumb_url,media_url,source,tags,owner_id,created_at,owner:users!assets_owner_id_fkey(full_name,business_name,email,country)')
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .map<ModerationItem>(
          (row) => ModerationItem(
            id: '${row['id']}',
            title: (row['title'] as String?) ?? 'Untitled Asset',
            status: (row['status'] as String?) ?? 'pending',
            category: (row['category'] as String?) ?? 'Uncategorized',
            thumbUrl: row['thumb_url'] as String?,
            mediaUrl: row['media_url'] as String?,
            source: (row['source'] as String?) ?? 'uploaded',
            tags: _toStringList(row['tags']),
            ownerId: '${row['owner_id'] ?? ''}',
            ownerName: _ownerName(row['owner']),
            ownerLocation: _ownerLocation(row['owner']),
            ownerEmail: _ownerEmail(row['owner']),
            createdAt: _tryParseDate(row['created_at']),
          ),
        )
        .toList();
  }

  Future<List<ModerationItem>> fetchModerationArchive({int limit = 50}) async {
    final rows = await _client
        .from('assets')
        .select(
            'id,title,status,category,thumb_url,media_url,source,tags,owner_id,created_at,owner:users!assets_owner_id_fkey(full_name,business_name,email,country)')
        .neq('status', 'pending')
        .order('updated_at', ascending: false)
        .limit(limit);

    return rows
        .map<ModerationItem>(
          (row) => ModerationItem(
            id: '${row['id']}',
            title: (row['title'] as String?) ?? 'Untitled Asset',
            status: (row['status'] as String?) ?? 'pending',
            category: (row['category'] as String?) ?? 'Uncategorized',
            thumbUrl: row['thumb_url'] as String?,
            mediaUrl: row['media_url'] as String?,
            source: (row['source'] as String?) ?? 'uploaded',
            tags: _toStringList(row['tags']),
            ownerId: '${row['owner_id'] ?? ''}',
            ownerName: _ownerName(row['owner']),
            ownerLocation: _ownerLocation(row['owner']),
            ownerEmail: _ownerEmail(row['owner']),
            createdAt: _tryParseDate(row['created_at']),
          ),
        )
        .toList();
  }

  Future<List<VerificationRequest>> fetchVerificationRequests({
    int limit = 40,
  }) async {
    final rows = await _client
        .from('users')
        .select(
            'id,full_name,business_name,email,role,country,business_type,gst_number,address,created_at')
        .eq('approval_status', 'pending')
        .or('role.eq.designer,role.eq.manufacturer')
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .map<VerificationRequest>(
          (row) => VerificationRequest(
            userId: '${row['id']}',
            name: _nameFromUserRow(row),
            subtitle: _subtitleFromUserRow(row),
            email: (row['email'] as String?) ?? '',
            role: (row['role'] as String?) ?? 'member',
            country: (row['country'] as String?) ?? '',
            hasGst: ((row['gst_number'] as String?) ?? '').trim().isNotEmpty,
            hasAddress: ((row['address'] as String?) ?? '').trim().isNotEmpty,
            hasBusinessType:
                ((row['business_type'] as String?) ?? '').trim().isNotEmpty,
            createdAt: _tryParseDate(row['created_at']),
          ),
        )
        .toList();
  }

  Future<void> moderateAsset({
    required String assetId,
    required bool approve,
  }) async {
    await _client.from('assets').update({
      'status': approve ? 'approved' : 'rejected',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', assetId);
  }

  Future<void> updateVerificationStatus({
    required String userId,
    required bool approve,
  }) async {
    await _client.from('users').update({
      'approval_status': approve ? 'approved' : 'rejected',
      'is_approved': approve,
    }).eq('id', userId);
  }

  Future<List<UserLedgerRow>> fetchUserLedger({int limit = 100}) async {
    final rows = await _client
        .from('users')
        .select(
            'id,full_name,username,business_name,email,role,is_member,credits_remaining,approval_status,last_credit_refresh,created_at')
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .map<UserLedgerRow>(
          (row) => UserLedgerRow(
            id: '${row['id']}',
            name: _resolveDisplayName(row),
            email: (row['email'] as String?) ?? '',
            role: (row['role'] as String?) ?? 'member',
            isMember: row['is_member'] as bool? ?? false,
            creditsRemaining: _toInt(row['credits_remaining']),
            approvalStatus: (row['approval_status'] as String?) ?? 'pending',
            lastCreditRefresh: _tryParseDate(row['last_credit_refresh']),
            createdAt: _tryParseDate(row['created_at']),
          ),
        )
        .toList();
  }

  Future<List<QuoteRecord>> fetchQuoteTracking({int limit = 200}) async {
    final rows = await _client
        .from('quote_requests')
        .select('*')
        .order('created_at', ascending: false)
        .limit(limit);

    if (rows.isEmpty) return [];

    // Collect unique user_ids from rows to resolve creator names
    final uploaderIds = <String>{};
    for (final row in rows) {
      final uid = '${row['user_id'] ?? ''}';
      if (uid.isNotEmpty && uid != 'null') uploaderIds.add(uid);
    }

    Map<String, String> uploaderNames = {};
    if (uploaderIds.isNotEmpty) {
      try {
        final userRows = await _client
            .from('users')
            .select('id,full_name,business_name')
            .inFilter('id', uploaderIds.toList());
        for (final u in userRows) {
          final id = '${u['id']}';
          final name = (u['full_name'] as String?)?.trim().isNotEmpty == true
              ? u['full_name'] as String
              : (u['business_name'] as String?) ?? 'Unknown';
          uploaderNames[id] = name;
        }
      } catch (_) {}
    }

    return rows.map<QuoteRecord>((row) {
      final productId = '${row['product_id'] ?? ''}';
      final userId = '${row['user_id'] ?? ''}';
      // Use the actual status column from quote_requests
      final status = (row['status'] as String?) ?? 'pending';
      
      return QuoteRecord(
        id: '${row['id']}',
        userName: (row['user_name'] as String?) ?? uploaderNames[userId] ?? 'Unknown user',
        userEmail: (row['user_email'] as String?) ?? '',
        productTitle: (row['product_title'] as String?) ?? 'Untitled item',
        productTable: (row['product_table'] as String?) ?? '',
        createdAt: _tryParseDate(row['created_at']),
        status: status,
        productId: productId,
        userId: userId,
        creatorName: uploaderNames[userId] ?? '',
        metalType: (row['metal_type'] as String?) ?? '',
      );
    }).toList();
  }

  /// Bulk update quote requests status
  Future<void> updateQuoteRequestsStatus(List<String> ids, String status) async {
    if (ids.isEmpty) return;
    await _client
        .from('quote_requests')
        .update({'status': status})
        .inFilter('id', ids);
  }

  /// Send a notification to a specific user
  Future<void> sendUserNotification({
    required String userId,
    required String title,
    required String body,
    String? relatedItemId,
    String type = 'opportunity',
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'related_item_id': relatedItemId,
      'type': type,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<DailyAnalyticsPoint>> fetchAnalytics({int days = 30}) async {
    final fromDate = DateTime.now().subtract(Duration(days: days));
    final rows = await _client
        .from('analytics_daily')
        .select('date,views,likes,saves,quotes_requested')
        .gte('date', fromDate.toIso8601String().split('T').first)
        .order('date', ascending: true);

    final Map<DateTime, DailyAnalyticsPoint> rolledUp = {};
    for (final row in rows) {
      final date = _tryParseDate(row['date']);
      if (date == null) continue;
      final key = DateTime(date.year, date.month, date.day);
      final current = rolledUp[key];
      final views = row['views'] as int? ?? 0;
      final likes = row['likes'] as int? ?? 0;
      final saves = row['saves'] as int? ?? 0;
      final quotesRequested = row['quotes_requested'] as int? ?? 0;
      if (current == null) {
        rolledUp[key] = DailyAnalyticsPoint(
          date: key,
          views: views,
          likes: likes,
          saves: saves,
          quotesRequested: quotesRequested,
        );
      } else {
        rolledUp[key] = DailyAnalyticsPoint(
          date: key,
          views: current.views + views,
          likes: current.likes + likes,
          saves: current.saves + saves,
          quotesRequested: current.quotesRequested + quotesRequested,
        );
      }
    }

    final items = rolledUp.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return items;
  }

  Future<List<InventoryItem>> fetchInventory({int limit = 100}) async {
    final rows = await _client
        .from('assets')
        .select(
            'id,title,category,status,source,thumb_url,media_url,owner_id,created_at,owner:users!assets_owner_id_fkey(full_name,business_name,email)')
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .map<InventoryItem>(
          (row) => InventoryItem(
            id: '${row['id']}',
            title: (row['title'] as String?) ?? 'Untitled',
            category: (row['category'] as String?) ?? 'Uncategorized',
            status: (row['status'] as String?) ?? 'pending',
            source: (row['source'] as String?) ?? 'uploaded',
            thumbUrl: row['thumb_url'] as String?,
            mediaUrl: row['media_url'] as String?,
            ownerId: '${row['owner_id'] ?? ''}',
            ownerName: _ownerName(row['owner']),
            ownerEmail: _ownerEmail(row['owner']),
            createdAt: _tryParseDate(row['created_at']),
          ),
        )
        .toList();
  }

  Future<List<InventoryItem>> fetchContentActivityLog({
    String table = 'all',
    String searchTerm = '',
    int limit = 100,
  }) async {
    final normalizedTerm = searchTerm.trim();
    final includesProducts = table == 'all' || table == 'products';
    final includesDesigner = table == 'all' || table == 'designerproducts';
    final includesManufacturer = table == 'all' || table == 'manufacturerproducts';
    final perTableLimit = table == 'all' ? (limit ~/ 3).clamp(1, limit) : limit;

    final productRows = <dynamic>[];
    final designerRows = <dynamic>[];
    final manufacturerRows = <dynamic>[];

    if (includesProducts) {
      var query = _client.from('products').select('id,"Product Title","Category","Image","Images",user_id');
      if (normalizedTerm.isNotEmpty) {
        query = query.ilike('Product Title', '%$normalizedTerm%');
      }
      productRows.addAll(await query
          .order('id', ascending: false)
          .limit(perTableLimit));
    }

    if (includesDesigner) {
      var query = _client.from('designerproducts').select('id,"Product Title","Category","Image",created_at,user_id');
      if (normalizedTerm.isNotEmpty) {
        query = query.ilike('Product Title', '%$normalizedTerm%');
      }
      designerRows.addAll(await query
          .order('created_at', ascending: false)
          .limit(perTableLimit));
    }

    if (includesManufacturer) {
      var query = _client.from('manufacturerproducts').select('id,"Product Title","Category","Image",created_at,user_id');
      if (normalizedTerm.isNotEmpty) {
        query = query.ilike('Product Title', '%$normalizedTerm%');
      }
      manufacturerRows.addAll(await query
          .order('created_at', ascending: false)
          .limit(perTableLimit));
    }

    final uploaderMap = await _fetchUploaderMap([
      ...productRows.map((row) => '${row['user_id'] ?? ''}'),
      ...designerRows.map((row) => '${row['user_id'] ?? ''}'),
      ...manufacturerRows.map((row) => '${row['user_id'] ?? ''}'),
    ]);

    final items = <InventoryItem>[
      ...productRows.map(
        (row) {
          final userId = '${row['user_id'] ?? ''}';
          final owner = uploaderMap[userId];
          return InventoryItem(
            id: 'products:${row['id']}',
            title: (row['Product Title'] as String?) ?? 'Untitled Product',
            category: (row['Category'] as String?) ?? 'Uncategorized',
            status: 'uploaded',
            source: 'products',
            thumbUrl: _extractImage(row['Image'], fallback: row['Images'] as String?),
            mediaUrl: _extractImage(row['Image'], fallback: row['Images'] as String?),
            ownerId: userId,
            ownerName: owner?['name'] ?? 'Unknown creator',
            ownerEmail: owner?['email'] ?? '',
            createdAt: null,
          );
        },
      ),
      ...designerRows.map(
        (row) {
          final userId = '${row['user_id'] ?? ''}';
          final owner = uploaderMap[userId];
          return InventoryItem(
            id: 'designerproducts:${row['id']}',
            title: (row['Product Title'] as String?) ?? 'Untitled Product',
            category: (row['Category'] as String?) ?? 'Uncategorized',
            status: 'uploaded',
            source: 'designerproducts',
            thumbUrl: _extractImage(row['Image']),
            mediaUrl: _extractImage(row['Image']),
            ownerId: userId,
            ownerName: owner?['name'] ?? 'Unknown creator',
            ownerEmail: owner?['email'] ?? '',
            createdAt: _tryParseDate(row['created_at']),
          );
        },
      ),
      ...manufacturerRows.map(
        (row) {
          final userId = '${row['user_id'] ?? ''}';
          final owner = uploaderMap[userId];
          return InventoryItem(
            id: 'manufacturerproducts:${row['id']}',
            title: (row['Product Title'] as String?) ?? 'Untitled Product',
            category: (row['Category'] as String?) ?? 'Uncategorized',
            status: 'uploaded',
            source: 'manufacturerproducts',
            thumbUrl: _extractImage(row['Image']),
            mediaUrl: _extractImage(row['Image']),
            ownerId: userId,
            ownerName: owner?['name'] ?? 'Unknown creator',
            ownerEmail: owner?['email'] ?? '',
            createdAt: _tryParseDate(row['created_at']),
          );
        },
      ),
    ];

    items.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateCompare = bDate.compareTo(aDate);
      if (dateCompare != 0) return dateCompare;
      return a.source.compareTo(b.source);
    });

    return items.take(limit).toList();
  }

  Future<void> setUserCredits({
  required String userId,
  required int credits,
}) async {
  final now = DateTime.now().toUtc().toIso8601String();
  
  await _client
      .from('users')
      .update({
        'credits_remaining': credits,
        'last_credit_refresh': now,
      })
      .eq('id', userId);
}

Future<void> refreshAllUserCredits({
  required int memberCredits,
  required int nonMemberCredits,
}) async {
  final now = DateTime.now().toUtc().toIso8601String();
  
  // Refresh member credits
  await _client
      .from('users')
      .update({
        'credits_remaining': memberCredits,
        'last_credit_refresh': now,
      })
      .eq('is_member', true);
  
  // Refresh non-member credits
  await _client
      .from('users')
      .update({
        'credits_remaining': nonMemberCredits,
        'last_credit_refresh': now,
      })
      .eq('is_member', false);
}

  Future<void> createInventoryAsset({
    required String title,
    required String category,
    required String description,
    required String mediaUrl,
    String? thumbUrl,
    String status = 'pending',
    String source = 'manual_admin',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('No authenticated admin user found');
    }
    await _client.from('assets').insert({
      'owner_id': userId,
      'title': title,
      'description': description,
      'media_url': mediaUrl,
      'thumb_url': (thumbUrl ?? '').trim().isEmpty ? null : thumbUrl,
      'category': category,
      'status': status,
      'source': source,
    });
  }

  Future<int> bulkCreateInventoryAssets(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return 0;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('No authenticated admin user found');
    }
    final payload = items
        .map(
          (row) => {
            'owner_id': userId,
            'title': row['title'],
            'description': row['description'],
            'media_url': row['media_url'],
            'thumb_url': row['thumb_url'],
            'category': row['category'],
            'status': row['status'] ?? 'pending',
            'source': row['source'] ?? 'bulk_admin',
          },
        )
        .toList();

    await _client.from('assets').insert(payload);
    return payload.length;
  }

  Future<List<SystemSetting>> fetchSystemSettings({int limit = 50}) async {
    final rows = await _client
        .from('settings')
        .select('key,value,description,updated_at')
        .order('updated_at', ascending: false)
        .limit(limit);

    return rows
        .map<SystemSetting>(
          (row) => SystemSetting(
            key: (row['key'] as String?) ?? '',
            value: (row['value'] as String?) ?? '',
            description: (row['description'] as String?) ?? '',
            updatedAt: _tryParseDate(row['updated_at']),
          ),
        )
        .toList();
  }

  Future<void> upsertSystemSettings(Map<String, String> values) async {
    final now = DateTime.now().toUtc().toIso8601String();
    if (values.isEmpty) return;

    // Use upsert to create missing keys or update existing ones
    for (final entry in values.entries) {
      final updated = await _client
          .from('settings')
          .upsert({
            'key': entry.key,
            'value': entry.value,
            'updated_at': now
          })
          .select('key')
          .maybeSingle();

      if (updated == null) {
        throw Exception(
          'Failed to upsert setting key "${entry.key}" due to policy or database error.',
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecentAdminLedger({
    int limit = 12,
  }) async {
    final logs = <Map<String, dynamic>>[];

    final recentSettings = await _client
        .from('settings')
        .select('key,value,updated_at')
        .order('updated_at', ascending: false)
        .limit(limit);

    logs.addAll(
      recentSettings.map(
        (row) => {
          'title': 'Setting "${row['key']}" updated to "${row['value']}".',
          'timestamp': row['updated_at'],
          'status': 'SYSTEM MOD',
        },
      ),
    );

    final recentNotifications = await _client
        .from('notifications')
        .select('title,created_at,type')
        .order('created_at', ascending: false)
        .limit(limit);

    logs.addAll(
      recentNotifications.map(
        (row) => {
          'title': row['title'] ?? 'Notification sent',
          'timestamp': row['created_at'],
          'status': ((row['type'] as String?) ?? 'default').toUpperCase(),
        },
      ),
    );

    logs.sort((a, b) {
      final ad = _tryParseDate(a['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = _tryParseDate(b['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    return logs.take(limit).toList();
  }

  Future<int> broadcastNotification({
    required String audience,
    required String subject,
    required String body,
    String urgency = 'standard',
    DateTime? scheduledFor,
  }) async {
    dynamic usersQuery = _client.from('users').select('id');

    switch (audience) {
      case 'manufacturers':
        usersQuery = usersQuery.eq('role', 'manufacturer');
        break;
      case 'verified_gemologists':
        usersQuery = usersQuery
            .eq('role', 'designer')
            .or('approval_status.eq.approved,is_approved.eq.true');
        break;
      case 'new_onboardings':
        final since = DateTime.now()
            .subtract(const Duration(days: 30))
            .toUtc()
            .toIso8601String();
        usersQuery = usersQuery.gte('created_at', since);
        break;
      case 'all_users':
      default:
        break;
    }

    final users = await usersQuery;
    if (users.isEmpty) return 0;

    final rows = users
        .map(
          (u) => {
            'user_id': u['id'],
            'type': urgency == 'high' ? 'opportunity' : 'default',
            'title': subject,
            'body': body,
            if (scheduledFor != null)
              'created_at': scheduledFor.toUtc().toIso8601String(),
          },
        )
        .toList();

    await _client.from('notifications').insert(rows);
    return rows.length;
  }

  Future<List<CurationFeedItem>> fetchCurationFeed({int? limit}) async {
    final quoteRows = await _client
        .from('quote_requests')
        .select('product_id,product_table')
        .limit(500);

    final Map<String, int> quoteCountByProductKey = {};
    for (final row in quoteRows) {
      final table = (row['product_table'] as String?) ?? '';
      final productId = '${row['product_id'] ?? ''}';
      final key = '$table::$productId';
      quoteCountByProductKey[key] = (quoteCountByProductKey[key] ?? 0) + 1;
    }

    final productRows = await _fetchAllRows(
      table: 'products',
      columns: 'id,"Product Title","Image","Images","Price"',
    );
    final designerRows = await _fetchAllRows(
      table: 'designerproducts',
      columns: 'id,"Product Title","Image","Price","created_at"',
      orderColumn: 'created_at',
      ascending: false,
    );
    final manufacturerRows = await _fetchAllRows(
      table: 'manufacturerproducts',
      columns: 'id,"Product Title","Image","Price","created_at"',
      orderColumn: 'created_at',
      ascending: false,
    );

    final items = <CurationFeedItem>[];

    for (final row in productRows) {
      final id = '${row['id']}';
      items.add(
        CurationFeedItem(
          id: id,
          title: (row['Product Title'] as String?) ?? 'Untitled Product',
          sourceTable: 'products',
          priceLabel: ((row['Price'] as String?) ?? '').trim(),
          imageUrl: _extractImage(
            row['Image'],
            fallback: row['Images'] as String?,
          ),
          quoteRequests: quoteCountByProductKey['products::$id'] ?? 0,
          createdAt: null,
        ),
      );
    }

    for (final row in designerRows) {
      final id = '${row['id']}';
      items.add(
        CurationFeedItem(
          id: id,
          title: (row['Product Title'] as String?) ?? 'Untitled Product',
          sourceTable: 'designerproducts',
          priceLabel: ((row['Price'] as String?) ?? '').trim(),
          imageUrl: _extractImage(row['Image']),
          quoteRequests: quoteCountByProductKey['designerproducts::$id'] ?? 0,
          createdAt: _tryParseDate(row['created_at']),
        ),
      );
    }

    for (final row in manufacturerRows) {
      final id = '${row['id']}';
      items.add(
        CurationFeedItem(
          id: id,
          title: (row['Product Title'] as String?) ?? 'Untitled Product',
          sourceTable: 'manufacturerproducts',
          priceLabel: ((row['Price'] as String?) ?? '').trim(),
          imageUrl: _extractImage(row['Image']),
          quoteRequests: 0,
          createdAt: _tryParseDate(row['created_at']),
        ),
      );
    }

    items.sort((a, b) {
      final scoreCompare = b.quoteRequests.compareTo(a.quoteRequests);
      if (scoreCompare != 0) return scoreCompare;
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    if (limit != null) {
      return items.take(limit).toList();
    }
    return items;
  }

  Future<List<AppraisalQueueItem>> fetchAppraisalQueue({int? limit}) async {
    final designerRows = await _fetchAllRows(
      table: 'designerproducts',
      columns: 'id,"Product Title","Price","Image",created_at,user_id',
      orderColumn: 'created_at',
      ascending: false,
    );
    final manufacturerRows = await _fetchAllRows(
      table: 'manufacturerproducts',
      columns: 'id,"Product Title","Price","Image",created_at,user_id',
      orderColumn: 'created_at',
      ascending: false,
    );

    final uploaderIds = <String>{
      ...designerRows.map((row) => '${row['user_id'] ?? ''}'),
      ...manufacturerRows.map((row) => '${row['user_id'] ?? ''}'),
    }..removeWhere((id) => id.isEmpty || id == 'null');

    final uploaderMap = <String, Map<String, String>>{};
    if (uploaderIds.isNotEmpty) {
      final uploaderRows = await _client
          .from('users')
          .select('id,full_name,email')
          .inFilter('id', uploaderIds.toList());
      for (final user in uploaderRows) {
        final id = '${user['id']}';
        uploaderMap[id] = {
          'name': (user['full_name'] as String?)?.trim().isNotEmpty == true
              ? user['full_name'] as String
              : 'Unknown uploader',
          'email': (user['email'] as String?) ?? '',
        };
      }
    }

    final items = <AppraisalQueueItem>[
      ...designerRows.map(
        (row) {
          final userId = '${row['user_id'] ?? ''}';
          final user = uploaderMap[userId];
          return AppraisalQueueItem(
            id: '${row['id']}',
            title: (row['Product Title'] as String?) ?? 'Untitled upload',
            sourceTable: 'designerproducts',
            uploaderUserId: userId,
            uploaderName: user?['name'] ?? 'Unknown uploader',
            uploaderEmail: user?['email'] ?? '',
            imageUrl: _extractImage(row['Image']),
            createdAt: _tryParseDate(row['created_at']),
            priceLabel: ((row['Price'] as String?) ?? '').trim(),
          );
        },
      ),
      ...manufacturerRows.map(
        (row) {
          final userId = '${row['user_id'] ?? ''}';
          final user = uploaderMap[userId];
          return AppraisalQueueItem(
            id: '${row['id']}',
            title: (row['Product Title'] as String?) ?? 'Untitled upload',
            sourceTable: 'manufacturerproducts',
            uploaderUserId: userId,
            uploaderName: user?['name'] ?? 'Unknown uploader',
            uploaderEmail: user?['email'] ?? '',
            imageUrl: _extractImage(row['Image']),
            createdAt: _tryParseDate(row['created_at']),
            priceLabel: ((row['Price'] as String?) ?? '').trim(),
          );
        },
      ),
    ];

    items.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    if (limit != null) {
      return items.take(limit).toList();
    }
    return items;
  }

  Future<MarketPulse> fetchMarketPulse() async {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final cacheKey = _marketPulseCacheDate == null
        ? null
        : DateTime(
            _marketPulseCacheDate!.year,
            _marketPulseCacheDate!.month,
            _marketPulseCacheDate!.day,
          );
    if (_marketPulseCache != null && cacheKey == todayKey) {
      return _marketPulseCache!;
    }

    try {
      final uri = Uri.parse(
        'https://api.metalpriceapi.com/v1/latest'
        '?api_key=23612dc21c649ce8dfcfc53d9727ab0a'
        '&base=INR'
        '&currencies=XAG,XAU',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch market prices');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final rates = payload['rates'] as Map<String, dynamic>? ?? const {};

      final xauRate = (rates['XAU'] as num?)?.toDouble() ?? 0;
      final xagRate = (rates['XAG'] as num?)?.toDouble() ?? 0;

      final double goldPriceInInr = xauRate > 0 ? (1 / xauRate).toDouble() : 0.0;
      final double silverPriceInInr =
          xagRate > 0 ? (1 / xagRate).toDouble() : 0.0;

      final pulse = MarketPulse(
        gold: MetalPricePoint(
          symbol: 'XAU',
          label: 'Gold',
          priceUsd: goldPriceInInr,
          changePercent: 0,
        ),
        silver: MetalPricePoint(
          symbol: 'XAG',
          label: 'Silver',
          priceUsd: silverPriceInInr,
          changePercent: 0,
        ),
        updatedAt: DateTime.now(),
        source: 'MetalPriceAPI (INR base)',
      );
      _marketPulseCache = pulse;
      _marketPulseCacheDate = today;
      return pulse;
    } catch (_) {
      final pulse = MarketPulse(
        gold: const MetalPricePoint(
          symbol: 'XAU',
          label: 'Gold',
          priceUsd: 0,
          changePercent: 0,
        ),
        silver: const MetalPricePoint(
          symbol: 'XAG',
          label: 'Silver',
          priceUsd: 0,
          changePercent: 0,
        ),
        updatedAt: DateTime.now(),
        source: 'Unavailable',
      );
      _marketPulseCache = pulse;
      _marketPulseCacheDate = today;
      return pulse;
    }
  }

  Future<int> _countAllRows(String table, {int pageSize = 1000}) async {
    var offset = 0;
    var total = 0;
    while (true) {
      final rows = await _client
          .from(table)
          .select('id')
          .range(offset, offset + pageSize - 1);
      total += rows.length;
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return total;
  }

  Future<List<dynamic>> _fetchAllRows({
    required String table,
    required String columns,
    String? orderColumn,
    bool ascending = false,
    int pageSize = 1000,
  }) async {
    final allRows = <dynamic>[];
    var offset = 0;
    while (true) {
      final query = _client.from(table).select(columns);
      final ordered = orderColumn == null
          ? query
          : query.order(orderColumn, ascending: ascending);
      final rows = await ordered.range(offset, offset + pageSize - 1);
      allRows.addAll(rows);
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return allRows;
  }

  String? _extractImage(dynamic value, {String? fallback}) {
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first != null && '$first'.isNotEmpty) return '$first';
    }
    if (value is String && value.isNotEmpty) {
      final trimmed = value.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final inner = trimmed.substring(1, trimmed.length - 1);
        final first = inner.split(',').map((e) => e.trim()).firstWhere(
              (e) => e.isNotEmpty,
              orElse: () => '',
            );
        if (first.isNotEmpty) return first.replaceAll('"', '');
      }
      return trimmed;
    }
    if (fallback != null && fallback.isNotEmpty) {
      return _extractImage(fallback);
    }
    return null;
  }

  DateTime? _tryParseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  String _ownerName(dynamic owner) {
    if (owner is Map<String, dynamic>) {
      final fullName = (owner['full_name'] as String?)?.trim() ?? '';
      if (fullName.isNotEmpty) return fullName;
      final business = (owner['business_name'] as String?)?.trim() ?? '';
      if (business.isNotEmpty) return business;
      final email = (owner['email'] as String?)?.trim() ?? '';
      if (email.isNotEmpty) return email.split('@').first;
    }
    return 'Unknown creator';
  }

  String _ownerLocation(dynamic owner) {
    if (owner is Map<String, dynamic>) {
      return (owner['country'] as String?)?.trim() ?? '';
    }
    return '';
  }

  String _ownerEmail(dynamic owner) {
    if (owner is Map<String, dynamic>) {
      return (owner['email'] as String?)?.trim() ?? '';
    }
    return '';
  }

  Future<Map<String, Map<String, String>>> _fetchUploaderMap(
    Iterable<String> rawIds,
  ) async {
    final uploaderIds = rawIds.toSet()
      ..removeWhere((id) => id.isEmpty || id == 'null');
    if (uploaderIds.isEmpty) return {};

    final rows = await _client
        .from('users')
        .select('id,full_name,business_name,email')
        .inFilter('id', uploaderIds.toList());

    final uploaderMap = <String, Map<String, String>>{};
    for (final row in rows) {
      final id = '${row['id']}';
      uploaderMap[id] = {
        'name': _ownerName(row),
        'email': _ownerEmail(row),
      };
    }
    return uploaderMap;
  }

  String _nameFromUserRow(Map<String, dynamic> row) {
    final fullName = (row['full_name'] as String?)?.trim() ?? '';
    if (fullName.isNotEmpty) return fullName;
    final business = (row['business_name'] as String?)?.trim() ?? '';
    if (business.isNotEmpty) return business;
    final email = (row['email'] as String?)?.trim() ?? '';
    if (email.contains('@')) return email.split('@').first;
    return email.isNotEmpty ? email : 'Unknown applicant';
  }

  String _subtitleFromUserRow(Map<String, dynamic> row) {
    final business = (row['business_name'] as String?)?.trim() ?? '';
    final businessType = (row['business_type'] as String?)?.trim() ?? '';
    final country = (row['country'] as String?)?.trim() ?? '';
    final parts = <String>[
      if (business.isNotEmpty) business,
      if (businessType.isNotEmpty) businessType,
      if (country.isNotEmpty) country,
    ];
    return parts.join(' • ');
  }

  String _resolveDisplayName(Map<String, dynamic> row) {
    final fullName = (row['full_name'] as String?)?.trim() ?? '';
    if (fullName.isNotEmpty) return fullName;

    final username = (row['username'] as String?)?.trim() ?? '';
    if (username.isNotEmpty) return username;

    final businessName = (row['business_name'] as String?)?.trim() ?? '';
    if (businessName.isNotEmpty) return businessName;

    final email = (row['email'] as String?)?.trim() ?? '';
    if (email.contains('@')) {
      final handle = email.split('@').first.trim();
      if (handle.isNotEmpty) return _prettifyHandle(handle);
    }
    if (email.isNotEmpty) return email;

    return 'Unnamed account';
  }

  String _prettifyHandle(String handle) {
    final cleaned = handle.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (cleaned.isEmpty) return handle;
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
  Future<List<MetalInsight>> _fetchMetalMetrics(String column) async {
    final List<MetalInsight> insights = [];

    Future<void> fetchTableWithPagination(String tableName) async {
      int offset = 0;
      const int limit = 1000;
      bool hasMore = true;
      final Map<String, int> counts = {};

      while (hasMore) {
        final rows = await _client
            .from(tableName)
            .select('"$column"')
            .range(offset, offset + limit - 1);

        if (rows.isEmpty) {
          hasMore = false;
        } else {
          for (final row in rows) {
            final val = (row[column] as String?)?.trim();
            if (val != null && val.isNotEmpty && val != 'null') {
              counts[val] = (counts[val] ?? 0) + 1;
            }
          }
          if (rows.length < limit) {
            hasMore = false;
          } else {
            offset += limit;
          }
        }
      }

      counts.forEach((label, count) {
        insights.add(MetalInsight(
          label: label,
          count: count,
          sourceTable: tableName,
        ));
      });
    }

    try {
      await Future.wait([
        fetchTableWithPagination('products'),
        fetchTableWithPagination('designerproducts'),
        fetchTableWithPagination('manufacturerproducts'),
      ]);
    } catch (e) {
      print('Error fetching metal metrics for $column: $e');
    }

    return insights;
  }
}
