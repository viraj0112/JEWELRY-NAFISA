import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One product's outcome in a fill run (an entry of `data.details`).
class AiFillItemDetail {
  AiFillItemDetail({
    required this.id,
    required this.status,
    this.reason,
    this.columns = const [],
  });

  final int? id;

  /// `filled`, `skipped` or `failed`.
  final String status;

  /// Raw reason from the backend, e.g. `404 NOT_FOUND. {'error': {...}}`.
  final String? reason;

  /// Columns written (filled rows only).
  final List<String> columns;

  bool get isFilled => status == 'filled';
  bool get isFailed => status == 'failed';

  /// The human-readable part of [reason]: the provider's `error.message` when
  /// the reason embeds one, otherwise the reason as-is.
  String? get message => extractErrorMessage(reason);

  factory AiFillItemDetail.fromJson(Map<String, dynamic> json) =>
      AiFillItemDetail(
        id: (json['id'] as num?)?.toInt(),
        status: '${json['status'] ?? 'unknown'}',
        reason: json['reason'] as String?,
        columns: ((json['columns'] as List?) ?? []).map((e) => '$e').toList(),
      );

  // Matches `'message': '...'` or `"message": "..."`. The backend passes on
  // Gemini's error as a Python dict repr, which quotes a string with " when it
  // contains an apostrophe - hence the backreference to the opening quote.
  static final _messagePattern = RegExp(
    r"""['"]message['"]\s*:\s*(['"])((?:\\.|(?!\1).)*)\1""",
    dotAll: true,
  );

  static String? extractErrorMessage(String? reason) {
    if (reason == null || reason.trim().isEmpty) return null;
    final match = _messagePattern.firstMatch(reason);
    if (match == null) return _friendly(reason.trim());
    return _friendly(
        match.group(2)!.replaceAll(r"\'", "'").replaceAll(r'\"', '"').trim());
  }

  // Google's retired-model error, e.g. "This model models/gemini-2.5-flash is
  // no longer available to new users. Please update your code to use
  // models/gemini-3.6-flash ...".
  static final _retiredModelPattern = RegExp(
    r'model (?:models/)?([\w.\-]+) is no longer available to new users',
    caseSensitive: false,
  );
  static final _suggestedModelPattern =
      RegExp(r'to use (?:models/)?([\w.\-]+)', caseSensitive: false);

  /// Rewrites provider messages that read oddly to our users into plain text.
  static String _friendly(String message) {
    final retired = _retiredModelPattern.firstMatch(message);
    if (retired == null) return message;
    final oldModel = _trimDots(retired.group(1)!);
    final suggested = _suggestedModelPattern.firstMatch(message)?.group(1);
    final newModel = suggested == null ? null : _trimDots(suggested);
    return 'This model $oldModel is no longer available to new users. '
        'Please update the model${newModel == null ? '' : ' to $newModel'} '
        'for latest features and improvements.';
  }

  static String _trimDots(String s) => s.replaceAll(RegExp(r'\.+$'), '');
}

/// Token counts Gemini reported for a run (or a sum of runs).
class AiFillUsage {
  const AiFillUsage({
    this.inputTokens = 0,
    this.cachedTokens = 0,
    this.outputTokens = 0,
    this.thinkingTokens = 0,
  });

  /// Includes [cachedTokens].
  final int inputTokens;
  final int cachedTokens;
  final int outputTokens;

  /// Billed at the output rate.
  final int thinkingTokens;

  int get totalTokens => inputTokens + outputTokens + thinkingTokens;

  AiFillUsage operator +(AiFillUsage o) => AiFillUsage(
        inputTokens: inputTokens + o.inputTokens,
        cachedTokens: cachedTokens + o.cachedTokens,
        outputTokens: outputTokens + o.outputTokens,
        thinkingTokens: thinkingTokens + o.thinkingTokens,
      );

