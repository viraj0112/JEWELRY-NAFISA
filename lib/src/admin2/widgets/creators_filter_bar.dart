import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/creators_provider.dart';

class CreatorsFilterBar extends StatelessWidget {
  final void Function(String)? onSearchChanged;
  final void Function(String?)? onStatusChanged;
  final void Function(String)? onCategoryChanged;

  const CreatorsFilterBar({
    super.key,
    this.onSearchChanged,
    this.onStatusChanged,
    this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreatorsProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  onChanged: (v) {
                    provider.setSearchQuery(v);
                    if (onSearchChanged != null) onSearchChanged!(v);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search creators...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    isDense: true,
                  ),
                ),
              ),

              // Status dropdown
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  value: provider.statusFilter,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Status')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (v) {
                    provider.setStatusFilter(v);
                    if (onStatusChanged != null) onStatusChanged!(v);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),

              // Category dropdown (fetched from designerproducts)
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: provider.categoryFilter,
                  items: provider.categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    provider.setCategoryFilter(v);
                    if (onCategoryChanged != null) onCategoryChanged!(v);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),

              OutlinedButton.icon(
                onPressed: () => provider.resetFilters(),
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}