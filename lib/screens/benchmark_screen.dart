import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/benchmark_settings.dart';
import '../models/cluster_config.dart';
import '../models/cluster_stats.dart';
import '../providers/benchmark_provider.dart';
import '../providers/cluster_provider.dart';
import '../providers/settings_provider.dart';
import '../services/pdf_report_service.dart';
import '../theme/app_colors.dart';
import '../widgets/eyebrow_pill.dart';

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  bool _showAdvancedSettings = false;

  void _startIngest(ClusterConfig cluster, BenchmarkSettings settings) {
    Provider.of<BenchmarkProvider>(context, listen: false).runIngestBenchmark(
      cluster: cluster,
      settings: settings,
    );
  }

  void _startSearch(ClusterConfig cluster, BenchmarkSettings settings) {
    Provider.of<BenchmarkProvider>(context, listen: false).runSearchBenchmark(
      cluster: cluster,
      settings: settings,
    );
  }

  void _openPdf(String? path) {
    if (path == null) return;
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
    return Consumer3<ClusterProvider, BenchmarkProvider, SettingsProvider>(
      builder: (context, clusterProv, benchProv, settingsProv, _) {
        final activeCluster = clusterProv.selectedCluster;
        final isRunning = benchProv.isRunning;
        final settings = settingsProv.settings;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            EyebrowPill.teal(label: 'BENCHMARK SCENARIOS'),
                            const SizedBox(height: 8),
                            const Text(
                              'Elasticsearch Performance Benchmarking',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navyDark,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Saturate CPU and JVM heap with heavy ingest reindex pipelines or query latency stress with complex async aggregations.',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Target Cluster Selector dropdown
                      _buildClusterSelector(clusterProv),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (activeCluster == null) ...[
                    // Prompt to select or add cluster
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 24),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Please select or add an active Elasticsearch cluster before running benchmark scenarios.',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navyDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // If Benchmark is running or completed, show Live Progress Panel
                    if (isRunning || benchProv.state == BenchmarkState.completed || benchProv.state == BenchmarkState.error || benchProv.state == BenchmarkState.stopped) ...[
                      _buildProgressSection(benchProv),
                      const SizedBox(height: 24),
                    ],

                    // Tunable Settings Bar
                    _buildSettingsBar(settingsProv),

                    const SizedBox(height: 24),

                    // Scenarios Cards (side-by-side)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ingest Benchmark Card
                        Expanded(
                          child: _buildScenarioCard(
                            title: 'Ingest & Reindex Benchmark',
                            badgeLabel: 'INGEST',
                            badgeColor: AppColors.purpleBg,
                            badgeBorder: AppColors.purpleBorder,
                            badgeText: AppColors.purpleText,
                            icon: Icons.upload_file_rounded,
                            iconColor: AppColors.purpleText,
                            description:
                                'Bulk ingests ${settings.targetSizeGb} GB of raw CEF WAF logs, seeds a Threat Intelligence enrich index, builds a high-saturation pipeline (Grok, KV, Enrich, Script, Fingerprint), and measures CPU saturation and throughput across reindex iterations.',
                            buttonLabel: isRunning ? 'Benchmark in progress...' : 'Start Ingest Benchmark',
                            buttonColor: AppColors.primaryBlue,
                            onPressed: isRunning ? null : () => _startIngest(activeCluster, settings),
                            highlights: [
                              'Target index: ${settings.targetSizeGb} GB raw logs',
                              'Shards: ${settings.primaryShards} Primaries, ${settings.replicaShards} Replicas',
                              'Pipeline: Extreme CPU Saturation (Entropy + OWASP + SHA-512)',
                              'Workers: ${settings.workers} Parallel Worker Indices',
                              'Enrich Policy: ${settings.threatIntelRecords} Threat IP records',
                              'Execution: ${settings.benchmarkMode == "no_iterations" || settings.benchmarkMode == "indefinitely" ? "Indefinitely" : (settings.iterationsCount == 1 ? "1 Iteration" : "${settings.iterationsCount} Iterations")}',
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Search Benchmark Card
                        Expanded(
                          child: _buildScenarioCard(
                            title: 'Complex Aggregation Search',
                            badgeLabel: 'SEARCH',
                            badgeColor: AppColors.successBg,
                            badgeBorder: AppColors.successBorder,
                            badgeText: AppColors.successText,
                            icon: Icons.search_rounded,
                            iconColor: AppColors.tealAccent,
                            description:
                                'Leverages the ${settings.targetSizeGb} GB dataset to execute multi-level async aggregations (1-hour Date Histograms, Term buckets, Cardinality, and Wildcard attack filters) to stress cluster search threads and query latency.',
                            buttonLabel: isRunning ? 'Benchmark in progress...' : 'Start Search Benchmark',
                            buttonColor: AppColors.tealAccent,
                            onPressed: isRunning ? null : () => _startSearch(activeCluster, settings),
                            highlights: [
                              'Dataset: ${settings.targetSizeGb} GB indexed logs',
                              'Shards: ${settings.primaryShards} Primaries, ${settings.replicaShards} Replicas',
                              'Workers: ${settings.workers} Concurrent Search Workers',
                              'Aggregations: Date Histogram + Terms + Cardinality',
                              'Filters: OWASP attack signatures & time ranges',
                              'Execution: ${settings.benchmarkMode == "no_iterations" || settings.benchmarkMode == "indefinitely" ? "Indefinitely" : (settings.iterationsCount == 1 ? "1 Iteration" : "${settings.iterationsCount} Iterations")}',
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClusterSelector(ClusterProvider clusterProv) {
    final clusters = clusterProv.clusters;
    final selected = clusterProv.selectedCluster;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected?.id,
          hint: const Text('Select Cluster', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primaryBlue),
          items: clusters.map((c) {
            return DropdownMenuItem<String>(
              value: c.id,
              child: Text(
                c.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navyDark),
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id != null) {
              final found = clusters.where((c) => c.id == id).firstOrNull;
              if (found != null) clusterProv.selectCluster(found);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSettingsBar(SettingsProvider settingsProv) {
    final settings = settingsProv.settings;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, size: 16, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Text(
                    'Benchmark Parameters',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.navyDark),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _showAdvancedSettings = !_showAdvancedSettings),
                child: Text(
                  _showAdvancedSettings ? 'Hide Advanced ▲' : 'Show Advanced ▼',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Quick presets row
          Row(
            children: [
              // Target Data Size
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Target Dataset Size', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildPresetButton(
                          label: '0.05 GB (Test)',
                          selected: settings.targetSizeGb == 0.05,
                          onTap: () => settingsProv.update((s) => s.targetSizeGb = 0.05),
                        ),
                        const SizedBox(width: 6),
                        _buildPresetButton(
                          label: '1 GB (Default)',
                          selected: settings.targetSizeGb == 1.0,
                          onTap: () => settingsProv.update((s) => s.targetSizeGb = 1.0),
                        ),
                        const SizedBox(width: 6),
                        _buildPresetButton(
                          label: '10 GB',
                          selected: settings.targetSizeGb == 10.0,
                          onTap: () => settingsProv.update((s) => s.targetSizeGb = 10.0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Execution Limit Mode
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Benchmark Stop Condition', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildPresetButton(
                          label: '1 Iteration',
                          selected: settings.benchmarkMode == 'iterations' && settings.iterationsCount == 1,
                          onTap: () => settingsProv.update((s) {
                            s.benchmarkMode = 'iterations';
                            s.iterationsCount = 1;
                          }),
                        ),
                        const SizedBox(width: 6),
                        _buildPresetButton(
                          label: '3 Iterations',
                          selected: settings.benchmarkMode == 'iterations' && settings.iterationsCount == 3,
                          onTap: () => settingsProv.update((s) {
                            s.benchmarkMode = 'iterations';
                            s.iterationsCount = 3;
                          }),
                        ),
                        const SizedBox(width: 6),
                        _buildPresetButton(
                          label: '5 Iterations',
                          selected: settings.benchmarkMode == 'iterations' && settings.iterationsCount == 5,
                          onTap: () => settingsProv.update((s) {
                            s.benchmarkMode = 'iterations';
                            s.iterationsCount = 5;
                          }),
                        ),
                        const SizedBox(width: 6),
                        _buildPresetButton(
                          label: 'Indefinitely',
                          selected: settings.benchmarkMode == 'no_iterations' || settings.benchmarkMode == 'indefinitely',
                          onTap: () => settingsProv.update((s) => s.benchmarkMode = 'no_iterations'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Concurrent Workers row
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('Concurrent Workers (1 Index per Worker & Parallel Search)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [1, 2, 4, 8, 16, 32].map((w) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildPresetButton(
                      label: w == 8 ? '$w (Default)' : '$w',
                      selected: settings.workers == w,
                      onTap: () => settingsProv.update((s) => s.workers = w),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Advanced settings
          if (_showAdvancedSettings) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildSettingInput(
                    label: 'Bulk Batch Size (docs)',
                    value: settings.bulkBatchSize.toString(),
                    onChanged: (val) {
                      final n = int.tryParse(val);
                      if (n != null && n > 0) settingsProv.update((s) => s.bulkBatchSize = n);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSettingInput(
                    label: 'Primary Shards',
                    value: settings.primaryShards.toString(),
                    onChanged: (val) {
                      final n = int.tryParse(val);
                      if (n != null && n > 0) settingsProv.update((s) => s.primaryShards = n);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSettingInput(
                    label: 'Replica Shards',
                    value: settings.replicaShards.toString(),
                    onChanged: (val) {
                      final n = int.tryParse(val);
                      if (n != null && n >= 0) settingsProv.update((s) => s.replicaShards = n);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSettingInput(
                    label: 'Threat Intel Records',
                    value: settings.threatIntelRecords.toString(),
                    onChanged: (val) {
                      final n = int.tryParse(val);
                      if (n != null && n > 0) settingsProv.update((s) => s.threatIntelRecords = n);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlue.withValues(alpha: 0.08) : AppColors.slateLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.borderLight,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.primaryBlue : AppColors.navyDark,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingInput({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        TextFormField(
          key: ValueKey('bench_input_${label}_$value'),
          initialValue: value,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildScenarioCard({
    required String title,
    required String badgeLabel,
    required Color badgeColor,
    required Color badgeBorder,
    required Color badgeText,
    required IconData icon,
    required Color iconColor,
    required String description,
    required String buttonLabel,
    required Color buttonColor,
    required VoidCallback? onPressed,
    required List<String> highlights,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(icon, color: iconColor, size: 24)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: badgeText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navyDark),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.45),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          ...highlights.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.tealAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(h, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navyDark)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(BenchmarkProvider benchProv) {
    final isRunning = benchProv.isRunning;
    final isDone = benchProv.state == BenchmarkState.completed;
    final isErr = benchProv.state == BenchmarkState.error;
    final isStopped = benchProv.state == BenchmarkState.stopped;

    Color stateColor = AppColors.primaryBlue;
    if (isDone) stateColor = AppColors.successText;
    if (isErr) stateColor = AppColors.dangerRed;
    if (isStopped) stateColor = AppColors.yellowWarm;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stateColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isRunning)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryBlue),
                    )
                  else if (isDone)
                    const Icon(Icons.check_circle_rounded, color: AppColors.successText, size: 22)
                  else if (isErr)
                    const Icon(Icons.error_outline_rounded, color: AppColors.dangerRed, size: 22)
                  else
                    const Icon(Icons.pause_circle_outline_rounded, color: AppColors.yellowWarm, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    isRunning
                        ? 'Benchmark In Progress'
                        : isDone
                            ? 'Benchmark Completed Successfully'
                            : isErr
                                ? 'Benchmark Error'
                                : 'Benchmark Stopped',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: stateColor,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Elapsed: ${_formatElapsed(benchProv.elapsedSeconds)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navyDark),
                  ),
                  const SizedBox(width: 16),
                  if (isRunning)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
                      onPressed: benchProv.stopBenchmark,
                      icon: const Icon(Icons.stop_rounded, size: 16),
                      label: const Text('Stop Benchmark'),
                    )
                  else
                    OutlinedButton(
                      onPressed: benchProv.reset,
                      child: const Text('Dismiss Panel'),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar & Percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  benchProv.currentPhase,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.navyDark),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(benchProv.progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryBlue),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: benchProv.progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppColors.slateBg,
              color: stateColor,
            ),
          ),

          const SizedBox(height: 20),

          // Live & Peak Metrics Cards
          Row(
            children: [
              _buildLiveMetricTile(
                title: 'PEAK CPU USAGE',
                value: '${benchProv.peakCpu.toStringAsFixed(1)}%',
                subtitle: 'Live: ${benchProv.liveCpu.toStringAsFixed(1)}%',
                icon: Icons.memory_rounded,
                color: benchProv.peakCpu > 80 ? AppColors.dangerRed : AppColors.primaryBlue,
              ),
              const SizedBox(width: 12),
              _buildLiveMetricTile(
                title: 'PEAK JVM HEAP',
                value: '${benchProv.peakHeap.toStringAsFixed(1)}%',
                subtitle: 'Live: ${benchProv.liveHeap.toStringAsFixed(1)}%',
                icon: Icons.layers_rounded,
                color: benchProv.peakHeap > 80 ? AppColors.yellowWarm : AppColors.tealAccent,
              ),
              const SizedBox(width: 12),
              _buildLiveMetricTile(
                title: 'TOTAL DISK USED',
                value: ClusterStats.formatBytes(benchProv.liveDiskUsed),
                subtitle: 'Cluster storage',
                icon: Icons.storage_rounded,
                color: AppColors.navyDark,
              ),
              const SizedBox(width: 12),
              _buildLiveMetricTile(
                title: 'DOCS INGESTED',
                value: '${benchProv.totalDocsIngested}',
                subtitle: 'Indexed records',
                icon: Icons.dataset_rounded,
                color: AppColors.navyDark,
              ),
            ],
          ),

          // If PDF generated, show download/open banner
          if (benchProv.lastResult?.pdfPath != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.successBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: AppColors.successText, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Performance Verification PDF Report Generated',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.successText),
                        ),
                        Text(
                          benchProv.lastResult!.pdfPath!,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.successText,
                      side: const BorderSide(color: AppColors.successBorder),
                    ),
                    onPressed: () => PdfReportService.exportReportToDirectory(context, benchProv.lastResult!.pdfPath!),
                    icon: const Icon(Icons.drive_file_move_rounded, size: 16),
                    label: const Text('Save To Folder...'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.successText),
                    onPressed: () => _openPdf(benchProv.lastResult!.pdfPath),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open PDF Report'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveMetricTile({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.slateLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatElapsed(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
