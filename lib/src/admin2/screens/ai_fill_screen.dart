import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/ai_fill_service.dart';

/// Admin "AI Data Fill" screen:
///   * Set the global LLM API key + default model (fallback for all users).
///   * Choose a table + row count and run a fill.
///   * Generate / rotate / revoke each B2B user's `dgn_…` master key, with a TTL.
///
/// Nothing on this screen ever reads a stored secret back. Keys are write-only
/// from the app's point of view: generated server-side, shown once, then only
/// ever referred to by their prefix.
class AdminAiFillScreen extends StatefulWidget {
  const AdminAiFillScreen({super.key});

  @override
  State<AdminAiFillScreen> createState() => _AdminAiFillScreenState();
}

class _AdminAiFillScreenState extends State<AdminAiFillScreen> {
  static const _ink = Color(0xFF0A2F22);
  static const _accent = Color(0xFF0A4F3F);
  static const _border = Color(0xFFE3E9E6);
  static const _muted = Color(0xFF61726C);

  late final AiFillService _service = AiFillService(Supabase.instance.client);

  final _globalKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();

  String _table = 'products';
  int _rowCount = 10;
  bool _loading = true;
  bool _running = false;
  bool _issuing = false;
  String? _error;
  String? _globalKeyHint;
  AiFillResult? _lastResult;

  List<ApiCredential> _credentials = [];
  Map<String, B2bUserOption> _users = {};

