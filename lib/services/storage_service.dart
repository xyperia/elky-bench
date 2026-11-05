import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/cluster_config.dart';
import '../models/benchmark_result.dart';
import '../models/benchmark_settings.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Directory? _storageDir;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _storageDir = await getApplicationSupportDirectory();
    } catch (e) {
      // Fallback for tests or unsupported environments
      _storageDir = Directory('${Directory.current.path}/.elkybench_data');
    }
    if (!_storageDir!.existsSync()) {
      _storageDir!.createSync(recursive: true);
    }
    _initialized = true;
  }

  File _getFile(String filename) {
    return File('${_storageDir!.path}/$filename');
  }

  // Clusters
  Future<List<ClusterConfig>> loadClusters() async {
    await init();
    final file = _getFile('clusters.json');
    if (!file.existsSync()) return [];
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final List<dynamic> data = jsonDecode(content);
      return data.map((e) => ClusterConfig.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading clusters: $e');
      return [];
    }
  }

  Future<void> saveClusters(List<ClusterConfig> clusters) async {
    await init();
    final file = _getFile('clusters.json');
    final data = clusters.map((e) => e.toJson()).toList();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  // Selected Cluster ID
  Future<String?> loadSelectedClusterId() async {
    await init();
    final file = _getFile('selected_cluster.txt');
    if (!file.existsSync()) return null;
    try {
      final id = await file.readAsString();
      return id.trim().isEmpty ? null : id.trim();
    } catch (e) {
      return null;
    }
  }

  Future<void> saveSelectedClusterId(String? id) async {
    await init();
    final file = _getFile('selected_cluster.txt');
    if (id == null) {
      if (file.existsSync()) file.deleteSync();
    } else {
      await file.writeAsString(id);
    }
  }

  // Benchmark Settings
  Future<BenchmarkSettings> loadSettings() async {
    await init();
    final file = _getFile('settings.json');
    if (!file.existsSync()) return BenchmarkSettings();
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return BenchmarkSettings();
      return BenchmarkSettings.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error loading settings: $e');
      return BenchmarkSettings();
    }
  }

  Future<void> saveSettings(BenchmarkSettings settings) async {
    await init();
    final file = _getFile('settings.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(settings.toJson()));
  }

  // Benchmark Results History
  Future<List<BenchmarkResult>> loadHistory() async {
    await init();
    final file = _getFile('history.json');
    if (!file.existsSync()) return [];
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final List<dynamic> data = jsonDecode(content);
      return data.map((e) => BenchmarkResult.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading history: $e');
      return [];
    }
  }

  Future<void> saveHistory(List<BenchmarkResult> history) async {
    await init();
    final file = _getFile('history.json');
    final data = history.map((e) => e.toJson()).toList();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<void> addHistoryItem(BenchmarkResult item) async {
    final list = await loadHistory();
    list.insert(0, item);
    await saveHistory(list);
  }

  Future<void> deleteHistoryItem(String id) async {
    final list = await loadHistory();
    list.removeWhere((item) => item.id == id);
    await saveHistory(list);
  }

  Future<void> clearHistory() async {
    await saveHistory([]);
  }
}
