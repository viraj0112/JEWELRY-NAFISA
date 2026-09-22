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
import 'package:jewelry_nafisa/src/B2BScreens/b2b_theme.dart';
import 'package:jewelry_nafisa/src/models/filter_criteria.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Entry point of the B2B workspace. Applies the B2B theme ABOVE the shell,
/// so the shell's own context - which opens the AI Fill, Filters and Upload
/// sheets - and every sub-screen, dialog and sheet inherit it.
class B2BShell extends StatelessWidget {
  const B2BShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: B2BTheme.build(Theme.of(context)),
      child: const _B2BShellView(),
    );
  }
}

class _B2BShellView extends StatefulWidget {
  const _B2BShellView();

  @override
  State<_B2BShellView> createState() => _B2BShellState();
}

class _B2BShellState extends State<_B2BShellView> {
  String? selectedLocation;
  int _currentPageSelected = 0;

  // Filter State
  FilterCriteria _filters = FilterCriteria();

  // AI-filled product IDs (session-scoped, cleared on reload)
  Set<int> _aiFilledIds = {};


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
      backgroundColor: B2BColors.canvas,
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 20,
        actions: [
          IconButton(
            tooltip: 'AI Fill My Products',
            style: IconButton.styleFrom(
              backgroundColor: B2BColors.goldSoft,
              foregroundColor: B2BColors.gold,
            ),
            icon: const Icon(Icons.auto_awesome, size: 20),
            onPressed: () async {
              final result = await AiFillPage.show(context);
              if (result != null && result.filledIds.isNotEmpty && mounted) {
                setState(() {
                  _aiFilledIds = {..._aiFilledIds, ...result.filledIds};
                });
              }
            },
          ),
          const SizedBox(width: 12),
        ],
        title: isMobile ? const _Wordmark() : _buildDesktopLayout(),
        bottom: isMobile
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _buildMobileLayout(),
                ),
              )
            : null,
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: B2BColors.border)),
        ),
        child: NavigationBar(
        onDestinationSelected: (int index) {
          if (index == 1) {
            UploadPage.show(context);
            return;
          }
          setState(() {
            _currentPageSelected = index;
          });
        },
        selectedIndex: _currentPageSelected,
        destinations: const <Widget>[
          NavigationDestination(
              selectedIcon: Icon(Icons.home_rounded),
              icon: Icon(Icons.home_outlined),
              label: "Home"),
          NavigationDestination(
              icon: Icon(Icons.file_upload_outlined), label: "Upload"),
          NavigationDestination(
              selectedIcon: Icon(Icons.insights_rounded),
              icon: Icon(Icons.insights_outlined),
              label: "Insights"),
          NavigationDestination(
              selectedIcon: Badge(child: Icon(Icons.notifications_rounded)),
              icon: Badge(child: Icon(Icons.notifications_none_rounded)),
              label: "Notifications"),
          NavigationDestination(
              selectedIcon: Icon(Icons.person_rounded),
              icon: Icon(Icons.person_outline_rounded),
              label: "Profile"),
        ],
        ),
      ),
      // Cross-fade between tabs instead of a hard cut.
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey(_currentPageSelected),
          child: <Widget>[
            // _filters and _aiFilledIds must be passed down.
            HomePage(filters: _filters, aiFilledIds: _aiFilledIds),
            const SizedBox.shrink(),
            InsightsPage(dateRange: _filters.dateRange),
            const NotificationsPage(),
            const ProfilePage(),
          ][_currentPageSelected],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        const _Wordmark(),

        const SizedBox(width: 32),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            alignment: Alignment.centerLeft,
            child: _buildSearchBar(),
          ),
        ),

        const SizedBox(width: 20),

        // 3. The Action Items
        const Icon(Icons.location_on_outlined, size: 22, color: B2BColors.gold),
        const SizedBox(width: 6),
        LocationDropdown(
          initialCountry: "India",
          initialValue: _filters.location,
          onChanged: (value) => setState(() {
            selectedLocation = value;
            _filters = _filters.copyWith(location: value);
          }),
        ),
        const SizedBox(width: 12),
        DateRangeFilter(
          selectedRange: _filters.dateRange,
          onDateSelected: (DateTimeRange range) =>
              setState(() => _filters = _filters.copyWith(dateRange: range)),
          onCleared: () => setState(
              () => _filters = _filters.copyWith(clearDateRange: true)),
        ),
        const SizedBox(width: 12),
        // Same filter sheet as mobile - previously the button only existed in
        // the mobile app bar, so desktop had no way to filter at all.
        OutlinedButton.icon(
          onPressed: _openFilterSheet,
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('Filters'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          tooltip: 'Filters',
          icon: const Icon(Icons.tune_rounded, color: B2BColors.primary),
          style: IconButton.styleFrom(
              backgroundColor: B2BColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(B2BRadius.md),
                  side: const BorderSide(color: B2BColors.border))),
        ),
      ],
    );
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<FilterCriteria>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) => _FilterSheet(
        initial: _filters,
        productTypes: _productTypeOptions,
        categories: _categoryOptions,
        metalTypes: _metalTypeOptions,
        loadingOptions: _isLoadingFilters,
      ),
    );
    if (result != null && mounted) setState(() => _filters = result);
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
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
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
        // Soft pill: filled, borderless until focused.
        filled: true,
        fillColor: B2BColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: B2BColors.primaryTint, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
        _filters = value.trim().isEmpty
            ? _filters.copyWith(clearSearchText: true)
            : _filters.copyWith(searchText: value.trim());
      });
    });
  }
}

