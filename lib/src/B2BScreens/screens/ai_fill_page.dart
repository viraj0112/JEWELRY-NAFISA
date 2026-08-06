import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/ai_fill_service.dart';

/// Self-service "AI Fill My Products" screen for designer/manufacturer users.
/// The backend derives which table (designerproducts / manufacturerproducts)
/// from the caller's role, and scopes the fill to their own rows.
class AiFillPage extends StatefulWidget {
  const AiFillPage({super.key});

  static Future<AiFillResult?> show(BuildContext context) {
    return showModalBottomSheet<AiFillResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.9,
        child: AiFillPage(),
      ),
    );
  }

  @override
  State<AiFillPage> createState() => _AiFillPageState();
}

class _AiFillPageState extends State<AiFillPage> {
  static const _ink = Color(0xFF0A2F22);
  static const _accent = Color(0xFF00695C);
  static const _border = Color(0xFFE3E9E6);

  late final AiFillService _service = AiFillService(Supabase.instance.client);

  final _llmKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();

  int _rowCount = 10;
  bool _loading = true;
  bool _running = false;
  String? _error;
  ApiCredential? _credential;
  AiFillResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _llmKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await _service.getMyCredential();
      if (!mounted) return;
      setState(() {
        _credential = cred;
        // Deliberately NOT prefilled with the stored key: the server only ever
        // returns a hint (last 4 chars), and the key itself is encrypted at
        // rest. An empty field here means "keep what's saved".
        _llmKeyCtrl.clear();
        _modelCtrl.text = cred?.llmModel ?? '';
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

  Future<void> _saveKey() async {
    final key = _llmKeyCtrl.text.trim();
    try {
      if (key.isEmpty) {
        // Blank means "leave my key as it is" - only the model changes.
        await _service.updateMyLlmModel(_modelCtrl.text);
        _toast('Model preference saved');
      } else {
        await _service.updateMyLlmKey(
          llmApiKey: key,
          llmModel: _modelCtrl.text,
        );
        _toast('Your LLM key saved (encrypted)');
      }
      _load();
    } catch (e) {
      _toast('Save failed: $e', error: true);
    }
  }

  Future<void> _removeKey() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove your LLM key'),
        content: const Text(
          'Fills will fall back to the platform key configured by your admin.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.clearMyLlmKey();
      _toast('Your LLM key was removed');
      _load();
    } catch (e) {
      _toast('Remove failed: $e', error: true);
    }
  }

  Future<void> _run() async {
    // The key itself stays server-side (resolved by the run-ai-fill edge
    // function). We still check locally only to give a friendlier message than
    // the backend's 403 when no key has been issued yet.
    if (_credential == null) {
      _toast('No API key assigned yet. Ask your admin to issue one.', error: true);
      return;
    }
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final result = await _service.runMyFill(limit: _rowCount);
      if (!mounted) return;
      setState(() => _lastResult = result);
      _toast('Filled ${result.success}/${result.total} of your products');
      // Pop the sheet and return the result so the caller can update badges.
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
      _toast('Run failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _running = false);
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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(children: const [
                    Icon(Icons.auto_awesome, color: _accent),
                    SizedBox(width: 8),
                    Text('AI Fill My Products',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
                  ]),
                  const SizedBox(height: 6),
                  const Text(
                    'Auto-complete the empty details of YOUR products with AI. '
                    'Only your own products are processed.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF61726C)),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                  _keyStatusBanner(),
                  const SizedBox(height: 20),
                  const Text('Your own LLM key (optional)',
                      style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 4),
                  const Text(
                    'Leave blank to use the platform key set by admin. '
                    'Provide your own to use your own quota.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF61726C)),
                  ),
                  const SizedBox(height: 10),
                  _storedKeyHint(),
                  const SizedBox(height: 10),
                  _field(
                    _credential?.llmKeyHint == null
                        ? 'LLM API key'
                        : 'Replace LLM API key',
                    _llmKeyCtrl,
                    obscure: true,
                    hint: _credential?.llmKeyHint == null
                        ? 'Paste your provider key'
                        : 'Leave blank to keep your saved key',
                  ),
                  const SizedBox(height: 10),
                  _field('Model name (optional)', _modelCtrl,
                      hint: 'e.g. gemini-2.5-pro'),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_credential?.llmKeyHint != null)
                        TextButton.icon(
                          onPressed: _removeKey,
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade700),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remove key'),
                        ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _saveKey,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Row(children: [
                    const Text('Products to process:',
                        style: TextStyle(fontSize: 13, color: Color(0xFF61726C))),
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
                      label: Text(_running ? 'Running…' : 'Fill my products'),
                    ),
                  ),
                  if (_lastResult != null) ...[
                    const SizedBox(height: 16),
                    _resultSummary(_lastResult!),
                  ],
                ],
              ),
            ),
    );
  }

  /// Shows only that a key is stored and its last 4 characters. The value
  /// itself is AES-encrypted server-side and is never sent to this screen.
  Widget _storedKeyHint() {
    final hint = _credential?.llmKeyHint;
    return Row(children: [
      Icon(hint == null ? Icons.info_outline : Icons.lock_outline,
          size: 16, color: hint == null ? const Color(0xFF61726C) : _accent),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          hint == null
              ? 'No personal key saved — the platform key will be used.'
              : 'Your key is saved and encrypted: $hint',
          style: const TextStyle(fontSize: 12, color: Color(0xFF61726C)),
        ),
      ),
    ]);
  }

  Widget _keyStatusBanner() {
    final cred = _credential;
    final hasKey = cred?.hasKey ?? false;
    final active = cred?.isActive ?? false;
    final expired = cred?.isExpired ?? false;
    final ok = hasKey && active && !expired;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFEAF6F0) : const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(ok ? Icons.verified_user_outlined : Icons.gpp_maybe_outlined,
            color: ok ? _accent : Colors.red.shade700, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            ok
                ? 'Master key ${cred!.statusLabel.toLowerCase()}. You can run AI fills.'
                : expired
                    ? 'Your master key expired. Ask your admin to generate a new one.'
                    : hasKey
                        ? 'Your master key is disabled. Contact your admin.'
                        : 'No master key assigned yet. Ask your admin to generate one.',
            style: TextStyle(
                fontSize: 12.5,
                color: ok ? _ink : Colors.red.shade800),
          ),
        ),
      ]),
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
                style: const TextStyle(fontWeight: FontWeight.w600, color: _ink)),
            if (r.filledIds.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Filled product IDs: ${r.filledIds.join(", ")}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF61726C))),
            ],
          ],
        ),
      );

  Widget _field(String label, TextEditingController ctrl,
          {bool obscure = false, String? hint}) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border),
          ),
        ),
      );
}
