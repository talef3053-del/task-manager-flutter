import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';
import '../services/export_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Runs an export action with friendly error handling.
  Future<void> _export(
      BuildContext context,
      Future<void> Function(ExportService service) action,
      ) async {
    final tasks = context.read<TaskProvider>().allTasks;
    final messenger = ScaffoldMessenger.of(context);

    if (tasks.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No tasks to export yet.')),
      );
      return;
    }
    try {
      await action(ExportService());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------- Theme ----------
          Text('Theme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.phone_android),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => settings.setThemeMode(s.first),
          ),

          // ---------- Accent colour ----------
          const SizedBox(height: 24),
          Text('Accent colour',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              for (var i = 0; i < SettingsProvider.accents.length; i++)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => settings.setAccent(i),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: SettingsProvider.accents[i],
                    child: settings.accentIndex == i
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),

          // ---------- Sound ----------
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Notification sound'),
            subtitle: const Text('Turn off for silent reminders'),
            value: settings.soundEnabled,
            onChanged: (v) async {
              final tasks = context.read<TaskProvider>();
              await settings.setSoundEnabled(v);
              // Reschedule so existing reminders use the new sound setting.
              await tasks.loadTasks();
            },
          ),

          // ---------- Export (Phase 8) ----------
          const Divider(height: 32),
          Text('Export and share',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Export as CSV'),
            subtitle: const Text('Opens in Excel or Google Sheets'),
            onTap: () => _export(context, (s) async {
              final tasks = context.read<TaskProvider>().allTasks;
              final file = await s.exportCsv(tasks);
              await s.shareFile(file, subject: 'My tasks (CSV)');
            }),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Export as PDF'),
            subtitle: const Text('A printable task report'),
            onTap: () => _export(context, (s) async {
              final tasks = context.read<TaskProvider>().allTasks;
              final file = await s.exportPdf(tasks);
              await s.shareFile(file, subject: 'My tasks (PDF)');
            }),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email task report'),
            subtitle: const Text('PDF report with a ready-made subject'),
            onTap: () => _export(context, (s) async {
              final tasks = context.read<TaskProvider>().allTasks;
              final file = await s.exportPdf(tasks);
              await s.shareFile(
                file,
                subject: 'Task report',
                text: 'Hello,\n\nMy current task report is attached.',
              );
            }),
          ),
        ],
      ),
    );
  }
}