import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/widgets/glowing_logo.dart';
import 'package:jewelry_nafisa/src/B2BScreens/b2b_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Config object that carries all filter state + callbacks from the parent
// screen into the floating panel. The panel reads from this and calls the
// same callbacks the top filter bar uses — so data is always re-fetched from
// Supabase when a selection changes, exactly like the existing filter bar.
// ─────────────────────────────────────────────────────────────────────────────
class FloatingFilterConfig {
  // ── Current selections ────────────────────────────────────────────────────
  final String selectedMetalType;
  final List<String> metalTypeOptions;
  final String selectedAkdMetalType;
  final String selectedProductType;
  final List<String> selectedCategories;
  final String selectedSubCategory;

  // ── Available options (loaded by parent, dependent on hierarchy) ──────────
  final List<String> akdMetalTypeOptions;
  final List<String> productTypeOptions;
  final List<String> categoryOptions;
  final List<String> subCategoryOptions;

  // ── Advanced Options ───────────────────────────────────────────────────────
  final List<String> availableMetalColors;
  final List<String> availableMetalPurities;
  final List<String> availableStoneShapes;
  final List<String> availableStoneTypes;
  final List<String> availableStoneQualities;
  final List<String> availableStoneSettings;
  final List<String> availableFeaturedTags;

  // Weight ranges determined dynamically from DB strings
  final List<double> metalWeightBounds;
  final List<double> stoneWeightBounds;

  // ── Advanced State Selections ──────────────────────────────────────────────
  final String? selectedJewelleryType; // 'Plain' or 'Studded'
  final List<String> selectedMetalColors;
  final List<String> selectedMetalPurities;
  final bool isEnamelWorkChecked;
  final List<String> selectedStoneShapes;
  final List<String> selectedStoneTypes;
  final List<String> selectedStoneQualities;
  final List<String> selectedStoneSettings;
  final List<String> selectedFeaturedTags;

  final List<double>? currentMetalWeightRange;
  final List<double>? currentStoneWeightRange;

  // ── Loading states ────────────────────────────────────────────────────────
  final bool isLoadingAkdMetalTypes;
  final bool isLoadingProductTypes;
  final bool isLoadingCategories;
  final bool isLoadingSubCategories;
  final bool isLoadingAdvancedOptions;

  // ── Callbacks (same ones used by the top filter bar) ─────────────────────
  final Future<void> Function(String, {bool applyImmediately})
      onMetalTypeChanged;
  final Future<void> Function(String?, {bool applyImmediately})
      onAkdMetalTypeChanged;
  final Future<void> Function(String?, {bool applyImmediately})
      onProductTypeChanged;
  final void Function(String) onCategoryChanged;
  final void Function(String?, {bool applyImmediately}) onSubCategoryChanged;

  // ── Callbacks for Advanced Filters (do not trigger immediate fetch) ────────
  final void Function(String?) onJewelleryTypeChanged;
  final void Function(List<double>) onMetalWeightChanged;
  final void Function(List<String>) onMetalColorsChanged;
  final void Function(List<String>) onMetalPuritiesChanged;
  final void Function(bool) onEnamelWorkChanged;
  final void Function(List<double>) onStoneWeightChanged;
  final void Function(List<String>) onStoneShapesChanged;
  final void Function(List<String>) onStoneTypesChanged;
  final void Function(List<String>) onStoneQualitiesChanged;
  final void Function(List<String>) onStoneSettingsChanged;
  final void Function(List<String>) onFeaturedTagsChanged;

  final VoidCallback onApplySelection;
  final Future<void> Function() onResetFilters;

