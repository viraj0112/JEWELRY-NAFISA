import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/creators_provider.dart';
import '../widgets/admin_page_header.dart';
import '../widgets/admin_skeletons.dart';
import '../widgets/creators_filter_bar.dart';
import '../widgets/creators_tabs.dart';
import './tabs/creators_3d_tab.dart';
import './tabs/creators_sketch_tab.dart';
import './tabs/creators_manufacturer_tab.dart';
import './tabs/creators_uploaded_works_tab.dart';
import './tabs/creators_teams_tab.dart';

class CreatorsSection extends StatefulWidget {
  const CreatorsSection({super.key});

  @override
  State<CreatorsSection> createState() => _CreatorsSectionState();
}

class _CreatorsSectionState extends State<CreatorsSection> {
  String selectedTab = "3d";

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreatorsProvider>();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 900 ? 12.0 : 24.0;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminPageHeader(
                    title: 'B2B Creators',
                    subtitle:
                        'Manage and verify platform creators and designers.',
                    actions: [
                      ElevatedButton.icon(
                        onPressed: () => provider.exportCsv(),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A1A1A),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Creator'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B7A59),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CreatorsFilterBar(
                    onSearchChanged: (q) {},
                    onStatusChanged: (s) {},
                    onCategoryChanged: (c) {},
                  ),
                  const SizedBox(height: 12),
                  CreatorsTabs(
                    selected: selectedTab,
                    onSelect: (v) => setState(() => selectedTab = v),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: provider.loading
                        ? const AdminSkeletonView(
                            variant: AdminSkeletonVariant.cards)
                        : _buildTabContent(provider),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabContent(CreatorsProvider provider) {
    if (selectedTab == "3d") {
      return Creators3DTab(creators: provider.creators);
    }
    if (selectedTab == "sketch") {
      return CreatorsSketchTab(creators: provider.creators);
    }
    if (selectedTab == "manufacturer") {
      return CreatorsManufacturerTab(creators: provider.creators);
    }
    if (selectedTab == "teams") {
      return CreatorsTeamsTab(creators: provider.creators);
    }
    return CreatorsUploadedWorksTab(
        works: provider.works, creators: provider.creators);
  }
}
