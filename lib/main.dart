import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/benchmark_provider.dart';
import 'providers/cluster_provider.dart';
import 'providers/history_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/benchmark_screen.dart';
import 'screens/clusters_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'widgets/cluster_status_bar.dart';
import 'widgets/sidebar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService().init();

  runApp(const ElkyBenchApp());
}

class ElkyBenchApp extends StatelessWidget {
  const ElkyBenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ClusterProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProxyProvider<HistoryProvider, BenchmarkProvider>(
          create: (context) => BenchmarkProvider(
            historyProvider: Provider.of<HistoryProvider>(context, listen: false),
          ),
          update: (_, historyProv, benchProv) =>
              benchProv ?? BenchmarkProvider(historyProvider: historyProv),
        ),
      ],
      child: MaterialApp(
        title: 'Elky Bench',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainShellScreen(),
      ),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  NavigationTab _activeTab = NavigationTab.clusters;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // Desktop Navigation Sidebar (250px)
                AppSidebar(
                  activeTab: _activeTab,
                  onTabSelected: (tab) => setState(() => _activeTab = tab),
                ),
                // Main Content View
                Expanded(
                  child: IndexedStack(
                    index: _activeTab.index,
                    children: const [
                      ClustersScreen(),
                      BenchmarkScreen(),
                      HistoryScreen(),
                      SettingsScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom Telemetry Status Bar
          const ClusterStatusBar(),
        ],
      ),
    );
  }
}
