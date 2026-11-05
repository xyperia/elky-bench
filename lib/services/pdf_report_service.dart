import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/benchmark_result.dart';
import '../theme/app_colors.dart';

class PdfReportService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  static Future<File> generateReport(
    BenchmarkResult result, {
    String? targetDirectory,
  }) async {
    final pdf = pw.Document(
      title: 'ElkyBench Report - ${result.clusterName}',
      author: 'ElkyBench',
    );

    // Color definitions for PDF matching Elastic brand
    final primaryBlue = PdfColor.fromHex('0077CC');
    final tealAccent = PdfColor.fromHex('00BFB3');
    final navyDark = PdfColor.fromHex('1B1C3A');
    final slateLight = PdfColor.fromHex('F8FAFC');
    final borderLight = PdfColor.fromHex('E2E8F0');
    final textMuted = PdfColor.fromHex('64748B');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _buildHeader(result, primaryBlue, textMuted, borderLight),
        footer: (context) => _buildFooter(context, result, textMuted, borderLight),
        build: (context) => [
          // 1. Executive Summary Hero Banner
          _buildHeroBanner(result, primaryBlue, tealAccent, navyDark, slateLight, borderLight),
          pw.SizedBox(height: 16),

          // 2. Performance Key Metrics Scorecard
          _buildScorecard(result, navyDark, primaryBlue, slateLight, borderLight, textMuted),
          pw.SizedBox(height: 16),

          // 3. Cluster Nodes & Topology Table
          _buildNodeTable(result, navyDark, borderLight, textMuted),
          pw.SizedBox(height: 16),

          // 4. Latency Distribution Table (p50, p90, p95, p99)
          _buildLatencyTable(result, navyDark, borderLight, textMuted, primaryBlue),
          pw.SizedBox(height: 16),

          // 5. Iterations Breakdown Table
          _buildIterationTable(result, navyDark, borderLight, textMuted),
          pw.SizedBox(height: 16),

          // 6. Cluster Resource Saturation (CPU & Heap snapshots)
          if (result.cpuSnapshots.isNotEmpty) ...[
            _buildResourceSnapshotsTable(result, navyDark, borderLight, textMuted),
            pw.SizedBox(height: 16),
          ],

          // 7. Benchmark Configuration Parameters
          _buildConfigTable(result, navyDark, borderLight, textMuted),
        ],
      ),
    );

    // Save to user-specified directory, or default ElkyBench_Reports folder
    Directory outputDir;
    if (targetDirectory != null && targetDirectory.trim().isNotEmpty) {
      outputDir = Directory(targetDirectory.trim());
      if (!outputDir.existsSync()) {
        try {
          outputDir.createSync(recursive: true);
        } catch (_) {
          outputDir = Directory('${Directory.current.path}/reports');
          if (!outputDir.existsSync()) outputDir.createSync(recursive: true);
        }
      }
    } else {
      try {
        final docs = await getApplicationDocumentsDirectory();
        outputDir = Directory('${docs.path}/ElkyBench_Reports');
        if (!outputDir.existsSync()) outputDir.createSync(recursive: true);
      } catch (_) {
        outputDir = Directory('${Directory.current.path}/reports');
        if (!outputDir.existsSync()) outputDir.createSync(recursive: true);
      }
    }

    final sanitizedClusterName = result.clusterName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filename = 'elkybench_${sanitizedClusterName}_${result.scenarioType}_${DateFormat('yyyyMMdd_HHmmss').format(result.startTime)}.pdf';
    final file = File('${outputDir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Copies an existing generated report to a user-selected folder.
  static Future<String?> exportReportToDirectory(BuildContext context, String currentPdfPath) async {
    final originalFile = File(currentPdfPath);
    if (!originalFile.existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report file not found on disk.')),
        );
      }
      return null;
    }

    final selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Directory to Save PDF Report',
    );

    if (selectedDir == null || selectedDir.trim().isEmpty) return null;

    final filename = currentPdfPath.split(Platform.pathSeparator).last;
    final destPath = '${selectedDir.trim()}${Platform.pathSeparator}$filename';
    await originalFile.copy(destPath);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.successText,
          content: Text('Report saved to:\n$destPath'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    return destPath;
  }

  static pw.Widget _buildHeader(
    BenchmarkResult result,
    PdfColor primaryBlue,
    PdfColor textMuted,
    PdfColor borderLight,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: borderLight, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 14,
                height: 14,
                decoration: pw.BoxDecoration(
                  color: primaryBlue,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'ELKY BENCH // PERFORMANCE VERIFICATION REPORT',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.8,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          pw.Text(
            result.clusterName.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(
    pw.Context context,
    BenchmarkResult result,
    PdfColor textMuted,
    PdfColor borderLight,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderLight, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Target Cluster: ${result.clusterName}',
            style: pw.TextStyle(fontSize: 8, color: textMuted),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textMuted),
          ),
          pw.Text(
            'Generated: ${_dateFormat.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8, color: textMuted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHeroBanner(
    BenchmarkResult result,
    PdfColor primaryBlue,
    PdfColor tealAccent,
    PdfColor navyDark,
    PdfColor slateLight,
    PdfColor borderLight,
  ) {
    final isIngest = result.scenarioType.toLowerCase() == 'ingest';
    final scenarioTitle = isIngest
        ? 'INGEST & REINDEX HIGH-SATURATION BENCHMARK'
        : 'COMPLEX AGGREGATION SEARCH BENCHMARK';

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: slateLight,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: borderLight, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: isIngest ? PdfColor.fromHex('FAF5FF') : PdfColor.fromHex('ECFDF5'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(
                    color: isIngest ? PdfColor.fromHex('E9D5FF') : PdfColor.fromHex('A7F3D0'),
                  ),
                ),
                child: pw.Text(
                  result.scenarioType.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: isIngest ? PdfColor.fromHex('7E22CE') : PdfColor.fromHex('047857'),
                  ),
                ),
              ),
              pw.Text(
                'Status: ${result.status.toUpperCase()}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: result.status == 'completed'
                      ? PdfColor.fromHex('047857')
                      : PdfColor.fromHex('B91C1C'),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            scenarioTitle,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: navyDark,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Cluster: ${result.clusterName} | Elasticsearch v${result.clusterVersion} (${result.clusterNodesCount} Nodes)',
            style: pw.TextStyle(fontSize: 10, color: primaryBlue, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Execution Window: ${_dateFormat.format(result.startTime)} - ${_dateFormat.format(result.endTime)} (Total: ${(result.totalDurationMs / 1000).toStringAsFixed(1)}s)',
            style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('64748B')),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildScorecard(
    BenchmarkResult result,
    PdfColor navyDark,
    PdfColor primaryBlue,
    PdfColor slateLight,
    PdfColor borderLight,
    PdfColor textMuted,
  ) {
    final avgSec = (result.avgIterationMs / 1000).toStringAsFixed(2);
    final p95Sec = (result.p95Ms / 1000).toStringAsFixed(2);
    final p99Sec = (result.p99Ms / 1000).toStringAsFixed(2);

    // Compute peak CPU and Heap from snapshots
    double peakCpu = 0.0;
    double peakHeapPct = 0.0;
    for (final snap in result.cpuSnapshots) {
      final cpu = (snap['clusterAvgCpu'] as num?)?.toDouble() ?? 0.0;
      if (cpu > peakCpu) peakCpu = cpu;
    }
    for (final snap in result.heapSnapshots) {
      final hp = (snap['heapPercent'] as num?)?.toDouble() ?? 0.0;
      if (hp > peakHeapPct) peakHeapPct = hp;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderLight, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'EXECUTIVE PERFORMANCE SCORECARD',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: textMuted,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'High-level benchmark summary highlighting overall execution throughput, key latency percentiles, and maximum resource saturation observed during the workload.',
            style: pw.TextStyle(fontSize: 7.5, color: textMuted),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricTile('COMPLETED ITERATIONS', '${result.iterationsCompleted}', '', navyDark, textMuted),
              _buildMetricTile('AVG ITERATION DURATION', avgSec, 'seconds', primaryBlue, textMuted),
              _buildMetricTile('p95 LATENCY', p95Sec, 'seconds', navyDark, textMuted),
              _buildMetricTile('p99 LATENCY', p99Sec, 'seconds', navyDark, textMuted),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: borderLight, thickness: 0.5),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricTile('PEAK CLUSTER CPU', '${peakCpu.toStringAsFixed(1)}%', 'utilization', navyDark, textMuted),
              _buildMetricTile('PEAK JVM HEAP', '${peakHeapPct.toStringAsFixed(1)}%', 'capacity', navyDark, textMuted),
              _buildMetricTile('DATASET SIZE', result.targetIndexSizeFormatted.isNotEmpty ? result.targetIndexSizeFormatted : '10 GB', 'index storage', navyDark, textMuted),
              _buildMetricTile('TOTAL DOCS', '${result.totalDocsIngested}', 'indexed records', navyDark, textMuted),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricTile(
    String label,
    String value,
    String subtitle,
    PdfColor valColor,
    PdfColor labelColor,
  ) {
    return pw.Container(
      width: 110,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: labelColor),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: valColor),
          ),
          if (subtitle.isNotEmpty) ...[
            pw.SizedBox(height: 1),
            pw.Text(
              subtitle,
              style: pw.TextStyle(fontSize: 7, color: labelColor),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildNodeTable(
    BenchmarkResult result,
    PdfColor navyDark,
    PdfColor borderLight,
    PdfColor textMuted,
  ) {
    final nodes = result.nodeSummaries;
    if (nodes.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'CLUSTER TOPOLOGY & NODE HARDWARE',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: textMuted,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Hardware allocation and real-time resource utilization across cluster nodes, identifying active roles (master, data, ingest), CPU load, JVM heap allocations, and disk storage consumption.',
          style: pw.TextStyle(fontSize: 7.5, color: textMuted),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: borderLight, width: 0.5),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('F1F5F9')),
              children: [
                _th('Node Name'),
                _th('Roles'),
                _th('CPU Utilization'),
                _th('JVM Heap Usage'),
                _th('Disk Capacity'),
              ],
            ),
            ...nodes.map((n) {
              final roles = (n['roles'] as List<dynamic>?)?.join(', ') ?? '-';
              final cpu = '${(n['cpuPercent'] as num?)?.toStringAsFixed(1) ?? "0"}%';
              final heapMb = ((n['heapUsedBytes'] as num?)?.toInt() ?? 0) ~/ (1024 * 1024);
              final heapMaxMb = ((n['heapMaxBytes'] as num?)?.toInt() ?? 0) ~/ (1024 * 1024);
              final heapStr = '$heapMb MB / $heapMaxMb MB (${(n['heapPercent'] as num?)?.toStringAsFixed(0) ?? "0"}%)';
              final diskGb = ((n['diskUsedBytes'] as num?)?.toInt() ?? 0) / (1024 * 1024 * 1024);
              final diskTotGb = ((n['diskTotalBytes'] as num?)?.toInt() ?? 0) / (1024 * 1024 * 1024);
              final diskStr = '${diskGb.toStringAsFixed(1)} GB / ${diskTotGb.toStringAsFixed(1)} GB';

              return pw.TableRow(
                children: [
                  _td(n['name']?.toString() ?? '-'),
                  _td(roles),
                  _td(cpu),
                  _td(heapStr),
                  _td(diskStr),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildLatencyTable(
    BenchmarkResult result,
    PdfColor navyDark,
    PdfColor borderLight,
    PdfColor textMuted,
    PdfColor primaryBlue,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'LATENCY PROFILE & PERCENTILES',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: textMuted,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Statistical distribution of iteration execution runtimes. p50 reflects median operational latency; p90, p95, and p99 measure tail latencies to evaluate cluster consistency and stability under peak stress.',
          style: pw.TextStyle(fontSize: 7.5, color: textMuted),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: borderLight, width: 0.5),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('F1F5F9')),
              children: [
                _th('Min Latency'),
                _th('Avg Latency'),
                _th('p50 (Median)'),
                _th('p90'),
                _th('p95'),
                _th('p99'),
                _th('Max Latency'),
              ],
            ),
            pw.TableRow(
              children: [
                _td('${(result.minIterationMs / 1000).toStringAsFixed(2)}s'),
                _td('${(result.avgIterationMs / 1000).toStringAsFixed(2)}s'),
                _td('${(result.p50Ms / 1000).toStringAsFixed(2)}s'),
                _td('${(result.p90Ms / 1000).toStringAsFixed(2)}s'),
                _td('${(result.p95Ms / 1000).toStringAsFixed(2)}s'),
                _td('${(result.p99Ms / 1000).toStringAsFixed(2)}s'),
                _td('${(result.maxIterationMs / 1000).toStringAsFixed(2)}s'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildIterationTable(
    BenchmarkResult result,
    PdfColor navyDark,
    PdfColor borderLight,
    PdfColor textMuted,
  ) {
    final durations = result.iterationDurationsMs;
    if (durations.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ITERATION-BY-ITERATION DURATION LOG',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: textMuted,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Chronological log of individual benchmark iterations, showing elapsed runtime in milliseconds and seconds alongside percentage variance relative to the average to track warmup effects and performance degradation.',
          style: pw.TextStyle(fontSize: 7.5, color: textMuted),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: borderLight, width: 0.5),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('F1F5F9')),
              children: [
                _th('Iteration #'),
                _th('Duration (ms)'),
                _th('Duration (sec)'),
                _th('Variance from Avg'),
              ],
            ),
            ...List.generate(durations.length, (i) {
              final ms = durations[i];
              final sec = (ms / 1000).toStringAsFixed(2);
              final variance = result.avgIterationMs > 0
                  ? ((ms - result.avgIterationMs) / result.avgIterationMs * 100).toStringAsFixed(1)
                  : '0.0';
              final varianceStr = variance.startsWith('-') ? '$variance%' : '+$variance%';

              return pw.TableRow(
                children: [
                  _td('Iteration ${i + 1}'),
                  _td('${ms.toStringAsFixed(0)} ms'),
                  _td('$sec s'),
                  _td(varianceStr),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildResourceSnapshotsTable(
    BenchmarkResult result,
    PdfColor navyDark,
    PdfColor borderLight,
    PdfColor textMuted,
  ) {
    final cpuList = result.cpuSnapshots;
    final heapList = result.heapSnapshots;
    final rowCount = cpuList.length < 8 ? cpuList.length : 8;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SYSTEM RESOURCE SATURATION SNAPSHOTS',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: textMuted,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Periodic telemetry samples captured during active workload execution, tracking cluster-wide CPU utilization percentage and JVM heap pressure over time to identify resource bottlenecks.',
          style: pw.TextStyle(fontSize: 7.5, color: textMuted),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: borderLight, width: 0.5),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('F1F5F9')),
              children: [
                _th('Sample #'),
                _th('Timestamp'),
                _th('Cluster Avg CPU %'),
                _th('JVM Heap Used %'),
              ],
            ),
            ...List.generate(rowCount, (i) {
              final cpuSnap = cpuList[i];
              final heapSnap = i < heapList.length ? heapList[i] : null;

              final timeStr = cpuSnap['time']?.toString() ?? '-';
              final cpuVal = '${((cpuSnap['clusterAvgCpu'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}%';
              final heapVal = heapSnap != null
                  ? '${((heapSnap['heapPercent'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}%'
                  : '-';

              return pw.TableRow(
                children: [
                  _td('Snapshot ${i + 1}'),
                  _td(timeStr),
                  _td(cpuVal),
                  _td(heapVal),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildConfigTable(
    BenchmarkResult result,
    PdfColor navyDark,
    PdfColor borderLight,
    PdfColor textMuted,
  ) {
    final settings = result.settingsUsed;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'BENCHMARK EXECUTION CONFIGURATION',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: textMuted,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Audit of parameters, batch sizes, dataset targets, shard topologies, and enrich settings applied during this benchmark execution to ensure repeatable testing conditions.',
          style: pw.TextStyle(fontSize: 7.5, color: textMuted),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: borderLight, width: 0.5),
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('F1F5F9')),
              children: [
                _th('Parameter'),
                _th('Value'),
                _th('Description'),
              ],
            ),
            pw.TableRow(children: [
              _td('Bulk Batch Size'),
              _td('${settings['bulkBatchSize'] ?? 10000} docs'),
              _td('Batch size for bulk indexing raw WAF logs'),
            ]),
            pw.TableRow(children: [
              _td('Target Raw Index Size'),
              _td('${settings['targetSizeGb'] ?? 10} GB'),
              _td('Target data volume generated before running benchmark'),
            ]),
            pw.TableRow(children: [
              _td('Shard Layout'),
              _td('${settings['primaryShards'] ?? 5} Primaries, ${settings['replicaShards'] ?? 0} Replicas'),
              _td('Elasticsearch index shard distribution'),
            ]),
            pw.TableRow(children: [
              _td('Concurrent Workers'),
              _td('${settings['workers'] ?? 8} Parallel Worker Indices'),
              _td('Dedicates isolated destination indices and Lucene IndexWriters per worker to maximize CPU saturation'),
            ]),
            pw.TableRow(children: [
              _td('Ingest Pipeline Processors'),
              _td('Extreme: Shannon Entropy, OWASP Deep Regex, Urldecode, KV, Enrich, Redact, SHA-512, SHA-256'),
              _td('Heavy compute pipeline executed across parallel worker indices to saturate cluster CPUs'),
            ]),
            pw.TableRow(children: [
              _td('Threat Intel Enrich Records'),
              _td('${settings['threatIntelRecords'] ?? 50000} records'),
              _td('Enrich policy IP threat lookup dataset'),
            ]),
            pw.TableRow(children: [
              _td('Async Search Aggregations'),
              _td('Date Histogram, Terms, Cardinality, Wildcard Filter'),
              _td('Multi-level aggregations executed to saturate search subsystem'),
            ]),
          ],
        ),
      ],
    );
  }

  static pw.Widget _th(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('1B1C3A'),
        ),
      ),
    );
  }

  static pw.Widget _td(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          color: PdfColor.fromHex('334155'),
        ),
      ),
    );
  }
}
