import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/benchmark_settings.dart';
import '../providers/cluster_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/eyebrow_pill.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  BenchmarkSettings _settings = BenchmarkSettings();
  String _dataPath = 'Loading...';
  bool _saved = false;
  bool _initializedFromProvider = false;

  @override
  void initState() {
    super.initState();
    _loadPath();
  }

  Future<void> _loadPath() async {
    String p = '';
    try {
      final dir = await getApplicationSupportDirectory();
      p = dir.path;
    } catch (_) {
      p = '${Directory.current.path}/.elkybench_data';
    }
    if (mounted) {
      setState(() => _dataPath = p);
    }
  }

  Future<void> _save(SettingsProvider settingsProv) async {
    await settingsProv.updateSettings(_settings);
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _pickReportDirectory(SettingsProvider settingsProv) async {
    final selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Report Output Directory',
      initialDirectory: _settings.reportDirectory,
    );
    if (selectedDir != null && selectedDir.trim().isNotEmpty) {
      setState(() {
        _settings.reportDirectory = selectedDir.trim();
      });
      await settingsProv.update((s) => s.reportDirectory = selectedDir.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.successText,
            content: Text('Report directory set to:\n$selectedDir'),
          ),
        );
      }
    }
  }

  Future<void> _resetReportDirectory(SettingsProvider settingsProv) async {
    setState(() {
      _settings.reportDirectory = null;
    });
    await settingsProv.update((s) => s.reportDirectory = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report directory reset to default (~/Documents/ElkyBench_Reports)')),
      );
    }
  }

  void _openDirectory(String path) {
    if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ClusterProvider, SettingsProvider>(
      builder: (context, clusterProv, settingsProv, _) {
        if (!_initializedFromProvider && settingsProv.isLoaded) {
          _settings = settingsProv.settings.clone();
          _initializedFromProvider = true;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  EyebrowPill.blue(label: 'APPLICATION CONFIGURATION'),
                  const SizedBox(height: 8),
                  const Text(
                    'Settings & Preferences',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navyDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Configure telemetry polling intervals, benchmark defaults, and data paths.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),

                  const SizedBox(height: 28),

                  // Section 1: Telemetry Polling Interval
                  _buildCard(
                    title: 'Cluster Health & Node Telemetry',
                    subtitle: 'Controls how frequently ElkyBench queries _nodes/stats for the bottom status bar.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Polling Frequency',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navyDark),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [5, 10, 15, 30].map((sec) {
                            final selected = clusterProv.pollIntervalSec == sec;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => clusterProv.setPollInterval(sec),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected ? AppColors.primaryBlue.withValues(alpha: 0.08) : AppColors.surfaceWhite,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selected ? AppColors.primaryBlue : AppColors.borderLight,
                                      width: selected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    '$sec Seconds ${sec == 10 ? "(Default)" : ""}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                      color: selected ? AppColors.primaryBlue : AppColors.navyDark,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section 2: Default Benchmark Defaults
                  _buildCard(
                    title: 'Benchmark Index Defaults',
                    subtitle: 'Default parameters applied when seeding raw WAF datasets.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildInput(
                                label: 'Default Primary Shards',
                                value: _settings.primaryShards.toString(),
                                onChanged: (v) {
                                  final n = int.tryParse(v);
                                  if (n != null && n > 0) _settings.primaryShards = n;
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildInput(
                                label: 'Default Replica Shards',
                                value: _settings.replicaShards.toString(),
                                onChanged: (v) {
                                  final n = int.tryParse(v);
                                  if (n != null && n >= 0) _settings.replicaShards = n;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInput(
                                label: 'Default Bulk Batch Size (docs)',
                                value: _settings.bulkBatchSize.toString(),
                                onChanged: (v) {
                                  final n = int.tryParse(v);
                                  if (n != null && n > 0) _settings.bulkBatchSize = n;
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildInput(
                                label: 'Default Target Size (GB)',
                                value: _settings.targetSizeGb.toString(),
                                onChanged: (v) {
                                  final n = double.tryParse(v);
                                  if (n != null && n > 0) _settings.targetSizeGb = n;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildInput(
                          label: 'Default Iterations Count',
                          value: _settings.iterationsCount.toString(),
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n > 0) _settings.iterationsCount = n;
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Concurrent Benchmark Workers (1 Index per Worker & Search Threads)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navyDark),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [1, 2, 4, 8, 16, 32].map((w) {
                            final isSel = _settings.workers == w;
                            return InkWell(
                              onTap: () => setState(() => _settings.workers = w),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.primaryBlue.withValues(alpha: 0.08) : AppColors.surfaceWhite,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSel ? AppColors.primaryBlue : AppColors.borderLight,
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  w == 8 ? '$w Workers (Default)' : '$w Workers',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                    color: isSel ? AppColors.primaryBlue : AppColors.navyDark,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _save(settingsProv),
                          child: Text(_saved ? 'Saved!' : 'Save Benchmark Defaults'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section 3: Report Output Directory
                  _buildCard(
                    title: 'Report Output Directory',
                    subtitle: 'Choose custom directory where generated benchmark PDF reports are saved.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Destination Folder',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navyDark),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.slateLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.folder_open_rounded, size: 18, color: AppColors.primaryBlue),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _settings.reportDirectory ?? 'Default: ~/Documents/ElkyBench_Reports',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    fontWeight: _settings.reportDirectory != null ? FontWeight.bold : FontWeight.normal,
                                    color: _settings.reportDirectory != null ? AppColors.navyDark : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _pickReportDirectory(settingsProv),
                              icon: const Icon(Icons.folder_rounded, size: 16),
                              label: const Text('Browse Directory...'),
                            ),
                            if (_settings.reportDirectory != null) ...[
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: () => _openDirectory(_settings.reportDirectory!),
                                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                                label: const Text('Open Folder'),
                              ),
                              const SizedBox(width: 10),
                              TextButton.icon(
                                onPressed: () => _resetReportDirectory(settingsProv),
                                icon: const Icon(Icons.restore_rounded, size: 15, color: AppColors.textMuted),
                                label: const Text('Reset to Default', style: TextStyle(color: AppColors.textMuted)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section 4: Data Storage Path
                  _buildCard(
                    title: 'Application Storage & Persistence',
                    subtitle: 'Local data directory where cluster configurations and history are securely persisted.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Storage Directory Path',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navyDark),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.slateLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Text(
                            _dataPath,
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.navyDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navyDark)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navyDark)),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey('settings_input_${label}_$value'),
          initialValue: value,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(isDense: true),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
