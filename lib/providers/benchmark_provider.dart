import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/benchmark_result.dart';
import '../models/benchmark_settings.dart';
import '../models/cluster_config.dart';
import '../models/cluster_stats.dart';
import '../services/elasticsearch_service.dart';
import '../services/log_generator_service.dart';
import '../services/pdf_report_service.dart';
import 'history_provider.dart';

enum BenchmarkState { idle, preparing, running, completed, error, stopped }

class BenchmarkProvider extends ChangeNotifier {
  final HistoryProvider historyProvider;
  final Uuid _uuid = const Uuid();

  BenchmarkState _state = BenchmarkState.idle;
  String _currentPhase = '';
  double _progress = 0.0; // 0.0 to 1.0
  int _currentIteration = 0;
  int _totalIterations = 0;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;
  Timer? _samplerTimer;
  bool _stopRequested = false;

  double _liveCpu = 0.0;
  double _liveHeap = 0.0;
  double _peakCpu = 0.0;
  double _peakHeap = 0.0;
  int _liveDiskUsed = 0;
  int _totalDocsIngested = 0;
  int? _estimatedRemainingSeconds;
  String? _errorMessage;
  BenchmarkResult? _lastResult;

  BenchmarkState get state => _state;
  String get currentPhase => _currentPhase;
  double get progress => _progress;
  int get currentIteration => _currentIteration;
  int get totalIterations => _totalIterations;
  int get elapsedSeconds => _elapsedSeconds;
  int? get estimatedRemainingSeconds => _estimatedRemainingSeconds;
  bool get isRunning => _state == BenchmarkState.running || _state == BenchmarkState.preparing;
  double get liveCpu => _liveCpu;
  double get liveHeap => _liveHeap;
  double get peakCpu => _peakCpu;
  double get peakHeap => _peakHeap;
  int get liveDiskUsed => _liveDiskUsed;
  int get totalDocsIngested => _totalDocsIngested;
  String? get errorMessage => _errorMessage;
  BenchmarkResult? get lastResult => _lastResult;
  ElasticsearchService? _currentEsService;

  BenchmarkProvider({required this.historyProvider});

  void stopBenchmark() {
    if (isRunning) {
      _stopRequested = true;
      _currentEsService?.cancelAllReindexTasks();
      _stopContinuousSampler();
      _currentPhase = 'Stopping benchmark gracefully...';
      notifyListeners();
    }
  }

  void reset() {
    _stopContinuousSampler();
    _state = BenchmarkState.idle;
    _currentPhase = '';
    _progress = 0.0;
    _currentIteration = 0;
    _totalIterations = 0;
    _elapsedSeconds = 0;
    _peakCpu = 0.0;
    _peakHeap = 0.0;
    _estimatedRemainingSeconds = null;
    _errorMessage = null;
    _lastResult = null;
    notifyListeners();
  }

  void _startTimer() {
    _elapsedSeconds = 0;
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
  }

