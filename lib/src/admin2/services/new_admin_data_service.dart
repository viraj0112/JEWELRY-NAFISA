import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_service.dart';
import '../models/new_admin_models.dart';

class NewAdminDataService {
  NewAdminDataService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static MarketPulse? _marketPulseCache;
  static DateTime? _marketPulseCacheDate;

  Future<DashboardViewData> fetchDashboardViewData() async {
    DashboardSnapshot? snapshot;
    List<CurationFeedItem>? curationFeed;
    List<AppraisalQueueItem>? appraisalQueue;
    MarketPulse? marketPulse;
    List<MetalInsight>? metalTypeInsights;
    List<MetalInsight>? metalColorInsights;

    try {
      snapshot = await fetchDashboardSnapshot();
    } catch (e) {
      throw Exception('fetchDashboardSnapshot failed: $e');
    }
    
    try {
      curationFeed = await fetchCurationFeed();
    } catch (e) {
      throw Exception('fetchCurationFeed failed: $e');
    }
    
    try {
      appraisalQueue = await fetchAppraisalQueue();
    } catch (e) {
      throw Exception('fetchAppraisalQueue failed: $e');
    }
    
    try {
      marketPulse = await fetchMarketPulse();
    } catch (e) {
      throw Exception('fetchMarketPulse failed: $e');
    }
    
    try {
      metalTypeInsights = await _fetchMetalMetrics('Metal Type');
    } catch (e) {
      throw Exception('fetchMetalMetrics(Metal Type) failed: $e');
    }
    
    try {
      metalColorInsights = await _fetchMetalMetrics('Metal Color');
    } catch (e) {
      throw Exception('fetchMetalMetrics(Metal Color) failed: $e');
    }

    return DashboardViewData(
      snapshot: snapshot!,
      curationFeed: curationFeed!,
      appraisalQueue: appraisalQueue!,
      marketPulse: marketPulse!,
      metalTypeInsights: metalTypeInsights!,
      metalColorInsights: metalColorInsights!,
    );
  }

  Future<DashboardSnapshot> fetchDashboardSnapshot() async {
    final users = await _client.from('users').select('id');
    final pending =
        await _client.from('assets').select('id').eq('status', 'pending');
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
            'id,title,status,category,thumb_url,media_url,description,attributes,source,tags,owner_id,created_at')
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(limit);

    final ownerIds = rows
        .map((r) => '${r['owner_id'] ?? ''}')
        .where((id) => id.isNotEmpty && id != 'null')
        .toSet()
        .toList();