  factory AiFillUsage.fromJson(Map<String, dynamic>? json) => AiFillUsage(
        inputTokens: (json?['input_tokens'] as num?)?.toInt() ?? 0,
        cachedTokens: (json?['cached_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (json?['output_tokens'] as num?)?.toInt() ?? 0,
        thinkingTokens: (json?['thinking_tokens'] as num?)?.toInt() ?? 0,
      );
}

/// Formats a USD amount; sub-cent costs keep enough digits to be meaningful.
String formatUsd(double usd) {
  if (usd == 0) return '\$0.00';
  if (usd < 0.01) return '\$${usd.toStringAsFixed(4)}';
  return '\$${usd.toStringAsFixed(2)}';
}

/// Result of a batch fill run, mirroring the FastAPI BatchFillResponse, plus
/// the cost the `run-ai-fill` Edge Function computed from the price table.
class AiFillResult {
  AiFillResult({
    required this.total,
    required this.success,
    required this.failed,
    required this.filledIds,
    required this.details,
    this.model,
    this.usage = const AiFillUsage(),
    this.costUsd,
    this.priceConfigured = false,
    this.batches = 1,
    this.stoppedReason,
  });

  final int total;
  final int success;
  final int failed;
  final List<int> filledIds;
  final List<Map<String, dynamic>> details;

  /// Gemini model the backend used.
  final String? model;
  final AiFillUsage usage;

  /// Null when no price is configured for [model] (cost unknown, not zero).
  final double? costUsd;
  final bool priceConfigured;

  /// Number of backend calls combined into this result.
  final int batches;

  /// Why a multi-batch run ended early, if it did.
  final String? stoppedReason;

  List<AiFillItemDetail> get items =>
      details.map(AiFillItemDetail.fromJson).toList();

  /// First failure message, for a short user-facing summary.
  String? get firstErrorMessage =>
      items.where((i) => i.isFailed).map((i) => i.message).firstOrNull;

  /// "$0.0123" / "price not set for <model>" / null when nothing was spent.
  String? get costLabel {
    if (usage.totalTokens == 0) return null;
    if (costUsd != null) return formatUsd(costUsd!);
    return 'price not set for ${model ?? 'this model'}';
  }

  /// Sums consecutive batch results into one run summary.
  static AiFillResult combine(List<AiFillResult> parts,
      {String? stoppedReason}) {
    if (parts.isEmpty) {
      return AiFillResult(
        total: 0,
        success: 0,
        failed: 0,
        filledIds: const [],
        details: const [],
        batches: 0,
        stoppedReason: stoppedReason,
      );
    }
    // Cost is known only if every part that used tokens was priced.
    final spent = parts.where((p) => p.usage.totalTokens > 0);
    final allPriced = spent.every((p) => p.costUsd != null);
    return AiFillResult(
      total: parts.fold(0, (s, p) => s + p.total),
      success: parts.fold(0, (s, p) => s + p.success),
      failed: parts.fold(0, (s, p) => s + p.failed),
      filledIds: [for (final p in parts) ...p.filledIds],
      details: [for (final p in parts) ...p.details],
      model: parts.map((p) => p.model).whereType<String>().lastOrNull,
      usage: parts.fold(const AiFillUsage(), (s, p) => s + p.usage),
      costUsd: allPriced
          ? parts.fold<double>(0, (s, p) => s + (p.costUsd ?? 0))
          : null,
      priceConfigured: allPriced,
      batches: parts.length,
      stoppedReason: stoppedReason,
    );
  }

  /// Prints one line per product - filled, skipped or failed (with the
  /// provider's error message) - plus tokens and cost, to the console /
  /// browser dev tools.
  void log({String label = 'AI Fill'}) {
    debugPrint('[$label] Run finished: $success filled, $failed failed, '
        '$total scanned${batches > 1 ? ' in $batches batches' : ''}');
    if (usage.totalTokens > 0) {
      debugPrint('[$label] Tokens: ${usage.inputTokens} in'
          '${usage.cachedTokens > 0 ? ' (${usage.cachedTokens} cached)' : ''}, '
          '${usage.outputTokens} out, ${usage.thinkingTokens} thinking'
          ' - cost: ${costLabel ?? '-'}${model == null ? '' : ' ($model)'}');
    }
    if (total == 0) {
      debugPrint('[$label] Nothing to fill - no products with empty details.');
    }
    for (final item in items) {
      final id = item.id == null ? '?' : '#${item.id}';
      if (item.isFilled) {
        final cols =
            item.columns.isEmpty ? '' : ' - ${item.columns.join(', ')}';
        debugPrint('[$label] FILLED  $id$cols');
      } else if (item.isFailed) {
        debugPrint('[$label] FAILED  $id - ${item.message ?? 'unknown error'}');
      } else {
        debugPrint('[$label] ${item.status.toUpperCase().padRight(7)} $id'
            '${item.message == null ? '' : ' - ${item.message}'}');
      }
    }
    if (stoppedReason != null) debugPrint('[$label] Stopped: $stoppedReason');
  }

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
      model: data['model'] as String?,
      usage: AiFillUsage.fromJson(data['usage'] as Map<String, dynamic>?),
      costUsd: (data['cost_usd'] as num?)?.toDouble(),
      priceConfigured: data['price_configured'] as bool? ?? false,
    );
  }
}

