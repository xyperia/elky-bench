import 'package:flutter/foundation.dart';
import '../models/benchmark_settings.dart';
import '../services/storage_service.dart';

class SettingsProvider with ChangeNotifier {
  final StorageService _storage = StorageService();
  BenchmarkSettings _settings = BenchmarkSettings();
  bool _isLoaded = false;
  Future<void>? _loadingFuture;

  BenchmarkSettings get settings => _settings;
  bool get isLoaded => _isLoaded;

  SettingsProvider() {
    _loadingFuture = loadSettings();
  }

  Future<void> loadSettings() async {
    _settings = await _storage.loadSettings();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateSettings(BenchmarkSettings newSettings) async {
    await _loadingFuture;
    _settings = newSettings;
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> update(void Function(BenchmarkSettings s) modifier) async {
    await _loadingFuture;
    modifier(_settings);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }
}
