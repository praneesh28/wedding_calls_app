// lib/screens/settings_page.dart
// Professional settings screen with card sections, toggles, and actions.

import 'package:flutter/material.dart';

import 'wedding_theme.dart';
import 'accounts_categories_page.dart';
import 'transaction_manager.dart';
import 'wedding_calls_page.dart';
import 'report_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _showPlaceholder(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title option coming soon'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      color: weddingOnSurface,
      fontWeight: FontWeight.w700,
    );
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: weddingOnSurfaceMuted,
    );

    return Scaffold(
      backgroundColor: weddingBg,
      appBar: AppBar(
        backgroundColor: weddingSurface,
        elevation: 1,
        centerTitle: true,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: weddingOnSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            const _ProfileHeader(),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Account',
              actions: [
                _ButtonTile(
                  icon: Icons.person_outline,
                  title: 'Account Details',
                  subtitle: 'Update your name, email, and contact number.',
                  onTap: () => _showPlaceholder(context, 'Account Details'),
                ),
                _ButtonTile(
                  icon: Icons.subscriptions_outlined,
                  title: 'Manage Subscription',
                  subtitle: 'Upgrade, downgrade, or cancel your plan.',
                  onTap: () => _showPlaceholder(context, 'Manage Subscription'),
                ),
                _ButtonTile(
                  icon: Icons.logout,
                  title: 'Sign Out',
                  subtitle: 'Log out of your Wedding Planner account.',
                  onTap: () => _showPlaceholder(context, 'Sign Out'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'App Preferences',
              actions: [
                _SwitchTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Notifications',
                  subtitle: 'Receive reminders for expenses and calls.',
                  value: true,
                  onChanged: (_) {},
                ),
                _SwitchTile(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Auto Sync',
                  subtitle: 'Sync data automatically with the cloud.',
                  value: true,
                  onChanged: (_) {},
                ),
                _DropdownTile(
                  icon: Icons.currency_exchange_outlined,
                  title: 'Default Currency',
                  subtitle: 'Display budgets and reports using this currency.',
                  value: '₹ Indian Rupee',
                  items: const [
                    '₹ Indian Rupee',
                    '\$ US Dollar',
                    '€ Euro',
                    '£ British Pound'
                  ],
                  onChanged: (_) {},
                ),
                _DropdownTile(
                  icon: Icons.language_outlined,
                  title: 'Language',
                  subtitle: 'Choose your preferred language.',
                  value: 'മലയാളം',
                  items: const ['English', 'हिंदी', 'தமிழ்', 'മലയാളം'],
                  onChanged: (_) =>
                      _showPlaceholder(context, 'Language selection'),
                ),
                _DropdownTile(
                  icon: Icons.format_paint_outlined,
                  title: 'Theme',
                  subtitle: 'Switch between light and dark themes.',
                  value: 'Wedding Theme',
                  items: const ['Wedding Theme', 'Dark', 'Light'],
                  onChanged: (_) {},
                ),
                _SwitchTile(
                  icon: Icons.filter_alt_outlined,
                  title: 'Advanced Filters',
                  subtitle: 'Enable saved filters for quick data insights.',
                  value: true,
                  onChanged: (_) {},
                ),
                _ButtonTile(
                  icon: Icons.backup_outlined,
                  title: 'Backup Settings',
                  subtitle: 'Configure automatic backups and retention.',
                  onTap: () => _showPlaceholder(context, 'Backup Settings'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Reminders & Notifications',
              subtitle:
                  'Fine-tune when and how you receive alerts from the planner.',
              actions: [
                _SwitchTile(
                  icon: Icons.calendar_today_outlined,
                  title: 'Daily Summary',
                  subtitle: 'Send a recap of expenses every evening.',
                  value: true,
                  onChanged: (_) {},
                ),
                _SwitchTile(
                  icon: Icons.alarm_on_outlined,
                  title: 'Upcoming Tasks',
                  subtitle: 'Remind me about due payments and calls.',
                  value: false,
                  onChanged: (_) {},
                ),
                _ButtonTile(
                  icon: Icons.schedule_outlined,
                  title: 'Notification Schedule',
                  subtitle: 'Choose custom times or quiet hours.',
                  onTap: () =>
                      _showPlaceholder(context, 'Notification Schedule'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Shortcuts',
              subtitle:
                  'Jump straight to frequently used screens for quick edits.',
              actions: [
                _ShortcutTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Transactions',
                  subtitle: 'Add and review income & expenses.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionManager(),
                    ),
                  ),
                ),
                _ShortcutTile(
                  icon: Icons.category_outlined,
                  title: 'Accounts & Categories',
                  subtitle: 'Manage debit/credit accounts and tags.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountsCategoriesPage(),
                    ),
                  ),
                ),
                _ShortcutTile(
                  icon: Icons.phone_forwarded_outlined,
                  title: 'Wedding Calls',
                  subtitle: 'Manage calls and appointment schedule.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WeddingCallsPage(),
                    ),
                  ),
                ),
                _ShortcutTile(
                  icon: Icons.pie_chart_outline,
                  title: 'Reports',
                  subtitle: 'View budget summaries and analytics.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReportPages(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Integrations',
              subtitle:
                  'Connect Wedding Planner with the tools you already use.',
              actions: [
                _ButtonTile(
                  icon: Icons.event_available_outlined,
                  title: 'Calendar Sync',
                  subtitle: 'Sync deadlines with Google or Apple Calendar.',
                  onTap: () => _showPlaceholder(context, 'Calendar Sync'),
                ),
                _ButtonTile(
                  icon: Icons.ios_share_outlined,
                  title: 'Share Dashboard',
                  subtitle: 'Generate a shareable link for stakeholders.',
                  onTap: () => _showPlaceholder(context, 'Share Dashboard'),
                ),
                _ButtonTile(
                  icon: Icons.cloud_sync_outlined,
                  title: 'Cloud Integrations',
                  subtitle: 'Connect Drive, Dropbox, or OneDrive.',
                  onTap: () => _showPlaceholder(context, 'Cloud Integrations'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Data & Privacy',
              actions: [
                _ButtonTile(
                  icon: Icons.download_outlined,
                  title: 'Export Data',
                  subtitle: 'Download your transactions and contacts.',
                  onTap: () => _showPlaceholder(context, 'Export Data'),
                ),
                _ButtonTile(
                  icon: Icons.upload_outlined,
                  title: 'Import Data',
                  subtitle: 'Restore from a Wedding Planner backup.',
                  onTap: () => _showPlaceholder(context, 'Import Data'),
                ),
                _ButtonTile(
                  icon: Icons.restore_outlined,
                  title: 'Restore Latest Backup',
                  subtitle: 'Revert to the most recent automatic backup.',
                  onTap: () =>
                      _showPlaceholder(context, 'Restore Latest Backup'),
                ),
                _ButtonTile(
                  icon: Icons.delete_sweep_outlined,
                  title: 'Clear Cache',
                  subtitle: 'Remove cached files and temporary data.',
                  onTap: () => _showPlaceholder(context, 'Clear Cache'),
                ),
                _ButtonTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'Understand how we keep your data secure.',
                  onTap: () => _showPlaceholder(context, 'Privacy Policy'),
                ),
                _ButtonTile(
                  icon: Icons.gavel_outlined,
                  title: 'Terms & Conditions',
                  subtitle: 'Review our usage terms and guidelines.',
                  onTap: () => _showPlaceholder(context, 'Terms & Conditions'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Support & About',
              actions: [
                _IconTextButton(
                  icon: Icons.help_outline,
                  title: 'Help Center',
                  subtitle: 'Find answers in the knowledge base.',
                  onTap: () => _showPlaceholder(context, 'Help Center'),
                ),
                _IconTextButton(
                  icon: Icons.mail_outline,
                  title: 'Contact Support',
                  subtitle: 'Request assistance from our team.',
                  onTap: () => _showPlaceholder(context, 'Contact Support'),
                ),
                const Divider(thickness: 0.4, color: weddingOnSurfaceMuted),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Version', style: captionStyle),
                      const SizedBox(height: 4),
                      Text('Wedding Planner 1.0.0',
                          style: titleStyle?.copyWith(fontSize: 14)),
                      const SizedBox(height: 12),
                      Text('© 2025 Wedding Planner',
                          style: captionStyle?.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: weddingSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    weddingAccent,
                    weddingAccent.withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Text(
                  'WP',
                  style: TextStyle(
                    color: weddingSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wedding Planner',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: weddingOnSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Plan and manage your big day effortlessly.',
                    style: TextStyle(
                      color: weddingOnSurfaceMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile editing coming soon'))),
              style: TextButton.styleFrom(
                foregroundColor: weddingAccent,
                backgroundColor: weddingAccent.withOpacity(0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
            )
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const _SectionCard({
    required this.title,
    required this.actions,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: weddingSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: weddingOnSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: weddingOnSurfaceMuted,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 16),
            for (var i = 0; i < actions.length; i++) ...[
              actions[i],
              if (i != actions.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: weddingAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: weddingAccent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: weddingOnSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: weddingOnSurfaceMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: weddingAccent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: weddingAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: weddingAccent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: weddingOnSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: weddingOnSurfaceMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: weddingOnSurfaceMuted, width: 0.8),
            ),
            child: DropdownButton<String>(
              value: value,
              onChanged: onChanged,
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        style: const TextStyle(color: weddingOnSurface),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: weddingAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: weddingAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: weddingOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: weddingOnSurfaceMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: weddingOnSurfaceMuted),
          ],
        ),
      ),
    );
  }
}

class _ButtonTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ButtonTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: weddingAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: weddingAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: weddingOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: weddingOnSurfaceMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: weddingOnSurfaceMuted),
          ],
        ),
      ),
    );
  }
}

class _IconTextButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _IconTextButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: weddingAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: weddingAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: weddingOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: weddingOnSurfaceMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
