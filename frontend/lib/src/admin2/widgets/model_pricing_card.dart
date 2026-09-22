import 'package:flutter/material.dart';

import '../../services/ai_fill_service.dart';

/// Admin editor for the per-model token prices used to compute what each AI
/// fill cost. Prices are USD per 1 million tokens, as Google lists them.
///
/// Costs are stored per run at the time of the run, so editing a price only
/// affects fills from then on.
class ModelPricingCard extends StatefulWidget {
  const ModelPricingCard({super.key, required this.service});

  final AiFillService service;

  @override
  State<ModelPricingCard> createState() => _ModelPricingCardState();
}

class _ModelPricingCardState extends State<ModelPricingCard> {
  static const _ink = Color(0xFF0A2F22);
  static const _muted = Color(0xFF61726C);
  static const _border = Color(0xFFE3E9E6);
  static const _accent = Color(0xFF0A4F3F);

  static final _modelPattern = RegExp(r'^[A-Za-z0-9._-]{1,100}$');

  bool _loading = true;
  String? _error;
  List<ModelPrice> _prices = [];

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
      final prices = await widget.service.listModelPrices();
      if (!mounted) return;
      setState(() {
        _prices = prices;
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

  Future<void> _edit([ModelPrice? existing]) async {
    final saved = await showDialog<ModelPrice>(
      context: context,
      builder: (_) => _PriceDialog(existing: existing, modelPattern: _modelPattern),
    );
    if (saved == null) return;
    try {
      await widget.service.saveModelPrice(saved);
      _toast('Price saved for ${saved.model}');
      _load();
    } catch (e) {
      _toast('Save failed: $e', error: true);
    }
  }

  Future<void> _delete(ModelPrice price) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove price'),
        content: Text('Fills with ${price.model} will show "price not set" '
            'until a price is added again. Past costs are kept.'),
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
      await widget.service.deleteModelPrice(price.model);
      _load();
    } catch (e) {
      _toast('Remove failed: $e', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : _accent,
    ));
  }

  static String _usd(double v) =>
      '\$${v.toStringAsFixed(v < 1 ? 4 : 2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.payments_outlined, size: 18, color: _accent),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Model Pricing',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _accent),
              onPressed: () => _edit(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add price'),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            'USD per 1 million tokens, from Google\'s Gemini API pricing page. '
            'Used to calculate the cost of every AI fill. Thinking tokens are '
            'charged at the output price.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.redAccent))
          else if (_prices.isEmpty)
            const Text(
              'No prices yet - fills will record tokens but show "price not set". '
              'Add a price for the model(s) you use.',
              style: TextStyle(fontSize: 12.5, color: _muted),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.w700, color: _ink, fontSize: 12.5),
                columns: const [
                  DataColumn(label: Text('Model')),
                  DataColumn(label: Text('Input'), numeric: true),
                  DataColumn(label: Text('Cached input'), numeric: true),
                  DataColumn(label: Text('Output'), numeric: true),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final p in _prices)
                    DataRow(cells: [
                      DataCell(Text(p.model)),
                      DataCell(Text(_usd(p.inputPerMillion))),
                      DataCell(Text(p.cachedInputPerMillion == null
                          ? '= input'
                          : _usd(p.cachedInputPerMillion!))),
                      DataCell(Text(_usd(p.outputPerMillion))),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _edit(p),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: Colors.red.shade700),
                          onPressed: () => _delete(p),
                        ),
                      ])),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PriceDialog extends StatefulWidget {
  const _PriceDialog({this.existing, required this.modelPattern});

  final ModelPrice? existing;
  final RegExp modelPattern;

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _model = TextEditingController(text: widget.existing?.model ?? '');
  late final _input = TextEditingController(
      text: widget.existing?.inputPerMillion.toString() ?? '');
  late final _cached = TextEditingController(
      text: widget.existing?.cachedInputPerMillion?.toString() ?? '');
  late final _output = TextEditingController(
      text: widget.existing?.outputPerMillion.toString() ?? '');

  @override
  void dispose() {
    _model.dispose();
    _input.dispose();
    _cached.dispose();
    _output.dispose();
    super.dispose();
  }

  String? _price(String? v, {bool optional = false}) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return optional ? null : 'Required';
    final n = double.tryParse(text);
    if (n == null || n < 0) return 'Enter a number ≥ 0';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(ModelPrice(
      model: _model.text.trim(),
      inputPerMillion: double.parse(_input.text.trim()),
      outputPerMillion: double.parse(_output.text.trim()),
      cachedInputPerMillion: _cached.text.trim().isEmpty
          ? null
          : double.parse(_cached.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    InputDecoration deco(String label, {String? hint, String? prefix}) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefix,
          isDense: true,
          border: const OutlineInputBorder(),
        );
    return AlertDialog(
      title: Text(editing ? 'Edit price' : 'Add model price'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _model,
              enabled: !editing,
              decoration: deco('Model', hint: 'e.g. gemini-3.6-flash'),
              validator: (v) => widget.modelPattern.hasMatch((v ?? '').trim())
                  ? null
                  : 'Use the exact model id (letters, digits, . - _)',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _input,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: deco('Input, per 1M tokens', prefix: '\$ '),
              validator: _price,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cached,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: deco('Cached input, per 1M tokens (optional)',
                  prefix: '\$ ', hint: 'blank = same as input'),
              validator: (v) => _price(v, optional: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _output,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: deco('Output (incl. thinking), per 1M tokens',
                  prefix: '\$ '),
              validator: _price,
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
