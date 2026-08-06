import 'dart:async';
import 'package:flutter/material.dart';
import "package:jewelry_nafisa/src/widgets/date_range_filter.dart";
import 'package:jewelry_nafisa/src/widgets/location_dropdown.dart';
import 'package:jewelry_nafisa/src/B2BScreens/screens/home.dart';
import 'package:jewelry_nafisa/src/B2BScreens/screens/insights.dart';
import 'package:jewelry_nafisa/src/B2BScreens/screens/ai_fill_page.dart';
import 'package:jewelry_nafisa/src/B2BScreens/screens/profile.dart';
import 'package:jewelry_nafisa/src/B2BScreens/screens/notifications.dart';
import 'package:jewelry_nafisa/src/B2BScreens/screens/upload.dart';
import 'package:jewelry_nafisa/src/models/filter_criteria.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class B2BShell extends StatefulWidget {
  const B2BShell({super.key});

  @override
  State<B2BShell> createState() => _B2BShellState();
}

class _B2BShellState extends State<B2BShell> {
  String? selectedLocation;
  int _currentPageSelected = 0;

  // Filter State
  FilterCriteria _filters = FilterCriteria();

  // AI-filled product IDs (session-scoped, cleared on reload)
  Set<int> _aiFilledIds = {};

  // Temporary state for the bottom sheet (to apply only on button press)
  FilterCriteria _tempFilters = FilterCriteria();

  // Dynamic filter options (from the signed-in user's own catalog only)
  List<String> _productTypeOptions = [];
  List<String> _categoryOptions = [];
  List<String> _metalTypeOptions = [];
  bool _isLoadingFilters = false;

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  late JewelryService _jewelryService;

  @override
  void initState() {
    super.initState();
    _jewelryService = JewelryService(Supabase.instance.client);
    _fetchFilterOptions();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Which catalog table the current user owns. Manufacturers filter their
  /// manufacturerproducts; everyone else (designers) their designerproducts.
  String get _userTable {
    final profile =
        Provider.of<UserProfileProvider>(context, listen: false).userProfile;
    return profile?.manufacturerProfile != null
        ? 'manufacturerproducts'
        : 'designerproducts';
  }

  Future<void> _fetchFilterOptions() async {
    setState(() => _isLoadingFilters = true);

    try {
      // Scoped to the user's own table + user_id, so the chips only ever show
      // values that actually exist in this seller's catalog.
      final options = await _jewelryService.getB2BFilterOptions(_userTable);

      setState(() {
        _productTypeOptions = options['productTypes'] ?? [];
        _categoryOptions = options['categories'] ?? [];
        _metalTypeOptions = options['metalTypes'] ?? [];
        _isLoadingFilters = false;
      });
    } catch (e) {
      debugPrint('Error fetching filter options: $e');
      setState(() => _isLoadingFilters = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            tooltip: 'AI Fill My Products',
            icon: const Icon(Icons.auto_awesome, color: Colors.teal),
            onPressed: () async {
              final result = await AiFillPage.show(context);
              if (result != null && result.filledIds.isNotEmpty && mounted) {
                setState(() {
                  _aiFilledIds = {..._aiFilledIds, ...result.filledIds};
                });
              }
            },
          ),
        ],
        title: isMobile
            ? const Text("Dagina.Design", style: TextStyle(color: Colors.teal))
            : _buildDesktopLayout(),
        bottom: isMobile
            ? PreferredSize(
                preferredSize: Size.fromHeight(50),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildMobileLayout(),
                ),
              )
            : null,
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          if (index == 1) {
            UploadPage.show(context);
            return;
          }
          setState(() {
            _currentPageSelected = index;
          });
        },
        indicatorColor: Colors.teal,
        selectedIndex: _currentPageSelected,
        destinations: const <Widget>[
          NavigationDestination(
              selectedIcon: Icon(Icons.home),
              icon: Icon(Icons.home),
              label: "Home"),
          NavigationDestination(icon: Icon(Icons.upload), label: "Upload"),
          NavigationDestination(icon: Icon(Icons.insights), label: "Insights"),
          NavigationDestination(
              icon: Badge(child: Icon(Icons.notifications_sharp)),
              label: "Notifications"),
          NavigationDestination(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
      body: <Widget>[
        // _filters and _aiFilledIds must be passed down.
        HomePage(filters: _filters, aiFilledIds: _aiFilledIds),
        const SizedBox.shrink(),
        InsightsPage(),
        NotificationsPage(),
        ProfilePage(),
      ][_currentPageSelected],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        const Text("Dagina.Design", style: TextStyle(color: Colors.teal)),

        const SizedBox(width: 30),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            alignment: Alignment.centerLeft,
            child: _buildSearchBar(),
          ),
        ),