/// Progress of a multi-batch fill, for the UI.
class AiFillProgress {
  const AiFillProgress({
    required this.batch,
    required this.requested,
    required this.soFar,
    this.waitingSeconds = 0,
  });

  /// 1-based number of the batch just finished.
  final int batch;

  /// Products the user asked for in total.
  final int requested;

  /// Everything completed so far.
  final AiFillResult soFar;

  /// > 0 while pausing before the next batch.
  final int waitingSeconds;
}

/// Batch size and pause between batches, set by the admin.
class AiFillBatchSettings {
  const AiFillBatchSettings({this.batchSize = 10, this.pauseSeconds = 10});

  final int batchSize;
  final int pauseSeconds;
}

/// Admin-maintained USD price per 1M tokens for one model.
class ModelPrice {
  const ModelPrice({
    required this.model,
    required this.inputPerMillion,
    required this.outputPerMillion,
    this.cachedInputPerMillion,
  });

  final String model;
  final double inputPerMillion;
  final double outputPerMillion;

  /// Null = cached input is charged at [inputPerMillion].
  final double? cachedInputPerMillion;

  factory ModelPrice.fromJson(Map<String, dynamic> json) => ModelPrice(
        model: json['model'] as String,
        inputPerMillion: (json['input_usd_per_million'] as num).toDouble(),
        outputPerMillion: (json['output_usd_per_million'] as num).toDouble(),
        cachedInputPerMillion:
            (json['cached_input_usd_per_million'] as num?)?.toDouble(),
      );
}

/// A model the LLM key can call, as listed by Google AI Studio.
class LlmModelOption {
  const LlmModelOption({required this.id, required this.displayName});

  /// The name stored and sent to the API, e.g. `gemini-2.5-flash`.
  final String id;

  /// Google's label, e.g. `Gemini 2.5 Flash`.
  final String displayName;

  factory LlmModelOption.fromJson(Map<String, dynamic> json) => LlmModelOption(
        id: json['id'] as String,
        displayName: json['display_name'] as String? ?? json['id'] as String,
      );
}

/// The models available to one key, plus which key they were listed for.
class LlmModelList {
  const LlmModelList({required this.models, required this.keySource});

  final List<LlmModelOption> models;

  /// `provided` (a key typed but not saved yet), `own` or `global`.
  final String keySource;
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

  /// Saved through the edge function (not a direct column update) so the name
  /// is checked against the models the user's key can actually call.
  Future<void> updateMyLlmModel(String llmModel) =>
      _invokeCredentials({
        'action': 'set_my_llm_model',
        'llm_model': llmModel.trim(),
      });

