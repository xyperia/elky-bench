import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/cluster_config.dart';
import '../models/cluster_stats.dart';

class ElasticsearchException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  ElasticsearchException(this.message, {this.statusCode, this.details});

  @override
  String toString() => 'ElasticsearchException: $message (Status: $statusCode)';
}

class BenchmarkUserCancelledException implements Exception {
  final String message;
  BenchmarkUserCancelledException([this.message = 'Benchmark cancelled by user.']);

  @override
  String toString() => message;
}

class ElasticsearchService {
  final ClusterConfig config;
  late final HttpClient _httpClient;

  ElasticsearchService(this.config) {
    _httpClient = HttpClient();
    _httpClient.connectionTimeout = const Duration(seconds: 15);

    if (config.sslMode == 'bypass') {
      _httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    } else if (config.sslMode == 'ca') {
      if (config.caCertContent != null && config.caCertContent!.isNotEmpty) {
        final secContext = SecurityContext(withTrustedRoots: true);
        try {
          secContext.setTrustedCertificatesBytes(utf8.encode(config.caCertContent!));
          _httpClient = HttpClient(context: secContext);
        } catch (e) {
          debugPrint('Error loading CA cert content: $e');
        }
      } else if (config.caCertPath != null && config.caCertPath!.isNotEmpty) {
        final secContext = SecurityContext(withTrustedRoots: true);
        try {
          secContext.setTrustedCertificates(config.caCertPath!);
          _httpClient = HttpClient(context: secContext);
        } catch (e) {
          debugPrint('Error loading CA cert from path: $e');
        }
      }
    }
  }

