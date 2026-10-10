import 'package:flutter/material.dart';

import 'auth_screens.dart';
import 'home_screen.dart';

/// Profile page of the Tiffie redesign (prototype). Values are parameters.
class GProfile extends StatelessWidget {
  final String name, contact;
  final VoidCallback? onEdit, onAddresses, onSubscription, onNotifications;
  final VoidCallback? onHelp, onLogout;
  final ValueChanged<int>? onTab;
  const GProfile({
    super.key,
    required this.name,
    required this.contact,
    this.onEdit,
    this.onAddresses,
    this.onSubscription,
    this.onNotifications,
    this.onHelp,
    this.onLogout,
    this.onTab,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GColors.cream,
    body: Column(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: GColors.green,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.of(context).padding.top + 24,
            24,
            28,
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFC9D4F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GColors.saffron, width: 2),
                ),
                child: Text(
                  name.isEmpty ? '' : name[0].toUpperCase(),
                  style: gText(26, w: FontWeight.w700, c: GColors.green),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: gText(18, w: FontWeight.w700, c: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: gText(12, c: const Color(0xFFD6DDD8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            children: [
              _row(
                Icons.manage_accounts_outlined,
                GColors.green,
                'Edit Profile',
                onEdit,
              ),
              _row(
                Icons.location_on_outlined,
                GColors.saffron,
                'Saved Addresses',
                onAddresses,
              ),
              _row(
                Icons.repeat,
                GColors.green,
                'My Tiffin Subscription',
                onSubscription,
              ),
              _row(
                Icons.notifications_none,
                GColors.green,
                'Notifications',
                onNotifications,
              ),
              _row(Icons.help_outline, GColors.green, 'Help & Support', onHelp),
              _logout(),
            ],
          ),
        ),
        GBottomNav(tab: 3, onTab: onTab),
      ],
    ),
  );

  Widget _row(IconData icon, Color c, String label, VoidCallback? onTap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: c),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: gText(12.5, w: FontWeight.w700, c: GColors.green),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: GColors.grey),
              ],
            ),
          ),
        ),
      );

  Widget _logout() => GestureDetector(
    onTap: onLogout,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.logout, size: 20, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          Text(
            'Log Out',
            style: gText(12.5, w: FontWeight.w700, c: const Color(0xFFDC2626)),
          ),
        ],
      ),
    ),
  );
}
