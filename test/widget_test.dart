import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:elky_bench/main.dart';
import 'package:elky_bench/models/cluster_config.dart';
import 'package:elky_bench/models/benchmark_settings.dart';
import 'package:elky_bench/models/benchmark_result.dart';
import 'package:elky_bench/models/cluster_stats.dart';
import 'package:elky_bench/services/log_generator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LogGeneratorService Tests', () {
    test('generateWafLog produces valid RFC3164 Syslog + CEF format', () {
      final log = LogGeneratorService.generateWafLog();
      expect(log, startsWith('<134>'));
      expect(log, contains('CEF:0|TebiSecurity|TebiProtec|4.2.1-rc9|'));
      expect(log, contains('rt='));
      expect(log, contains('src='));
      expect(log, contains('spt='));
      expect(log, contains('dst='));
      expect(log, contains('dpt='));
      expect(log, contains('proto='));
      expect(log, contains('act='));
      expect(log, contains('app='));
      expect(log, contains('requestMethod='));
      expect(log, contains('request='));
      expect(log, contains('requestClientApplication='));
      expect(log, contains('cs1Label=RuleGroup'));
      expect(log, contains('cs2Label=MatchedPayload'));
      expect(log, contains('dvchost='));
    });

    test('generateBatch produces multiple distinct documents with timestamps', () {
      final batch = LogGeneratorService.generateBatch(10);
      expect(batch.length, equals(10));
      for (final doc in batch) {
        expect(doc.containsKey('@timestamp'), isTrue);
        expect(doc.containsKey('message'), isTrue);
        expect(doc['message'], contains('CEF:0|'));
      }
    });

    test('generateThreatIntelRecords produces structured enrichment data', () {
      final records = LogGeneratorService.generateThreatIntelRecords(5);
      expect(records.length, equals(5));
      for (final r in records) {
        expect(r.containsKey('ip'), isTrue);
        expect(r.containsKey('threat_type'), isTrue);
        expect(r.containsKey('confidence_score'), isTrue);
        expect(r.containsKey('country_code'), isTrue);
        expect(r.containsKey('asn'), isTrue);
      }
    });
  });

  group('Data Models Serialization Tests', () {
    test('ClusterConfig toJson / fromJson roundtrip', () {
      final config = ClusterConfig(
        id: 'test-uuid-1',
        name: 'Production ES',
        url: 'https://elasticsearch.internal:9200',
        authType: 'apikey',
        apiKey: 'VGVzdEFwaUtleUlkOlRlc3RBcGlLZXlTZWNyZXQ=',
        sslMode: 'bypass',
        createdAt: DateTime.now(),
      );

      final json = config.toJson();
      final restored = ClusterConfig.fromJson(json);

      expect(restored.id, equals(config.id));
      expect(restored.name, equals(config.name));
      expect(restored.url, equals(config.url));
      expect(restored.authType, equals('apikey'));
      expect(restored.apiKey, equals(config.apiKey));
      expect(restored.sslMode, equals('bypass'));
    });

    test('BenchmarkSettings default and copy values', () {
      final settings = BenchmarkSettings();
      expect(settings.bulkBatchSize, equals(10000));
      expect(settings.targetSizeGb, equals(1.0));
      expect(settings.primaryShards, equals(5));
      expect(settings.replicaShards, equals(0));
      expect(settings.monitorIntervalSec, equals(10));

      final json = settings.toJson();
      final restored = BenchmarkSettings.fromJson(json);
      expect(restored.bulkBatchSize, equals(10000));
    });

    test('ClusterStats byte formatting', () {
      expect(ClusterStats.formatBytes(0), equals('0 B'));
      expect(ClusterStats.formatBytes(1024), equals('1.0 KB'));
      expect(ClusterStats.formatBytes(1048576), equals('1.0 MB'));
      expect(ClusterStats.formatBytes(1073741824), equals('1.0 GB'));
    });

    test('BenchmarkResult toJson / fromJson roundtrip', () {
      final result = BenchmarkResult(
        id: 'bench-1',
        clusterId: 'cluster-1',
        clusterName: 'Test Cluster',
        clusterUrl: 'https://test.es',
        scenarioType: 'ingest',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(minutes: 5)),
        totalDurationMs: 300000,
        iterationsCompleted: 5,
        avgIterationMs: 60000,
        minIterationMs: 55000,
        maxIterationMs: 65000,
        p50Ms: 60000,
        p90Ms: 64000,
        p95Ms: 64500,
        p99Ms: 64900,
        status: 'completed',
        rawIndexName: 'elkybench-waf-raw',
        targetIndexSizeFormatted: '10 GB',
        totalDocsIngested: 100000,
        cpuSnapshots: [],
        heapSnapshots: [],
        iterationDurationsMs: [55000, 58000, 60000, 62000, 65000],
        clusterVersion: '9.5.2',
        clusterNodesCount: 5,
        nodeSummaries: [],
        settingsUsed: {},
      );

      final json = result.toJson();
      final restored = BenchmarkResult.fromJson(json);

      expect(restored.id, equals('bench-1'));
      expect(restored.scenarioType, equals('ingest'));
      expect(restored.iterationsCompleted, equals(5));
      expect(restored.avgIterationMs, equals(60000));
    });
  });

  group('UI Smoke Test', () {
    testWidgets('ElkyBenchApp builds without crashing', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const ElkyBenchApp());
      await tester.pumpAndSettle();

      expect(find.text('Elky Bench'), findsOneWidget);
      expect(find.text('Elasticsearch Benchmark'), findsOneWidget);
      expect(find.text('MAIN NAVIGATION'), findsOneWidget);
      expect(find.text('Clusters'), findsOneWidget);
      expect(find.text('Benchmark'), findsOneWidget);
      expect(find.text('History & Reports'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('ClustersScreen handles narrow window resize without overflow or clipping into buttons', (WidgetTester tester) async {
      // Narrow desktop window (850x600)
      tester.view.physicalSize = const Size(850, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const ElkyBenchApp());
      await tester.pumpAndSettle();

      // Ensure no overflow errors occurred
      expect(tester.takeException(), isNull);
    });
  });
}
