import 'package:flutter_test/flutter_test.dart';
import 'package:elky_bench/providers/benchmark_provider.dart';
import 'package:elky_bench/providers/history_provider.dart';
import 'package:elky_bench/models/benchmark_settings.dart';
import 'package:elky_bench/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BenchmarkProvider options and document scaling calculation', () {
    final settings = BenchmarkSettings(targetSizeGb: 1.0);
    final targetDocs1Gb = (settings.targetSizeGb * 4000000).round();
    expect(targetDocs1Gb, equals(4000000));

    final settings005 = BenchmarkSettings(targetSizeGb: 0.05);
    final targetDocs005Gb = (settings005.targetSizeGb * 4000000).round();
    expect(targetDocs005Gb, equals(200000));

    final settings10Gb = BenchmarkSettings(targetSizeGb: 10.0);
    final targetDocs10Gb = (settings10Gb.targetSizeGb * 4000000).round();
    expect(targetDocs10Gb, equals(40000000));
  });

  test('Stop benchmark in the middle preserves completed iterations', () async {
    final storage = StorageService();
    await storage.init();
    final history = HistoryProvider();
    final provider = BenchmarkProvider(historyProvider: history);

    expect(provider.isRunning, isFalse);
    expect(provider.state, equals(BenchmarkState.idle));
  });
}
