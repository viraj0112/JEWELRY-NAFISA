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

/// How long a freshly generated master key stays valid.
enum MasterKeyTtl {
  week('week', '1 week'),
  month('month', '1 month'),
  year('year', '1 year'),
  never('never', 'Never expires');

  const MasterKeyTtl(this.wire, this.label);

  /// Value sent to the `ai-credentials` edge function.
  final String wire;
  final String label;
}

/// A master key, returned exactly once at generation time.
///
/// The database keeps only a SHA-256 hash (for verification) and an AES-GCM
/// ciphertext (so the server can replay it to the fill backend). Nothing can
/// recover this string afterwards - if the admin loses it, they rotate.
class IssuedMasterKey {
  IssuedMasterKey({
    required this.apiKey,
    required this.keyPrefix,
    required this.expiresAt,
  });

  final String apiKey;
  final String keyPrefix;
  final DateTime? expiresAt;

  factory IssuedMasterKey.fromJson(Map<String, dynamic> json) =>
      IssuedMasterKey(
        apiKey: json['api_key'] as String? ?? '',
        keyPrefix: json['key_prefix'] as String? ?? '',
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.tryParse('${json['expires_at']}'),
      );
}

/// One user's AI-fill credentials, as the CLIENT is allowed to see them.
///
/// No field here is a secret. The migration revoked column-level SELECT on
/// `x_api_key*` and `llm_api_key*` from the `authenticated` role, so even a
/// hand-written `select('*')` cannot pull key material into a browser.
class ApiCredential {
  ApiCredential({
    required this.userId,
    required this.hasKey,
    this.keyPrefix,
    this.llmKeyHint,
    this.llmModel,
    this.isActive = true,
    this.expiresAt,
    this.lastUsedAt,
  });

  final String userId;

  /// True when a master key exists for this user.
  final bool hasKey;

  /// Display-only head of the key, e.g. `dgn_4452abeb`.
  final String? keyPrefix;

  /// Display-only tail of the user's LLM key, e.g. `••••7f2a`. Null when unset.
  final String? llmKeyHint;

  final String? llmModel;
  final bool isActive;

  /// Null means the key never expires.
  final DateTime? expiresAt;
  final DateTime? lastUsedAt;

  bool get isExpired =>
      expiresAt != null && !expiresAt!.isAfter(DateTime.now().toUtc());

  bool get isUsable => hasKey && isActive && !isExpired;

  /// Human-readable state for the UI badge.
  String get statusLabel {
    if (!hasKey) return 'No key';
    if (!isActive) return 'Disabled';
    if (isExpired) return 'Expired';
    if (expiresAt == null) return 'Active · never expires';
    final days = expiresAt!.difference(DateTime.now().toUtc()).inDays;
    if (days <= 0) return 'Active · expires today';
    return 'Active · expires in $days day${days == 1 ? '' : 's'}';
  }

  factory ApiCredential.fromJson(Map<String, dynamic> json) => ApiCredential(
        userId: json['user_id'] as String,
        hasKey: (json['key_prefix'] as String?)?.isNotEmpty ?? false,
        keyPrefix: json['key_prefix'] as String?,
        llmKeyHint: json['llm_key_hint'] as String?,
        llmModel: json['llm_model'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.tryParse('${json['expires_at']}'),
        lastUsedAt: json['last_used_at'] == null
            ? null
            : DateTime.tryParse('${json['last_used_at']}'),
      );
}

/// A user who can be granted a master key.
class B2bUserOption {
  B2bUserOption({required this.id, required this.label, required this.role});

  final String id;
  final String label;
  final String role;
}

/// Talks to the DatabasePrefill FastAPI backend + the credentials/settings
/// tables in Supabase. Used by the admin, designer, and manufacturer screens.
///
/// Every write that touches key material goes through the `ai-credentials`
/// edge function, which encrypts before storing. The client holds plaintext
/// only for the instant a key is generated or typed in.
class AiFillService {
  AiFillService(this._supabase);

  final SupabaseClient _supabase;

  static const _credentialsFn = 'ai-credentials';

  // ---------------------------------------------------------------------------
  // Credentials (Supabase)
  // ---------------------------------------------------------------------------

  /// The signed-in user's own credential row (or null if none issued yet).
  Future<ApiCredential?> getMyCredential() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _supabase
        .from('api_credential_status')
        .select(
            'user_id, key_prefix, llm_key_hint, llm_model, is_active, expires_at, last_used_at')
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return ApiCredential.fromJson(row);
  }

