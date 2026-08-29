import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MenuWidget extends StatelessWidget {
  const MenuWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.mostrarAdmin = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Muestra la pestaña "Admin" (entre Inicio y Perfil) solo a admins.
  final bool mostrarAdmin;

  @override
  Widget build(BuildContext context) {
    final List<BottomNavigationBarItem> items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Inicio',
      ),
      if (mostrarAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          activeIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Perfil',
      ),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.red,
          unselectedItemColor: AppColors.inkSecondary,
          showUnselectedLabels: true,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.4,
          ),
          items: items,
        ),
      ),
    );
  }
}