  const FloatingFilterConfig({
    required this.selectedMetalType,
    this.metalTypeOptions = const [
      'All',
      'Gold',
      'Silver',
      'Platinum',
      'Instant'
    ],
    this.selectedAkdMetalType = 'All',
    this.selectedProductType = 'All',
    this.selectedCategories = const [],
    this.selectedSubCategory = 'All',
    this.akdMetalTypeOptions = const ['All'],
    this.productTypeOptions = const ['All'],
    this.categoryOptions = const ['All'],
    this.subCategoryOptions = const ['All'],

    // New Advanced Options Defaults
    this.availableMetalColors = const [],
    this.availableMetalPurities = const [],
    this.availableStoneShapes = const [],
    this.availableStoneTypes = const [],
    this.availableStoneQualities = const [],
    this.availableStoneSettings = const [],
    this.availableFeaturedTags = const [],
    this.metalWeightBounds = const [0.0, 100.0],
    this.stoneWeightBounds = const [0.0, 100.0],

    // New Advanced State Defaults
    this.selectedJewelleryType,
    this.selectedMetalColors = const [],
    this.selectedMetalPurities = const [],
    this.isEnamelWorkChecked = false,
    this.selectedStoneShapes = const [],
    this.selectedStoneTypes = const [],
    this.selectedStoneQualities = const [],
    this.selectedStoneSettings = const [],
    this.selectedFeaturedTags = const [],
    this.currentMetalWeightRange,
    this.currentStoneWeightRange,
    this.isLoadingAkdMetalTypes = false,
    this.isLoadingProductTypes = false,
    this.isLoadingCategories = false,
    this.isLoadingSubCategories = false,
    this.isLoadingAdvancedOptions = false,
    required this.onMetalTypeChanged,
    required this.onAkdMetalTypeChanged,
    required this.onProductTypeChanged,
    required this.onCategoryChanged,
    required this.onSubCategoryChanged,

    // New Advanced Callbacks
    required this.onJewelleryTypeChanged,
    required this.onMetalWeightChanged,
    required this.onMetalColorsChanged,
    required this.onMetalPuritiesChanged,
    required this.onEnamelWorkChanged,
    required this.onStoneWeightChanged,
    required this.onStoneShapesChanged,
    required this.onStoneTypesChanged,
    required this.onStoneQualitiesChanged,
    required this.onStoneSettingsChanged,
    required this.onFeaturedTagsChanged,
    required this.onApplySelection,
    required this.onResetFilters,
  });

  bool get hasActiveFilters =>
      selectedMetalType != 'All' ||
      selectedProductType != 'All' ||
      selectedCategories.isNotEmpty ||
      selectedSubCategory != 'All' ||
      selectedJewelleryType != null ||
      selectedMetalColors.isNotEmpty ||
      selectedMetalPurities.isNotEmpty ||
      isEnamelWorkChecked ||
      selectedStoneShapes.isNotEmpty ||
      selectedStoneTypes.isNotEmpty ||
      selectedStoneQualities.isNotEmpty ||
      selectedStoneSettings.isNotEmpty ||
      selectedFeaturedTags.isNotEmpty ||
      currentMetalWeightRange != null ||
      currentStoneWeightRange != null;

