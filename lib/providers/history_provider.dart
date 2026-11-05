import 'package:flutter/foundation.dart';
import '../models/benchmark_result.dart';
import '../services/pdf_report_service.dart';
import '../services/storage_service.dart';

class HistoryProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  List<BenchmarkResult> _history = [];
  bool _isLoading = false;

  List<BenchmarkResult> get history => _history;
  bool get isLoading => _isLoading;

  HistoryProvider() {
    loadHistory();
  }

  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();

    _history = await _storage.loadHistory();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addResult(BenchmarkResult result) async {
    _history.insert(0, result);
    await _storage.saveHistory(_history);
    notifyListeners();
  }

  Future<void> deleteResult(String id) async {
    _history.removeWhere((item) => item.id == id);
    await _storage.saveHistory(_history);
    notifyListeners();
  }

  Future<void> clearAll() async {
    _history.clear();
    await _storage.clearHistory();
    notifyListeners();
  }

  Future<String> regeneratePdf(BenchmarkResult result) async {
    final file = await PdfReportService.generateReport(result);
    final updated = result.copyWith(pdfPath: file.path);
    final idx = _history.indexWhere((h) => h.id == result.id);
    if (idx != -1) {
      _history[idx] = updated;
      await _storage.saveHistory(_history);
      notifyListeners();
    }
    return file.path;
  }
}