    final ownerMap = <String, Map<String, dynamic>>{};
    if (ownerIds.isNotEmpty) {
      try {
        final users = await _client
            .from('users')
            .select('id,full_name,business_name,email,phone,country')
            .inFilter('id', ownerIds);
        for (final u in users) {
          ownerMap['${u['id']}'] = u;
        }
      } catch (_) {}
    }

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
            ownerName: _ownerName(ownerMap['${row['owner_id']}'] ?? row['owner']),
            ownerLocation: _ownerLocation(ownerMap['${row['owner_id']}'] ?? row['owner']),
            ownerEmail: _ownerEmail(ownerMap['${row['owner_id']}'] ?? row['owner']),
            ownerPhone: _ownerPhone(ownerMap['${row['owner_id']}'] ?? row['owner']),
            createdAt: _tryParseDate(row['created_at']),
            description: (row['description'] as String?) ?? '',
            attributes: (row['attributes'] as Map<String, dynamic>?) ?? {},
          ),
        )
        .toList();
  }

  Future<List<ModerationItem>> fetchModerationArchive({int limit = 50}) async {
    final rows = await _client
        .from('assets')
        .select(
            'id,title,status,category,thumb_url,media_url,description,attributes,source,tags,owner_id,created_at')
        .neq('status', 'pending')
        .order('updated_at', ascending: false)
        .limit(limit);

    final ownerIds = rows
        .map((r) => '${r['owner_id'] ?? ''}')
        .where((id) => id.isNotEmpty && id != 'null')
        .toSet()
        .toList();

    final ownerMap = <String, Map<String, dynamic>>{};
    if (ownerIds.isNotEmpty) {
      try {
        final users = await _client
            .from('users')
            .select('id,full_name,business_name,email,phone,country')
            .inFilter('id', ownerIds);
        for (final u in users) {
          ownerMap['${u['id']}'] = u;
        }
      } catch (_) {}
    }

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
            ownerName: _ownerName(ownerMap['${row['owner_id']}'] ?? row['owner']),
            ownerLocation: _ownerLocation(ownerMap['${row['owner_id']}'] ?? row['owner']),
            ownerEmail: _ownerEmail(ownerMap['${row['owner_id']}'] ?? row['owner']),
            ownerPhone: _ownerPhone(ownerMap['${row['owner_id']}'] ?? row['owner']),
            createdAt: _tryParseDate(row['created_at']),
            description: (row['description'] as String?) ?? '',
            attributes: (row['attributes'] as Map<String, dynamic>?) ?? {},
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
        .inFilter('role', ['designer', 'manufacturer'])
        .order('created_at', ascending: false)
        .limit(limit);

    // Collect user IDs to look up document URLs from profile tables
    final userIds = rows
        .map<String>((r) => '${r['id'] ?? ''}')
        .where((id) => id.isNotEmpty && id != 'null')
        .toList();

    // Fetch document URLs from both profile tables in parallel.
    // Wrapped in try-catch because RLS may restrict reading other users' profiles.
    final docMap = <String, Map<String, String?>>{};
    if (userIds.isNotEmpty) {
      try {
        final results = await Future.wait([
          _client
              .from('designer_profiles')
              .select('user_id,work_file_url,business_card_url')
              .inFilter('user_id', userIds),
          _client
              .from('manufacturer_profiles')
              .select('user_id,work_file_url,business_card_url')
              .inFilter('user_id', userIds),
        ]);
        for (final profileRows in results) {
          for (final p in profileRows) {
            final uid = '${p['user_id'] ?? ''}';
            if (uid.isEmpty || uid == 'null') continue;
            docMap[uid] = {
              'work_file_url': p['work_file_url'] as String?,
              'business_card_url': p['business_card_url'] as String?,
            };
          }
        }
      } catch (_) {
        // RLS may block reading other users' profiles — continue without docs
      }
    }

    return rows
        .map<VerificationRequest>(
          (row) {
            final uid = '${row['id']}';
            final docs = docMap[uid];
            return VerificationRequest(
              userId: uid,
              name: _nameFromUserRow(row),
              subtitle: _subtitleFromUserRow(row),
              email: (row['email'] as String?) ?? '',
              role: (row['role'] as String?) ?? 'member',
              country: (row['country'] as String?) ?? '',
              hasGst:
                  ((row['gst_number'] as String?) ?? '').trim().isNotEmpty,
              hasAddress:
                  ((row['address'] as String?) ?? '').trim().isNotEmpty,
              hasBusinessType:
                  ((row['business_type'] as String?) ?? '').trim().isNotEmpty,
              createdAt: _tryParseDate(row['created_at']),
              workFileUrl: docs?['work_file_url'],
              businessCardUrl: docs?['business_card_url'],
            );
          },
        )
        .toList();
  }

  Future<void> moderateAsset({
    required String assetId,
    required bool approve,
  }) async {
    final status = approve ? 'approved' : 'rejected';
    final now = DateTime.now().toUtc().toIso8601String();

    // Fetch the asset metadata regardless of outcome to send notification
    final assetResult = await _client
        .from('assets')
        .select(
            'source, title, description, media_url, thumb_url, category, tags, owner_id, attributes')
        .eq('id', assetId)
        .maybeSingle();

    await _client.from('assets').update({
      'status': status,
      'updated_at': now,
    }).eq('id', assetId);

    if (approve && assetResult != null) {
      try {
        final source = assetResult['source'] as String?;
        if (source == 'designerproducts' || source == 'manufacturerproducts') {
          // Check if it already exists there by title and owner
          final existingProduct = await _client
              .from(source!)
              .select('id')
              .eq('Product Title', assetResult['title'] ?? '')
              .eq('user_id', assetResult['owner_id'] ?? '')
              .maybeSingle();

          final attributes = _sanitizeProductAttributes(
            (assetResult['attributes'] as Map<String, dynamic>?) ?? {},
          );

          // "Images" is the unified text[] column (Phase 3 rename of "Image").
          // Bulk upload submits multi-image products but assets.media_url only
          // holds one, so it keeps the full ordered list in attributes. Prefer
          // that; fall back to media_url for single-image/admin submissions.
          final attributeImages = attributes['Images'];
          final imagesArray = (attributeImages is List && attributeImages.isNotEmpty)
              ? attributeImages
              : (assetResult['media_url'] != null
                  ? [assetResult['media_url']]
                  : <String>[]);
          // Already applied above; prevent the attributes spread from re-adding it.
          attributes.remove('Images');

          if (existingProduct != null) {
            // Update existing
            await _client.from(source).update({
              'Images': imagesArray,
              'Description': assetResult['description'],
              'Product Tags': assetResult['tags'],
              ...attributes,
            }).eq('id', existingProduct['id']);
          } else {
            // Insert new
            await _client.from(source).insert({
              'Product Title': assetResult['title'],
              'Description': assetResult['description'],
              'Images': imagesArray,
              'Product Type': assetResult['category'],
              'user_id': assetResult['owner_id'],
              'Product Tags': assetResult['tags'],
              ...attributes,
            });
          }
        }
      } catch (e) {
        // Surface the failure instead of silently claiming success: if the
        // product row never lands, the admin needs to know (this is what made
        // an earlier "approved but not in DB" bug invisible).
        print('Error updating product table after moderation: $e');
        rethrow;
      }
    }

    if (assetResult != null) {
      final ownerId = assetResult['owner_id'] as String?;
      final title = assetResult['title'] ?? 'Your submission';
      if (ownerId != null && ownerId.isNotEmpty) {
        try {
          await _client.from('notifications').insert({
            'user_id': ownerId,
            'type': 'milestone',
            'title': approve ? 'Product Approved' : 'Product Rejected',
            'body': approve
                ? 'Your product "$title" has been approved and published to the platform.'
                : 'Your product "$title" has been rejected.',
            'related_item_id': assetId,
          });
        } catch (e) {
          print('Failed to send moderation notification to user: $e');
        }
      }
    }
  }

  Future<void> moderateAssetsBulk(
    List<String> assetIds, {
    required bool approve,
  }) async {
    for (final id in assetIds) {
      await moderateAsset(assetId: id, approve: approve);
    }
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

  /// Largest number of values put into a single PostgREST `in.(…)` filter.
  ///
  /// PostgREST filters ride in the query string of a GET. A UUID costs ~39
  /// characters there, so ~200 of them already pushes the URL past the 8 KB
  /// request-line limit that Supabase's edge proxy enforces. The proxy rejects
  /// it *before* PostgREST sees it, which is why the failure arrives as a bare
  /// `PostgrestException(message: Bad Request, code: 400, details: , hint: null)`
  /// - the body is a plain gateway error with none of the SQL detail a genuine
  /// PostgREST 400 would carry. That is exactly the error the admin User
  /// Management screen was showing once the catalog grew past a few hundred
  /// assets. 100 keeps each URL comfortably under 4 KB.
  static const int _inFilterChunkSize = 100;

  /// Run `select ... where <column> in (...)` in URL-safe batches.
  Future<List<Map<String, dynamic>>> _selectInChunks({
    required String table,
    required String columns,
    required String column,
    required List<String> values,
  }) async {
    if (values.isEmpty) return [];
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < values.length; i += _inFilterChunkSize) {
      final end = (i + _inFilterChunkSize).clamp(0, values.length);
      final chunk = values.sublist(i, end);
      final rows =
          await _client.from(table).select(columns).inFilter(column, chunk);
      out.addAll((rows as List).map((e) => Map<String, dynamic>.from(e)));
    }
    return out;
  }

  /// Registration documents for the given user rows, keyed by user id.
  ///
  /// Three sources, because a document's location depends on how far the user
  /// got through onboarding:
  ///   1. `designer-files` table   - finalised uploads, keyed by user_id.
  ///   2. `pending_signup_uploads` - uploaded at signup but not yet finalised.
  ///      Keyed by EMAIL, since `finalize-signup-uploads` only runs once the
  ///      user confirms their address and signs in. A user sitting in
  ///      "pending approval" has their documents ONLY here - which is exactly
  ///      the moment the admin needs to see them, and why the screen looked
  ///      empty before.
  ///   3. `designer_profiles` / `manufacturer_profiles` - the legacy columns
  ///      written by the older signUpAdmin path.
  ///
  /// A failure in any one source is logged and skipped rather than thrown: a
  /// missing document list must not take down the whole User Management screen.
  Future<Map<String, List<UserDocument>>> _fetchUserDocuments(
      List<Map<String, dynamic>> rows) async {
    final out = <String, List<UserDocument>>{};
    if (rows.isEmpty) return out;

    final userIds = rows.map((r) => '${r['id']}').toList();
    final emailToId = <String, String>{};
    for (final r in rows) {
      final email = (r['email'] as String?)?.trim().toLowerCase();
      if (email != null && email.isNotEmpty) emailToId[email] = '${r['id']}';
    }

    void add(String userId, UserDocument doc) =>
        (out[userId] ??= <UserDocument>[]).add(doc);

    // 1. Finalised uploads.
    try {
      final files = await _selectInChunks(
        table: 'designer-files',
        columns: 'user_id, file_type, file_url, created_at',
        column: 'user_id',
        values: userIds,
      );
      for (final f in files) {
        add('${f['user_id']}', UserDocument(
          fileType: '${f['file_type']}',
          source: 'linked',
          url: f['file_url'] as String?,
          uploadedAt: _tryParseDate(f['created_at']),
        ));
      }
    } catch (e) {
      debugPrint('designer-files lookup failed: $e');
    }

    // 2. Not-yet-finalised uploads, matched on email.
    if (emailToId.isNotEmpty) {
      try {
        final pending = await _selectInChunks(
          table: 'pending_signup_uploads',
          columns: 'email, file_type, object_path, status, created_at',
          column: 'email',
          values: emailToId.keys.toList(),
        );
        for (final p in pending) {
          if ('${p['status']}' == 'linked') continue; // already covered above
          final uid = emailToId['${p['email']}'.toLowerCase()];
          if (uid == null) continue;
          add(uid, UserDocument(
            fileType: '${p['file_type']}',
            source: 'pending',
            objectPath: p['object_path'] as String?,
            uploadedAt: _tryParseDate(p['created_at']),
          ));
        }
      } catch (e) {
        debugPrint('pending_signup_uploads lookup failed: $e');
      }
    }

    // 3. Legacy profile columns.
    for (final table in ['designer_profiles', 'manufacturer_profiles']) {
      try {
        final profiles = await _selectInChunks(
          table: table,
          columns: 'user_id, work_file_url, business_card_url',
          column: 'user_id',
          values: userIds,
        );
        for (final p in profiles) {
          final uid = '${p['user_id']}';
          final work = p['work_file_url'] as String?;
          final card = p['business_card_url'] as String?;
          if (work != null && work.isNotEmpty) {
            add(uid,
                UserDocument(fileType: 'work_file', source: 'linked', url: work));
          }
          if (card != null && card.isNotEmpty) {
            add(uid, UserDocument(
                fileType: 'business_card', source: 'linked', url: card));
          }
        }
      } catch (e) {
        debugPrint('$table lookup failed: $e');
      }
    }

    // The same document can surface from more than one source (e.g. a legacy
    // profile column plus a designer-files row). Keep one per file_type,
    // preferring a finalised copy over a pending one.
    for (final entry in out.entries) {
      final byType = <String, UserDocument>{};
      for (final doc in entry.value) {
        final existing = byType[doc.fileType];
        if (existing == null || (existing.isPending && !doc.isPending)) {
          byType[doc.fileType] = doc;
        }
      }
      out[entry.key] = byType.values.toList();
    }

    return out;
  }

  /// Mint a time-limited URL for a registration document.
  ///
  /// Signed URLs are used for BOTH kinds of document, not just pending ones:
  /// the `designer-files` bucket is private (`public = false`), yet
  /// `finalize-signup-uploads` stores a `getPublicUrl()` link, which does not
  /// resolve against a private bucket. Signing the object path is what actually
  /// works — and it expires, so a link copied out of the admin screen doesn't
  /// become a permanent handle on someone's business documents.
  Future<String?> createDocumentSignedUrl(String objectPath,
      {int expiresInSeconds = 300}) async {
    try {
      return await _client.storage
          .from('designer-files')
          .createSignedUrl(objectPath, expiresInSeconds);
    } catch (e) {
      debugPrint('createSignedUrl failed for $objectPath: $e');
      return null;
    }
  }

  /// Recover the storage object path from a stored URL.
  ///
  /// Handles both shapes Supabase produces:
  ///   .../storage/v1/object/public/designer-files/users/<uid>/work_file.pdf
  ///   .../storage/v1/object/sign/designer-files/users/<uid>/work_file.pdf?...
  /// Returns null when the string isn't a designer-files URL, in which case the
  /// caller falls back to using it verbatim.
  static String? objectPathFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    const marker = '/designer-files/';
    final idx = url.indexOf(marker);
    if (idx == -1) return null;
    final path = url.substring(idx + marker.length).split('?').first;
    return path.isEmpty ? null : Uri.decodeComponent(path);
  }

  Future<List<UserLedgerRow>> fetchUserLedger({int limit = 100}) async {
    List<Map<String, dynamic>> rows = [];
    try {
      rows = await _client
          .from('users')
          .select(
              'id,full_name,username,business_name,email,phone,role,is_member,credits_remaining,approval_status,last_credit_refresh,created_at,last_activity_at')
          .order('created_at', ascending: false)
          .limit(limit);
    } catch (e) {
      throw Exception('users query failed: $e');
    }

    if (rows.isEmpty) return [];

    final userIds = rows.map((r) => '${r['id']}').toList();

    // 1. Fetch assets owned by these users to get asset_id -> owner_id mapping
    List<Map<String, dynamic>> assetsRes = [];
    try {
      assetsRes = await _selectInChunks(
        table: 'assets',
        columns: 'id, owner_id',
        column: 'owner_id',
        values: userIds,
      );
    } catch (e) {
      throw Exception('assets query failed: $e');
    }

    final Map<String, String> assetToOwner = {};
    final Set<String> relevantAssetIds = {};
    for (final a in assetsRes) {
      final aid = '${a['id']}';
      final oid = '${a['owner_id']}';
      assetToOwner[aid] = oid;
      relevantAssetIds.add(aid);
    }

    // 2. Fetch engagement metrics for these assets
    final Map<String, Map<String, int>> userMetrics = {};
    for (final uid in userIds) {
      userMetrics[uid] = {'v': 0, 'l': 0, 's': 0};
    }

    if (relevantAssetIds.isNotEmpty) {
      try {
        final analyticsRes = await _selectInChunks(
          table: 'analytics_daily',
          columns: 'asset_id, views, likes, shares',
          column: 'asset_id',
          values: relevantAssetIds.toList(),
        );

        for (final stat in analyticsRes) {
        final aid = '${stat['asset_id']}';
        final ownerId = assetToOwner[aid];
        if (ownerId != null && userMetrics.containsKey(ownerId)) {
          userMetrics[ownerId]!['v'] =
              (userMetrics[ownerId]!['v'] ?? 0) + (stat['views'] as int? ?? 0);
          userMetrics[ownerId]!['l'] =
              (userMetrics[ownerId]!['l'] ?? 0) + (stat['likes'] as int? ?? 0);
          userMetrics[ownerId]!['s'] =
              (userMetrics[ownerId]!['s'] ?? 0) + (stat['shares'] as int? ?? 0);
        }
      }
      } catch (e) {
        throw Exception('analytics_daily query failed: $e');
      }
    }

    final documents = await _fetchUserDocuments(rows);

    return rows.map<UserLedgerRow>((row) {
      final uid = '${row['id']}';
      final metrics = userMetrics[uid] ?? {'v': 0, 'l': 0, 's': 0};
      return UserLedgerRow(
        documents: documents[uid] ?? const [],
        id: uid,
        name: _resolveDisplayName(row),
        email: (row['email'] as String?) ?? '',
        phone: (row['phone'] as String?) ?? '',
        role: (row['role'] as String?) ?? 'member',
        isMember: row['is_member'] as bool? ?? false,
        creditsRemaining: _toInt(row['credits_remaining']),
        approvalStatus: (row['approval_status'] as String?) ?? 'pending',
        lastCreditRefresh: _tryParseDate(row['last_credit_refresh']),
        createdAt: _tryParseDate(row['created_at']),
        lastActivityAt: _tryParseDate(row['last_activity_at']),
        totalViews: metrics['v'] ?? 0,
        totalLikes: metrics['l'] ?? 0,
        totalShares: metrics['s'] ?? 0,
      );
    }).toList();
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
        userName: (row['user_name'] as String?) ??
            uploaderNames[userId] ??
            'Unknown user',
        userEmail: (row['user_email'] as String?) ?? '',
        productTitle: (row['product_title'] as String?) ?? 'Untitled item',
        productTable: (row['product_table'] as String?) ?? '',
        createdAt: _tryParseDate(row['created_at']),
        status: status,
        productId: productId,
        userId: userId,
        creatorName: uploaderNames[userId] ?? '',
        metalType: (row['metal_type'] as String?) ?? '',
        metalPurity: (row['metal_purity'] as String?) ?? '',
        goldWeight: (row['gold_weight'] as String?) ?? '',
        metalColor: (row['metal_color'] as String?) ?? '',
        metalFinish: (row['metal_finish'] as String?) ?? '',
        stoneType: _toStringList(row['stone_type']),
        stoneColor: _toStringList(row['stone_color']),
        stoneCount: _toStringList(row['stone_count']),
        stonePurity: _toStringList(row['stone_purity']),
        stoneCut: _toStringList(row['stone_cut']),
        stoneUsed: _toStringList(row['stone_used']),
        stoneWeight: _toStringList(row['stone_weight']),
        stoneSetting: _toStringList(row['stone_setting']),
        additionalNotes: (row['additional_notes'] as String?) ?? '',
        productUrl: (row['product_url'] as String?) ?? '',
        phoneNumber: (row['user_phone'] as String?) ??
            (row['phone_number'] as String?) ??
            '',
        metalWeight: (row['metal_weight'] as String?) ?? '',
        netWeight: (row['net_weight'] as String?) ?? '',
        dimension: (row['dimension'] as String?) ?? '',
        designType: (row['design_type'] as String?) ?? '',
        artForm: (row['art_form'] as String?) ?? '',
        plating: (row['plating'] as String?) ?? '',
        enamelWork: _toStringList(row['enamel_work']),
        customizable: _toStringList(row['customizable']),
        category: (row['category'] as String?) ?? '',
        subCategory: (row['sub_category'] as String?) ?? '',
        plain: (row['plain'] as String?) ?? '',
        studded: _toStringList(row['studded']),
      );
    }).toList();
  }

  /// Bulk update quote requests status
  Future<void> updateQuoteRequestsStatus(
      List<String> ids, String status) async {
    if (ids.isEmpty) return;
    await _client
        .from('quote_requests')
        .update({'status': status}).inFilter('id', ids);
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

  Future<List<Map<String, dynamic>>> fetchGeographicEngagement() async {
    // We delegate to DashboardService which already has the complex aggregation logic
    return await DashboardService.fetchEngagementByLocation();
  }

  Future<List<InventoryItem>> fetchInventory({int limit = 100}) async {
    final rows = await _client
        .from('assets')
        .select(
            'id,title,category,status,source,thumb_url,media_url,owner_id,created_at,owner:users!assets_owner_id_fkey(full_name,business_name,email,phone)')
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
            ownerPhone: _ownerPhone(row['owner']),
            createdAt: _tryParseDate(row['created_at']),
          ),
        )
        .toList();
  }

  Future<List<InventoryItem>> fetchContentActivityLog({
    String table = 'all',
    String searchTerm = '',
    int limit = 100,
    int minLikes = 0,
    int minViews = 0,
    int minShares = 0,
    int minCreditsUsed = 0,
    String? productType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final normalizedTerm = searchTerm.trim();
    final includesProducts = table == 'all' || table == 'products';
    final includesDesigner = table == 'all' || table == 'designerproducts';
    final includesManufacturer =
        table == 'all' || table == 'manufacturerproducts';

    // Over-fetch when any post-fetch filter is active (metrics are counted in
    // Dart; category/uploader matching also happens in Dart), so enough rows
    // survive the final filtering to fill `limit`.
    final hasPostFilters = minLikes > 0 ||
        minViews > 0 ||
        minShares > 0 ||
        minCreditsUsed > 0 ||
        normalizedTerm.isNotEmpty;
    final fetchLimit = hasPostFilters ? math.max(limit, 1000) : limit;

    int calculatedLimit = fetchLimit ~/ 3;
    if (calculatedLimit < 1) calculatedLimit = 1;
    final perTableLimit = table == 'all' ? calculatedLimit : fetchLimit;

    final productRows = <dynamic>[];
    final designerRows = <dynamic>[];
    final manufacturerRows = <dynamic>[];

    // NOTE(Phase 3 flip): 'category_arr' becomes '"Category"' and the legacy
    // "Category"/"Image"/"Images" columns disappear - update these selects in
    // the SAME release as the Phase 3 SQL migration.
    const commonCols =
        'id,"Product Title","Category",created_at,user_id,"Product Type","Images"';

    // The free-text term matches title, category, uploader and product type.
    // Category is a text[] and uploader lives in `users`, so that matching
    // happens in Dart on the over-fetched newest rows; only the structured
    // filters (product type, date window) narrow server-side.
    PostgrestFilterBuilder<dynamic> applyCommon(
        PostgrestFilterBuilder<dynamic> query) {
      if (productType != null && productType.trim().isNotEmpty) {
        query = query.ilike('Product Type', '%${productType.trim()}%');
      }
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }
      return query;
    }

    if (includesProducts) {
      // products.created_at exists since Phase 1 - date filter/sort now real.
      final query =
          applyCommon(_client.from('products').select('$commonCols,"Images"'));
      productRows.addAll(await query
          .order('created_at', ascending: false)
          .limit(perTableLimit));
    }

    if (includesDesigner) {
      final query =
          applyCommon(_client.from('designerproducts').select(commonCols));
      designerRows.addAll(await query
          .order('created_at', ascending: false)
          .limit(perTableLimit));
    }

    if (includesManufacturer) {
      final query =
          applyCommon(_client.from('manufacturerproducts').select(commonCols));
      manufacturerRows.addAll(await query
          .order('created_at', ascending: false)
          .limit(perTableLimit));
    }

    // Collect all IDs for batch metric fetching
    final allProductIds = [
      ...productRows.map((r) => r['id'].toString()),
      ...designerRows.map((r) => r['id'].toString()),
      ...manufacturerRows.map((r) => r['id'].toString()),
    ];
    print('ActivityLog: allProductIds = $allProductIds');

    if (allProductIds.isEmpty) return [];

    // Parallel fetch of engagement metrics for the current batch
    // Quote IDs to ensure PostgREST treats them as text strings, avoiding type match failures
    final quotedIds = allProductIds.toList();

    final metricsResults = await Future.wait([
      _client
          .from('likes')
          .select('item_id, item_table')
          .inFilter('item_id', quotedIds),
      _client
          .from('views')
          .select('item_id, item_table')
          .inFilter('item_id', quotedIds),
      _client
          .from('shares')
          .select('item_id, item_table')
          .inFilter('item_id', quotedIds),
      _client
          .from('user_unlocked_items')
          .select('item_id')
          .inFilter('item_id', quotedIds),
    ]);

    final likesRows = metricsResults[0] as List;
    final viewsRows = metricsResults[1] as List;
    final sharesRows = metricsResults[2] as List;
    final unlocksRows = metricsResults[3] as List;

    // Helper to build count maps
    Map<String, int> _countBySource(List rows, bool useTable) {
      final counts = <String, int>{};
      for (var row in rows) {
        final id = row['item_id'].toString();
        final tableSuffix =
            useTable ? (row['item_table'] ?? 'products') : 'all';
        final key = '$tableSuffix:$id';
        counts[key] = (counts[key] ?? 0) + 1;
      }
      return counts;
    }

    final likesMap = _countBySource(likesRows, true);
    final viewsMap = _countBySource(viewsRows, true);
    final sharesMap = _countBySource(sharesRows, true);
    print(
        'ActivityLog: Found ${likesRows.length} likes, ${viewsRows.length} views, ${sharesRows.length} shares, ${unlocksRows.length} unlocks.');

    // Unlock map ignores table (matching old pattern)
    final unlocksMap = <String, int>{};
    for (var row in unlocksRows) {
      final id = row['item_id'].toString();
      unlocksMap[id] = (unlocksMap[id] ?? 0) + 1;
    }

    print('ActivityLog likesRows: $likesRows');
    final uploaderMap = await _fetchUploaderMap([
      ...productRows.map((row) => '${row['user_id'] ?? ''}'),
      ...designerRows.map((row) => '${row['user_id'] ?? ''}'),
      ...manufacturerRows.map((row) => '${row['user_id'] ?? ''}'),
    ]);

    InventoryItem _mapRow(dynamic row, String source) {
      final id = row['id'].toString();
      final userId = '${row['user_id'] ?? ''}';
      final owner = uploaderMap[userId];
      final key = '$source:$id';

      // "Category" is text[]; join its values for display.
      String category = 'Uncategorized';
      final arr = row['Category'];
      if (arr is List && arr.isNotEmpty) {
        category = arr.map((e) => e.toString()).join(', ');
      }

      return InventoryItem(
        id: key,
        title: (row['Product Title'] as String?) ?? 'Untitled Product',
        category: category,
        status: 'uploaded',
        source: source,
        thumbUrl: _extractImage(row['Images']),
        mediaUrl: _extractImage(row['Images']),
        ownerId: userId,
        ownerName: owner?['name'] ?? 'Unknown creator',
        ownerEmail: owner?['email'] ?? '',
        ownerPhone: owner?['phone'] ?? '',
        createdAt: _tryParseDate(row['created_at']),
        likesCount: likesMap[key] ?? 0,
        viewsCount: viewsMap[key] ?? 0,
        sharesCount: sharesMap[key] ?? 0,
        creditsUsed: unlocksMap[id] ?? 0,
        productType: row['Product Type'] as String?,
      );
    }

    var items = [
      ...productRows.map((r) => _mapRow(r, 'products')),
      ...designerRows.map((r) => _mapRow(r, 'designerproducts')),
      ...manufacturerRows.map((r) => _mapRow(r, 'manufacturerproducts')),
    ];

    // Final filtering in Dart
    if (minLikes > 0)
      items = items.where((i) => i.likesCount >= minLikes).toList();
    if (minViews > 0)
      items = items.where((i) => i.viewsCount >= minViews).toList();
    if (minShares > 0)
      items = items.where((i) => i.sharesCount >= minShares).toList();
    if (minCreditsUsed > 0)
      items = items.where((i) => i.creditsUsed >= minCreditsUsed).toList();
    if (normalizedTerm.isNotEmpty) {
      final term = normalizedTerm.toLowerCase();
      items = items
          .where((i) =>
              i.title.toLowerCase().contains(term) ||
              i.category.toLowerCase().contains(term) ||
              i.ownerName.toLowerCase().contains(term) ||
              i.ownerEmail.toLowerCase().contains(term) ||
              (i.productType ?? '').toLowerCase().contains(term))
          .toList();
    }

    // Sort by date
    items.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return items.take(limit).toList();
  }

  Future<void> setUserCredits({
    required String userId,
    required int credits,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    await _client.from('users').update({
      'credits_remaining': credits,
      'last_credit_refresh': now,
    }).eq('id', userId);
  }

  Future<void> refreshAllUserCredits({
    required int memberCredits,
    required int nonMemberCredits,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    // Refresh member credits
    await _client.from('users').update({
      'credits_remaining': memberCredits,
      'last_credit_refresh': now,
    }).eq('is_member', true);

    // Refresh non-member credits
    await _client.from('users').update({
      'credits_remaining': nonMemberCredits,
      'last_credit_refresh': now,
    }).eq('is_member', false);
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

  Future<int> bulkCreateInventoryAssets(
      List<Map<String, dynamic>> items) async {
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
          .upsert({'key': entry.key, 'value': entry.value, 'updated_at': now})
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
      final ad = _tryParseDate(a['timestamp']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = _tryParseDate(b['timestamp']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
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

  /// Broadcast a notification to a specific list of user IDs.
  ///
  /// This method allows the admin to target individual users directly,
  /// bypassing the predefined audience filters. The `userIds` list should
  /// contain Supabase user IDs. The notification payload mirrors the one used
  /// in `broadcastNotification`.
  Future<int> broadcastToSpecificUsers({
    required List<String> userIds,
    required String subject,
    required String body,
    String urgency = 'standard',
    DateTime? scheduledFor,
  }) async {
    if (userIds.isEmpty) return 0;
    final rows = userIds
        .map(
          (id) => {
            'user_id': id,
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

  /// Search for users by optional username, email, or phone.
  /// Returns a list of user maps containing at least id, username, email, and phone.
  Future<List<Map<String, dynamic>>> searchUsers({
    String? username,
    String? email,
    String? phone,
  }) async {
    var query = _client.from('users').select('id,username,email,phone');
    if (username != null && username.isNotEmpty) {
      query = query.ilike('username', username);
    }
    if (email != null && email.isNotEmpty) {
      query = query.ilike('email', email);
    }
    if (phone != null && phone.isNotEmpty) {
      query = query.ilike('phone', phone);
    }
    final rows = await query;
    return List<Map<String, dynamic>>.from(rows);
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
      columns: 'id,"Product Title","Price","Images"',
    );
    final designerRows = await _fetchAllRows(
      table: 'designerproducts',
      columns: 'id,"Product Title","Price","created_at","Images"',
      orderColumn: 'created_at',
      ascending: false,
    );
    final manufacturerRows = await _fetchAllRows(
      table: 'manufacturerproducts',
      columns: 'id,"Product Title","Price","created_at","Images"',
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
          imageUrl: _extractImage(row['Images']),
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
          imageUrl: _extractImage(row['Images'] ?? row['Image']),
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
          imageUrl: _extractImage(row['Images'] ?? row['Image']),
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
      columns: 'id,"Product Title","Price",created_at,user_id,"Images"',
      orderColumn: 'created_at',
      ascending: false,
    );
    final manufacturerRows = await _fetchAllRows(
      table: 'manufacturerproducts',
      columns: 'id,"Product Title","Price",created_at,user_id,"Images"',
      orderColumn: 'created_at',
      ascending: false,
    );

    final uploaderIds = <String>{
      ...designerRows.map((row) => '${row['user_id'] ?? ''}'),
      ...manufacturerRows.map((row) => '${row['user_id'] ?? ''}'),
    }..removeWhere((id) => id.isEmpty || id == 'null');

    final uploaderMap = <String, Map<String, String>>{};
    // business_name lives in the role-specific profile tables (PK: user_id).
    final businessNameMap = <String, String>{};
    if (uploaderIds.isNotEmpty) {
      final ids = uploaderIds.toList();
      final results = await Future.wait([
        _client.from('users').select('id,full_name,email').inFilter('id', ids),
        _client
            .from('designer_profiles')
            .select('user_id,business_name')
            .inFilter('user_id', ids),
        _client
            .from('manufacturer_profiles')
            .select('user_id,business_name')
            .inFilter('user_id', ids),
      ]);
      for (final user in results[0]) {
        final id = '${user['id']}';
        uploaderMap[id] = {
          'name': (user['full_name'] as String?)?.trim().isNotEmpty == true
              ? user['full_name'] as String
              : 'Unknown uploader',
          'email': (user['email'] as String?) ?? '',
        };
      }
      for (final profile in [...results[1], ...results[2]]) {
        final name = (profile['business_name'] as String?)?.trim() ?? '';
        if (name.isNotEmpty) {
          businessNameMap['${profile['user_id']}'] = name;
        }
      }
    }

    AppraisalQueueItem mapRow(dynamic row, String sourceTable) {
      final userId = '${row['user_id'] ?? ''}';
      final user = uploaderMap[userId];
      return AppraisalQueueItem(
        id: '${row['id']}',
        title: (row['Product Title'] as String?) ?? 'Untitled upload',
        sourceTable: sourceTable,
        uploaderUserId: userId,
        uploaderName: user?['name'] ?? 'Unknown uploader',
        uploaderEmail: user?['email'] ?? '',
        businessName: businessNameMap[userId] ?? '',
        imageUrl: _extractImage(row['Images'] ?? row['Image']),
        createdAt: _tryParseDate(row['created_at']),
        priceLabel: ((row['Price'] as String?) ?? '').trim(),
      );
    }

    final items = <AppraisalQueueItem>[
      ...designerRows.map((row) => mapRow(row, 'designerproducts')),
      ...manufacturerRows.map((row) => mapRow(row, 'manufacturerproducts')),
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

      final double goldPriceInInr =
          xauRate > 0 ? (1 / xauRate).toDouble() : 0.0;
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
      total += (rows as List).length;
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

  /// Normalizes an asset's `attributes` JSONB (written by the B2B upload
  /// flow) into a shape that is safe to spread into a designer/manufacturer
  /// product row: coerces the unified array columns to text[], and drops keys
  /// that are not real product columns (e.g. "Jewelry Type", a UI-only field).
  Map<String, dynamic> _sanitizeProductAttributes(Map<String, dynamic> attrs) {
    // Keys that exist in attributes but are NOT columns on the product tables.
    const nonColumnKeys = {'Jewelry Type'};
    // Columns that are text[] post-Phase-3 but may arrive as a scalar String.
    const arrayColumns = {'Metal Color', 'Category', 'Images'};

    final out = <String, dynamic>{};
    attrs.forEach((key, value) {
      if (nonColumnKeys.contains(key) || value == null) return;
      if (arrayColumns.contains(key) && value is! List) {
        final s = '$value'.trim();
        out[key] = s.isEmpty ? <String>[] : [s];
      } else {
        out[key] = value;
      }
    });
    return out;
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
      return value
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
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

  String _ownerPhone(dynamic owner) {
    if (owner is Map<String, dynamic>) {
      return (owner['phone'] as String?)?.trim() ?? '';
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
        .select('id,full_name,business_name,email,phone')
        .inFilter('id', uploaderIds.toList());

    final uploaderMap = <String, Map<String, String>>{};
    for (final row in rows) {
      final id = '${row['id']}';
      uploaderMap[id] = {
        'name': _ownerName(row),
        'email': _ownerEmail(row),
        'phone': _ownerPhone(row),
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
    // "Metal Color" is the Phase 1 unified array column `metal_color_arr` -
    // a product can contribute MULTIPLE color values, so it must be unnested,
    // not scalar-cast (the previous code did `row[column] as String?`, which
    // "Metal Color" is a text[] array (unified); "Metal Type" stays scalar.
    final isArrayColumn = column == 'Metal Color';
    final selectColumn = '"$column"';

    Future<void> fetchTableWithPagination(String tableName) async {
      int offset = 0;
      const int limit = 1000;
      bool hasMore = true;
      final Map<String, int> counts = {};

      while (hasMore) {
        final rows = await _client
            .from(tableName)
            .select(selectColumn)
            .range(offset, offset + limit - 1);

        if (rows.isEmpty) {
          hasMore = false;
        } else {
          for (final row in rows) {
            if (isArrayColumn) {
              final arr = row['Metal Color'];
              if (arr is List) {
                for (final item in arr) {
                  final val = item?.toString().trim();
                  if (val != null && val.isNotEmpty && val != 'null') {
                    counts[val] = (counts[val] ?? 0) + 1;
                  }
                }
              }
            } else {
              final val = (row[column] as String?)?.trim();
              if (val != null && val.isNotEmpty && val != 'null') {
                counts[val] = (counts[val] ?? 0) + 1;
              }
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

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? 0.0;
    return 0.0;
  }

  Future<JewelryPricingMasterData> fetchPricingMetadata() async {
    try {
      final rows =
          await _client.from('settings').select('key,value').inFilter('key', [
        'rate_gold',
        'rate_silver',
        'rate_platinum',
        'making_groups',
        'stone_groups',
        'admin_whatsapp_target'
      ]);

      final Map<String, String> data = {
        for (var row in rows) (row['key'] as String): (row['value'] as String)
      };

      return JewelryPricingMasterData(
        rateGold: double.tryParse(data['rate_gold'] ?? '0') ?? 0,
        rateSilver: double.tryParse(data['rate_silver'] ?? '0') ?? 0,
        ratePlatinum: double.tryParse(data['rate_platinum'] ?? '0') ?? 0,
        makingGroups: _parseJsonToMap(data['making_groups']),
        stoneGroups: _parseJsonToMap(data['stone_groups']),
        whatsappTarget: data['admin_whatsapp_target'] ?? '918879018801',
      );
    } catch (_) {
      return JewelryPricingMasterData.empty();
    }
  }

  Map<String, double> _parseJsonToMap(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final decoded = json.decode(jsonStr);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), _toDouble(v)));
      }
    } catch (_) {}
    return {};
  }
}