  int get activeCount {
    int n = 0;
    if (selectedMetalType != 'All') n++;
    if (selectedProductType != 'All') n++;
    if (selectedCategories.isNotEmpty) n += selectedCategories.length;
    if (selectedSubCategory != 'All') n++;
    if (selectedJewelleryType != null) n++;
    if (selectedMetalColors.isNotEmpty) n++;
    if (selectedMetalPurities.isNotEmpty) n++;
    if (isEnamelWorkChecked) n++;
    if (selectedStoneShapes.isNotEmpty) n++;
    if (selectedStoneTypes.isNotEmpty) n++;
    if (selectedStoneQualities.isNotEmpty) n++;
    if (selectedStoneSettings.isNotEmpty) n++;
    if (selectedFeaturedTags.isNotEmpty) n++;
    if (currentMetalWeightRange != null) n++;
    if (currentStoneWeightRange != null) n++;
    return n;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FloatingFilterOverlay — wraps any child with the vertical FILTERS button
// and the slide-in filter panel. It is purely a UI shell: all state lives in
// the parent screen, and all changes are routed back via FloatingFilterConfig.
// ─────────────────────────────────────────────────────────────────────────────
class FloatingFilterOverlay extends StatefulWidget {
  final Widget child;
  final FloatingFilterConfig config;

  const FloatingFilterOverlay({
    super.key,
    required this.child,
    required this.config,
  });

  @override
  State<FloatingFilterOverlay> createState() => _FloatingFilterOverlayState();
}

class _FloatingFilterOverlayState extends State<FloatingFilterOverlay>
    with TickerProviderStateMixin {
  bool _isPanelOpen = false;

  late AnimationController _slideController;
  late CurvedAnimation _curvedSlide;
  late AnimationController _backdropController;
  late Animation<double> _backdropAnimation;

  static const Color _green = B2BColors.primaryDeep;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _curvedSlide = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _backdropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _backdropAnimation = CurvedAnimation(
      parent: _backdropController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _backdropController.dispose();
    super.dispose();
  }

  // ── Open / close ───────────────────────────────────────────────────────────

  void _openPanel() {
    setState(() => _isPanelOpen = true);
    _backdropController.forward();
    _slideController.forward();
  }

  void _closePanel() {
    _slideController.reverse().then((_) {
      if (mounted) setState(() => _isPanelOpen = false);
    });
    _backdropController.reverse();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    final slideAnimation = Tween<Offset>(
      begin: isMobile ? const Offset(0.0, 1.0) : const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(_curvedSlide);

    return Stack(
      children: [
        widget.child,

        // Backdrop
        if (_isPanelOpen)
          FadeTransition(
            opacity: _backdropAnimation,
            child: GestureDetector(
              onTap: _closePanel,
              child: Container(color: B2BColors.muted),
            ),
          ),

        // Slide-in panel
        if (_isPanelOpen)
          Positioned(
            top: isMobile ? MediaQuery.of(context).size.height * 0.15 : 0,
            bottom: 0,
            right: 0,
            left: isMobile ? 0 : null,
            child: SlideTransition(
              position: slideAnimation,
              child: _FloatingFilterPanel(
                config: widget.config,
                onClose: _closePanel,
                isMobile: isMobile,
              ),
            ),
          ),

        // Floating FILTERS tab button
        if (!_isPanelOpen)
          Positioned(
            right: isMobile ? 0 : 0,
            left: isMobile ? 0 : null,
            bottom: isMobile ? 16 : null, // Bottom on mobile
            top: isMobile ? null : MediaQuery.of(context).size.height * 0.38,
            child: _buildFloatingButton(isMobile),
          ),
      ],
    );
  }

  Widget _buildFloatingButton(bool isMobile) {
    final count = widget.config.activeCount;

    if (isMobile) {
      // Pill shaped button at the bottom center
      return Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: _openPanel,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: _green.withValues(alpha: 0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.diamond_outlined,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'FILTERS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 12),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB300),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _openPanel,
      child: Container(
        width: 36,
        height: 120,
        decoration: BoxDecoration(
          color: _green,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            bottomLeft: Radius.circular(10),
          ),
          boxShadow: [
            BoxShadow(
              color: _green.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(-3, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (count > 0)
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB300),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            const Icon(Icons.diamond_outlined, color: Colors.white, size: 16),
            const SizedBox(height: 4),
            const RotatedBox(
              quarterTurns: 1,
              child: Text(
                'FILTERS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The actual panel content — separated so it rebuilds when config changes
// without re-creating the animation controllers.
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingFilterPanel extends StatelessWidget {
  final FloatingFilterConfig config;
  final VoidCallback onClose;
  final bool isMobile;

  static const Color _green = B2BColors.primaryDeep;

  const _FloatingFilterPanel({
    required this.config,
    required this.onClose,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        width: isMobile ? double.infinity : 310,
        height: double.infinity,
        decoration: BoxDecoration(
          color: B2BColors.canvas,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            bottomLeft: isMobile ? Radius.zero : const Radius.circular(20),
            topRight: isMobile ? const Radius.circular(20) : Radius.zero,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: isMobile ? const Offset(0, -6) : const Offset(-6, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHierarchyFilters(context),
                    // ── Advanced Filters ───────────────────────────────────────────
                    _buildAdvancedFilters(context),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchyFilters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildSectionLabel(Icons.account_tree_outlined, 'CATALOG HIERARCHY'),
        const SizedBox(height: 8),
        _buildAccordion(
          title: 'Metal Type',
          activeCount: config.selectedMetalType == 'All' ? 0 : 1,
          children: [
            _buildSingleSelectWrap(
              options: config.metalTypeOptions,
              selected: config.selectedMetalType,
              onChanged: (value) => config.onMetalTypeChanged(value),
            ),
          ],
        ),
        if (config.selectedMetalType == 'Instant' &&
            config.akdMetalTypeOptions.length > 1)
          _buildAccordion(
            title: 'Instant Metal',
            activeCount: config.selectedAkdMetalType == 'All' ? 0 : 1,
            children: [
              _buildSingleSelectWrap(
                options: config.akdMetalTypeOptions,
                selected: config.selectedAkdMetalType,
                onChanged: (value) => config.onAkdMetalTypeChanged(value),
              ),
            ],
          ),
        if (config.selectedMetalType != 'All' &&
            config.productTypeOptions.length > 1)
          _buildAccordion(
            title: 'Product Type',
            activeCount: config.selectedProductType == 'All' ? 0 : 1,
            children: [
              _buildSingleSelectWrap(
                options: config.productTypeOptions,
                selected: config.selectedProductType,
                onChanged: (value) => config.onProductTypeChanged(value),
              ),
            ],
          ),
        if (config.selectedProductType != 'All' &&
            config.categoryOptions.length > 1)
          _buildAccordion(
            title: 'Category',
            activeCount: config.selectedCategories.length,
            children: [
              _buildMultiSelectWrap(
                options: config.categoryOptions
                    .where((option) => option != 'All')
                    .toList(),
                selections: config.selectedCategories,
                onChanged: (values) {
                  final previous = config.selectedCategories.toSet();
                  final changed = values.where((v) => v != 'All').toSet();
                  for (final value in {...previous, ...changed}) {
                    if (previous.contains(value) != changed.contains(value)) {
                      config.onCategoryChanged(value);
                    }
                  }
                },
              ),
            ],
          ),
        if (config.selectedCategories.isNotEmpty &&
            config.subCategoryOptions.length > 1)
          _buildAccordion(
            title: 'Subcategory',
            activeCount: config.selectedSubCategory == 'All' ? 0 : 1,
            children: [
              _buildSingleSelectWrap(
                options: config.subCategoryOptions,
                selected: config.selectedSubCategory,
                onChanged: (value) => config.onSubCategoryChanged(value),
              ),
            ],
          ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 14),
      decoration: const BoxDecoration(
        color: B2BColors.canvas,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: B2BColors.ink,
                ),
              ),
              Text(
                'Refine Selection',
                style: TextStyle(
                  fontSize: 13,
                  color: B2BColors.muted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20),
            color: B2BColors.inkSoft,
          ),
        ],
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _green),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: _green,
          ),
        ),
      ],
    );
  }

  // ── Bottom action buttons ─────────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: B2BColors.canvas,
        border: Border(top: BorderSide(color: B2BColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: () {
              config.onApplySelection();
              onClose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              elevation: 0,
            ),
            child: const Text(
              'APPLY SELECTION',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              config.onResetFilters().whenComplete(onClose);
            },
            icon: const Icon(Icons.close, size: 13),
            label: const Text(
              'CLEAR ALL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: B2BColors.muted,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

// ── Advanced Filters ──────────────────────────────────────────────────────
  Widget _buildAdvancedFilters(BuildContext context) {
    if (config.isLoadingAdvancedOptions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: GlowingLogo(size: 40)),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        const Divider(),
        _buildSectionLabel(Icons.tune_outlined, 'ADVANCED FILTERS'),
        const SizedBox(height: 10),

        // 1. Jewellery Type
        _buildAccordion(
          title: 'Jewellery Type',
          activeCount: config.selectedJewelleryType != null ? 1 : 0,
          children: [
            Wrap(
              spacing: 8,
              children: ['Plain', 'Studded'].map((type) {
                final isSelected = config.selectedJewelleryType == type;
                return _FilterChip(
                  label: type,
                  isSelected: isSelected,
                  onTap: () =>
                      config.onJewelleryTypeChanged(isSelected ? null : type),
                );
              }).toList(),
            ),
          ],
        ),

        // 2. Metal Weight (Range Slider)
        _buildAccordion(
          title: 'Metal Weight',
          activeCount: config.currentMetalWeightRange != null ? 1 : 0,
          children: [
            _buildRangeSlider(
              bounds: config.metalWeightBounds,
              current: config.currentMetalWeightRange,
              onChanged: config.onMetalWeightChanged,
              unit: 'g',
            ),
          ],
        ),

        // 3. Metal Color
        _buildAccordion(
          title: 'Metal Color',
          activeCount: config.selectedMetalColors.length,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: config.availableMetalColors.map((color) {
                final isSelected = config.selectedMetalColors.contains(color);
                return GestureDetector(
                  onTap: () {
                    final newSelections =
                        List<String>.from(config.selectedMetalColors);
                    if (isSelected) {
                      newSelections.remove(color);
                    } else {
                      newSelections.add(color);
                    }
                    config.onMetalColorsChanged(newSelections);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getMetalColorHex(color),
                          border: Border.all(
                            color: isSelected ? _green : B2BColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: _green.withValues(alpha: 0.3),
                                      blurRadius: 4)
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        color,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // 4. Metal Purity
        _buildAccordion(
          title: 'Metal Purity',
          activeCount: config.selectedMetalPurities.length,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 8,
              children: config.availableMetalPurities.map((purity) {
                final isSelected =
                    config.selectedMetalPurities.contains(purity);
                return _FilterChip(
                  label: purity,
                  isSelected: isSelected,
                  onTap: () {
                    final newSelections =
                        List<String>.from(config.selectedMetalPurities);
                    if (isSelected) {
                      newSelections.remove(purity);
                    } else {
                      newSelections.add(purity);
                    }
                    config.onMetalPuritiesChanged(newSelections);
                  },
                );
              }).toList(),
            ),
          ],
        ),

        // 5. Enamel Work
        _buildAccordion(
          title: 'Enamel Work',
          activeCount: config.isEnamelWorkChecked ? 1 : 0,
          children: [
            CheckboxListTile(
              title:
                  const Text('Has Enamel Work', style: TextStyle(fontSize: 13)),
              value: config.isEnamelWorkChecked,
              onChanged: (val) => config.onEnamelWorkChanged(val ?? false),
              activeColor: _green,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),

        // Stone Filters (Hidden if Plain is selected)
        if (config.selectedJewelleryType != 'Plain') ...[
          // 6. Stone Weight
          _buildAccordion(
            title: 'Stone Weight',
            activeCount: config.currentStoneWeightRange != null ? 1 : 0,
            children: [
              _buildRangeSlider(
                bounds: config.stoneWeightBounds,
                current: config.currentStoneWeightRange,
                onChanged: config.onStoneWeightChanged,
                unit: 'ct',
              ),
            ],
          ),

          // 7. Stone Shape
          _buildAccordion(
            title: 'Stone Shape',
            activeCount: config.selectedStoneShapes.length,
            children: [
              _buildMultiSelectWrap(
                options: config.availableStoneShapes,
                selections: config.selectedStoneShapes,
                onChanged: config.onStoneShapesChanged,
              ),
            ],
          ),

          // 8. Stone Type
          _buildAccordion(
            title: 'Stone Type',
            activeCount: config.selectedStoneTypes.length,
            children: [
              _buildMultiSelectWrap(
                options: config.availableStoneTypes,
                selections: config.selectedStoneTypes,
                onChanged: config.onStoneTypesChanged,
              ),
            ],
          ),

          // 9. Stone Quality
          _buildAccordion(
            title: 'Stone Quality',
            activeCount: config.selectedStoneQualities.length,
            children: [
              _buildMultiSelectWrap(
                options: config.availableStoneQualities,
                selections: config.selectedStoneQualities,
                onChanged: config.onStoneQualitiesChanged,
              ),
            ],
          ),

          // 10. Stone Setting
          _buildAccordion(
            title: 'Stone Setting',
            activeCount: config.selectedStoneSettings.length,
            children: [
              _buildMultiSelectWrap(
                options: config.availableStoneSettings,
                selections: config.selectedStoneSettings,
                onChanged: config.onStoneSettingsChanged,
              ),
            ],
          ),
        ],

        // Featured is intentionally disabled until tag quality is reliable.
      ],
    );
  }

  Widget _buildAccordion({
    required String title,
    required int activeCount,
    required List<Widget> children,
  }) {
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: B2BColors.inkSoft,
              ),
            ),
            if (activeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$activeCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ]
          ],
        ),
        iconColor: _green,
        collapsedIconColor: B2BColors.muted,
        childrenPadding: const EdgeInsets.only(bottom: 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildMultiSelectWrap({
    required List<String> options,
    required List<String> selections,
    required void Function(List<String>) onChanged,
  }) {
    if (options.isEmpty) {
      return const Text('No options',
          style: TextStyle(fontSize: 12, color: Colors.grey));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selections.contains(option);
        return _FilterChip(
          label: option,
          isSelected: isSelected,
          onTap: () {
            final newSelections = List<String>.from(selections);
            if (isSelected) {
              newSelections.remove(option);
            } else {
              newSelections.add(option);
            }
            onChanged(newSelections);
          },
        );
      }).toList(),
    );
  }

  Widget _buildSingleSelectWrap({
    required List<String> options,
    required String selected,
    required void Function(String) onChanged,
  }) {
    if (options.isEmpty) {
      return const Text('No options',
          style: TextStyle(fontSize: 12, color: Colors.grey));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 8,
      children: options.map((option) {
        return _FilterChip(
          label: option,
          isSelected: selected == option,
          onTap: () {
            if (selected != option) onChanged(option);
          },
        );
      }).toList(),
    );
  }

  Widget _buildRangeSlider({
    required List<double> bounds,
    required List<double>? current,
    required void Function(List<double>) onChanged,
    required String unit,
  }) {
    if (bounds[1] <= bounds[0]) {
      return const Text('Range unavailable',
          style: TextStyle(fontSize: 12, color: Colors.grey));
    }

    final currentValues = current ?? bounds;
    // ensure bounds are respected (in case bounds changed)
    final minVal = currentValues[0] < bounds[0] ? bounds[0] : currentValues[0];
    final maxVal = currentValues[1] > bounds[1] ? bounds[1] : currentValues[1];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${minVal.toStringAsFixed(1)}$unit',
                style: const TextStyle(fontSize: 12)),
            Text('${maxVal.toStringAsFixed(1)}$unit',
                style: const TextStyle(fontSize: 12)),
          ],
        ),
        RangeSlider(
          values: RangeValues(minVal, maxVal),
          min: bounds[0],
          max: bounds[1],
          activeColor: _green,
          inactiveColor: B2BColors.border,
          onChanged: (RangeValues values) {
            onChanged([values.start, values.end]);
          },
        ),
      ],
    );
  }

  Color _getMetalColorHex(String colorStr) {
    final lower = colorStr.toLowerCase();
    // Order matters: check the more specific qualifiers (rose/white) before the
    // generic "gold", so "Rose Gold" doesn't fall into the yellow-gold branch.
    if (lower.contains('rose')) return const Color(0xFFB76E79); // rose gold
    if (lower.contains('white')) return B2BColors.border; // white gold
    if (lower.contains('platinum')) return const Color(0xFFE5E4E2); // platinum
    if (lower.contains('silver')) return const Color(0xFFC0C0C0); // silver
    // "Yellow", "Yellow Gold", and bare "Gold" all read as yellow gold.
    if (lower.contains('yellow') || lower.contains('gold')) {
      return const Color(0xFFE6B422); // richer gold (less neon than FFD700)
    }
    return B2BColors.border; // unknown / malformed
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metal type chip — replicates the Gold/Silver/Get it style from the top bar
// ─────────────────────────────────────────────────────────────────────────────
class _MetalChip extends StatelessWidget {
  final String metal;
  final bool isSelected;
  final VoidCallback onTap;

  const _MetalChip({
    required this.metal,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    BoxDecoration decoration;
    Color textColor;

    if (isSelected) {
      textColor = Colors.white;
      switch (metal) {
        case 'Gold':
          decoration = BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFB84D)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          );
          break;
        case 'Silver':
          decoration = BoxDecoration(
            color: const Color(0xFFB8B8B8),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB8B8B8).withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          );
          break;
        default: // Instant/Get it
          decoration = BoxDecoration(
            gradient: const LinearGradient(
              colors: [B2BColors.primaryDeep, B2BColors.primary, B2BColors.primaryDeep],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: B2BColors.primaryDeep.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          );
      }
    } else {
      textColor = B2BColors.inkSoft;
      decoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: B2BColors.border, width: 1.5),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: decoration,
        child: Text(
          metal == 'Instant' ? 'Get it' : metal,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic selectable bubble chip
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? B2BColors.primaryDeep : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? B2BColors.primaryDeep : B2BColors.border,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? B2BColors.primaryDeep.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : B2BColors.inkSoft,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