/// "Dagina.Design" in the serif face with a gold full stop.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'Dagina', style: B2BText.serif(size: 22, color: B2BColors.primary)),
        TextSpan(text: '.', style: B2BText.serif(size: 22, color: B2BColors.gold)),
        TextSpan(
            text: 'Design',
            style: B2BText.serif(
                size: 22, weight: FontWeight.w400, color: B2BColors.primary)),
      ]),
    );
  }
}

/// The Filters bottom sheet: a pinned header and footer around scrolling
/// sections. Works on a copy of the filters and returns it on "Show results"
/// (null when dismissed), so nothing changes until the user applies.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.productTypes,
    required this.categories,
    required this.metalTypes,
    required this.loadingOptions,
  });

  final FilterCriteria initial;
  final List<String> productTypes;
  final List<String> categories;
  final List<String> metalTypes;
  final bool loadingOptions;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late FilterCriteria _f = widget.initial.copyWith();

  static const _demandLevels = ['High', 'Medium', 'Rising'];

  int get _activeCount => [
        _f.location,
        _f.productType,
        _f.category,
        _f.metalType,
        _f.demandLevel,
        _f.dateRange,
      ].where((v) => v != null).length;

  // A tap on the selected chip clears it (single choice per section).
  String? _toggle(String? current, String value) =>
      current == value ? null : value;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header (pinned) ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 12, 14),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: B2BColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('REFINE YOUR CATALOGUE', style: B2BText.eyebrow()),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text('Filters', style: B2BText.serif(size: 26)),
                            const SizedBox(width: 10),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _activeCount == 0
                                  ? const SizedBox.shrink()
                                  : Container(
                                      key: ValueKey(_activeCount),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: B2BColors.primary,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text('$_activeCount active',
                                          style: B2BText.sans(
                                              size: 11.5,
                                              weight: FontWeight.w600,
                                              color: Colors.white)),
                                    ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Sections (scroll) ──────────────────────────────────────────
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              children: [
                _FilterSection(
                  title: 'Location',
                  value: _f.location,
                  child: LocationDropdown(
                    initialCountry: 'India',
                    initialValue: _f.location,
                    width: null,
                    onChanged: (v) => setState(() => _f.location = v),
                  ),
                ),
                _FilterSection(
                  title: 'Product type',
                  value: _f.productType,
                  child: _ChoiceChips(
                    options: widget.productTypes,
                    selected: _f.productType,
                    loading: widget.loadingOptions,
                    onSelected: (v) => setState(
                        () => _f.productType = _toggle(_f.productType, v)),
                  ),
                ),
                _FilterSection(
                  title: 'Category',
                  value: _f.category,
                  child: _ChoiceChips(
                    options: widget.categories,
                    selected: _f.category,
                    loading: widget.loadingOptions,
                    searchable: true,
                    onSelected: (v) =>
                        setState(() => _f.category = _toggle(_f.category, v)),
                  ),
                ),
                _FilterSection(
                  title: 'Metal type',
                  value: _f.metalType,
                  child: _ChoiceChips(
                    options: widget.metalTypes,
                    selected: _f.metalType,
                    loading: widget.loadingOptions,
                    onSelected: (v) =>
                        setState(() => _f.metalType = _toggle(_f.metalType, v)),
                  ),
                ),
                _FilterSection(
                  title: 'Demand level',
                  value: _f.demandLevel,
                  child: _ChoiceChips(
                    options: _demandLevels,
                    selected: _f.demandLevel,
                    onSelected: (v) => setState(
                        () => _f.demandLevel = _toggle(_f.demandLevel, v)),
                  ),
                ),
                _FilterSection(
                  title: 'Date uploaded',
                  value: _f.dateRange == null ? null : 'Custom range',
                  last: true,
                  child: SizedBox(
                    width: double.infinity,
                    child: DateRangeFilter(
                      selectedRange: _f.dateRange,
                      onDateSelected: (range) =>
                          setState(() => _f.dateRange = range),
                      onCleared: () => setState(() => _f.dateRange = null),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Footer (pinned) ────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                24, 14, 24, 14 + MediaQuery.paddingOf(context).bottom),
            decoration: const BoxDecoration(
              color: B2BColors.surface,
              border: Border(top: BorderSide(color: B2BColors.border)),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: _activeCount == 0
                      ? null
                      : () => setState(() =>
                          _f = FilterCriteria(searchText: widget.initial.searchText)),
                  child: const Text('Clear all'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _f),
                      child: Text(_activeCount == 0
                          ? 'Show all products'
                          : 'Show results'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled block in the filter sheet, with the current choice shown on the
/// right and a hairline between sections.
class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.child,
    this.value,
    this.last = false,
  });

  final String title;
  final String? value;
  final Widget child;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: B2BColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: B2BText.sans(
                      size: 14.5, weight: FontWeight.w600, color: B2BColors.ink)),
              const Spacer(),
              if (value != null)
                Flexible(
                  child: Text(value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: B2BText.sans(
                          size: 12.5,
                          weight: FontWeight.w500,
                          color: B2BColors.gold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Single-choice chips. Long lists collapse to the first few with "Show all",
/// and [searchable] lists get a small search box.
class _ChoiceChips extends StatefulWidget {
  const _ChoiceChips({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.loading = false,
    this.searchable = false,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  final bool loading;
  final bool searchable;

  @override
  State<_ChoiceChips> createState() => _ChoiceChipsState();
}

class _ChoiceChipsState extends State<_ChoiceChips> {
  static const _collapsedCount = 10;
  bool _expanded = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 1.8)),
      );
    }
    if (widget.options.isEmpty) {
      return Text('No options in your catalogue yet',
          style: B2BText.sans(size: 13, color: B2BColors.faint)
              .copyWith(fontStyle: FontStyle.italic));
    }

    final query = _query.trim().toLowerCase();
    var visible = query.isEmpty
        ? widget.options
        : widget.options.where((o) => o.toLowerCase().contains(query)).toList();
    final collapsible = query.isEmpty && visible.length > _collapsedCount;
    if (collapsible && !_expanded) {
      visible = visible.take(_collapsedCount).toList();
      // Keep the current choice visible even when it's past the cut.
      final sel = widget.selected;
      if (sel != null && !visible.contains(sel) && widget.options.contains(sel)) {
        visible = [...visible, sel];
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.searchable && widget.options.length > _collapsedCount) ...[
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: B2BText.sans(size: 13.5),
            decoration: InputDecoration(
              hintText: 'Search ${widget.options.length} options…',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true,
              fillColor: B2BColors.surfaceAlt,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(B2BRadius.md),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(B2BRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (visible.isEmpty)
          Text('No matches',
              style: B2BText.sans(size: 13, color: B2BColors.faint))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in visible)
                _chip(option, option == widget.selected),
            ],
          ),
        if (collapsible)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18),
              label: Text(_expanded
                  ? 'Show fewer'
                  : 'Show all ${widget.options.length}'),
            ),
          ),
      ],
    );
  }

  Widget _chip(String label, bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Material(
        color: selected ? B2BColors.primarySoft : B2BColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(B2BRadius.xl),
          side: BorderSide(
              color: selected ? B2BColors.primary : B2BColors.border,
              width: selected ? 1.2 : 1),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(B2BRadius.xl)),
          onTap: () => widget.onSelected(label),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: selected
                      ? const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.check_rounded,
                              size: 15, color: B2BColors.primary),
                        )
                      : const SizedBox.shrink(),
                ),
                Text(
                  label,
                  style: B2BText.sans(
                    size: 13,
                    weight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? B2BColors.primaryDeep : B2BColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