        const SizedBox(width: 20),

        // 3. The Action Items
        const Icon(Icons.location_on_outlined, size: 28, color: Colors.teal),
        const SizedBox(width: 5),
        LocationDropdown(
          initialCountry: "India",
          onChanged: (value) => setState(() => selectedLocation = value),
        ),
        const SizedBox(width: 15),
        DateRangeFilter(onDateSelected: (DateTimeRange range) {}),
        const SizedBox(width: 15),
        // Same filter sheet as mobile - previously the button only existed in
        // the mobile app bar, so desktop had no way to filter at all.
        OutlinedButton.icon(
          onPressed: _openFilterSheet,
          icon: const Icon(Icons.filter_list, color: Colors.teal, size: 20),
          label: const Text('Filters', style: TextStyle(color: Colors.teal)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.teal.withOpacity(0.3)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Row(
      children: [
        Expanded(
          child: _buildSearchBar(),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _openFilterSheet,
          icon: const Icon(Icons.filter_list, color: Colors.teal),
          style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.teal.withOpacity(0.3)))),
        ),
      ],
    );
  }

  void _openFilterSheet() {
    // Initialize temp filters with current state when opening sheet
    _tempFilters = FilterCriteria(
              location: _filters.location,
              dateRange: _filters.dateRange,
              productType: _filters.productType,
              category: _filters.category,
              metalType: _filters.metalType,
              demandLevel: _filters.demandLevel,
              category1: _filters.category1,
              category2: _filters.category2,
              category3: _filters.category3,
            );

            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) {
                // Use StatefulBuilder to update local state within the bottom sheet
                return StatefulBuilder(
                    builder: (BuildContext context, StateSetter setSheetState) {
                  return Padding(
                    padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 24,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Filters",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal)),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              )
                            ],
                          ),
                          const SizedBox(height: 20),

                          // -- Location --
                          const Text("Location",
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 20, color: Colors.teal),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: LocationDropdown(
                                    initialCountry:
                                        _tempFilters.location ?? "India",
                                    onChanged: (value) {
                                      setSheetState(
                                          () => _tempFilters.location = value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // -- Product Type --
                          if (_isLoadingFilters)
                            const CircularProgressIndicator()
                          else
                            _buildChipSection(
                                "Product Type",
                                _productTypeOptions,
                                _tempFilters.productType,
                                (val) => setSheetState(() =>
                                    _tempFilters.productType =
                                        val == _tempFilters.productType
                                            ? null
                                            : val)),
                          const SizedBox(height: 20),

                          // -- Category --
                          if (_isLoadingFilters)
                            const CircularProgressIndicator()
                          else
                            _buildChipSection(
                                "Category",
                                _categoryOptions,
                                _tempFilters.category,
                                (val) => setSheetState(() => _tempFilters
                                        .category =
                                    val == _tempFilters.category ? null : val)),

                          // Category1/2/3 sub-filters were removed: those
                          // columns are being dropped in Phase 3 and are
                          // folded into the single unified Category array.
                          const SizedBox(height: 20),

                          // -- Metal Type --
                          if (_isLoadingFilters)
                            const CircularProgressIndicator()
                          else
                            _buildChipSection(
                                "Metal Type",
                                _metalTypeOptions,
                                _tempFilters.metalType,
                                (val) => setSheetState(() =>
                                    _tempFilters.metalType =
                                        val == _tempFilters.metalType
                                            ? null
                                            : val)),
                          const SizedBox(height: 20),

                          // -- Demand Level --
                          _buildChipSection(
                              "Demand Level",
                              ["High", "Medium", "Rising"],
                              _tempFilters.demandLevel,
                              (val) => setSheetState(() =>
                                  _tempFilters.demandLevel =
                                      val == _tempFilters.demandLevel
                                          ? null
                                          : val)),
                          const SizedBox(height: 20),

                          // -- Date Range --
                          const Text("Date Range",
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: DateRangeFilter(
                                onDateSelected: (DateTimeRange range) {
                              setSheetState(
                                  () => _tempFilters.dateRange = range);
                            }),
                          ),

                          const SizedBox(height: 30),

                          // Footer
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                setState(() {
                                  _filters = _tempFilters;
                                });
                                Navigator.pop(context);
                              },
                              child: const Text("Apply Filters",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                });
              },
            );
  }

  // Widget _buildSearchBar() {
  //   padding: const EdgeInsets.symmetric(horizontal: 20),
  //   return TextField(
  //     maxLength: 250,
  //     decoration: InputDecoration(
  //       counterText: "",
  //       hintText: "Search designs...",
  //       prefixIcon: const Icon(Icons.search),
  //       border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0)),
  //       contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
  //       isDense: true,
  //     ),
  //   );
  // }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      maxLength: 250,
      textInputAction: TextInputAction.search,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        counterText: "",
        hintText: "Search by SKU, name, type, category…",
        prefixIcon: const Icon(Icons.search),
        suffixIcon: (_filters.searchText ?? '').isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: 'Clear search',
                onPressed: () {
                  _searchCtrl.clear();
                  _onSearchChanged('');
                },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0)),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
        isDense: true,
      ),
    );
  }

  // Debounced free-text search: pushes the term into _filters (so HomePage,
  // which receives _filters, filters its already-loaded product list by it).
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _filters = FilterCriteria(
          location: _filters.location,
          dateRange: _filters.dateRange,
          searchText: value.trim().isEmpty ? null : value.trim(),
          productType: _filters.productType,
          category: _filters.category,
          metalType: _filters.metalType,
          demandLevel: _filters.demandLevel,
        );
      });
    });
  }

  Widget _buildChipSection(String title, List<String> options,
      String? selectedValue, Function(String) onSelect,
      {bool showTitle = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle && title.isNotEmpty)
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        if (showTitle && title.isNotEmpty) const SizedBox(height: 10),
        if (options.isEmpty)
          Text(
            'No options in your catalog yet',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
            final isSelected = selectedValue == option;
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                onSelect(option);
              },
              selectedColor: Colors.teal.withOpacity(0.1),
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                color: isSelected ? Colors.teal : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: isSelected
                  ? const BorderSide(color: Colors.teal)
                  : BorderSide.none,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              showCheckmark: false,
            );
            }).toList(),
          ),
      ],
    );
  }
}

// child: Row(
//   children: [
//     Expanded(
//       child: TextField(
//         maxLength: 250,
//         autofocus: true,
//         decoration: InputDecoration(
//           hintText: "Search designs, categories ...",
//           prefixIcon: const Icon(Icons.search),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0)),
//           contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
//         ),
//       ),
//     ),
//     const SizedBox(width: 10),
//     const Icon(Icons.location_on_outlined, size: 40),
//     LocationDropdown(
//       initialCountry: "India",
//       onChanged: (value) {
//         setState(() {
//           selectedLocation = value;
//         });
//       },
//     ),
//     const SizedBox(width: 10),
//     const Icon(Icons.calendar_month),
//     DateRangeFilter(onDateSelected: (DateTimeRange range){})
//   ],
// ),
