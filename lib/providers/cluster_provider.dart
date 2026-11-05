import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/cluster_config.dart';
import '../models/cluster_stats.dart';
import '../services/elasticsearch_service.dart';
import '../services/storage_service.dart';

class ClusterProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();

  List<ClusterConfig> _clusters = [];
  ClusterConfig? _selectedCluster;
  ClusterStats? _currentStats;
  bool _isLoading = false;
  String? _statsError;
  Timer? _pollingTimer;
  int _pollIntervalSec = 10;

  List<ClusterConfig> get clusters => _clusters;
  ClusterConfig? get selectedCluster => _selectedCluster;
  ClusterStats? get currentStats => _currentStats;
  bool get isLoading => _isLoading;
  String? get statsError => _statsError;
  int get pollIntervalSec => _pollIntervalSec;

  ClusterProvider() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    _clusters = await _storage.loadClusters();

    if (_clusters.isEmpty) {
      // Seed initial local cluster template
      final defaultCluster = ClusterConfig(
        id: 'cluster-local',
        name: 'Local Cluster',
        url: 'http://localhost:9200',
        authType: 'none',
        sslMode: 'bypass',
        createdAt: DateTime.now(),
      );
      _clusters.add(defaultCluster);
      await _storage.saveClusters(_clusters);
    }

    final savedId = await _storage.loadSelectedClusterId();

    if (savedId != null) {
      final found = _clusters.where((c) => c.id == savedId).toList();
      if (found.isNotEmpty) {
        _selectedCluster = found.first;
      }
    }

    if (_selectedCluster == null && _clusters.isNotEmpty) {
      _selectedCluster = _clusters.first;
    }

    _isLoading = false;
    notifyListeners();

    if (_selectedCluster != null) {
      startMonitoring();
    }
  }

  void setPollInterval(int seconds) {
    if (seconds <= 2) seconds = 2;
    _pollIntervalSec = seconds;
    if (_selectedCluster != null) {
      startMonitoring();
    }
  }

  void selectCluster(ClusterConfig? cluster) {
    if (_selectedCluster?.id == cluster?.id) return;
    _selectedCluster = cluster;
    _storage.saveSelectedClusterId(cluster?.id);
    _currentStats = null;
    _statsError = null;
    notifyListeners();

    if (_selectedCluster != null) {
      startMonitoring();
    } else {
      stopMonitoring();
    }
  }

  Future<void> addCluster(ClusterConfig cluster) async {
    _clusters.add(cluster);
    await _storage.saveClusters(_clusters);
    if (_selectedCluster == null) {
      selectCluster(cluster);
    } else {
      notifyListeners();
    }
  }

  Future<void> updateCluster(ClusterConfig cluster) async {
    final idx = _clusters.indexWhere((c) => c.id == cluster.id);
    if (idx != -1) {
      _clusters[idx] = cluster;
      await _storage.saveClusters(_clusters);
      if (_selectedCluster?.id == cluster.id) {
        _selectedCluster = cluster;
        startMonitoring();
      }
      notifyListeners();
    }
  }

  Future<void> deleteCluster(String id) async {
    _clusters.removeWhere((c) => c.id == id);
    await _storage.saveClusters(_clusters);

    if (_selectedCluster?.id == id) {
      _selectedCluster = _clusters.isNotEmpty ? _clusters.first : null;
      await _storage.saveSelectedClusterId(_selectedCluster?.id);
      if (_selectedCluster != null) {
        startMonitoring();
      } else {
        stopMonitoring();
        _currentStats = null;
      }
    }
    notifyListeners();
  }

  void startMonitoring() {
    _pollingTimer?.cancel();
    fetchStats();
    _pollingTimer = Timer.periodic(Duration(seconds: _pollIntervalSec), (_) {
      fetchStats();
    });
  }

  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> fetchStats() async {
    final cluster = _selectedCluster;
    if (cluster == null) return;

    try {
      final es = ElasticsearchService(cluster);
      final stats = await es.getClusterStats();
      es.close();

      _currentStats = stats;
      _statsError = null;
      notifyListeners();
    } catch (e) {
      _statsError = e.toString();
      _currentStats = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
