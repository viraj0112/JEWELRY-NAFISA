import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/creators_provider.dart';
import '../widgets/admin_page_header.dart';
import '../widgets/creators_filter_bar.dart';
import '../widgets/creators_tabs.dart';
import './tabs/creators_3d_tab.dart';
import './tabs/creators_sketch_tab.dart';
import './tabs/creators_manufacturer_tab.dart';
import './tabs/creators_uploaded_works_tab.dart';

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
                        'Discover, filter, and collaborate with verified creators.',
                    actions: [
                      ElevatedButton.icon(
                        onPressed: provider.loading
                            ? null
                            : () => provider.loadCreators(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh List'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          // open invite dialog
                        },
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Invite Creator'),
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
                        ? const Center(child: CircularProgressIndicator())
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
    return CreatorsUploadedWorksTab(
        works: provider.works, creators: provider.creators);
  }
}
