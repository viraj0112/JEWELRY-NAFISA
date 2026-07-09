import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/models/filter_criteria.dart';
import 'package:jewelry_nafisa/src/services/filter_service.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FilterPanel extends StatefulWidget {
  final FilterCriteria initialFilters;
  final Function(FilterCriteria) onApplyFilters;
  final Function() onClearFilters;
  final Function() onClose;

  const FilterPanel({
    super.key,
    required this.initialFilters,
    required this.onApplyFilters,
    required this.onClearFilters,
    required this.onClose,
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  final FilterService _filterService = FilterService();
  final JewelryService _jewelryService =
      JewelryService(Supabase.instance.client);

  // Filter state
  String? _selectedCategory;
  String? _selectedMetalType;
  double _selectedPriceRange = 10000.0;
  List<String> _categoryOptions = [];
  List<String> _metalTypeOptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load categories
      final categories = await _filterService.getDistinctValues('Category');
      setState(() {
        _categoryOptions = ['All', ...categories];
        _selectedCategory = widget.initialFilters.category;
        _isLoading = false;
      });

      // Load metal types
      final metalTypes = await _filterService.getDistinctValues('Metal Type');
      setState(() {
        _metalTypeOptions = ['All', ...metalTypes];
        _selectedMetalType = widget.initialFilters.metalType;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading filter options: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      transform: Matrix4.translationValues(0, 0, 0),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),

            // Category Section
            ExpansionTile(
              title: Text('CATEGORY'),
              leading: const Icon(Icons.category),
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _categoryOptions.length,
                  itemBuilder: (context, index) {
                    final option = _categoryOptions[index];
                    return CheckboxListTile(
                      title: Text(option),
                      value: _selectedCategory == option ?? false,
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value == true ? option : null;
                        });
                      },
                    );
                  },
                ),
              ],
            ),

            // Metal Type Section
            ExpansionTile(
              title: Text('METAL'),
              leading: const Icon(Icons.precision_manufacturing),
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _metalTypeOptions.length,
                  itemBuilder: (context, index) {
                    final option = _metalTypeOptions[index];
                    return RadioListTile(
                      title: Text(option),
                      groupValue: _selectedMetalType,
                      value: option,
                      onChanged: (value) {
                        setState(() {
                          _selectedMetalType = value;
                        });
                      },
                    );
                  },
                ),
              ],
            ),

            // Price Range Section
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PRICE RANGE'),
                  const SizedBox(height: 8),
                  Slider(
                    value: _selectedPriceRange,
                    min: 0,
                    max: 100000,
                    divisions: 100,
                    label: '\$${_selectedPriceRange.toStringAsFixed(0)}',
                    onChanged: (value) {
                      setState(() {
                        _selectedPriceRange = value;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\$0'),
                      Text('\$${_selectedPriceRange.toStringAsFixed(0)}'),
                      Text('\$100,000+'),
                    ],
                  ),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        // Clear filters
                        setState(() {
                          _selectedCategory = null;
                          _selectedMetalType = 'All';
                          _selectedPriceRange = 10000.0;
                        });
                        widget.onClearFilters();
                      },
                      child: const Text('CLEAR ALL'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        // Apply filters
                        final newFilters = FilterCriteria(
                          category: _selectedCategory,
                          metalType: _selectedMetalType,
                          // Add price range handling if needed
                        );
                        widget.onApplyFilters(newFilters);
                        widget.onClose();
                      },
                      child: const Text('APPLY SELECTION'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
