import 'dart:async';

import 'package:flutter/material.dart';

import '../services/ai_fill_service.dart';

/// Dropdown of the Gemini models an LLM key can actually use, fetched live
/// from Google AI Studio (through the `ai-credentials` edge function, so the
/// stored key never reaches the browser).
///
/// The selected model id lives in [controller], so screens keep their existing
/// save logic. When [keyController] is given, the list reloads for a key the
/// user is typing, before it is saved.
class LlmModelPicker extends StatefulWidget {
  const LlmModelPicker({
    super.key,
    required this.controller,
    required this.loadModels,
    this.keyController,
    this.label = 'Model',
    this.defaultOptionLabel,
    this.decoration = const InputDecoration(),
  });

  /// Holds the selected model id; empty means "use the default" when
  /// [defaultOptionLabel] is set.
  final TextEditingController controller;

  /// Lists models for [typedKey] when non-null, else for the saved key.
  final Future<LlmModelList> Function(String? typedKey) loadModels;

  /// Field holding a newly typed (unsaved) API key.
  final TextEditingController? keyController;

  final String label;

  /// When set, adds a blank "use the default model" option with this label.
  final String? defaultOptionLabel;

  /// Base decoration; label, helper, error and suffix are filled in here.
  final InputDecoration decoration;

  @override
  State<LlmModelPicker> createState() => _LlmModelPickerState();
}

class _LlmModelPickerState extends State<LlmModelPicker> {
  // Google API keys are 39 characters; don't query for a half-pasted one.
  static const _minKeyLength = 20;

  List<LlmModelOption> _models = const [];
  String _keySource = '';
  bool _loading = false;
  String? _error;
  String _loadedForKey = '';
  Timer? _debounce;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSelectionChanged);
    widget.keyController?.addListener(_onKeyChanged);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onSelectionChanged);
    widget.keyController?.removeListener(_onKeyChanged);
    super.dispose();
  }

  String get _typedKey => widget.keyController?.text.trim() ?? '';

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  void _onKeyChanged() {
    final key = _typedKey;
    if (key == _loadedForKey) return;
    if (key.isNotEmpty && key.length < _minKeyLength) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _load);
  }

  Future<void> _load() async {
    final key = _typedKey;
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.loadModels(key.isEmpty ? null : key);
      // A newer request (the key changed again) supersedes this one.
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _models = result.models;
        _keySource = result.keySource;
        _loadedForKey = key;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _models = const [];
        _loadedForKey = key;
        _loading = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  String get _sourceLabel => switch (_keySource) {
        'provided' => 'the key you entered',
        'own' => 'your saved key',
        'global' => 'the platform key',
        _ => 'this key',
      };

  @override
  Widget build(BuildContext context) {
    final selected = widget.controller.text.trim();
    final allowDefault = widget.defaultOptionLabel != null;
    final known = _models.any((m) => m.id == selected);
    // A saved model the key can't use (e.g. a typo) stays visible and flagged,
    // rather than silently vanishing from the field.
    final unavailable = selected.isNotEmpty && !known && !_loading && _error == null;

    final items = <DropdownMenuItem<String>>[
      if (allowDefault)
        DropdownMenuItem(value: '', child: Text(widget.defaultOptionLabel!)),
      if (selected.isNotEmpty && !known)
        DropdownMenuItem(
          value: selected,
          child: Text(
            unavailable ? '$selected (not available)' : selected,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      for (final m in _models)
        DropdownMenuItem(
          value: m.id,
          child: Text(
            m.displayName == m.id ? m.id : '${m.displayName}  ·  ${m.id}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];

    final String? value = selected.isNotEmpty || allowDefault ? selected : null;

    return DropdownButtonFormField<String>(
      // Rebuild when the options or the externally-set value change, since
      // initialValue is only read on creation.
      key: ValueKey('$value|${_models.length}|$_loadedForKey'),
      initialValue: value,
      isExpanded: true,
      items: items,
      onChanged: (v) => widget.controller.text = v ?? '',
      decoration: widget.decoration.copyWith(
        labelText: widget.label,
        helperText: _loading
            ? 'Loading models from Google AI Studio…'
            : _error == null
                ? '${_models.length} models available for $_sourceLabel'
                : null,
        errorText: _error ??
            (unavailable
                ? '"$selected" is not available for $_sourceLabel. Pick another model.'
                : null),
        errorMaxLines: 3,
        suffixIcon: _loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: 'Refresh models',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _load,
              ),
      ),
    );
  }
}