  /// Models the relevant LLM key can use, fetched live from Google AI Studio
  /// by the edge function - the stored key never comes to the browser.
  ///
  /// [llmApiKey] lists a key that was typed but not saved yet. Otherwise the
  /// caller's own saved key is used, falling back to the admin's global key
  /// (the same precedence a fill uses). [global] lists the global key's models
  /// (admin only).
  Future<LlmModelList> listModels({
    String? llmApiKey,
    bool global = false,
  }) async {
    final data = await _invokeCredentials({
      'action': 'list_models',
      'scope': global ? 'global' : 'mine',
      if ((llmApiKey ?? '').trim().isNotEmpty) 'llm_api_key': llmApiKey!.trim(),
    });
    return LlmModelList(
      keySource: data['key_source'] as String? ?? '',
      models: ((data['models'] as List?) ?? [])
          .map((e) => LlmModelOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
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

  /// Only the non-secret parts: the model name, a hint showing whether a
  /// global key is configured, and the batch/rate settings.
  ///
  /// Read through `llm_settings_public`, whose select list holds no key
  /// columns, so there is no path to them from a session token. `*` keeps
  /// this working before newer view columns exist.
  Future<Map<String, dynamic>?> getLlmSettings() async {
    return await _supabase
        .from('llm_settings_public')
        .select()
        .eq('id', 1)
        .maybeSingle();
  }

  Future<void> updateLlmSettings({
    String? globalLlmApiKey,
    String? defaultModel,
    int? batchSize,
    int? batchPauseSeconds,
    int? requestsPerMinute,
  }) async {
    await _invokeCredentials({
      'action': 'set_global_llm_key',
      if (globalLlmApiKey != null) 'llm_api_key': globalLlmApiKey,
      if (defaultModel != null && defaultModel.trim().isNotEmpty)
        'default_model': defaultModel.trim(),
      if (batchSize != null) 'fill_batch_size': batchSize,
      if (batchPauseSeconds != null) 'fill_batch_pause_seconds': batchPauseSeconds,
      if (requestsPerMinute != null) 'llm_requests_per_minute': requestsPerMinute,
    });
  }

  /// Batch size/pause for large fills. Readable by every signed-in user via a
  /// narrow SECURITY DEFINER function (llm_settings itself is admin-only);
  /// falls back to defaults if it isn't available.
  Future<AiFillBatchSettings> getBatchSettings() async {
    try {
      final rows = await _supabase.rpc('ai_fill_batch_settings');
      final row = (rows is List && rows.isNotEmpty)
          ? Map<String, dynamic>.from(rows.first as Map)
          : null;
      if (row == null) return const AiFillBatchSettings();
      return AiFillBatchSettings(
        batchSize: (row['fill_batch_size'] as num?)?.toInt() ?? 10,
        pauseSeconds: (row['fill_batch_pause_seconds'] as num?)?.toInt() ?? 10,
      );
    } catch (e) {
      debugPrint('[AI Fill] Using default batch settings: $e');
      return const AiFillBatchSettings();
    }
  }

  // ---------------------------------------------------------------------------
  // Model pricing (admin)
  // ---------------------------------------------------------------------------

  Future<List<ModelPrice>> listModelPrices() async {
    final rows = await _supabase
        .from('llm_model_pricing')
        .select('model, input_usd_per_million, output_usd_per_million, '
            'cached_input_usd_per_million')
        .order('model');
    return (rows as List)
        .map((e) => ModelPrice.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveModelPrice(ModelPrice price) async {
    await _supabase.from('llm_model_pricing').upsert({
      'model': price.model.trim(),
      'input_usd_per_million': price.inputPerMillion,
      'output_usd_per_million': price.outputPerMillion,
      'cached_input_usd_per_million': price.cachedInputPerMillion,
      'updated_by': _supabase.auth.currentUser?.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> deleteModelPrice(String model) async {
    await _supabase.from('llm_model_pricing').delete().eq('model', model);
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
    List<int> excludeIds = const [],
  }) {
    return _invokeFill({
      'mode': 'admin',
      'table_name': tableName,
      'limit': limit,
      if (excludeIds.isNotEmpty) 'exclude_ids': excludeIds,
    });
  }

  /// B2B/MANUFACTURER: fill only the caller's own products. Table is derived
  /// server-side from the caller's role.
  Future<AiFillResult> runMyFill({
    required int limit,
    List<int> excludeIds = const [],
  }) {
    return _invokeFill({
      'mode': 'mine',
      'limit': limit,
      if (excludeIds.isNotEmpty) 'exclude_ids': excludeIds,
    });
  }

  // Consecutive rate-limited batches tolerated before giving up.
  static const _maxRateLimitedBatches = 3;

  static bool _isRateLimitMessage(String? message) {
    final m = (message ?? '').toLowerCase();
    return m.contains('429') ||
        m.contains('resource_exhausted') ||
        m.contains('rate limit') ||
        m.contains('quota');
  }

  /// Fills [requested] products in batches of [settings.batchSize], one batch
  /// at a time with [settings.pauseSeconds] between them, so a large fill
  /// stays under Gemini's per-minute request/token limits.
  ///
  /// [runBatch] performs one backend call for up to `limit` products, skipping
  /// `excludeIds` (rows already attempted in this run). The run stops early
  /// when nothing is left to fill, when a whole batch fails for a non-rate
  /// reason (retrying would only spend money on the same error), after
  /// repeated rate limiting, or when [isCancelled] returns true.
  Future<AiFillResult> runInBatches({
    required int requested,
    required AiFillBatchSettings settings,
    required Future<AiFillResult> Function(int limit, List<int> excludeIds)
        runBatch,
    void Function(AiFillProgress progress)? onProgress,
    bool Function()? isCancelled,
    int rateLimitPauseSeconds = 60,
  }) async {
    final parts = <AiFillResult>[];
    final attempted = <int>{};
    var remaining = requested;
    var rateLimitedBatches = 0;
    String? stoppedReason;
    bool cancelled() => isCancelled?.call() ?? false;

    while (remaining > 0) {
      if (cancelled()) {
        stoppedReason = 'Cancelled by user';
        break;
      }
      final size = remaining < settings.batchSize ? remaining : settings.batchSize;
      final AiFillResult batch;
      try {
        batch = await runBatch(size, attempted.toList());
      } catch (e) {
        if (_isRateLimitMessage('$e') &&
            ++rateLimitedBatches < _maxRateLimitedBatches) {
          debugPrint('[AI Fill] Batch rate-limited, waiting before retrying: $e');
          await _pause(rateLimitPauseSeconds, parts, requested, onProgress, cancelled);
          continue;
        }
        if (parts.isEmpty) rethrow; // nothing done yet - report the error
        stoppedReason = '$e'.replaceFirst('Exception: ', '');
        break;
      }
      parts.add(batch);
      batch.log(label: 'AI Fill batch ${parts.length}');

      // Rate-limited products weren't really attempted - leave them eligible
      // for the next batch. Everything else is excluded from now on.
      final items = batch.items;
      final rateLimited =
          items.where((i) => i.isFailed && _isRateLimitMessage(i.message));
      attempted.addAll(items
          .where((i) => !(i.isFailed && _isRateLimitMessage(i.message)))
          .map((i) => i.id)
          .whereType<int>());
      remaining -= batch.total - rateLimited.length;

      onProgress?.call(AiFillProgress(
        batch: parts.length,
        requested: requested,
        soFar: AiFillResult.combine(parts),
      ));

      if (batch.total == 0) break; // nothing left to fill
      if (rateLimited.isNotEmpty && batch.success == 0) {
        if (++rateLimitedBatches >= _maxRateLimitedBatches) {
          stoppedReason = 'Gemini kept rate-limiting requests. '
              'Try a smaller batch size or longer pause.';
          break;
        }
        await _pause(rateLimitPauseSeconds, parts, requested, onProgress, cancelled);
        continue;
      }
      rateLimitedBatches = 0;
      // Judge only products that reached Gemini: ones skipped for having no
      // image cost nothing and say nothing about the model or key.
      final analysed =
          items.where((i) => !(i.status == 'skipped' && i.reason == 'no image url'));
      if (batch.success == 0 &&
          analysed.isNotEmpty &&
          analysed.every((i) => i.isFailed)) {
        stoppedReason = 'Every product in the last batch failed'
            '${batch.firstErrorMessage == null ? '' : ': ${batch.firstErrorMessage}'}';
        break;
      }
      if (remaining > 0) {
        await _pause(settings.pauseSeconds, parts, requested, onProgress, cancelled);
      }
    }

    final result = AiFillResult.combine(parts, stoppedReason: stoppedReason);
    if (parts.length > 1 || stoppedReason != null) {
      result.log(label: 'AI Fill total');
    }
    return result;
  }

  /// Waits between batches, reporting a countdown and stopping early on cancel.
  Future<void> _pause(
    int seconds,
    List<AiFillResult> parts,
    int requested,
    void Function(AiFillProgress progress)? onProgress,
    bool Function() cancelled,
  ) async {
    for (var left = seconds; left > 0 && !cancelled(); left--) {
      onProgress?.call(AiFillProgress(
        batch: parts.length,
        requested: requested,
        soFar: AiFillResult.combine(parts),
        waitingSeconds: left,
      ));
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  Future<AiFillResult> _invokeFill(Map<String, dynamic> body) async {
    // functions.invoke attaches the user's session (Authorization: Bearer
    // <jwt>) automatically; no secret is placed on the request by us.
    final FunctionResponse res;
    try {
      res = await _supabase.functions.invoke('run-ai-fill', body: body);
    } on FunctionException catch (e) {
      // Non-2xx responses throw; the backend's reason is in `error` (edge
      // function) or `detail` (FastAPI).
      final details = e.details;
      final detail = details is Map
          ? (details['error'] ?? details['detail'] ?? 'status ${e.status}')
          : 'status ${e.status}';
      final message = AiFillItemDetail.extractErrorMessage('$detail');
      debugPrint('[AI Fill] Run failed (HTTP ${e.status}): $message');
      throw Exception('Fill failed: $message');
    }

    final data = res.data;
    if (res.status != 200) {
      final detail = (data is Map && data['error'] != null)
          ? data['error']
          : 'status ${res.status}';
      debugPrint('[AI Fill] Run failed: $detail');
      throw Exception('Fill failed: $detail');
    }
    final result = AiFillResult.fromJson(Map<String, dynamic>.from(data as Map));
    result.log();
    return result;
  }

  Future<Map<String, dynamic>> _invokeCredentials(
      Map<String, dynamic> body) async {
    final FunctionResponse res;
    try {
      res = await _supabase.functions.invoke(_credentialsFn, body: body);
    } on FunctionException catch (e) {
      // Non-2xx responses throw; surface the function's own message rather
      // than the exception's raw dump.
      final details = e.details;
      throw Exception(details is Map && details['error'] != null
          ? details['error']
          : 'status ${e.status}');
    }
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
