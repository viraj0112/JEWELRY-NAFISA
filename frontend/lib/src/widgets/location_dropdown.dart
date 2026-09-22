import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

/// State picker for a country, with type-to-search.
///
/// Starts empty ("All states") unless [initialValue] is given - it used to
/// pre-select the first state, which looked like an applied filter. Styling
/// comes from the surrounding theme's input decoration.
class LocationDropdown extends StatefulWidget {
  final String initialCountry;

  /// The state to show as selected (e.g. the currently applied filter).
  final String? initialValue;
  final void Function(String?)? onChanged;

  /// Fixed width; null stretches to the available width.
  final double? width;

  const LocationDropdown({
    super.key,
    this.initialCountry = "India",
    this.initialValue,
    this.onChanged,
    this.width = 200,
  });

  @override
  State<LocationDropdown> createState() => _LocationDropdownState();
}

class _LocationDropdownState extends State<LocationDropdown> {
  // States per country, shared by every instance so reopening the filter
  // sheet doesn't refetch the list.
  static final Map<String, List<String>> _cache = {};

  List<String> _states = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final country = widget.initialCountry;
    final cached = _cache[country];
    if (cached != null) {
      setState(() {
        _states = cached;
        _loading = false;
      });
      return;
    }
    try {
      final response = await http.get(Uri.parse(
          "https://countriesnow.space/api/v0.1/countries/states/q?country=${Uri.encodeQueryComponent(country)}"));
      final data = response.statusCode == 200 ? json.decode(response.body) : null;
      final states = (data?["data"]?["states"] as List?)
              ?.map((s) => '${s["name"]}')
              .toList() ??
          <String>[];
      if (states.isNotEmpty) _cache[country] = states;
      if (!mounted) return;
      setState(() {
        _states = states;
        _loading = false;
        _failed = states.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (_loading || _failed) {
      return SizedBox(
        width: widget.width,
        child: InputDecorator(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.location_on_outlined, size: 20),
          ),
          child: Row(children: [
            if (_loading) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.6, color: muted),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                _loading ? 'Loading states…' : 'Locations unavailable',
                style: TextStyle(color: muted, fontSize: 14),
              ),
            ),
            if (_failed)
              InkWell(
                onTap: () {
                  setState(() {
                    _loading = true;
                    _failed = false;
                  });
                  _load();
                },
                child: Icon(Icons.refresh_rounded, size: 18, color: muted),
              ),
          ]),
        ),
      );
    }

    final selected =
        _states.contains(widget.initialValue) ? widget.initialValue : null;
    return DropdownMenu<String>(
      initialSelection: selected,
      width: widget.width,
      expandedInsets: widget.width == null ? EdgeInsets.zero : null,
      hintText: 'All states',
      leadingIcon: const Icon(Icons.location_on_outlined, size: 20),
      enableFilter: true,
      requestFocusOnTap: true,
      menuHeight: 320,
      onSelected: widget.onChanged,
      dropdownMenuEntries: _states
          .map((state) => DropdownMenuEntry<String>(value: state, label: state))
          .toList(),
    );
  }
}
