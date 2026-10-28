import 'package:flutter/material.dart';

import '../data/expense_repository.dart';
import '../main.dart';
import '../services/export_service.dart';
import '../widgets/common.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _exportAll(BuildContext context, bool pdf) async {
    try {
      final all = await context.repo.fetchExpenses();
      if (pdf) {
        await ExportService().exportPdf(all, label: 'All expenses');
      } else {
        await ExportService().exportCsv(all, label: 'All expenses');
      }
    } catch (e) {
      if (context.mounted) showMessage(context, 'Export failed: $e', error: true);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your expenses stay saved to your Google account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final repo = context.repo;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await repo.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppSettingsScope.of(context);
    final repo = context.repo;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                (repo.displayName ?? repo.email ?? '?').substring(0, 1).toUpperCase(),
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(repo.displayName ?? 'Signed in'),
            subtitle: Text(repo.email ?? ''),
          ),
          SectionHeader(title: 'Appearance', padding: const EdgeInsets.fromLTRB(16, 20, 16, 8)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
              ],
              selected: {settings.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (v) => settings.themeMode = v.first,
            ),
          ),
          SectionHeader(title: 'Spending', padding: const EdgeInsets.fromLTRB(16, 28, 16, 0)),
          ListTile(
            leading: const Icon(Icons.category_rounded),
            title: const Text('Categories'),
            subtitle: const Text('Add, reorder or remove categories'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.table_view_rounded),
            title: const Text('Export everything as CSV'),
            subtitle: const Text('Opens in Sheets or Excel'),
            onTap: () => _exportAll(context, false),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded),
            title: const Text('Export everything as PDF'),
            subtitle: const Text('A printable report with totals'),
            onTap: () => _exportAll(context, true),
          ),
          SectionHeader(title: 'Account', padding: const EdgeInsets.fromLTRB(16, 28, 16, 0)),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
            title: Text('Sign out', style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => _signOut(context),
          ),
          if (kDemoMode)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Demo mode: sample data, nothing is saved.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
