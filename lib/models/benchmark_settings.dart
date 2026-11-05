class BenchmarkSettings {
  int bulkBatchSize; // default 10000
  double targetSizeGb; // default 1.0
  int primaryShards; // default 5
  int replicaShards; // default 0
  int monitorIntervalSec; // default 10
  String benchmarkMode; // 'iterations', 'time_limit', or 'no_iterations'
  int iterationsCount; // default 5
  int timeLimitMinutes; // default 5
  int threatIntelRecords; // default 50000
  String pipelineIntensity; // 'extreme'
  int workers; // default 8, choices: 1, 2, 4, 8, 16, 32
  String? reportDirectory; // Custom directory path where PDF reports are saved

  BenchmarkSettings({
    this.bulkBatchSize = 10000,
    this.targetSizeGb = 1.0,
    this.primaryShards = 5,
    this.replicaShards = 0,
    this.monitorIntervalSec = 10,
    this.benchmarkMode = 'iterations',
    this.iterationsCount = 5,
    this.timeLimitMinutes = 5,
    this.threatIntelRecords = 50000,
    this.pipelineIntensity = 'extreme',
    this.workers = 8,
    this.reportDirectory,
  });

  Map<String, dynamic> toJson() => {
    'bulkBatchSize': bulkBatchSize,
    'targetSizeGb': targetSizeGb,
    'primaryShards': primaryShards,
    'replicaShards': replicaShards,
    'monitorIntervalSec': monitorIntervalSec,
    'benchmarkMode': benchmarkMode,
    'iterationsCount': iterationsCount,
    'timeLimitMinutes': timeLimitMinutes,
    'threatIntelRecords': threatIntelRecords,
    'pipelineIntensity': pipelineIntensity,
    'workers': workers,
    'reportDirectory': reportDirectory,
  };

  factory BenchmarkSettings.fromJson(Map<String, dynamic> json) => BenchmarkSettings(
    bulkBatchSize: (json['bulkBatchSize'] as num?)?.toInt() ?? 10000,
    targetSizeGb: (json['targetSizeGb'] as num?)?.toDouble() ?? 1.0,
    primaryShards: (json['primaryShards'] as num?)?.toInt() ?? 5,
    replicaShards: (json['replicaShards'] as num?)?.toInt() ?? 0,
    monitorIntervalSec: (json['monitorIntervalSec'] as num?)?.toInt() ?? 10,
    benchmarkMode: json['benchmarkMode'] as String? ?? 'iterations',
    iterationsCount: (json['iterationsCount'] as num?)?.toInt() ?? 5,
    timeLimitMinutes: (json['timeLimitMinutes'] as num?)?.toInt() ?? 5,
    threatIntelRecords: (json['threatIntelRecords'] as num?)?.toInt() ?? 50000,
    pipelineIntensity: json['pipelineIntensity'] as String? ?? 'extreme',
    workers: (json['workers'] as num?)?.toInt() ?? 8,
    reportDirectory: json['reportDirectory'] as String?,
  );

  BenchmarkSettings clone() => BenchmarkSettings.fromJson(toJson());
}