  void close() {
    _httpClient.close(force: true);
  }

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    String base = config.url.trim();
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      base = 'https://$base';
    }
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    String cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$base$cleanPath';
    final uri = Uri.parse(fullUrl);
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: {...uri.queryParameters, ...queryParams});
    }
    return uri;
  }

  void _addAuthHeaders(HttpHeaders headers) {
    if (config.authType == 'apikey' && config.apiKey != null && config.apiKey!.isNotEmpty) {
      headers.set('Authorization', 'ApiKey ${config.apiKey!.trim()}');
    } else if (config.authType == 'basic' && config.username != null) {
      final user = config.username!.trim();
      final pass = config.password ?? '';
      final token = base64Encode(utf8.encode('$user:$pass'));
      headers.set('Authorization', 'Basic $token');
    }
  }

  Future<dynamic> _request(
    String method,
    String path, {
    dynamic body,
    Map<String, String>? queryParams,
    String contentType = 'application/json',
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final uri = _buildUri(path, queryParams);
    HttpClientRequest request;

    switch (method.toUpperCase()) {
      case 'GET':
        request = await _httpClient.getUrl(uri);
        break;
      case 'POST':
        request = await _httpClient.postUrl(uri);
        break;
      case 'PUT':
        request = await _httpClient.putUrl(uri);
        break;
      case 'DELETE':
        request = await _httpClient.deleteUrl(uri);
        break;
      case 'HEAD':
        request = await _httpClient.headUrl(uri);
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    _addAuthHeaders(request.headers);
    request.headers.set('Content-Type', contentType);
    request.headers.set('Accept', 'application/json');

    if (body != null) {
      if (body is String) {
        request.write(body);
      } else if (body is List<int>) {
        request.add(body);
      } else {
        request.write(jsonEncode(body));
      }
    }

    final response = await request.close().timeout(timeout);
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (responseBody.trim().isEmpty) return {};
      try {
        return jsonDecode(responseBody);
      } catch (_) {
        return responseBody;
      }
    } else {
      dynamic errorJson;
      try {
        errorJson = jsonDecode(responseBody);
      } catch (_) {
        errorJson = responseBody;
      }
      throw ElasticsearchException(
        'Elasticsearch request failed [${response.statusCode}] $method $path: ${errorJson is Map ? (errorJson['error']?['reason'] ?? errorJson['message'] ?? responseBody) : responseBody}',
        statusCode: response.statusCode,
        details: errorJson,
      );
    }
  }

  // 1. Connection and Cluster Info
  Future<Map<String, dynamic>> testConnection() async {
    final res = await _request('GET', '/');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> getClusterHealth() async {
    final res = await _request('GET', '/_cluster/health');
    return Map<String, dynamic>.from(res as Map);
  }

  // 2. Node Stats for Status Bar and Live Monitoring
  Future<ClusterStats> getClusterStats() async {
    // Query _nodes/stats/os,jvm,fs with an 8-second timeout for responsive telemetry
    final statsData = await _request(
      'GET',
      '/_nodes/stats/os,jvm,fs',
      timeout: const Duration(seconds: 8),
    );
    String clusterHealthStatus = 'unknown';
    try {
      final healthData = await _request(
        'GET',
        '/_cluster/health',
        timeout: const Duration(seconds: 5),
      );
      clusterHealthStatus = (healthData is Map ? healthData['status'] as String? : null) ?? 'unknown';
    } catch (_) {
      clusterHealthStatus = 'unknown';
    }

    final nodesMap = statsData['nodes'] as Map<String, dynamic>? ?? {};
    final List<NodeStatItem> nodeItems = [];

    double totalCpuPercent = 0.0;
    int validCpuNodes = 0;
    int totalHeapUsed = 0;
    int totalHeapMax = 0;
    int totalDiskUsed = 0;
    int totalDiskCapacity = 0;

    nodesMap.forEach((nodeId, nodeVal) {
      final node = nodeVal as Map<String, dynamic>;
      final name = node['name'] as String? ?? nodeId;
      final roles = (node['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

      // OS CPU
      final os = node['os'] as Map<String, dynamic>?;
      final cpu = os?['cpu'] as Map<String, dynamic>?;
      final cpuPct = (cpu?['percent'] as num?)?.toDouble() ?? 0.0;
      if (cpuPct >= 0) {
        totalCpuPercent += cpuPct;
        validCpuNodes++;
      }

      // JVM Heap
      final jvm = node['jvm'] as Map<String, dynamic>?;
      final mem = jvm?['mem'] as Map<String, dynamic>?;
      final heapUsed = (mem?['heap_used_in_bytes'] as num?)?.toInt() ?? 0;
      final heapMax = (mem?['heap_max_in_bytes'] as num?)?.toInt() ?? 0;
      final heapPct = (mem?['heap_used_percent'] as num?)?.toDouble() ??
          (heapMax > 0 ? (heapUsed / heapMax * 100) : 0.0);
      totalHeapUsed += heapUsed;
      totalHeapMax += heapMax;

      // FS Disk
      final fs = node['fs'] as Map<String, dynamic>?;
      final fsTotal = fs?['total'] as Map<String, dynamic>?;
      final diskCap = (fsTotal?['total_in_bytes'] as num?)?.toInt() ?? 0;
      final diskAvail = (fsTotal?['available_in_bytes'] as num?)?.toInt() ?? 0;
      final diskUsed = diskCap - diskAvail;
      final diskPct = diskCap > 0 ? (diskUsed / diskCap * 100) : 0.0;
      totalDiskUsed += diskUsed;
      totalDiskCapacity += diskCap;

      nodeItems.add(NodeStatItem(
        id: nodeId,
        name: name,
        roles: roles,
        cpuPercent: cpuPct,
        heapUsedBytes: heapUsed,
        heapMaxBytes: heapMax,
        heapPercent: heapPct,
        diskUsedBytes: diskUsed,
        diskTotalBytes: diskCap,
        diskPercent: diskPct,
      ));
    });

    final avgCpu = validCpuNodes > 0 ? (totalCpuPercent / validCpuNodes) : 0.0;
    final avgHeapPct = totalHeapMax > 0 ? (totalHeapUsed / totalHeapMax * 100) : 0.0;
    final avgDiskPct = totalDiskCapacity > 0 ? (totalDiskUsed / totalDiskCapacity * 100) : 0.0;

    return ClusterStats(
      cpuPercent: avgCpu,
      heapUsedBytes: totalHeapUsed,
      heapMaxBytes: totalHeapMax,
      heapPercent: avgHeapPct,
      diskUsedBytes: totalDiskUsed,
      diskTotalBytes: totalDiskCapacity,
      diskPercent: avgDiskPct,
      nodeCount: nodesMap.length,
      status: clusterHealthStatus,
      timestamp: DateTime.now(),
      nodes: nodeItems,
    );
  }

  // 3. Index Management
  Future<bool> updateIndexSettings(String indexName, Map<String, dynamic> settings) async {
    try {
      final res = await _request('PUT', '/$indexName/_settings', body: settings);
      return res is Map && res['acknowledged'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> indexExists(String indexName) async {
    try {
      final res = await _request('GET', '/_cat/indices/$indexName', queryParams: {'format': 'json'});
      return res is List && res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<int?> getIndexPrimaryShards(String indexName) async {
    try {
      final res = await _request('GET', '/$indexName/_settings?flat_settings=true');
      if (res is Map && res[indexName] is Map) {
        final settings = res[indexName]['settings'] as Map?;
        final pri = settings?['index.number_of_shards']?.toString();
        if (pri != null) return int.tryParse(pri);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> deleteIndex(String indexName) async {
    try {
      final res = await _request('DELETE', '/$indexName');
      return res is Map && res['acknowledged'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createIndex(
    String indexName, {
    int primaryShards = 5,
    int replicaShards = 0,
    Map<String, dynamic>? mappings,
  }) async {
    if (await indexExists(indexName)) {
      // Apply replica shard tuning immediately even to existing index
      await updateIndexSettings(indexName, {'index.number_of_replicas': replicaShards});
      return true;
    }

    final body = <String, dynamic>{
      'settings': {
        'number_of_shards': primaryShards,
        'number_of_replicas': replicaShards,
        'refresh_interval': '30s', // Optimized for ingest
      },
    };
    if (mappings != null) {
      body['mappings'] = mappings;
    }

    try {
      final res = await _request('PUT', '/$indexName', body: body);
      return res is Map && (res['acknowledged'] == true);
    } on ElasticsearchException catch (e) {
      if (e.statusCode == 400 && e.message.contains('already exists')) {
        await updateIndexSettings(indexName, {'index.number_of_replicas': replicaShards});
        return true;
      }
      rethrow;
    }
  }

  Future<void> refreshIndex(String indexName) async {
    try {
      await _request('POST', '/$indexName/_refresh');
    } catch (_) {}
  }

  // 4. Bulk Ingest with Auto-Retry & Resilient Timeout
  Future<Map<String, dynamic>> bulkIngest(
    String indexName,
    List<Map<String, dynamic>> docs, {
    int maxRetries = 3,
  }) async {
    if (docs.isEmpty) return {'errors': false, 'took': 0, 'items_count': 0};

    final StringBuffer buffer = StringBuffer();
    for (final doc in docs) {
      buffer.writeln(jsonEncode({'index': {'_index': indexName}}));
      buffer.writeln(jsonEncode(doc));
    }
    final ndjson = buffer.toString();

    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final res = await _request(
          'POST',
          '/_bulk',
          body: ndjson,
          contentType: 'application/x-ndjson',
          timeout: const Duration(seconds: 180),
        );

        return {
          'errors': res['errors'] ?? false,
          'took': res['took'] ?? 0,
          'items_count': docs.length,
        };
      } catch (e) {
        if (attempt >= maxRetries) {
          rethrow;
        }
        // Exponential backoff retry: 2s, 4s, 8s
        final backoffMs = 2000 * attempt;
        await Future.delayed(Duration(milliseconds: backoffMs));
      }
    }
  }

  // 5. Index Size via _cat/indices
  Future<Map<String, dynamic>> getIndexStats(String indexName) async {
    try {
      final res = await _request('GET', '/_cat/indices/$indexName', queryParams: {
        'format': 'json',
        'bytes': 'b',
        'h': 'index,health,status,pri,rep,docs.count,store.size,pri.store.size',
      });
      if (res is List && res.isNotEmpty) {
        final row = res[0] as Map<String, dynamic>;
        final priSize = int.tryParse(row['pri.store.size']?.toString() ?? '0') ?? 0;
        final totalSize = int.tryParse(row['store.size']?.toString() ?? '0') ?? 0;
        final docCount = int.tryParse(row['docs.count']?.toString() ?? '0') ?? 0;
        return {
          'primarySizeBytes': priSize,
          'totalSizeBytes': totalSize,
          'docCount': docCount,
        };
      }
    } catch (_) {}
    return {
      'primarySizeBytes': 0,
      'totalSizeBytes': 0,
      'docCount': 0,
    };
  }

  Future<bool> enrichPolicyExists(String policyName) async {
    try {
      final res = await _request('GET', '/_enrich/policy/$policyName');
      return res is Map && (res['policies'] as List?)?.isNotEmpty == true;
    } catch (_) {
      return false;
    }
  }

  // 6. Threat Intel Index & Enrich Policy
  Future<void> setupThreatIntelEnrichPolicy({
    required String enrichIndexName,
    required String policyName,
    required List<Map<String, dynamic>> threatRecords,
    int primaryShards = 5,
    int replicaShards = 0,
  }) async {
    // 1. Check or create source index with user-tuned shards
    final exists = await indexExists(enrichIndexName);
    if (!exists) {
      await createIndex(
        enrichIndexName,
        primaryShards: primaryShards,
        replicaShards: replicaShards,
        mappings: {
          'properties': {
            'ip': {'type': 'keyword'},
            'threat_type': {'type': 'keyword'},
            'confidence_score': {'type': 'integer'},
            'country_code': {'type': 'keyword'},
            'asn': {'type': 'keyword'},
            'is_active': {'type': 'boolean'},
            'last_observed': {'type': 'date'},
          }
        },
      );
    } else {
      await updateIndexSettings(enrichIndexName, {'index.number_of_replicas': replicaShards});
    }

    // 2. Ingest threat records if not already populated
    final stats = await getIndexStats(enrichIndexName);
    final docCount = stats['docCount'] as int? ?? 0;
    if (docCount < threatRecords.length) {
      const chunkSize = 5000;
      for (int i = docCount; i < threatRecords.length; i += chunkSize) {
        final end = (i + chunkSize < threatRecords.length) ? i + chunkSize : threatRecords.length;
        final chunk = threatRecords.sublist(i, end);
        await bulkIngest(enrichIndexName, chunk);
      }
      // Refresh index so enrich policy sees all documents
      await refreshIndex(enrichIndexName);
    }

    // 3. Create enrich policy if it does not already exist
    final policyExists = await enrichPolicyExists(policyName);
    if (!policyExists) {
      final policyBody = {
        'match': {
          'indices': enrichIndexName,
          'match_field': 'ip',
          'enrich_fields': ['threat_type', 'confidence_score', 'country_code', 'asn', 'is_active'],
        }
      };
      try {
        await _request('PUT', '/_enrich/policy/$policyName', body: policyBody);
      } on ElasticsearchException catch (e) {
        if (e.statusCode != 400 || !e.message.contains('already exists')) {
          rethrow;
        }
      }
    }

    // 4. Always execute enrich policy to build the active .enrich-* cache index
    await _request('POST', '/_enrich/policy/$policyName/_execute');
  }

  // 7. Heavy Ingest Pipeline Setup (Extreme CPU Saturation)
  Future<void> createHeavyIngestPipeline({
    required String pipelineId,
    required String enrichPolicyName,
    String intensity = 'extreme',
  }) async {
    final processors = [
        // 1. Grok syslog header and CEF basic fields
        {
          'grok': {
            'field': 'message',
            'patterns': [
              r'^<%{POSINT:syslog_pri}>%{DATA:syslog_timestamp} %{NOTSPACE:syslog_host} CEF:%{INT:cef_version}\|%{DATA:cef_vendor}\|%{DATA:cef_product}\|%{DATA:cef_version_num}\|%{DATA:cef_sig_id}\|%{DATA:cef_sig_name}\|%{DATA:cef_severity}\|%{GREEDYDATA:cef_extension}'
            ],
            'ignore_failure': true,
          }
        },
        // 2. Parse KV extensions
        {
          'kv': {
            'field': 'cef_extension',
            'field_split': r' (?=[a-zA-Z0-9]+(=|\\=))',
            'value_split': '=',
            'ignore_failure': true,
          }
        },
        // 3. URL Decode for request URI
        {
          'urldecode': {
            'field': 'request',
            'target_field': 'request_decoded',
            'ignore_missing': true,
          }
        },
        // 4. Second-Stage Deep Regex Grok for OWASP attack signature classification
        {
          'grok': {
            'field': 'cs2',
            'patterns': [
              r'(?i)%{DATA:attack_sqli}(union(\s+all)?\s+select|waitfor\s+delay|extractvalue\s*\(|--|-#|\x27\s*or\s*\x27?1\x27?=\x27?1|\x27\s*OR\s*1=1)',
              r'(?i)%{DATA:attack_xss}(<script[^>]*>|javascript:|onerror\s*=|document\.cookie)',
              r'(?i)%{DATA:attack_rce}(;\s*(cat|ls|whoami|curl|wget|bash|sh)\b|\|\s*(bash|sh))',
              r'(?i)%{DATA:attack_lfi}(\.\./|\.\.\\|/etc/passwd|windows/win\.ini)',
              r'%{GREEDYDATA:attack_generic}'
            ],
            'ignore_failure': true,
            'ignore_missing': true,
          }
        },
        // 5. Type conversions
        {
          'convert': {
            'field': 'cef_severity',
            'type': 'integer',
            'ignore_missing': true,
          }
        },
        {
          'convert': {
            'field': 'dpt',
            'type': 'integer',
            'ignore_missing': true,
          }
        },
        {
          'convert': {
            'field': 'spt',
            'type': 'integer',
            'ignore_missing': true,
          }
        },
        // 6. Threat Intel IP enrichment
        {
          'enrich': {
            'policy_name': enrichPolicyName,
            'field': 'src',
            'target_field': 'threat_intel',
            'max_matches': 1,
            'ignore_missing': true,
          }
        },
        // 7. Painless Shannon Entropy loop, character class distribution, and risk scoring
        {
          'script': {
            'lang': 'painless',
            'source': '''
              String payload = ctx.cs2 != null ? ctx.cs2 : (ctx.request != null ? ctx.request : "");
              int len = payload.length();
              double entropy = 0.0;
              int specialChars = 0;
              int upperChars = 0;
              int digits = 0;
              if (len > 0) {
                int[] counts = new int[256];
                for (int i = 0; i < len; i++) {
                  char c = payload.charAt(i);
                  int idx = (int)c;
                  if (idx < 256) {
                    counts[idx]++;
                  }
                  if (!Character.isLetterOrDigit(c)) {
                    specialChars++;
                  }
                  if (Character.isUpperCase(c)) {
                    upperChars++;
                  }
                  if (Character.isDigit(c)) {
                    digits++;
                  }
                }
                for (int i = 0; i < 256; i++) {
                  if (counts[i] > 0) {
                    double p = (double)counts[i] / (double)len;
                    entropy -= p * (Math.log(p) / Math.log(2.0));
                  }
                }
              }
              ctx.shannon_entropy = Math.round(entropy * 1000.0) / 1000.0;
              ctx.is_high_entropy = entropy > 4.2;
              ctx.special_char_ratio = len > 0 ? (Math.round(((double)specialChars / (double)len) * 1000.0) / 1000.0) : 0.0;
              int sev = ctx.cef_severity != null ? ctx.cef_severity : 5;
              int baseRisk = sev * 12;
              if (ctx.act != null && ctx.act == "Blocked") {
                baseRisk += 20;
              }
              if (ctx.is_high_entropy) {
                baseRisk += 25;
              }
              if (ctx.threat_intel != null && ctx.threat_intel.confidence_score != null) {
                baseRisk += (int)ctx.threat_intel.confidence_score;
              }
              ctx.computed_risk_score = baseRisk;
              ctx.benchmark_processed_at = new Date().getTime();
              ctx.rule_group_normalized = ctx.cs1 != null ? ctx.cs1.toLowerCase() : "unknown";
            ''',
            'ignore_failure': true,
          }
        },
        // 8. Regex Redact processor for token and sensitive pattern masking
        {
          'redact': {
            'field': 'message',
            'patterns': [r'%{EMAILADDRESS:EMAIL}'],
            'ignore_missing': true,
          }
        },
        // 9. SHA-512 Cryptographic Payload Hash
        {
          'fingerprint': {
            'fields': ['message', 'request'],
            'target_field': 'payload_sha512',
            'method': 'SHA-512',
            'ignore_missing': true,
          }
        },
        // 10. SHA-256 Deduplication Hash
        {
          'fingerprint': {
            'fields': ['src', 'dst', 'cef_sig_id'],
            'target_field': 'event_hash',
            'method': 'SHA-256',
            'ignore_missing': true,
          }
        },
        // 11. Lowercase action
        {
          'lowercase': {
            'field': 'act',
            'ignore_missing': true,
          }
        },
      ];

      final body = {
        'description': 'ElkyBench Extreme CPU Saturation Ingest Pipeline: Shannon Entropy, OWASP Regex, Urldecode, KV, Enrich, Redact, SHA-512 & SHA-256',
        'processors': processors,
      };

      await _request('PUT', '/_ingest/pipeline/$pipelineId', body: body);
    }

  // 8. Reindex Benchmark Iteration (Multi-Index Async Parallel Workers with Live Progress & Cancellation)
  final List<String> _activeReindexTaskIds = [];
  List<String> get activeReindexTaskIds => List.unmodifiable(_activeReindexTaskIds);

  Future<void> cancelTask(String taskId) async {
    try {
      await _request('POST', '/_tasks/$taskId/_cancel', timeout: const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> cancelAllReindexTasks() async {
    for (final taskId in _activeReindexTaskIds) {
      await cancelTask(taskId);
    }
    _activeReindexTaskIds.clear();
    try {
      await _request('POST', '/_tasks/_cancel?actions=*reindex*', timeout: const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<Map<String, dynamic>> executeReindexIteration({
    required String sourceIndex,
    required String destIndex,
    required String pipelineId,
    int primaryShards = 5,
    int replicaShards = 0,
    int workers = 8,
    void Function(int processedDocs, int totalDocs, double progressFraction)? onProgress,
    bool Function()? isStopRequested,
  }) async {
    // Determine destination indices based on selected workers
    final int effectiveWorkers = workers.clamp(1, 32);
    final List<String> destIndices = effectiveWorkers > 1
        ? List.generate(effectiveWorkers, (i) => '$destIndex-w$i')
        : [destIndex];


    // Prepare destination indices: clean up stale indices from previous aborted runs
    for (final targetIndex in destIndices) {
      try {
        if (await indexExists(targetIndex)) {
          await _request('DELETE', '/$targetIndex');
        }
      } catch (_) {}

      await createIndex(
        targetIndex,
        primaryShards: primaryShards,
        replicaShards: replicaShards,
      );

      // Apply High-Saturation Index Optimizations:
      // 1. Asynchronous Translog: eliminates disk fsync I/O wait, freeing CPU for pure compute
      // 2. High flush threshold: prevents Lucene commit stalls
      // 3. Relaxed refresh interval: eliminates constant segment reader re-opening
      await updateIndexSettings(targetIndex, {
        'index.refresh_interval': '30s',
        'index.translog.durability': 'async',
        'index.translog.sync_interval': '60s',
        'index.translog.flush_threshold_size': '2gb',
      });
    }

    final stopwatch = Stopwatch()..start();
    final List<String> taskIds = [];
    _activeReindexTaskIds.clear();

    // Launch parallel reindex tasks, one per destination index with sliced source partitioning
    for (int i = 0; i < destIndices.length; i++) {
      final targetIndex = destIndices[i];
      final Map<String, dynamic> sourceMap = {
        'index': sourceIndex,
        'size': 2500, // Keep ingest thread queues saturated
      };

      if (destIndices.length > 1) {
        sourceMap['slice'] = {
          'id': i,
          'max': destIndices.length,
        };
      }

      final reindexBody = {
        'source': sourceMap,
        'dest': {'index': targetIndex, 'pipeline': pipelineId},
      };

      final launchRes = await _request(
        'POST',
        '/_reindex',
        body: reindexBody,
        queryParams: {'wait_for_completion': 'false'},
        timeout: const Duration(seconds: 45),
      );

      if (launchRes is! Map || launchRes['task'] == null) {
        throw ElasticsearchException('Failed to launch reindex worker $i: $launchRes');
      }

      final taskId = launchRes['task'].toString();
      taskIds.add(taskId);
      _activeReindexTaskIds.add(taskId);
    }

    final Set<String> completedTasks = {};
    final Map<String, int> taskProcessedDocs = {};
    final Map<String, int> taskTotalDocs = {};
    int totalDocsCombined = 0;
    double maxEsTook = 0;

    try {
      while (completedTasks.length < taskIds.length) {
        if (isStopRequested?.call() == true) {
          await cancelAllReindexTasks();
          throw BenchmarkUserCancelledException('Reindex stopped by user.');
        }

        await Future.delayed(const Duration(seconds: 2));

        for (final taskId in taskIds) {
          if (completedTasks.contains(taskId)) continue;

          Map<String, dynamic> taskStatus;
          try {
            final taskRes = await _request('GET', '/_tasks/$taskId', timeout: const Duration(seconds: 15));
            taskStatus = Map<String, dynamic>.from(taskRes as Map);
          } catch (_) {
            continue;
          }

          final isCompleted = taskStatus['completed'] == true;
          final taskInfo = taskStatus['task'] as Map<String, dynamic>?;
          final statusMap = taskInfo?['status'] as Map<String, dynamic>?;

          if (statusMap != null) {
            final tTotal = (statusMap['total'] as num?)?.toInt() ?? 0;
            final tCreated = (statusMap['created'] as num?)?.toInt() ?? 0;
            final tUpdated = (statusMap['updated'] as num?)?.toInt() ?? 0;
            taskTotalDocs[taskId] = tTotal;
            taskProcessedDocs[taskId] = tCreated + tUpdated;
          }

          if (isCompleted) {
            if (taskStatus['error'] != null) {
              final err = taskStatus['error'];
              throw ElasticsearchException(
                'Reindex worker failed: ${err is Map ? (err['reason'] ?? err['type']) : err}',
                details: err,
              );
            }
            final resp = taskStatus['response'] as Map<String, dynamic>?;
            final took = (resp?['took'] as num?)?.toDouble() ?? 0;
            if (took > maxEsTook) maxEsTook = took;
            completedTasks.add(taskId);
          }
        }

        // Aggregate progress across all worker indices
        int currentProcessed = 0;
        int currentTotal = 0;
        for (final tId in taskIds) {
          currentProcessed += taskProcessedDocs[tId] ?? 0;
          currentTotal += taskTotalDocs[tId] ?? 0;
        }
        if (currentTotal > totalDocsCombined) totalDocsCombined = currentTotal;

        if (totalDocsCombined > 0) {
          final frac = (currentProcessed / totalDocsCombined).clamp(0.0, 1.0);
          onProgress?.call(currentProcessed, totalDocsCombined, frac);
        }
      }
    } finally {
      stopwatch.stop();
      _activeReindexTaskIds.clear();
      // Guarantee index settings are restored to production defaults and refreshed
      for (final targetIndex in destIndices) {
        try {
          await updateIndexSettings(targetIndex, {
            'index.refresh_interval': '1s',
            'index.translog.durability': 'request',
            'index.translog.sync_interval': '5s',
            'index.translog.flush_threshold_size': '512mb',
          });
          await refreshIndex(targetIndex);
        } catch (_) {}
      }
    }

    final totalProcessed = taskProcessedDocs.values.fold<int>(0, (a, b) => a + b);
    return {
      'durationMs': stopwatch.elapsedMilliseconds.toDouble(),
      'esTookMs': maxEsTook > 0 ? maxEsTook : stopwatch.elapsedMilliseconds.toDouble(),
      'docsReindexed': totalProcessed > 0 ? totalProcessed : totalDocsCombined,
      'workers': destIndices.length,
      'destIndices': destIndices,
    };
  }

  // 9. Search Benchmark Iteration with Heavy Aggregations & Concurrent Workers
  Future<Map<String, dynamic>> executeSearchIteration({
    required String indexName,
    int workers = 1,
    bool Function()? isStopRequested,
  }) async {
    if (isStopRequested?.call() == true) {
      throw BenchmarkUserCancelledException('Search stopped by user.');
    }
    final searchBody = {
      'size': 0,
      'query': {
        'bool': {
          'must': [
            {
              'bool': {
                'should': [
                  {'wildcard': {'message': '*SQL Injection*'}},
                  {'wildcard': {'message': '*Cross-site Scripting*'}},
                  {'wildcard': {'message': '*Remote Code Execution*'}},
                  {'wildcard': {'message': '*Path Traversal*'}},
                ]
              }
            }
          ],
          'filter': [
            {
              'range': {
                '@timestamp': {
                  'gte': 'now-90d',
                  'lte': 'now+1d',
                }
              }
            }
          ]
        }
      },
      'aggs': {
        'timeline': {
          'date_histogram': {
            'field': '@timestamp',
            'fixed_interval': '1h',
          },
          'aggs': {
            'unique_sources': {
              'cardinality': {'field': '@timestamp'}
            }
          }
        },
        'signature_buckets': {
          'terms': {
            'field': '_index',
            'size': 20,
          }
        }
      }
    };

    final effectiveWorkers = workers.clamp(1, 64);
    final stopwatch = Stopwatch()..start();
    final futures = List.generate(
      effectiveWorkers,
      (_) => _request(
        'POST',
        '/$indexName/_search',
        body: searchBody,
        queryParams: {
          'max_concurrent_shard_requests': '100',
          'request_cache': 'false',
        },
        timeout: const Duration(seconds: 60),
      ),
    );

    final results = await Future.wait(futures);
    stopwatch.stop();

    double totalEsTook = 0.0;
    int totalHits = 0;
    for (final res in results) {
      final took = (res is Map ? (res['took'] as num?)?.toDouble() : null) ?? 0.0;
      totalEsTook += took;
      final hits = (res is Map && res['hits'] is Map && (res['hits'] as Map)['total'] is Map)
          ? ((res['hits'] as Map)['total']['value'] ?? 0)
          : 0;
      totalHits += (hits is num ? hits.toInt() : 0);
    }
    final avgEsTook = results.isNotEmpty ? totalEsTook / results.length : stopwatch.elapsedMilliseconds.toDouble();

    return {
      'durationMs': stopwatch.elapsedMilliseconds.toDouble(),
      'esTookMs': avgEsTook,
      'hits': totalHits,
      'workers': effectiveWorkers,
    };
  }

  // 10. Clean Benchmark Resources
  Future<Map<String, int>> cleanBenchmarkResources() async {
    int deletedIndices = 0;
    int deletedPipelines = 0;
    int deletedPolicies = 0;

    // 0. Cancel any running reindex tasks across cluster before deleting resources
    await cancelAllReindexTasks();

    // 1. Delete indices matching elkybench-* (safely using exact names to bypass cluster destructive_requires_name locks)
    try {
      final catIndices = await _request('GET', '/_cat/indices?format=json');
      if (catIndices is List) {
        for (final item in catIndices) {
          if (item is Map && item['index'] != null) {
            final idxName = item['index'].toString();
            if (idxName.startsWith('elkybench-') || idxName.startsWith('.enrich-elkybench-')) {
              try {
                await _request('DELETE', '/$idxName');
                deletedIndices++;
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {
      try {
        await _request('DELETE', '/elkybench-*');
      } catch (_) {}
    }

    // 2. Find and delete pipelines
    try {
      final pipelines = await _request('GET', '/_ingest/pipeline/elkybench-*');
      if (pipelines is Map) {
        for (final key in pipelines.keys) {
          try {
            await _request('DELETE', '/_ingest/pipeline/$key');
            deletedPipelines++;
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 3. Find and delete enrich policies
    try {
      final policies = await _request('GET', '/_enrich/policy');
      if (policies is Map && policies['policies'] is List) {
        for (final p in policies['policies']) {
          final pMap = p as Map<String, dynamic>;
          String? name;
          if (pMap.containsKey('config')) {
            final config = pMap['config'] as Map<String, dynamic>?;
            final match = config?['match'] as Map<String, dynamic>?;
            name = match?['name'] as String?;
          }
          name ??= pMap.keys.first;
          if (name.startsWith('elkybench-')) {
            try {
              await _request('DELETE', '/_enrich/policy/$name');
              deletedPolicies++;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    return {
      'indices': deletedIndices,
      'pipelines': deletedPipelines,
      'policies': deletedPolicies,
    };
  }
}
