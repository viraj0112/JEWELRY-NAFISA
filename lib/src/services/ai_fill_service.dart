import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a batch fill run, mirroring the FastAPI BatchFillResponse.
class AiFillResult {
  AiFillResult({
    required this.total,
    required this.success,
    required this.failed,
    required this.filledIds,
    required this.details,
  });

  final int total;
  final int success;
  final int failed;
  final List<int> filledIds;
  final List<Map<String, dynamic>> details;

  factory AiFillResult.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? json;
    return AiFillResult(
      total: (data['total'] as num?)?.toInt() ?? 0,
      success: (data['success'] as num?)?.toInt() ?? 0,
      failed: (data['failed'] as num?)?.toInt() ?? 0,
      filledIds: ((data['filled_ids'] as List?) ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      details: ((data['details'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}

/// One user's AI-fill credentials.
class ApiCredential {
  ApiCredential({
    required this.userId,
    required this.hasKey,
    this.llmApiKey,
    this.llmModel,
    this.isActive = true,
  });

  final String userId;

  /// True when a key exists for this user. The key value itself is deliberately
  /// NOT fetched to the client anymore - it is used only server-side by the
  /// run-ai-fill edge function - so the UI knows a key exists without holding it.
  final bool hasKey;
  final String? llmApiKey;
  final String? llmModel;
  final bool isActive;

  factory ApiCredential.fromJson(Map<String, dynamic> json) => ApiCredential(
        userId: json['user_id'] as String,
        hasKey: json['has_key'] as bool? ??
            ((json['x_api_key'] as String?)?.isNotEmpty ?? false),
        llmApiKey: json['llm_api_key'] as String?,
        llmModel: json['llm_model'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );
}

/// Talks to the DatabasePrefill FastAPI backend + the credentials/settings
/// tables in Supabase. Used by the admin, designer, and manufacturer screens.
class AiFillService {
  AiFillService(this._supabase);

  final SupabaseClient _supabase;

  // ---------------------------------------------------------------------------
  // Credentials (Supabase)
  // ---------------------------------------------------------------------------

  /// The signed-in user's own credential row (or null if none issued yet).
  Future<ApiCredential?> getMyCredential() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;
    // Note: x_api_key is intentionally not selected - the client never needs
    // the key value, only whether one exists (derived below).
    final row = await _supabase
        .from('api_credentials')
        .select('user_id, llm_api_key, llm_model, is_active')
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    // A row existing means a key was issued.
    return ApiCredential.fromJson({...row, 'has_key': true});
  }

  /// The user updates their OWN personal LLM key/model (allowed by RLS).
  Future<void> updateMyLlmKey({String? llmApiKey, String? llmModel}) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not signed in');
    await _supabase.from('api_credentials').update({
      'llm_api_key': (llmApiKey ?? '').trim().isEmpty ? null : llmApiKey!.trim(),
      'llm_model': (llmModel ?? '').trim().isEmpty ? null : llmModel!.trim(),
    }).eq('user_id', uid);
  }

  // ---- Admin-only credential management (RLS enforces admin) ----

  /// Lists credential rows for the admin UI WITHOUT the secret x_api_key: the
  /// admin only needs to see who has a key and toggle/rotate it, and pulling
  /// every user's key into the browser is exactly the exposure being closed.
  /// Rotation ([issueKey]) still returns the new key once, at creation time.
  Future<List<Map<String, dynamic>>> listCredentials() async {
    final rows = await _supabase
        .from('api_credentials')
        .select('user_id, llm_model, is_active, '
            'users(full_name, email, role)')
        .order('created_at');
    return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Issue (or rotate) a user's x-api-key. Generates a random key if none given.
  Future<String> issueKey(String userId, {String? key}) async {
    final apiKey = (key == null || key.trim().isEmpty) ? _randomKey() : key.trim();
    await _supabase.from('api_credentials').upsert({
      'user_id': userId,
      'x_api_key': apiKey,
      'is_active': true,
    });
    return apiKey;
  }

  Future<void> setCredentialActive(String userId, bool active) async {
    await _supabase
        .from('api_credentials')
        .update({'is_active': active}).eq('user_id', userId);
  }

  // ---------------------------------------------------------------------------
  // Global LLM settings (admin)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getLlmSettings() async {
    return await _supabase
        .from('llm_settings')
        .select('global_llm_api_key, default_model')
        .eq('id', 1)
        .maybeSingle();
  }

  Future<void> updateLlmSettings({
    String? globalLlmApiKey,
    String? defaultModel,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    final payload = <String, dynamic>{'id': 1, 'updated_by': uid};
    if (globalLlmApiKey != null) {
      payload['global_llm_api_key'] =
          globalLlmApiKey.trim().isEmpty ? null : globalLlmApiKey.trim();
    }
    if (defaultModel != null && defaultModel.trim().isNotEmpty) {
      payload['default_model'] = defaultModel.trim();
    }
    await _supabase.from('llm_settings').upsert(payload);
  }

  // ---------------------------------------------------------------------------
  // Backend fill calls
  // ---------------------------------------------------------------------------

  /// ADMIN: fill any table. The caller's x-api-key never leaves the server -
  /// the `run-ai-fill` edge function resolves it from the caller's session,
  /// so the browser only ever sends its Supabase JWT.
  Future<AiFillResult> runAdminFill({
    required String tableName,
    required int limit,
  }) {
    return _invokeFill({
      'mode': 'admin',
      'table_name': tableName,
      'limit': limit,
    });
  }

  /// B2B/MANUFACTURER: fill only the caller's own products. Table is derived
  /// server-side from the caller's role.
  Future<AiFillResult> runMyFill({
    required int limit,
  }) {
    return _invokeFill({
      'mode': 'mine',
      'limit': limit,
    });
  }

  Future<AiFillResult> _invokeFill(Map<String, dynamic> body) async {
    // functions.invoke attaches the user's session (Authorization: Bearer
    // <jwt>) automatically; no secret is placed on the request by us.
    final res = await _supabase.functions.invoke(
      'run-ai-fill',
      body: body,
    );

    final data = res.data;
    if (res.status != 200) {
      final detail = (data is Map && data['error'] != null)
          ? data['error']
          : 'status ${res.status}';
      throw Exception('Fill failed: $detail');
    }
    return AiFillResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  String _randomKey() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = (now * 2654435761) & 0x7fffffff;
    return 'dgn_${now.toRadixString(36)}${rand.toRadixString(36)}';
  }
}
