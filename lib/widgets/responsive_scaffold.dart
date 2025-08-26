import 'package:flutter/material.dart';

/// A responsive scaffold that adapts to different screen sizes
/// Provides consistent navigation and layout patterns across the app
class ResponsiveScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;
  final bool showBottomNavigation;
  final int currentIndex;
  final Function(int)? onNavigationTap;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  
  const ResponsiveScaffold({
    Key? key,
    required this.body,
    required this.title,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.showBottomNavigation = true,
    this.currentIndex = 0,
    this.onNavigationTap,
    this.showBackButton = false,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: actions,
        bottom: bottom,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: isWide ? _buildWideLayout() : body,
      bottomNavigationBar: showBottomNavigation && !isWide 
          ? _buildBottomNavigationBar(theme)
          : null,
      floatingActionButton: floatingActionButton,
    );
  }
  
  Widget _buildWideLayout() {
    return Row(
      children: [
        // Side navigation for wide screens
        NavigationRail(
          selectedIndex: currentIndex,
          onDestinationSelected: onNavigationTap,
          labelType: NavigationRailLabelType.all,
          destinations: _getNavigationDestinations().map((dest) =>
            NavigationRailDestination(
              icon: Icon(dest.icon),
              selectedIcon: Icon(dest.activeIcon ?? dest.icon),
              label: Text(dest.label),
            ),
          ).toList(),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        // Main content
        Expanded(child: body),
      ],
    );
  }
  
  Widget _buildBottomNavigationBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: Colors.grey,
          currentIndex: currentIndex.clamp(0, _getNavigationDestinations().length - 1),
          backgroundColor: Colors.white,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          iconSize: 24,
          onTap: onNavigationTap,
          items: _getNavigationDestinations().map((dest) =>
            BottomNavigationBarItem(
              icon: Icon(dest.icon),
              activeIcon: Icon(dest.activeIcon ?? dest.icon),
              label: dest.label,
            ),
          ).toList(),
        ),
      ),
    );
  }
  
  List<NavigationDestination> _getNavigationDestinations() {
    return const [
      NavigationDestination(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder,
        label: 'Projects',
      ),
      NavigationDestination(
        icon: Icons.pets_outlined,
        activeIcon: Icons.pets,
        label: 'Animals',
      ),
      NavigationDestination(
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment,
        label: 'Records',
      ),
      NavigationDestination(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profile',
      ),
    ];
  }
}

/// Navigation destination model
class NavigationDestination {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  
  const NavigationDestination({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

/// Helper mixin for screens to handle common navigation logic
mixin NavigationHandler<T extends StatefulWidget> on State<T> {
  void handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushNamedAndRemoveUntil(
          context, 
          '/dashboard', 
          (route) => false,
        );
        break;
      case 1:
        Navigator.pushNamed(context, '/projects');
        break;
      case 2:
        Navigator.pushNamed(context, '/animals');
        break;
      case 3:
        Navigator.pushNamed(context, '/records');
        break;
      case 4:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }
  
  int getCurrentIndex(String routeName) {
    switch (routeName) {
      case '/dashboard':
      case '/':
        return 0;
      case '/projects':
        return 1;
      case '/animals':
        return 2;
      case '/records':
        return 3;
      case '/profile':
        return 4;
      default:
        return 0;
    }
  }
}