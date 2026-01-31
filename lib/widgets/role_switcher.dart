import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/role_service.dart';
import '../utils/app_theme.dart';

class RoleSwitcher extends StatelessWidget {
  final UserModel user;
  final Function()? onRoleChanged;

  const RoleSwitcher({
    super.key,
    required this.user,
    this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Only show if user has multiple roles
    if (user.roles.length < 2) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<UserRole>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.swap_horiz,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            _getRoleDisplayName(user.activeRole),
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.white),
        ],
      ),
      onSelected: (UserRole role) async {
        if (role == user.activeRole) return;

        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        try {
          await RoleService().switchActiveRole(role);
          
          if (context.mounted) {
            Navigator.of(context).pop(); // Close loading
            
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Switched to ${_getRoleDisplayName(role)} mode'),
                backgroundColor: Colors.green,
              ),
            );

            // Trigger callback
            onRoleChanged?.call();
            
            // Force app restart to reload UI
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context).pop(); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error switching role: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      itemBuilder: (BuildContext context) {
        return user.roles.map((UserRole role) {
          final isActive = role == user.activeRole;
          return PopupMenuItem<UserRole>(
            value: role,
            child: Row(
              children: [
                Icon(
                  _getIconForRole(role),
                  color: isActive ? AppColors.primary : Colors.grey,
                ),
                const SizedBox(width: 12),
                Text(
                  _getRoleDisplayName(role),
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? AppColors.primary : Colors.black,
                  ),
                ),
                const Spacer(),
                if (isActive)
                  const Icon(Icons.check, color: AppColors.primary, size: 20),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.propertyAgent:
        return 'Agent';
      case UserRole.admin:
        return 'Admin';
    }
  }

  IconData _getIconForRole(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return Icons.person;
      case UserRole.propertyAgent:
        return Icons.business;
      case UserRole.admin:
        return Icons.admin_panel_settings;
    }
  }
}
