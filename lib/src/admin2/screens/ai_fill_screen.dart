import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/ai_fill_service.dart';

/// Admin "AI Data Fill" screen:
///   * Set the global LLM API key + default model (fallback for all users).
///   * Choose a table + row count and run a fill.
///   * Issue / rotate / disable each user's x-api-key.
class AdminAiFillScreen extends StatefulWidget {
  const AdminAiFillScreen({super.key});

  @override
  State<AdminAiFillScreen> createState() => _AdminAiFillScreenState();
}

class _AdminAiFillScreenState extends State<AdminAiFillScreen> {
  static const _ink = Color(0xFF0A2F22);
  static const _accent = Color(0xFF0A4F3F);
  static const _border = Color(0xFFE3E9E6);

  late final AiFillService _service =
      AiFillService(Supabase.instance.client);

  final _globalKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();

  String _table = 'products';
  int _rowCount = 10;
  bool _loading = true;
  bool _running = false;
  String? _error;
  AiFillResult? _lastResult;
  List<Map<String, dynamic>> _credentials = [];

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
      if (!mounted) return;
      setState(() {
        _modelCtrl.text = (settings?['default_model'] as String?) ?? 'gemini-2.5-pro';
        _globalKeyCtrl.text = (settings?['global_llm_api_key'] as String?) ?? '';
        _credentials = creds;
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
        globalLlmApiKey: _globalKeyCtrl.text,
        defaultModel: _modelCtrl.text,
      );
      _toast('Global LLM settings saved');
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

  Future<void> _issueKey(String userId) async {
    try {
      final key = await _service.issueKey(userId);
      _toast('Key issued: $key');
      _load();
    } catch (e) {
      _toast('Issue failed: $e', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : _accent,
    ));
  }

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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 4),
        const Text(
          'Auto-complete empty product fields with AI. Configure the global key, '
          'pick a table and row count, and issue keys to your users.',
          style: TextStyle(fontSize: 13, color: Color(0xFF61726C)),
        ),
        const SizedBox(height: 20),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 4),
            const Text('Used for any user who has not set their own key.',
                style: TextStyle(fontSize: 12, color: Color(0xFF61726C))),
            const SizedBox(height: 16),
            _field('Global LLM API key', _globalKeyCtrl, obscure: true,
                hint: 'Paste the provider API key'),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _table,
              decoration: _decoration('Table'),
              items: const [
                DropdownMenuItem(value: 'products', child: Text('Products (catalog)')),
                DropdownMenuItem(value: 'designerproducts', child: Text('Designer products')),
                DropdownMenuItem(
                    value: 'manufacturerproducts', child: Text('Manufacturer products')),
              ],
              onChanged: (v) => setState(() => _table = v ?? 'products'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Rows to process:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF61726C))),
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
                        width: 16, height: 16,
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

  Widget _resultSummary(AiFillResult r) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last run: ${r.success} filled · ${r.failed} failed · ${r.total} scanned',
                style: const TextStyle(fontWeight: FontWeight.w600, color: _ink)),
            if (r.filledIds.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Filled IDs: ${r.filledIds.join(", ")}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF61726C))),
            ],
          ],
        ),
      );

  Widget _credentialsCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('User API Keys',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 4),
            const Text('Issue an x-api-key so a user can run their own fills.',
                style: TextStyle(fontSize: 12, color: Color(0xFF61726C))),
            const SizedBox(height: 12),
            if (_credentials.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No keys issued yet.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF61726C))),
              )
            else
              ..._credentials.map(_credentialRow),
          ],
        ),
      );

  Widget _credentialRow(Map<String, dynamic> c) {
    final user = (c['users'] as Map?) ?? const {};
    final name = user['full_name'] ?? user['email'] ?? c['user_id'];
    final role = user['role'] ?? '';
    final active = c['is_active'] as bool? ?? true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name  ·  $role',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(active ? 'Key active · hidden' : 'Key disabled',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF61726C))),
              ],
            ),
          ),
          Switch(
            value: active,
            activeColor: _accent,
            onChanged: (v) async {
              await _service.setCredentialActive(c['user_id'] as String, v);
              _load();
            },
          ),
          TextButton(
            onPressed: () => _issueKey(c['user_id'] as String),
            child: const Text('Rotate'),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
