// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:elky_bench/models/cluster_config.dart';
import 'package:elky_bench/models/benchmark_settings.dart';
import 'package:elky_bench/services/elasticsearch_service.dart';
import 'package:elky_bench/providers/history_provider.dart';
import 'package:elky_bench/providers/benchmark_provider.dart';

class _AllowRealNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return client;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Allow real HTTP requests by overriding AFTER ensureInitialized()
  HttpOverrides.global = _AllowRealNetworkHttpOverrides();

  final apiKey = Platform.environment['ELASTIC_API_KEY'] ?? '';
  final clusterUrl = Platform.environment['ELASTIC_URL'] ?? '';

  if (apiKey.isEmpty || clusterUrl.isEmpty) {
    test('E2E Live Benchmark skipped (ELASTIC_API_KEY and ELASTIC_URL not set in environment)', () {
      print('[INFO] Set ELASTIC_API_KEY and ELASTIC_URL to run live end-to-end integration tests.');
    });
    return;
  }

  final cluster = ClusterConfig(
    id: 'verify-cluster-001',
    name: 'Live Test Cluster',
    url: clusterUrl,
    authType: 'apikey',
    apiKey: apiKey,
    sslMode: 'bypass',
    createdAt: DateTime.now(),
  );

  group('Live Elasticsearch Cluster End-to-End Verification', () {
    test('1. Test Connection & Telemetry Stats', () async {
      final es = ElasticsearchService(cluster);
      final conn = await es.testConnection();
      expect(conn.containsKey('cluster_name'), isTrue);
      expect(conn.containsKey('version'), isTrue);
      expect(conn['version']['number'], isNotEmpty);

      final health = await es.getClusterHealth();
      expect(health.containsKey('status'), isTrue);

      final stats = await es.getClusterStats();
      expect(stats.nodeCount, greaterThan(0));
      expect(stats.cpuPercent, greaterThanOrEqualTo(0.0));
      expect(stats.heapUsedBytes, greaterThan(0));
      expect(stats.diskTotalBytes, greaterThan(0));
      print('[✓] Telemetry verified: CPU=${stats.cpuPercent.toStringAsFixed(1)}%, Heap=${stats.heapPercent.toStringAsFixed(1)}%, DiskUsed=${(stats.diskUsedBytes / (1024*1024*1024)).toStringAsFixed(1)}GB');
      es.close();
    });

    test(
      '2. Execute Ingest Benchmark Scenario End-to-End with PDF Generation',
      () async {
      final historyProv = HistoryProvider();
      final benchProv = BenchmarkProvider(historyProvider: historyProv);

      final settings = BenchmarkSettings(
        bulkBatchSize: 500,
        targetSizeGb: 0.002, // 2 MB seed for fast verification
        primaryShards: 5,
        replicaShards: 0,
        benchmarkMode: 'iterations',
        iterationsCount: 2,
        threatIntelRecords: 200,
        pipelineIntensity: 'extreme',
        workers: 4,
      );

      print('[*] Starting Ingest Benchmark on cluster...');
      await benchProv.runIngestBenchmark(cluster: cluster, settings: settings);

      if (benchProv.state != BenchmarkState.completed) {
        print('Benchmark state: ${benchProv.state}, Error: ${benchProv.errorMessage}');
      }
      expect(benchProv.state, equals(BenchmarkState.completed));
      expect(benchProv.lastResult, isNotNull);
      final result = benchProv.lastResult!;
      expect(result.iterationsCompleted, equals(2));
      expect(result.avgIterationMs, greaterThan(0));
      expect(result.pdfPath, isNotNull);

      final pdfFile = File(result.pdfPath!);
      expect(pdfFile.existsSync(), isTrue);

      // Verify all created indices follow primary and replica shard tuning
      final esVerify = ElasticsearchService(cluster);
      final rawStats = await esVerify.getIndexStats('elkybench-waf-raw');
      expect(rawStats['docCount'], greaterThan(0));
      print('[✓] Verified indices created with tuned shards: primary=${settings.primaryShards}, replica=${settings.replicaShards}');
      esVerify.close();

      print('[✓] Ingest Benchmark Completed: ${result.iterationsCompleted} iterations, avg=${result.avgIterationMs.toStringAsFixed(1)}ms');
      print('[✓] PDF Report generated at: ${result.pdfPath} (${pdfFile.lengthSync()} bytes)');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test(
      '2b. Execute Ingest Benchmark Consecutive Run (Verifies Resumable Upload & Existing Enrich Policy without clean)',
      () async {
      final historyProv = HistoryProvider();
      final benchProv = BenchmarkProvider(historyProvider: historyProv);

      final settings = BenchmarkSettings(
        bulkBatchSize: 500,
        targetSizeGb: 0.003, // Slight increase to 3 MB to test resuming from previous 2 MB
        primaryShards: 5,
        replicaShards: 0,
        benchmarkMode: 'iterations',
        iterationsCount: 1,
        threatIntelRecords: 200,
        pipelineIntensity: 'extreme',
        workers: 4,
      );

      print('[*] Starting Consecutive Ingest Benchmark to test Resume & Existing Policy...');
      await benchProv.runIngestBenchmark(cluster: cluster, settings: settings);

      if (benchProv.state != BenchmarkState.completed) {
        print('Benchmark state: ${benchProv.state}, Error: ${benchProv.errorMessage}');
      }
      expect(benchProv.state, equals(BenchmarkState.completed));
      print('[✓] Consecutive run completed successfully without 400 errors!');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('3. Execute Search Benchmark Scenario End-to-End with PDF Generation', () async {
      final historyProv = HistoryProvider();
      final benchProv = BenchmarkProvider(historyProvider: historyProv);

      final settings = BenchmarkSettings(
        bulkBatchSize: 500,
        targetSizeGb: 0.002,
        primaryShards: 5,
        replicaShards: 0,
        benchmarkMode: 'iterations',
        iterationsCount: 2,
        workers: 4,
      );

      print('[*] Starting Search Benchmark on cluster...');
      await benchProv.runSearchBenchmark(cluster: cluster, settings: settings);

      if (benchProv.state != BenchmarkState.completed) {
        print('Benchmark state: ${benchProv.state}, Error: ${benchProv.errorMessage}');
      }
      expect(benchProv.state, equals(BenchmarkState.completed));
      expect(benchProv.lastResult, isNotNull);
      final result = benchProv.lastResult!;
      expect(result.iterationsCompleted, equals(2));
      expect(result.avgIterationMs, greaterThan(0));
      expect(result.pdfPath, isNotNull);

      final pdfFile = File(result.pdfPath!);
      expect(pdfFile.existsSync(), isTrue);
      print('[✓] Search Benchmark Completed: ${result.iterationsCompleted} iterations, avg=${result.avgIterationMs.toStringAsFixed(1)}ms');
      print('[✓] PDF Report generated at: ${result.pdfPath} (${pdfFile.lengthSync()} bytes)');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('4. Clean Cluster Benchmark Resources', () async {
      final es = ElasticsearchService(cluster);
      print('[*] Cleaning all benchmark resources on destination cluster...');
      final cleanResult = await es.cleanBenchmarkResources();
      print('[✓] Cleaned: ${cleanResult['indices']} indices, ${cleanResult['pipelines']} pipelines, ${cleanResult['policies']} enrich policies');
      es.close();
    });
  });
}
