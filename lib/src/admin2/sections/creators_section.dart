import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/creators_provider.dart';
import '../widgets/creators_filter_bar.dart';
import '../widgets/creators_tabs.dart';
import './tabs/creators_3d_tab.dart';
import './tabs/creators_sketch_tab.dart';
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
      appBar: AppBar(
        title: const Text("B2B Creators"),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Fixed: Changed onSpecializationChanged to onCategoryChanged
          CreatorsFilterBar(
            onSearchChanged: (q) {},   // Logic handled internally by provider in the widget
            onStatusChanged: (s) {},   // Logic handled internally by provider in the widget
            onCategoryChanged: (c) {}, // Logic handled internally by provider in the widget
          ),

          CreatorsTabs(
            selected: selectedTab,
            onSelect: (v) => setState(() => selectedTab = v),
          ),

          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : _buildTabContent(provider),
          )
        ],
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
    return CreatorsUploadedWorksTab(works: provider.works, creators: provider.creators);
  }
}