import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

var url = Uri.parse("https://countriesnow.space/api/v0.1/countries/states");

typedef locMenu = DropdownMenuEntry<String>;


class LocationDropdown extends StatefulWidget {
  final String initialCountry;
  final void Function(String?)? onChanged;
  const LocationDropdown({super.key, this.initialCountry = "India", this.onChanged});

  @override
  State<LocationDropdown> createState() => _LocationDropdownState();
}

class _LocationDropdownState extends State<LocationDropdown> {
  List<String> dropDownValues = [];
  String? selectedState;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchStates(widget.initialCountry);
  }

  Future<void> fetchStates(String country) async {
    final newUrl = Uri.parse("https://countriesnow.space/api/v0.1/countries/states/q?country=$country");
    final response = await http.get(newUrl);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data["data"] != null && data["data"]["states"] != null) {
        setState(() {
          dropDownValues = List<String>.from(data["data"]["states"].map((s) => s["name"]));
          selectedState = dropDownValues.isNotEmpty ? dropDownValues.first : null;
          loading = false;
        });
      } else {
        setState(() { loading = false; });
      }
    } else {
      setState(() { loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(width: 40, height: 40, child: CircularProgressIndicator());
    }
    if (dropDownValues.isEmpty) {
      return const Text("No states found");
    }
    return DropdownMenu<String>(
      initialSelection: selectedState,
      width: 180,
      onSelected: (String? value) {
        setState(() {
          selectedState = value;
        });
        if (widget.onChanged != null) {
          widget.onChanged!(value);
        }
      },
      dropdownMenuEntries: dropDownValues.map((state) => DropdownMenuEntry<String>(value: state, label: state)).toList(),
    );
  }
}