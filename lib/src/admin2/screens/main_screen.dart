import "package:flutter/material.dart";
import "../screens/productupload_screen.dart";
import "package:provider/provider.dart";
import "../sections/users_section.dart";
import "../sections/analytics_section.dart";
import "../sections/content_section.dart";
import "../screens/b2b_creators_screen.dart";
import "../widgets/app_sidebar.dart";
import "../providers/app_state.dart";
import "../providers/users_provider.dart";
import "../widgets/admin_profile_menu.dart"; 

class ManinScreen extends StatelessWidget {
  const ManinScreen({super.key});

  Widget _renderContent(String activeView) {
    switch (activeView) {
      case "content":
        return const ContentSection();
      case "users":
        return ChangeNotifierProvider(
          create: (_) => UsersProvider(),
          child: const UsersSection(),
        );
      case "b2b-creators":
        return const B2BCreatorsScreen();
      case "product-upload":
        return const ProductUploadScreen();
      case "analytics":
        return const AnalyticsSection();
      case "dashboard":
        return const Center(child: Text("Dashboard Placeholder"));
      default:
        return const B2BCreatorsScreen();
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
              ? const Drawer(
                  child: AppSidebar(),
                )
              : null,
          body: Row(
            children: [
              if (!isMobile) const AppSidebar(),
              Expanded(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    children: [
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (isMobile)
                              IconButton(
                                icon: const Icon(Icons.menu),
                                onPressed: () => Scaffold.of(context).openDrawer(),
                              )
                            else
                              Text(
                                _getViewTitle(appState.activeView),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87
                                ),
                              ),
                            
                            const AdminProfileMenu(), 
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(isMobile
                              ? 16.0
                              : isTablet
                                  ? 20.0
                                  : 24.0),
                          child: _renderContent(appState.activeView),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getViewTitle(String view) {
    switch (view) {
      case 'users': return 'Users Management';
      case 'content': return 'Content Management';
      case 'b2b-creators': return 'B2B Creators';
      case 'analytics': return 'Analytics';
      case 'dashboard': return 'Dashboard';
      default: return 'Admin Panel';
    }
  }
}