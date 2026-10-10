import 'package:flutter/material.dart';

import 'auth_screens.dart';
import 'home_screen.dart';

/// Profile page of the Tiffie redesign (prototype). Values are parameters.
class GProfile extends StatelessWidget {
  final String name, contact;
  final VoidCallback? onEdit, onAddresses, onSubscription, onNotifications;
  final VoidCallback? onHelp, onLogout, onUpdate;

  /// Dark mode switch row. Hidden when [onDark] is null.
  final bool? dark;
  final ValueChanged<bool>? onDark;
  final String? version;
  final bool showAddresses, showNotifications;
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
    this.onUpdate,
    this.dark,
    this.onDark,
    this.version,
    this.showAddresses = true,
    this.showNotifications = true,
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
          decoration: BoxDecoration(
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
                  style: gText(26, w: FontWeight.w700, c: GColors.ink),
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
                GColors.ink,
                'Edit Profile',
                onEdit,
              ),
              if (showAddresses)
                _row(
                  Icons.location_on_outlined,
                  GColors.saffron,
                  'Saved Addresses',
                  onAddresses,
                ),
              _row(
                Icons.repeat,
                GColors.ink,
                'My Tiffin Subscription',
                onSubscription,
              ),
              if (showNotifications)
                _row(
                  Icons.notifications_none,
                  GColors.ink,
                  'Notifications',
                  onNotifications,
                ),
              if (onUpdate != null)
                _row(
                  Icons.system_update_alt,
                  GColors.saffron,
                  'Check for updates',
                  onUpdate,
                  note: version,
                ),
              if (onDark != null)
                _row(
                  Icons.dark_mode_outlined,
                  GColors.ink,
                  'Dark mode',
                  () => onDark!(!(dark ?? false)),
                  trailing: Switch(
                    value: dark ?? false,
                    onChanged: onDark,
                    activeThumbColor: GColors.saffron,
                    activeTrackColor: GColors.saffron.withValues(alpha: 0.35),
                  ),
                ),
              _row(Icons.help_outline, GColors.ink, 'Help & Support', onHelp),
              _logout(),
            ],
          ),
        ),
        GBottomNav(tab: 4, onTab: onTab),
      ],
    ),
  );

  Widget _row(
    IconData icon,
    Color c,
    String label,
    VoidCallback? onTap, {
    String? note,
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: GColors.card,
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
                style: gText(12.5, w: FontWeight.w700, c: GColors.ink),
              ),
            ),
            if (note != null) ...[
              Text(note, style: gText(11, c: GColors.grey)),
              const SizedBox(width: 6),
            ],
            trailing ??
                Icon(Icons.chevron_right, size: 20, color: GColors.grey),
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
        color: GColors.dangerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GColors.dangerLine),
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
