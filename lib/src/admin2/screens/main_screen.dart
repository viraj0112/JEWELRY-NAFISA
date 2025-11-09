import "package:flutter/material.dart";
import "package:jewelry_nafisa/src/admin2/sections/analytics_section.dart";
import "package:jewelry_nafisa/src/admin2/sections/content_section.dart";
import "package:jewelry_nafisa/src/admin2/widgets/app_sidebar.dart";
import "package:provider/provider.dart";
import 'package:jewelry_nafisa/src/admin2/providers/app_state.dart';

class ManinScreen extends StatelessWidget {
  const ManinScreen({super.key});

  Widget _renderContent(String activeView) {
    switch (activeView) {
      case "content":
        return ContentSection();
      case "analytics":
        return const AnalyticsSection();
      default:
        return  ContentSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;
    final isTablet = width >= 800 && width < 1200;

    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          drawer: isMobile
              ? Drawer(
                  child: const AppSidebar(),
                )
              : null,
          body: Stack(
            children: [
              Row(
                children: [
                  if (!isMobile) const AppSidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: Padding(
                              // Responsive padding
                              padding: EdgeInsets.all(isMobile
                                  ? 16.0
                                  : isTablet
                                      ? 20.0
                                      : 24.0),
                              child: _renderContent(appState.activeView),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
