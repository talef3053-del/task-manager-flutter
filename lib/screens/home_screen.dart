import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_tile.dart';
import 'settings_screen.dart';
import 'task_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openForm([Task? task]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
    );
  }

  void _toggleSearch() {
    if (_searching) {
      _searchCtrl.clear();
      context.read<TaskProvider>().setQuery('');
    }
    setState(() => _searching = !_searching);
  }

  static const _filterLabels = {
    TaskFilter.all: 'All tasks',
    TaskFilter.overdue: 'Overdue only',
    TaskFilter.repeating: 'Repeating only',
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final searching = provider.query
        .trim()
        .isNotEmpty;

    String empty(String normal) =>
        provider.hasActiveSearchOrFilter ? 'No matching tasks.' : normal;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search tasks...',
              border: InputBorder.none,
            ),
            onChanged: provider.setQuery,
          )
              : const Text('Rida work reminder'),
          actions: [
            IconButton(
              tooltip: _searching ? 'Close search' : 'Search',
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: _toggleSearch,
            ),
            PopupMenuButton<TaskFilter>(
              tooltip: 'Filter',
              icon: Icon(
                provider.filter == TaskFilter.all
                    ? Icons.filter_list
                    : Icons.filter_list_alt,
              ),
              onSelected: provider.setFilter,
              itemBuilder: (_) =>
              [
                for (final f in TaskFilter.values)
                  CheckedPopupMenuItem(
                    value: f,
                    checked: provider.filter == f,
                    child: Text(_filterLabels[f]!),
                  ),
              ],
            ),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings),
              onPressed: () =>
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Today'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Repeated'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openForm,
          icon: const Icon(Icons.add),
          label: const Text('New task'),
        ),
        body: provider.isLoading &&
            provider.todayTasks.isEmpty &&
            !searching
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            TaskListView(
              tasks: provider.todayTasks,
              emptyIcon: Icons.today,
              emptyMessage: empty('Nothing due today. Enjoy your day!'),
              onOpen: _openForm,
            ),
            TaskListView(
              tasks: provider.upcomingTasks,
              emptyIcon: Icons.event_note,
              emptyMessage: empty('No upcoming tasks.'),
              onOpen: _openForm,
            ),
            TaskListView(
              tasks: provider.completedTasks,
              emptyIcon: Icons.task_alt,
              emptyMessage: empty('No completed tasks yet.'),
              onOpen: _openForm,
            ),
            TaskListView(
              tasks: provider.repeatedTasks,
              emptyIcon: Icons.repeat,
              emptyMessage: empty('No repeating tasks yet.'),
              onOpen: _openForm,
            ),
          ],
        ),
      ),
    );
  }
}