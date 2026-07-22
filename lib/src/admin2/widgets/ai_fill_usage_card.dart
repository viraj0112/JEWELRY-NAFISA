import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Per-user AI Data-Fill usage, sourced from the `ai_fill_usage_by_user` RPC
/// (admin-only). Every AI fill is logged server-side by the `run-ai-fill` Edge
/// Function, so this leaderboard covers all users — admins and B2B accounts
/// alike — and reflects rows actually written, not just attempts.
class AiFillUsageCard extends StatefulWidget {
  const AiFillUsageCard({super.key});

  @override
  State<AiFillUsageCard> createState() => _AiFillUsageCardState();
}

class _UsageRow {
  _UsageRow({
    required this.userId,
    required this.name,
    required this.role,
    required this.runs,
    required this.filled,
    required this.failed,
    required this.lastUsed,
  });

  final String userId;
  final String name;
  final String role;
  final int runs;
  final int filled;
  final int failed;
  final DateTime? lastUsed;
}

class _AiFillUsageCardState extends State<AiFillUsageCard> {
  static const _ink = Color(0xFF0A2F22);
  static const _mutedInk = Color(0xFF61726C);
  static const _surface = Colors.white;
  static const _border = Color(0xFFE3E9E6);
  static const _accent = Color(0xFF0A4F3F);
  static const _gold = Color(0xFFA8842B);

  final _supabase = Supabase.instance.client;

  int _days = 30;
  bool _loading = true;
  String? _error;
  List<_UsageRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _supabase
          .rpc('ai_fill_usage_by_user', params: {'p_days': _days});
      final rows = (res as List).map((r) {
        final name = (r['full_name'] as String?)?.trim().isNotEmpty == true
            ? r['full_name'] as String
            : (r['username'] as String?)?.trim().isNotEmpty == true
                ? r['username'] as String
                : (r['email'] as String?) ?? 'Unknown user';
        return _UsageRow(
          userId: (r['user_id'] ?? '').toString(),
          name: name,
          role: (r['role'] ?? 'member').toString(),
          runs: (r['fill_runs'] as num?)?.toInt() ?? 0,
          filled: (r['total_filled'] as num?)?.toInt() ?? 0,
          failed: (r['total_failed'] as num?)?.toInt() ?? 0,
          lastUsed: r['last_used_at'] == null
              ? null
              : DateTime.tryParse(r['last_used_at'].toString()),
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Fill Usage by User',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                    SizedBox(height: 4),
                    Text(
                      'Who is filling catalog data with AI — runs and rows written per user.',
                      style: TextStyle(fontSize: 12.5, color: _mutedInk),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 20, color: _mutedInk),
                tooltip: 'Reload',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _rangePills(),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Could not load AI fill usage: $_error',
                  style: const TextStyle(color: Colors.redAccent)),
            )
          else
            _buildList(),
        ],
      ),
    );
  }

  Widget _rangePills() {
    const options = [(7, '7 days'), (30, '30 days'), (90, '90 days')];
    return Wrap(
      spacing: 8,
      children: options.map((o) {
        final active = _days == o.$1;
        return ChoiceChip(
          label: Text(o.$2),
          selected: active,
          onSelected: (_) {
            if (_days == o.$1) return;
            setState(() => _days = o.$1);
            _load();
          },
          selectedColor: _accent,
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : _mutedInk,
          ),
          showCheckmark: false,
          side: BorderSide(color: active ? _accent : _border),
          backgroundColor: Colors.white,
        );
      }).toList(),
    );
  }

  Widget _buildList() {
    if (_rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('No AI fill activity in this period.',
              style: TextStyle(fontSize: 12.5, color: _mutedInk)),
        ),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < _rows.length; i++) _buildRow(i + 1, _rows[i]),
      ],
    );
  }

  Widget _buildRow(int rank, _UsageRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('#$rank',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _mutedInk)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: _ink)),
                const SizedBox(height: 2),
                Text(
                  '${r.role} · ${r.runs} run${r.runs == 1 ? '' : 's'}'
                  '${r.failed > 0 ? ' · ${r.failed} failed' : ''}',
                  style: const TextStyle(fontSize: 11, color: _mutedInk),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${r.filled}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _accent)),
              const Text('rows filled',
                  style: TextStyle(fontSize: 10, color: _gold)),
            ],
          ),
        ],
      ),
    );
  }
}