  void _stopTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  void _startContinuousSampler(
    ElasticsearchService es,
    List<Map<String, dynamic>> cpuList,
    List<Map<String, dynamic>> heapList,
  ) {
    _samplerTimer?.cancel();
    _samplerTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!isRunning) return;
      await _sampleStats(es, cpuList, heapList);
      notifyListeners();
    });
  }

  void _stopContinuousSampler() {
    _samplerTimer?.cancel();
    _samplerTimer = null;
  }

  // --- Ingest Benchmark Scenario ---
  Future<void> runIngestBenchmark({
    required ClusterConfig cluster,
    required BenchmarkSettings settings,
  }) async {
    if (isRunning) return;

    _state = BenchmarkState.preparing;
    _stopRequested = false;
    _errorMessage = null;
    _lastResult = null;
    _progress = 0.0;
    _totalDocsIngested = 0;
    _currentIteration = 0;
    _peakCpu = 0.0;
    _peakHeap = 0.0;
    _estimatedRemainingSeconds = null;
    _totalIterations = settings.benchmarkMode == 'iterations' ? settings.iterationsCount : 0;
    _currentPhase = 'Connecting to Elasticsearch cluster...';
    notifyListeners();
    _startTimer();

    final es = ElasticsearchService(cluster);
    _currentEsService = es;
    final startTime = DateTime.now();
    final List<Map<String, dynamic>> cpuSnapshots = [];
    final List<Map<String, dynamic>> heapSnapshots = [];
    final List<double> iterationDurations = [];
    String clusterVersion = 'unknown';
    int nodeCount = 0;
    List<Map<String, dynamic>> nodeSummaries = [];

    try {
      // 0. Cancel any orphan reindex tasks across cluster before starting
      await es.cancelAllReindexTasks();

      // 1. Cluster info & baseline stats
      final connInfo = await es.testConnection();
      clusterVersion = connInfo['version']?['number']?.toString() ?? '9.5.2';

      final initialStats = await es.getClusterStats();
      nodeCount = initialStats.nodeCount;
      nodeSummaries = initialStats.nodes.map((n) => n.toJson()).toList();
      _liveCpu = initialStats.cpuPercent;
      _liveHeap = initialStats.heapPercent;
      _liveDiskUsed = initialStats.diskUsedBytes;
      _peakCpu = _liveCpu;
      _peakHeap = _liveHeap;
      _startContinuousSampler(es, cpuSnapshots, heapSnapshots);
      notifyListeners();

      // 2. Prepare or check raw dataset index (Resumable)
      final rawIndex = 'elkybench-waf-raw';
      _currentPhase = 'Checking raw WAF dataset index ($rawIndex)...';
      notifyListeners();

      final rawExists = await es.indexExists(rawIndex);
      if (rawExists) {
        final currentShards = await es.getIndexPrimaryShards(rawIndex);
        if (currentShards != null && currentShards != settings.primaryShards) {
          _currentPhase = 'Recreating raw index to match tuned shard count (${settings.primaryShards} shards)...';
          notifyListeners();
          await es.deleteIndex(rawIndex);
        }
      }

      final rawStillExists = await es.indexExists(rawIndex);
      if (!rawStillExists) {
        _currentPhase = 'Creating raw WAF log index (${settings.primaryShards} shards)...';
        notifyListeners();
        await es.createIndex(
          rawIndex,
          primaryShards: settings.primaryShards,
          replicaShards: settings.replicaShards,
          mappings: {
            'properties': {
              '@timestamp': {'type': 'date'},
              'message': {'type': 'text'},
            }
          },
        );
      } else {
        // Ensure tuned replica count is applied to existing index
        await es.updateIndexSettings(rawIndex, {'index.number_of_replicas': settings.replicaShards});
      }

      final existingIndexStats = await es.getIndexStats(rawIndex);
      final int targetDocs = (settings.targetSizeGb * 4000000).round();
      int currentBytes = existingIndexStats['primarySizeBytes'] as int? ?? 0;
      _totalDocsIngested = existingIndexStats['docCount'] as int? ?? 0;

      if (_totalDocsIngested < targetDocs) {
        final seedStartTime = DateTime.now();
        final int initialDocs = _totalDocsIngested;

        if (_totalDocsIngested > 0) {
          final curM = (_totalDocsIngested / 1000000).toStringAsFixed(2);
          final totM = (targetDocs / 1000000).toStringAsFixed(2);
          final remM = ((targetDocs - _totalDocsIngested) / 1000000).toStringAsFixed(2);
          _currentPhase = 'Resuming upload: $curM M / $totM M docs indexed (${ClusterStats.formatBytes(currentBytes)}). Remaining: $remM M docs...';
          _progress = (_totalDocsIngested / targetDocs).clamp(0.0, 1.0) * 0.4;
          notifyListeners();
        } else {
          _currentPhase = 'Generating and bulk ingesting random WAF logs...';
          notifyListeners();
        }

        while (_totalDocsIngested < targetDocs && !_stopRequested) {
          final batch = LogGeneratorService.generateBatch(settings.bulkBatchSize);
          await es.bulkIngest(rawIndex, batch);
          _totalDocsIngested += batch.length;

          final elapsedSec = DateTime.now().difference(seedStartTime).inSeconds;
          final docsIngestedThisSession = _totalDocsIngested - initialDocs;

          String rateStr = '';
          String etaStr = '';
          if (elapsedSec >= 2 && docsIngestedThisSession > 0) {
            final docsPerSec = docsIngestedThisSession / elapsedSec;
            rateStr = ' • ${(docsPerSec).round()} docs/s';

            final remainingDocs = targetDocs - _totalDocsIngested;
            if (remainingDocs > 0 && docsPerSec > 0) {
              final remSec = (remainingDocs / docsPerSec).ceil();
              _estimatedRemainingSeconds = remSec;
              final m = remSec ~/ 60;
              final s = remSec % 60;
              etaStr = ' • ETA: ${m}m ${s.toString().padLeft(2, '0')}s';
            } else {
              _estimatedRemainingSeconds = 0;
            }
          }

          // Progress calculation: 0.0 to 0.4 for seeding phase
          final seedProgress = (_totalDocsIngested / targetDocs).clamp(0.0, 1.0) * 0.4;
          _progress = seedProgress;
          final curMStr = (_totalDocsIngested / 1000000).toStringAsFixed(2);
          final totMStr = (targetDocs / 1000000).toStringAsFixed(2);
          final targetGbStr = settings.targetSizeGb.toStringAsFixed(2);
          _currentPhase = 'Ingesting raw logs: $curMStr M / $totMStr M docs ($targetGbStr GB target)$rateStr$etaStr';

          // Snapshot live metrics
          _sampleStats(es, cpuSnapshots, heapSnapshots);
          notifyListeners();
        }

        await es.refreshIndex(rawIndex);
        final postStats = await es.getIndexStats(rawIndex);
        currentBytes = postStats['primarySizeBytes'] as int? ?? currentBytes;
      } else {
        _progress = 0.4;
        _currentPhase = 'Found complete seed dataset: $_totalDocsIngested docs (${ClusterStats.formatBytes(currentBytes)}). Ready!';
        notifyListeners();
      }

      if (_stopRequested) {
        _stopTimer();
        _state = BenchmarkState.idle;
        _currentPhase = 'Benchmark cancelled by user.';
        _progress = 0.0;
        notifyListeners();
        return;
      }

      // 3. Setup Threat Intel & Enrich Policy
      _currentPhase = 'Setting up Threat Intelligence enrichment index (${settings.threatIntelRecords} records)...';
      _progress = 0.45;
      notifyListeners();

      final enrichIndex = 'elkybench-threat-intel-src';
      final policyName = 'elkybench-threat-policy';
      final threatRecords = LogGeneratorService.generateThreatIntelRecords(
        min(settings.threatIntelRecords, 20000), // Cap at 20K per batch for rapid setup
      );
      await es.setupThreatIntelEnrichPolicy(
        enrichIndexName: enrichIndex,
        policyName: policyName,
        threatRecords: threatRecords,
        primaryShards: settings.primaryShards,
        replicaShards: settings.replicaShards,
      );

      // 4. Create Heavy Ingest Pipeline
      _currentPhase = 'Configuring high-saturation ingest pipeline (${settings.pipelineIntensity.toUpperCase()})...';
      _progress = 0.5;
      notifyListeners();

      final pipelineId = 'elkybench-heavy-waf-pipeline';
      await es.createHeavyIngestPipeline(
        pipelineId: pipelineId,
        enrichPolicyName: policyName,
        intensity: settings.pipelineIntensity,
      );

      // 5. Ingest Reindex Benchmarking Loop
      _state = BenchmarkState.running;
      notifyListeners();

      final maxIter = settings.benchmarkMode == 'iterations' ? settings.iterationsCount : 9999;
      int iter = 0;
      while (!_stopRequested) {
        if (settings.benchmarkMode == 'iterations') {
          if (iter >= maxIter) break;
        }

        iter++;
        _currentIteration = iter;
        _currentPhase = 'Executing Reindex Iteration $iter (${settings.workers} Parallel Worker Indices)...';
        notifyListeners();

        final destIndex = 'elkybench-waf-enriched-iter-$iter';
        final iterStartTime = DateTime.now();

        try {
          final iterResult = await es.executeReindexIteration(
            sourceIndex: rawIndex,
            destIndex: destIndex,
            pipelineId: pipelineId,
            primaryShards: settings.primaryShards,
            replicaShards: settings.replicaShards,
            workers: settings.workers,
            onProgress: (processedDocs, totalDocs, frac) {
              final elapsedIterSec = DateTime.now().difference(iterStartTime).inSeconds;
              String rateStr = '';
              if (elapsedIterSec >= 2 && processedDocs > 0) {
                final docsPerSec = (processedDocs / elapsedIterSec).round();
                rateStr = ' • $docsPerSec docs/s';
              }
              final pDocsM = (processedDocs / 1000000).toStringAsFixed(1);
              final tDocsM = (totalDocs / 1000000).toStringAsFixed(1);
              final pct = (frac * 100).toStringAsFixed(1);

              if (settings.benchmarkMode == 'iterations') {
                final iterBase = 0.5 + ((iter - 1) / maxIter * 0.5);
                _progress = (iterBase + (frac * (0.5 / maxIter))).clamp(0.0, 1.0);

                if (elapsedIterSec >= 2 && frac > 0.01) {
                  final estTotalIterSec = elapsedIterSec / frac;
                  final remThisIterSec = estTotalIterSec - elapsedIterSec;
                  final remSubsequentItersSec = (maxIter - iter) * estTotalIterSec;
                  _estimatedRemainingSeconds = (remThisIterSec + remSubsequentItersSec).ceil();
                }
              } else {
                // 'no_iterations' (Indefinitely) - continuous runs until manually stopped
                _progress = (0.5 + (frac * 0.5)).clamp(0.0, 1.0);
                _estimatedRemainingSeconds = null;
              }

              String etaStr = '';
              if (_estimatedRemainingSeconds != null && _estimatedRemainingSeconds! > 0) {
                final m = _estimatedRemainingSeconds! ~/ 60;
                final s = _estimatedRemainingSeconds! % 60;
                etaStr = ' • ETA: ${m}m ${s.toString().padLeft(2, '0')}s';
              }

              final iterLabel = settings.benchmarkMode == 'iterations' ? '$iter/$maxIter' : '$iter';
              _currentPhase = 'Reindexing Iteration $iterLabel (${settings.workers} Workers): $pDocsM M / $tDocsM M docs ($pct%)$rateStr$etaStr';
              notifyListeners();
            },
            isStopRequested: () => _stopRequested,
          );

          final durationMs = (iterResult['durationMs'] as num).toDouble();
          iterationDurations.add(durationMs);

          // Snapshot stats
          await _sampleStats(es, cpuSnapshots, heapSnapshots);

          // Update progress & ETA
          if (settings.benchmarkMode == 'iterations') {
            _progress = 0.5 + (iter / maxIter * 0.5);
            if (iterationDurations.isNotEmpty) {
              final avgMs = iterationDurations.reduce((a, b) => a + b) / iterationDurations.length;
              final remainingIters = maxIter - iter;
              _estimatedRemainingSeconds = (remainingIters * avgMs / 1000).ceil();
            }
          } else {
            _progress = 0.5;
            _estimatedRemainingSeconds = null;
          }
          notifyListeners();
        } on BenchmarkUserCancelledException {
          // Exclude interrupted iteration from result
          break;
        }
      }

      final endTime = DateTime.now();
      _stopTimer();
      _estimatedRemainingSeconds = 0;

      if (iterationDurations.isNotEmpty) {
        // Compute performance metrics from completed iterations only
        final summary = _computeMetrics(
          startTime: startTime,
          endTime: endTime,
          durations: iterationDurations,
          cluster: cluster,
          scenario: 'ingest',
          rawIndex: rawIndex,
          totalDocs: _totalDocsIngested,
          cpuSnapshots: cpuSnapshots,
          heapSnapshots: heapSnapshots,
          clusterVersion: clusterVersion,
          nodeCount: nodeCount,
          nodeSummaries: nodeSummaries,
          settings: settings,
          status: 'completed',
        );

        _currentPhase = 'Generating PDF Benchmark Report...';
        notifyListeners();

        final pdfFile = await PdfReportService.generateReport(
          summary,
          targetDirectory: settings.reportDirectory,
        );
        final finalResult = summary.copyWith(pdfPath: pdfFile.path);

        await historyProvider.addResult(finalResult);
        _lastResult = finalResult;
        _state = BenchmarkState.completed;
        _progress = 1.0;
        final stoppedNote = _stopRequested ? ' (Stopped; completed ${iterationDurations.length} iteration(s))' : '';
        _currentPhase = 'Ingest benchmark completed$stoppedNote! Report generated: ${pdfFile.path}';
        notifyListeners();
      } else {
        _state = BenchmarkState.idle;
        _progress = 0.0;
        _currentPhase = 'Benchmark stopped before completing iteration 1. No iteration recorded.';
        notifyListeners();
      }
    } catch (e) {
      _stopTimer();
      _state = BenchmarkState.error;
      _errorMessage = e.toString();
      _currentPhase = 'Benchmark failed: $e';
      notifyListeners();
    } finally {
      _stopContinuousSampler();
      _stopTimer();
      _currentEsService = null;
      es.close();
    }
  }

  // --- Search Benchmark Scenario ---
  Future<void> runSearchBenchmark({
    required ClusterConfig cluster,
    required BenchmarkSettings settings,
  }) async {
    if (isRunning) return;

    _state = BenchmarkState.preparing;
    _stopRequested = false;
    _errorMessage = null;
    _lastResult = null;
    _progress = 0.0;
    _totalDocsIngested = 0;
    _currentIteration = 0;
    _peakCpu = 0.0;
    _peakHeap = 0.0;
    _estimatedRemainingSeconds = null;
    _totalIterations = settings.benchmarkMode == 'iterations' ? settings.iterationsCount : 0;
    _currentPhase = 'Connecting to Elasticsearch cluster...';
    notifyListeners();
    _startTimer();

    final es = ElasticsearchService(cluster);
    _currentEsService = es;
    final startTime = DateTime.now();
    final List<Map<String, dynamic>> cpuSnapshots = [];
    final List<Map<String, dynamic>> heapSnapshots = [];
    final List<double> iterationDurations = [];
    String clusterVersion = 'unknown';
    int nodeCount = 0;
    List<Map<String, dynamic>> nodeSummaries = [];

    try {
      final connInfo = await es.testConnection();
      clusterVersion = connInfo['version']?['number']?.toString() ?? '9.5.2';

      final initialStats = await es.getClusterStats();
      nodeCount = initialStats.nodeCount;
      nodeSummaries = initialStats.nodes.map((n) => n.toJson()).toList();
      _liveCpu = initialStats.cpuPercent;
      _liveHeap = initialStats.heapPercent;
      _liveDiskUsed = initialStats.diskUsedBytes;
      _peakCpu = _liveCpu;
      _peakHeap = _liveHeap;
      _startContinuousSampler(es, cpuSnapshots, heapSnapshots);
      notifyListeners();

      // Check or seed raw index (Resumable)
      final rawIndex = 'elkybench-waf-raw';
      _currentPhase = 'Checking search dataset index ($rawIndex)...';
      notifyListeners();

      final rawExists = await es.indexExists(rawIndex);
      if (rawExists) {
        final currentShards = await es.getIndexPrimaryShards(rawIndex);
        if (currentShards != null && currentShards != settings.primaryShards) {
          _currentPhase = 'Recreating raw index to match tuned shard count (${settings.primaryShards} shards)...';
          notifyListeners();
          await es.deleteIndex(rawIndex);
        }
      }

      final rawStillExists = await es.indexExists(rawIndex);
      if (!rawStillExists) {
        _currentPhase = 'Creating raw WAF log index (${settings.primaryShards} shards)...';
        notifyListeners();
        await es.createIndex(
          rawIndex,
          primaryShards: settings.primaryShards,
          replicaShards: settings.replicaShards,
          mappings: {
            'properties': {
              '@timestamp': {'type': 'date'},
              'message': {'type': 'text'},
            }
          },
        );
      } else {
        // Ensure tuned replica count is applied to existing index
        await es.updateIndexSettings(rawIndex, {'index.number_of_replicas': settings.replicaShards});
      }

      var stats = await es.getIndexStats(rawIndex);
      final int targetDocs = (settings.targetSizeGb * 4000000).round();
      int currentBytes = stats['primarySizeBytes'] as int? ?? 0;
      _totalDocsIngested = stats['docCount'] as int? ?? 0;

      if (_totalDocsIngested < targetDocs) {
        final seedStartTime = DateTime.now();
        final int initialDocs = _totalDocsIngested;

        if (_totalDocsIngested > 0) {
          final curM = (_totalDocsIngested / 1000000).toStringAsFixed(2);
          final totM = (targetDocs / 1000000).toStringAsFixed(2);
          final remM = ((targetDocs - _totalDocsIngested) / 1000000).toStringAsFixed(2);
          _currentPhase = 'Resuming upload: $curM M / $totM M docs indexed (${ClusterStats.formatBytes(currentBytes)}). Remaining: $remM M docs...';
          _progress = (_totalDocsIngested / targetDocs).clamp(0.0, 1.0) * 0.3;
          notifyListeners();
        } else {
          _currentPhase = 'Seeding logs for search benchmark...';
          notifyListeners();
        }

        while (_totalDocsIngested < targetDocs && !_stopRequested) {
          final batch = LogGeneratorService.generateBatch(settings.bulkBatchSize);
          await es.bulkIngest(rawIndex, batch);
          _totalDocsIngested += batch.length;

          final elapsedSec = DateTime.now().difference(seedStartTime).inSeconds;
          final docsIngestedThisSession = _totalDocsIngested - initialDocs;

          String rateStr = '';
          String etaStr = '';
          if (elapsedSec >= 2 && docsIngestedThisSession > 0) {
            final docsPerSec = docsIngestedThisSession / elapsedSec;
            rateStr = ' • ${(docsPerSec).round()} docs/s';

            final remainingDocs = targetDocs - _totalDocsIngested;
            if (remainingDocs > 0 && docsPerSec > 0) {
              final remSec = (remainingDocs / docsPerSec).ceil();
              _estimatedRemainingSeconds = remSec;
              final m = remSec ~/ 60;
              final s = remSec % 60;
              etaStr = ' • ETA: ${m}m ${s.toString().padLeft(2, '0')}s';
            } else {
              _estimatedRemainingSeconds = 0;
            }
          }

          _progress = (_totalDocsIngested / targetDocs).clamp(0.0, 1.0) * 0.3;
          final curMStr = (_totalDocsIngested / 1000000).toStringAsFixed(2);
          final totMStr = (targetDocs / 1000000).toStringAsFixed(2);
          final targetGbStr = settings.targetSizeGb.toStringAsFixed(2);
          _currentPhase = 'Seeding search index: $curMStr M / $totMStr M docs ($targetGbStr GB target)$rateStr$etaStr';

          _sampleStats(es, cpuSnapshots, heapSnapshots);
          notifyListeners();
        }
        await es.refreshIndex(rawIndex);
        final postStats = await es.getIndexStats(rawIndex);
        currentBytes = postStats['primarySizeBytes'] as int? ?? currentBytes;
      } else {
        _progress = 0.3;
        _currentPhase = 'Found complete seed dataset: $_totalDocsIngested docs (${ClusterStats.formatBytes(currentBytes)}). Ready!';
        notifyListeners();
      }

      if (_stopRequested) {
        _stopTimer();
        _state = BenchmarkState.idle;
        _currentPhase = 'Benchmark cancelled by user.';
        _progress = 0.0;
        notifyListeners();
        return;
      }

      // Search Benchmark Loop
      _state = BenchmarkState.running;
      notifyListeners();

      final maxIter = settings.benchmarkMode == 'iterations' ? settings.iterationsCount : 9999;
      int iter = 0;
      while (!_stopRequested) {
        if (settings.benchmarkMode == 'iterations') {
          if (iter >= maxIter) break;
        }

        iter++;
        _currentIteration = iter;
        _currentPhase = 'Executing Search Iteration $iter (${settings.workers} Workers)...';
        notifyListeners();

        try {
          final iterResult = await es.executeSearchIteration(
            indexName: rawIndex,
            workers: settings.workers,
            isStopRequested: () => _stopRequested,
          );
          final durationMs = (iterResult['durationMs'] as num).toDouble();
          iterationDurations.add(durationMs);

          await _sampleStats(es, cpuSnapshots, heapSnapshots);

          // Update progress & ETA
          if (settings.benchmarkMode == 'iterations') {
            _progress = 0.3 + (iter / maxIter * 0.7);
            if (iterationDurations.isNotEmpty) {
              final avgMs = iterationDurations.reduce((a, b) => a + b) / iterationDurations.length;
              final remainingIters = maxIter - iter;
              _estimatedRemainingSeconds = (remainingIters * avgMs / 1000).ceil();
            }
          } else {
            // 'no_iterations' (Indefinitely) - continuous runs until manually stopped
            _progress = 0.5;
            _estimatedRemainingSeconds = null;
          }
          notifyListeners();
        } on BenchmarkUserCancelledException {
          // Interrupted iteration excluded from results
          break;
        }
      }

      final endTime = DateTime.now();
      _stopTimer();
      _estimatedRemainingSeconds = 0;

      if (iterationDurations.isNotEmpty) {
        final summary = _computeMetrics(
          startTime: startTime,
          endTime: endTime,
          durations: iterationDurations,
          cluster: cluster,
          scenario: 'search',
          rawIndex: rawIndex,
          totalDocs: _totalDocsIngested,
          cpuSnapshots: cpuSnapshots,
          heapSnapshots: heapSnapshots,
          clusterVersion: clusterVersion,
          nodeCount: nodeCount,
          nodeSummaries: nodeSummaries,
          settings: settings,
          status: 'completed',
        );

        _currentPhase = 'Generating PDF Benchmark Report...';
        notifyListeners();

        final pdfFile = await PdfReportService.generateReport(
          summary,
          targetDirectory: settings.reportDirectory,
        );
        final finalResult = summary.copyWith(pdfPath: pdfFile.path);

        await historyProvider.addResult(finalResult);
        _lastResult = finalResult;
        _state = BenchmarkState.completed;
        _progress = 1.0;
        final stoppedNote = _stopRequested ? ' (Stopped; completed ${iterationDurations.length} iteration(s))' : '';
        _currentPhase = 'Search benchmark completed$stoppedNote! Report saved: ${pdfFile.path}';
        notifyListeners();
      } else {
        _state = BenchmarkState.idle;
        _progress = 0.0;
        _currentPhase = 'Benchmark stopped before completing iteration 1. No iteration recorded.';
        notifyListeners();
      }
    } catch (e) {
      _stopTimer();
      _state = BenchmarkState.error;
      _errorMessage = e.toString();
      _currentPhase = 'Benchmark failed: $e';
      notifyListeners();
    } finally {
      _stopContinuousSampler();
      _stopTimer();
      _currentEsService = null;
      es.close();
    }
  }

  // --- Clean Benchmark Resources ---
  Future<Map<String, int>> cleanCluster(ClusterConfig cluster) async {
    final es = ElasticsearchService(cluster);
    try {
      final res = await es.cleanBenchmarkResources();
      return res;
    } finally {
      _stopContinuousSampler();
      _stopTimer();
      _currentEsService = null;
      es.close();
    }
  }

  Future<void> _sampleStats(
    ElasticsearchService es,
    List<Map<String, dynamic>> cpuList,
    List<Map<String, dynamic>> heapList,
  ) async {
    try {
      final stats = await es.getClusterStats();
      _liveCpu = stats.cpuPercent;
      _liveHeap = stats.heapPercent;
      _liveDiskUsed = stats.diskUsedBytes;

      if (_liveCpu > _peakCpu) _peakCpu = _liveCpu;
      if (_liveHeap > _peakHeap) _peakHeap = _liveHeap;

      final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
      cpuList.add({
        'time': timeStr,
        'clusterAvgCpu': stats.cpuPercent,
      });
      heapList.add({
        'time': timeStr,
        'heapPercent': stats.heapPercent,
        'heapUsedBytes': stats.heapUsedBytes,
      });
    } catch (_) {}
  }

  BenchmarkResult _computeMetrics({
    required DateTime startTime,
    required DateTime endTime,
    required List<double> durations,
    required ClusterConfig cluster,
    required String scenario,
    required String rawIndex,
    required int totalDocs,
    required List<Map<String, dynamic>> cpuSnapshots,
    required List<Map<String, dynamic>> heapSnapshots,
    required String clusterVersion,
    required int nodeCount,
    required List<Map<String, dynamic>> nodeSummaries,
    required BenchmarkSettings settings,
    required String status,
  }) {
    final totalDurationMs = endTime.difference(startTime).inMilliseconds;
    final sorted = List<double>.from(durations)..sort();

    double avg = 0.0;
    double minVal = 0.0;
    double maxVal = 0.0;
    double p50 = 0.0;
    double p90 = 0.0;
    double p95 = 0.0;
    double p99 = 0.0;

    if (sorted.isNotEmpty) {
      avg = sorted.reduce((a, b) => a + b) / sorted.length;
      minVal = sorted.first;
      maxVal = sorted.last;
      p50 = _getPercentile(sorted, 0.50);
      p90 = _getPercentile(sorted, 0.90);
      p95 = _getPercentile(sorted, 0.95);
      p99 = _getPercentile(sorted, 0.99);
    }

    return BenchmarkResult(
      id: _uuid.v4(),
      clusterId: cluster.id,
      clusterName: cluster.name,
      clusterUrl: cluster.url,
      scenarioType: scenario,
      startTime: startTime,
      endTime: endTime,
      totalDurationMs: totalDurationMs,
      iterationsCompleted: durations.length,
      avgIterationMs: avg,
      minIterationMs: minVal,
      maxIterationMs: maxVal,
      p50Ms: p50,
      p90Ms: p90,
      p95Ms: p95,
      p99Ms: p99,
      status: status,
      rawIndexName: rawIndex,
      targetIndexSizeFormatted: '${settings.targetSizeGb} GB',
      totalDocsIngested: totalDocs,
      cpuSnapshots: cpuSnapshots,
      heapSnapshots: heapSnapshots,
      iterationDurationsMs: durations,
      clusterVersion: clusterVersion,
      clusterNodesCount: nodeCount,
      nodeSummaries: nodeSummaries,
      settingsUsed: settings.toJson(),
    );
  }

  double _getPercentile(List<double> sorted, double percentile) {
    if (sorted.isEmpty) return 0.0;
    final index = (percentile * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }
}
