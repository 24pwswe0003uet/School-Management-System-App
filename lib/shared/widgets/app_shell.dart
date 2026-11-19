import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../theme/app_theme.dart';
import '../theme/app_breakpoints.dart';

/// Navigation item definition for AppShell sidebar and drawer.
class AppNavDestination {
  const AppNavDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.badge,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String? badge;
}

/// Responsive modern application shell providing persistent collapsible sidebar
/// on desktop/tablet and drawer/bottom-bar on mobile.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.schoolName = AppConfig.appName,
    this.userName,
    this.userRole,
    this.onLogout,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppNavDestination> destinations;
  final Widget body;
  final String schoolName;
  final String? userName;
  final String? userRole;
  final VoidCallback? onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isSidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isTablet = AppBreakpoints.isTablet(context);

    if (isDesktop || isTablet) {
      return Scaffold(
        body: Row(
          children: [
            // Collapsible Sidebar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isSidebarCollapsed ? 72 : 240,
              decoration: const BoxDecoration(
                color: AppTheme.primaryNavy,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(1, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // App Branding Header
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: const Icon(Icons.school, color: Colors.white, size: 24),
                        ),
                        if (!_isSidebarCollapsed) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.schoolName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),

                  // Navigation list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      itemCount: widget.destinations.length,
                      itemBuilder: (context, index) {
                        final dest = widget.destinations[index];
                        final isSelected = index == widget.selectedIndex;

                        if (_isSidebarCollapsed) {
                          return Tooltip(
                            message: dest.label,
                            placement: TooltipPlacement.right,
                            child: InkWell(
                              onTap: () => widget.onDestinationSelected(index),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              child: Container(
                                height: 44,
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                ),
                                child: Icon(
                                  isSelected ? (dest.selectedIcon ?? dest.icon) : dest.icon,
                                  color: isSelected ? Colors.white : Colors.white70,
                                  size: 22,
                                ),
                              ),
                            ),
                          );
                        }

                        return InkWell(
                          onTap: () => widget.onDestinationSelected(index),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          child: Container(
                            height: 40,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? (dest.selectedIcon ?? dest.icon) : dest.icon,
                                  color: isSelected ? Colors.white : Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    dest.label,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // User Profile & Collapse Toggle Footer
                  const Divider(color: Colors.white12, height: 1),
                  if (widget.userName != null && !_isSidebarCollapsed)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white24,
                            child: Text(
                              widget.userName![0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.userName!,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.userRole != null)
                                  Text(
                                    widget.userRole!,
                                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.onLogout != null)
                            IconButton(
                              icon: const Icon(Icons.logout, size: 18, color: Colors.white70),
                              tooltip: 'Logout',
                              onPressed: widget.onLogout,
                            ),
                        ],
                      ),
                    ),
                  // Collapse / Expand button
                  IconButton(
                    onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                    icon: Icon(
                      _isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                      color: Colors.white70,
                    ),
                    tooltip: _isSidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // Main content
            Expanded(child: widget.body),
          ],
        ),
      );
    }

    // Phone / Small Mobile Scaffold
    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.primaryNavy),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  widget.userName != null && widget.userName!.isNotEmpty
                      ? widget.userName![0].toUpperCase()
                      : 'S',
                  style: const TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.bold),
                ),
              ),
              accountName: Text(widget.userName ?? widget.schoolName),
              accountEmail: Text(widget.userRole ?? AppConfig.appName),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.destinations.length,
                itemBuilder: (context, index) {
                  final dest = widget.destinations[index];
                  final isSelected = index == widget.selectedIndex;
                  return ListTile(
                    leading: Icon(dest.icon, color: isSelected ? AppTheme.primaryNavy : null),
                    title: Text(
                      dest.label,
                      style: TextStyle(
                        color: isSelected ? AppTheme.primaryNavy : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onDestinationSelected(index);
                    },
                  );
                },
              ),
            ),
            if (widget.onLogout != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.dangerRed),
                title: const Text('Logout', style: TextStyle(color: AppTheme.dangerRed)),
                onTap: widget.onLogout,
              ),
            ],
          ],
        ),
      ),
      body: widget.body,
    );
  }
}
