import 'package:flutter_test/flutter_test.dart';
import 'package:elky_bench/providers/settings_provider.dart';
import 'package:elky_bench/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SettingsProvider synchronizes and persists shard and pipeline settings', () async {
    final storage = StorageService();
    await storage.init();

    final settingsProv = SettingsProvider();
    await settingsProv.loadSettings();

    // Update primary shards to 10, pipeline intensity to extreme, workers to 16, and mode to no_iterations
    await settingsProv.update((s) {
      s.primaryShards = 10;
      s.replicaShards = 1;
      s.pipelineIntensity = 'extreme';
      s.workers = 16;
      s.targetSizeGb = 1.0;
      s.benchmarkMode = 'no_iterations';
    });

    expect(settingsProv.settings.primaryShards, equals(10));
    expect(settingsProv.settings.replicaShards, equals(1));
    expect(settingsProv.settings.pipelineIntensity, equals('extreme'));
    expect(settingsProv.settings.workers, equals(16));
    expect(settingsProv.settings.targetSizeGb, equals(1.0));
    expect(settingsProv.settings.benchmarkMode, equals('no_iterations'));

    // Reload from storage to verify persistence
    final reloaded = await storage.loadSettings();
    expect(reloaded.primaryShards, equals(10));
    expect(reloaded.replicaShards, equals(1));
    expect(reloaded.pipelineIntensity, equals('extreme'));
    expect(reloaded.workers, equals(16));
    expect(reloaded.targetSizeGb, equals(1.0));
    expect(reloaded.benchmarkMode, equals('no_iterations'));
  });
}
