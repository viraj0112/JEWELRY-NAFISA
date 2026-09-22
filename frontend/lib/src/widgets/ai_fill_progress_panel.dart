import 'package:flutter/material.dart';

import '../services/ai_fill_service.dart';

/// One line explaining how a fill of [requested] products will be split up.
class AiFillBatchHint extends StatelessWidget {
  const AiFillBatchHint({
    super.key,
    required this.requested,
    required this.settings,
  });

  final int requested;
  final AiFillBatchSettings settings;

  @override
  Widget build(BuildContext context) {
    final batches = (requested / settings.batchSize).ceil();
    final text = batches <= 1
        ? 'Runs as a single batch.'
        : 'Runs in $batches batches of up to ${settings.batchSize}, '
            'pausing ${settings.pauseSeconds}s between batches to stay '
            'within Gemini rate limits.';
    return Text(text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF61726C)));
  }
}

/// Live status of a running multi-batch fill, with a Cancel button.
class AiFillProgressPanel extends StatelessWidget {
  const AiFillProgressPanel({
    super.key,
    required this.progress,
    required this.requested,
    required this.batchSize,
    this.onCancel,
    this.cancelling = false,
    this.accent = const Color(0xFF00695C),
  });

  /// Null until the first batch finishes.
  final AiFillProgress? progress;
  final int requested;
  final int batchSize;
  final VoidCallback? onCancel;
  final bool cancelling;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final soFar = p?.soFar;
    final done = soFar == null ? 0 : soFar.total;
    final totalBatches = (requested / batchSize).ceil();
    final status = p == null
        ? 'Starting batch 1 of $totalBatches…'
        : p.waitingSeconds > 0
            ? 'Batch ${p.batch} of $totalBatches done - next batch in ${p.waitingSeconds}s'
            : 'Batch ${p.batch} of $totalBatches done';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(status,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF0A2F22))),
            ),
            if (onCancel != null)
              TextButton(
                onPressed: cancelling ? null : onCancel,
                child: Text(cancelling ? 'Stopping…' : 'Cancel'),
              ),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: requested == 0 ? null : (done / requested).clamp(0.0, 1.0),
            color: accent,
            backgroundColor: accent.withValues(alpha: 0.15),
          ),
          if (soFar != null) ...[
            const SizedBox(height: 8),
            Text(
              '${soFar.success} filled · ${soFar.failed} failed · '
              '$done of $requested scanned'
              '${soFar.costLabel == null ? '' : ' · ${soFar.costLabel}'}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF61726C)),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Cost: $0.0123 · 52,310 tokens (gemini-3.6-flash)" for a finished run.
class AiFillCostLine extends StatelessWidget {
  const AiFillCostLine({super.key, required this.result});

  final AiFillResult result;

  @override
  Widget build(BuildContext context) {
    final cost = result.costLabel;
    if (cost == null) return const SizedBox.shrink();
    final tokens = result.usage.totalTokens;
    return Text(
      'Cost: $cost · ${_thousands(tokens)} tokens'
      '${result.model == null ? '' : ' (${result.model})'}',
      style: TextStyle(
        fontSize: 12,
        color: result.costUsd == null
            ? Colors.orange.shade800
            : const Color(0xFF61726C),
      ),
    );
  }

  static String _thousands(int n) => n.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}
