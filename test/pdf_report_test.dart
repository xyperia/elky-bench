// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:elky_bench/models/benchmark_result.dart';
import 'package:elky_bench/services/pdf_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PdfReportService generates valid anti-slop PDF report', () async {
    final result = BenchmarkResult(
      id: 'test-report-uuid-001',
      clusterId: 'c-001',
      clusterName: 'AWS Found Production',
      clusterUrl: 'https://elasticsearch.internal:9200',
      scenarioType: 'ingest',
      startTime: DateTime.now().subtract(const Duration(minutes: 12)),
      endTime: DateTime.now(),
      totalDurationMs: 720000,
      iterationsCompleted: 5,
      avgIterationMs: 24500,
      minIterationMs: 21200,
      maxIterationMs: 28900,
      p50Ms: 24100,
      p90Ms: 27800,
      p95Ms: 28400,
      p99Ms: 28850,
      status: 'completed',
      rawIndexName: 'elkybench-waf-raw',
      targetIndexSizeFormatted: '10.0 GB',
      totalDocsIngested: 100000,
      cpuSnapshots: [
        {'time': '12:00:10', 'clusterAvgCpu': 45.2},
        {'time': '12:00:20', 'clusterAvgCpu': 78.6},
        {'time': '12:00:30', 'clusterAvgCpu': 89.1},
        {'time': '12:00:40', 'clusterAvgCpu': 92.4},
      ],
      heapSnapshots: [
        {'time': '12:00:10', 'heapPercent': 55.0, 'heapUsedBytes': 2300000000},
        {'time': '12:00:20', 'heapPercent': 68.4, 'heapUsedBytes': 2900000000},
        {'time': '12:00:30', 'heapPercent': 74.2, 'heapUsedBytes': 3150000000},
        {'time': '12:00:40', 'heapPercent': 79.5, 'heapUsedBytes': 3400000000},
      ],
      iterationDurationsMs: [21200, 23500, 24100, 24800, 28900],
      clusterVersion: '9.5.2',
      clusterNodesCount: 5,
      nodeSummaries: [
        {
          'name': 'instance-0000000020',
          'roles': ['data_content', 'data_hot', 'ingest'],
          'cpuPercent': 82.5,
          'heapUsedBytes': 3033441024,
          'heapMaxBytes': 4294967296,
          'heapPercent': 70.6,
          'diskUsedBytes': 120711188480,
          'diskTotalBytes': 257698037760,
          'diskPercent': 46.8,
        },
      ],
      settingsUsed: {
        'bulkBatchSize': 10000,
        'targetSizeGb': 10.0,
        'primaryShards': 5,
        'replicaShards': 0,
        'threatIntelRecords': 50000,
      },
    );

    final file = await PdfReportService.generateReport(result);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(1000));

    final bytes = await file.readAsBytes();
    // Validate PDF magic bytes: %PDF-
    final magic = String.fromCharCodes(bytes.sublist(0, 5));
    expect(magic, equals('%PDF-'));
    print('Generated PDF Report at: ${file.path} (${bytes.length} bytes)');
  });
}
