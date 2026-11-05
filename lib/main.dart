import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'providers/task_provider.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved settings first so the first frame already has the right theme.
  final settings = SettingsProvider();
  await settings.load();

  await NotificationService.instance.init();
  runApp(TaskManagerApp(settings: settings));
  NotificationService.instance.requestPermissions();
}

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key, required this.settings});

  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => TaskProvider()..loadTasks()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, s, _) => MaterialApp(
          title: 'Rida work reminder',
          debugShowCheckedModeBanner: false,
          themeMode: s.themeMode,
          theme: AppTheme.light(s.accentColor),
          darkTheme: AppTheme.dark(s.accentColor),
          home: const _LifecycleReloader(child: HomeScreen()),
        ),
      ),
    );
  }
}

/// Reloads tasks whenever the app comes back to the foreground, which also
/// runs the recurrence check for the new day.
class _LifecycleReloader extends StatefulWidget {
  const _LifecycleReloader({required this.child});

  final Widget child;

  @override
  State<_LifecycleReloader> createState() => _LifecycleReloaderState();
}

class _LifecycleReloaderState extends State<_LifecycleReloader>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<TaskProvider>().loadTasks();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}