  /// The user sets their OWN provider key. It is sent once, over TLS, to the
  /// edge function, which encrypts it before it reaches Postgres - it is never
  /// stored or read back in plaintext.
  Future<void> updateMyLlmKey({String? llmApiKey, String? llmModel}) async {
    final key = (llmApiKey ?? '').trim();
    if (key.isEmpty) {
      await _invokeCredentials({'action': 'clear_my_llm_key'});
      if ((llmModel ?? '').trim().isNotEmpty) {
        await updateMyLlmModel(llmModel!);
      }
      return;
    }
    await _invokeCredentials({
      'action': 'set_my_llm_key',
      'llm_api_key': key,
      if ((llmModel ?? '').trim().isNotEmpty) 'llm_model': llmModel!.trim(),
    });
  }

  /// The model name is not a secret, so the user may write it directly - the
  /// migration grants UPDATE on exactly that one column.
  Future<void> updateMyLlmModel(String llmModel) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('Not signed in');
    await _supabase
        .from('api_credentials')
        .update({'llm_model': llmModel.trim().isEmpty ? null : llmModel.trim()})
        .eq('user_id', uid);
  }

  Future<void> clearMyLlmKey() =>
      _invokeCredentials({'action': 'clear_my_llm_key'});

  // ---- Admin-only credential management ----

  /// Credential rows for the admin UI. Secret columns are not merely omitted
  /// from this select - the database refuses to return them to this role.
  Future<List<ApiCredential>> listCredentials() async {
    final rows = await _supabase
        .from('api_credential_status')
        .select('user_id, key_prefix, llm_key_hint, llm_model, is_active, '
            'expires_at, last_used_at, created_at')
        .order('created_at');
    return (rows as List)
        .map((e) => ApiCredential.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Display names for the credential list and the "generate key" picker.
  Future<Map<String, B2bUserOption>> listKeyEligibleUsers() async {
    final rows = await _supabase
        .from('users')
        .select('id, full_name, business_name, email, role')
        .inFilter('role', ['designer', 'manufacturer', 'admin']).order('email');

    final out = <String, B2bUserOption>{};
    for (final r in (rows as List)) {
      final m = Map<String, dynamic>.from(r);
      final id = '${m['id']}';
      final label = (m['business_name'] as String?)?.trim().isNotEmpty == true
          ? m['business_name'] as String
          : (m['full_name'] as String?)?.trim().isNotEmpty == true
              ? m['full_name'] as String
              : (m['email'] as String?) ?? id;
      out[id] = B2bUserOption(
        id: id,
        label: label,
        role: (m['role'] as String?) ?? 'member',
      );
    }
    return out;
  }

  /// Generate (or rotate) a user's `dgn_…` master key with a TTL.
  ///
  /// Returns the plaintext ONCE - show it to the admin immediately, because
  /// no later call can retrieve it.
  Future<IssuedMasterKey> issueMasterKey(
    String userId, {
    MasterKeyTtl ttl = MasterKeyTtl.never,
  }) async {
    final data = await _invokeCredentials({
      'action': 'issue_key',
      'user_id': userId,
      'ttl': ttl.wire,
    });
    return IssuedMasterKey.fromJson(data);
  }

  Future<void> setCredentialActive(String userId, bool active) =>
      _invokeCredentials({
        'action': 'set_active',
        'user_id': userId,
        'is_active': active,
      });

  /// Wipe the key material entirely (stronger than disabling).
  Future<void> revokeMasterKey(String userId) => _invokeCredentials({
        'action': 'revoke_key',
        'user_id': userId,
      });

  // ---------------------------------------------------------------------------
  // Global LLM settings (admin)
  // ---------------------------------------------------------------------------

  /// Only the non-secret parts: the model name and a hint showing whether a
  /// global key is configured.
  Future<Map<String, dynamic>?> getLlmSettings() async {
    return await _supabase
        .from('llm_settings')
        .select('default_model, global_llm_key_hint')
        .eq('id', 1)
        .maybeSingle();
  }

  Future<void> updateLlmSettings({
    String? globalLlmApiKey,
    String? defaultModel,
  }) async {
    await _invokeCredentials({
      'action': 'set_global_llm_key',
      if (globalLlmApiKey != null) 'llm_api_key': globalLlmApiKey,
      if (defaultModel != null && defaultModel.trim().isNotEmpty)
        'default_model': defaultModel.trim(),
    });
  }

  // ---------------------------------------------------------------------------
  // Backend fill calls
  // ---------------------------------------------------------------------------

  /// ADMIN: fill any table. The caller's x-api-key never leaves the server -
  /// the `run-ai-fill` edge function decrypts it there, so the browser only
  /// ever sends its Supabase JWT.
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

  Future<Map<String, dynamic>> _invokeCredentials(
      Map<String, dynamic> body) async {
    final res = await _supabase.functions.invoke(_credentialsFn, body: body);
    final data = res.data;
    if (res.status != 200) {
      final detail = (data is Map && data['error'] != null)
          ? data['error']
          : 'status ${res.status}';
      throw Exception(detail.toString());
    }
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }
}