  String? _selectedUserId;
  MasterKeyTtl _selectedTtl = MasterKeyTtl.month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _globalKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await _service.getLlmSettings();
      final creds = await _service.listCredentials();
      final users = await _service.listKeyEligibleUsers();
      if (!mounted) return;
      setState(() {
        _modelCtrl.text =
            (settings?['default_model'] as String?) ?? 'gemini-2.5-pro';
        // The global key itself is never fetched - only a hint that one exists.
        _globalKeyHint = settings?['global_llm_key_hint'] as String?;
        _globalKeyCtrl.clear();
        _credentials = creds;
        _users = users;
        if (_selectedUserId != null && !users.containsKey(_selectedUserId)) {
          _selectedUserId = null;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _service.updateLlmSettings(
        // Blank means "leave the stored key alone" - we can't round-trip it,
        // so an empty field must not be mistaken for "clear the key".
        globalLlmApiKey:
            _globalKeyCtrl.text.trim().isEmpty ? null : _globalKeyCtrl.text,
        defaultModel: _modelCtrl.text,
      );
      _toast('Global LLM settings saved');
      _load();
    } catch (e) {
      _toast('Save failed: $e', error: true);
    }
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final result = await _service.runAdminFill(
        tableName: _table,
        limit: _rowCount,
      );
      if (!mounted) return;
      setState(() => _lastResult = result);
      _toast('Filled ${result.success}/${result.total} rows');
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
      _toast('Run failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Master keys
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _generateKey(String userId, MasterKeyTtl ttl,
      {bool isRotation = false}) async {
    setState(() => _issuing = true);
    try {
      final issued = await _service.issueMasterKey(userId, ttl: ttl);
      if (!mounted) return;
      await _showKeyOnceDialog(issued, _users[userId]?.label ?? userId);
      _load();
    } catch (e) {
      _toast('${isRotation ? 'Rotation' : 'Generation'} failed: $e',
          error: true);
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  /// The one and only time the plaintext key is visible. There is no
  /// "show again" - the server kept a hash, not the key.
  Future<void> _showKeyOnceDialog(IssuedMasterKey issued, String who) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Master key generated'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('For $who',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: SelectableText(
                  issued.apiKey,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 14, color: _ink),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                issued.expiresAt == null
                    ? 'This key never expires.'
                    : 'Expires ${_formatDate(issued.expiresAt!)}.',
                style: const TextStyle(fontSize: 12.5, color: _muted),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.warning_amber_rounded,
                    size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Copy it now. Only a hash is stored, so this value cannot '
                    'be shown again — losing it means generating a new one.',
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.orange.shade900),
                  ),
                ),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: issued.apiKey));
              _toast('Key copied to clipboard');
            },
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            label: const Text('Copy key'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("I've saved it"),
          ),
        ],
      ),
    );
  }

  Future<void> _rotateWithTtlPrompt(ApiCredential cred) async {
    var ttl = cred.expiresAt == null ? MasterKeyTtl.never : MasterKeyTtl.month;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Rotate master key'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The current key for ${_users[cred.userId]?.label ?? cred.userId} '
                  'stops working immediately.',
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MasterKeyTtl>(
                  value: ttl,
                  decoration: _decoration('New key valid for'),
                  items: MasterKeyTtl.values
                      .map((t) =>
                          DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) => setLocal(() => ttl = v ?? ttl),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _accent),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Rotate'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await _generateKey(cred.userId, ttl, isRotation: true);
    }
  }

  Future<void> _revoke(ApiCredential cred) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke master key'),
        content: Text(
          'This deletes the key material for '
          '${_users[cred.userId]?.label ?? cred.userId}. They will not be able '
          'to run AI fills until a new key is generated.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.revokeMasterKey(cred.userId);
      _toast('Key revoked');
      _load();
    } catch (e) {
      _toast('Revoke failed: $e', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : _accent,
    ));
  }

  static String _formatDate(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AI Data Fill',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 4),
        const Text(
          'Auto-complete empty product fields with AI. Configure the global key, '
          'pick a table and row count, and generate master keys for your B2B users.',
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 20),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child:
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ),
        LayoutBuilder(builder: (context, c) {
          final narrow = c.maxWidth < 900;
          final left = _globalSettingsCard();
          final right = _runCard();
          if (narrow) {
            return Column(children: [left, const SizedBox(height: 16), right]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ]);
        }),
        const SizedBox(height: 16),
        _generateKeyCard(),
        const SizedBox(height: 16),
        _credentialsCard(),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: child,
      );

  Widget _globalSettingsCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Global LLM Settings',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 4),
            const Text('Used for any user who has not set their own key.',
                style: TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 16),
            Row(children: [
              Icon(
                _globalKeyHint == null
                    ? Icons.gpp_maybe_outlined
                    : Icons.lock_outline,
                size: 16,
                color: _globalKeyHint == null ? Colors.orange.shade800 : _accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _globalKeyHint == null
                      ? 'No global key configured yet.'
                      : 'Key stored (encrypted): $_globalKeyHint',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _field('Replace global LLM API key', _globalKeyCtrl, obscure: true,
                hint: 'Leave blank to keep the current key'),
            const SizedBox(height: 12),
            _field('Default model name', _modelCtrl, hint: 'e.g. gemini-2.5-pro'),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _accent),
                onPressed: _saveSettings,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save settings'),
              ),
            ),
          ],
        ),
      );

  Widget _runCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Run a Fill',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _table,
              decoration: _decoration('Table'),
              items: const [
                DropdownMenuItem(
                    value: 'products', child: Text('Products (catalog)')),
                DropdownMenuItem(
                    value: 'designerproducts', child: Text('Designer products')),
                DropdownMenuItem(
                    value: 'manufacturerproducts',
                    child: Text('Manufacturer products')),
              ],
              onChanged: (v) => setState(() => _table = v ?? 'products'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Rows to process:',
                  style: TextStyle(fontSize: 13, color: _muted)),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: _rowCount.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  activeColor: _accent,
                  label: '$_rowCount',
                  onChanged: (v) => setState(() => _rowCount = v.round()),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text('$_rowCount',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _accent),
                onPressed: _running ? null : _run,
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(_running ? 'Running…' : 'Run AI Fill'),
              ),
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              _resultSummary(_lastResult!),
            ],
          ],
        ),
      );

  Widget _generateKeyCard() {
    final options = _users.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.vpn_key_outlined, size: 18, color: _accent),
            SizedBox(width: 8),
            Text('Generate Master Key',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
          ]),
          const SizedBox(height: 4),
          const Text(
            'A B2B user needs a master key (dgn_…) before they can run AI '
            'database prefill. The key is shown once, then stored hashed.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 720;
            final userField = DropdownButtonFormField<String>(
              value: _selectedUserId,
              isExpanded: true,
              decoration: _decoration('B2B user'),
              hint: const Text('Select a user'),
              items: options
                  .map((u) => DropdownMenuItem(
                        value: u.id,
                        child: Text('${u.label}  ·  ${u.role}',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedUserId = v),
            );
            final ttlField = DropdownButtonFormField<MasterKeyTtl>(
              value: _selectedTtl,
              isExpanded: true,
              decoration: _decoration('Valid for (TTL)'),
              items: MasterKeyTtl.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedTtl = v ?? _selectedTtl),
            );
            final button = SizedBox(
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _accent),
                onPressed: (_selectedUserId == null || _issuing)
                    ? null
                    : () => _generateKey(_selectedUserId!, _selectedTtl),
                icon: _issuing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_moderator_outlined, size: 18),
                label: Text(_issuing ? 'Generating…' : 'Generate key'),
              ),
            );

            if (narrow) {
              return Column(children: [
                userField,
                const SizedBox(height: 12),
                ttlField,
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: button),
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: userField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ttlField),
              const SizedBox(width: 12),
              button,
            ]);
          }),
        ],
      ),
    );
  }

  Widget _resultSummary(AiFillResult r) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Last run: ${r.success} filled · ${r.failed} failed · ${r.total} scanned',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, color: _ink)),
            if (r.filledIds.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Filled IDs: ${r.filledIds.join(", ")}',
                  style: const TextStyle(fontSize: 12, color: _muted)),
            ],
          ],
        ),
      );

  Widget _credentialsCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Issued Keys',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 4),
            const Text(
                'Key values are not retrievable — only their prefix and status.',
                style: TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 12),
            if (_credentials.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No keys issued yet.',
                    style: TextStyle(fontSize: 13, color: _muted)),
              )
            else
              ..._credentials.map(_credentialRow),
          ],
        ),
      );

  Widget _credentialRow(ApiCredential c) {
    final user = _users[c.userId];
    final name = user?.label ?? c.userId;
    final role = user?.role ?? '';

    final Color chipColor;
    if (!c.hasKey) {
      chipColor = _muted;
    } else if (!c.isActive || c.isExpired) {
      chipColor = Colors.red.shade700;
    } else if (c.expiresAt != null &&
        c.expiresAt!.difference(DateTime.now().toUtc()).inDays <= 7) {
      chipColor = Colors.orange.shade800;
    } else {
      chipColor = _accent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role.isEmpty ? name : '$name  ·  $role',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(children: [
                  Text(
                    c.keyPrefix == null ? '—' : '${c.keyPrefix}${'•' * 8}',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11.5, color: _muted),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: chipColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(c.statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: chipColor)),
                  ),
                ]),
              ],
            ),
          ),
          Tooltip(
            message: c.isActive ? 'Disable key' : 'Enable key',
            child: Switch(
              value: c.isActive,
              activeColor: _accent,
              onChanged: c.hasKey
                  ? (v) async {
                      try {
                        await _service.setCredentialActive(c.userId, v);
                        _load();
                      } catch (e) {
                        _toast('Update failed: $e', error: true);
                      }
                    }
                  : null,
            ),
          ),
          TextButton(
            onPressed: _issuing ? null : () => _rotateWithTtlPrompt(c),
            child: const Text('Rotate'),
          ),
          if (c.hasKey)
            IconButton(
              tooltip: 'Revoke',
              onPressed: () => _revoke(c),
              icon: Icon(Icons.delete_outline,
                  size: 20, color: Colors.red.shade700),
            ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
      );

  Widget _field(String label, TextEditingController ctrl,
          {bool obscure = false, String? hint}) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: _decoration(label, hint: hint),
      );
}
