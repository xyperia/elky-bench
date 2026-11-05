class BenchmarkResult {
  final String id;
  final String clusterId;
  final String clusterName;
  final String clusterUrl;
  final String scenarioType; // 'ingest' or 'search'
  final DateTime startTime;
  final DateTime endTime;
  final int totalDurationMs;
  final int iterationsCompleted;
  final double avgIterationMs;
  final double minIterationMs;
  final double maxIterationMs;
  final double p50Ms;
  final double p90Ms;
  final double p95Ms;
  final double p99Ms;
  final String status; // 'completed', 'stopped', 'failed'
  final String? errorMessage;
  final String rawIndexName;
  final String targetIndexSizeFormatted;
  final int totalDocsIngested;
  final List<Map<String, dynamic>> cpuSnapshots;
  final List<Map<String, dynamic>> heapSnapshots;
  final List<double> iterationDurationsMs;
  final String clusterVersion;
  final int clusterNodesCount;
  final List<Map<String, dynamic>> nodeSummaries;
  final String? pdfPath;
  final Map<String, dynamic> settingsUsed;

  BenchmarkResult({
    required this.id,
    required this.clusterId,
    required this.clusterName,
    required this.clusterUrl,
    required this.scenarioType,
    required this.startTime,
    required this.endTime,
    required this.totalDurationMs,
    required this.iterationsCompleted,
    required this.avgIterationMs,
    required this.minIterationMs,
    required this.maxIterationMs,
    required this.p50Ms,
    required this.p90Ms,
    required this.p95Ms,
    required this.p99Ms,
    required this.status,
    this.errorMessage,
    required this.rawIndexName,
    required this.targetIndexSizeFormatted,
    required this.totalDocsIngested,
    required this.cpuSnapshots,
    required this.heapSnapshots,
    required this.iterationDurationsMs,
    required this.clusterVersion,
    required this.clusterNodesCount,
    required this.nodeSummaries,
    this.pdfPath,
    required this.settingsUsed,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'clusterId': clusterId,
    'clusterName': clusterName,
    'clusterUrl': clusterUrl,
    'scenarioType': scenarioType,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'totalDurationMs': totalDurationMs,
    'iterationsCompleted': iterationsCompleted,
    'avgIterationMs': avgIterationMs,
    'minIterationMs': minIterationMs,
    'maxIterationMs': maxIterationMs,
    'p50Ms': p50Ms,
    'p90Ms': p90Ms,
    'p95Ms': p95Ms,
    'p99Ms': p99Ms,
    'status': status,
    'errorMessage': errorMessage,
    'rawIndexName': rawIndexName,
    'targetIndexSizeFormatted': targetIndexSizeFormatted,
    'totalDocsIngested': totalDocsIngested,
    'cpuSnapshots': cpuSnapshots,
    'heapSnapshots': heapSnapshots,
    'iterationDurationsMs': iterationDurationsMs,
    'clusterVersion': clusterVersion,
    'clusterNodesCount': clusterNodesCount,
    'nodeSummaries': nodeSummaries,
    'pdfPath': pdfPath,
    'settingsUsed': settingsUsed,
  };

  factory BenchmarkResult.fromJson(Map<String, dynamic> json) => BenchmarkResult(
    id: json['id'] as String,
    clusterId: json['clusterId'] as String,
    clusterName: json['clusterName'] as String,
    clusterUrl: json['clusterUrl'] as String? ?? '',
    scenarioType: json['scenarioType'] as String,
    startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ?? DateTime.now(),
    endTime: DateTime.tryParse(json['endTime'] as String? ?? '') ?? DateTime.now(),
    totalDurationMs: (json['totalDurationMs'] as num?)?.toInt() ?? 0,
    iterationsCompleted: (json['iterationsCompleted'] as num?)?.toInt() ?? 0,
    avgIterationMs: (json['avgIterationMs'] as num?)?.toDouble() ?? 0.0,
    minIterationMs: (json['minIterationMs'] as num?)?.toDouble() ?? 0.0,
    maxIterationMs: (json['maxIterationMs'] as num?)?.toDouble() ?? 0.0,
    p50Ms: (json['p50Ms'] as num?)?.toDouble() ?? 0.0,
    p90Ms: (json['p90Ms'] as num?)?.toDouble() ?? 0.0,
    p95Ms: (json['p95Ms'] as num?)?.toDouble() ?? 0.0,
    p99Ms: (json['p99Ms'] as num?)?.toDouble() ?? 0.0,
    status: json['status'] as String? ?? 'completed',
    errorMessage: json['errorMessage'] as String?,
    rawIndexName: json['rawIndexName'] as String? ?? '',
    targetIndexSizeFormatted: json['targetIndexSizeFormatted'] as String? ?? '',
    totalDocsIngested: (json['totalDocsIngested'] as num?)?.toInt() ?? 0,
    cpuSnapshots: (json['cpuSnapshots'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [],
    heapSnapshots: (json['heapSnapshots'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [],
    iterationDurationsMs: (json['iterationDurationsMs'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [],
    clusterVersion: json['clusterVersion'] as String? ?? '',
    clusterNodesCount: (json['clusterNodesCount'] as num?)?.toInt() ?? 0,
    nodeSummaries: (json['nodeSummaries'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [],
    pdfPath: json['pdfPath'] as String?,
    settingsUsed: Map<String, dynamic>.from(json['settingsUsed'] as Map? ?? {}),
  );

  BenchmarkResult copyWith({String? pdfPath}) {
    return BenchmarkResult(
      id: id,
      clusterId: clusterId,
      clusterName: clusterName,
      clusterUrl: clusterUrl,
      scenarioType: scenarioType,
      startTime: startTime,
      endTime: endTime,
      totalDurationMs: totalDurationMs,
      iterationsCompleted: iterationsCompleted,
      avgIterationMs: avgIterationMs,
      minIterationMs: minIterationMs,
      maxIterationMs: maxIterationMs,
      p50Ms: p50Ms,
      p90Ms: p90Ms,
      p95Ms: p95Ms,
      p99Ms: p99Ms,
      status: status,
      errorMessage: errorMessage,
      rawIndexName: rawIndexName,
      targetIndexSizeFormatted: targetIndexSizeFormatted,
      totalDocsIngested: totalDocsIngested,
      cpuSnapshots: cpuSnapshots,
      heapSnapshots: heapSnapshots,
      iterationDurationsMs: iterationDurationsMs,
      clusterVersion: clusterVersion,
      clusterNodesCount: clusterNodesCount,
      nodeSummaries: nodeSummaries,
      pdfPath: pdfPath ?? this.pdfPath,
      settingsUsed: settingsUsed,
    );
  }
}
