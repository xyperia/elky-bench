class NodeStatItem {
  final String id;
  final String name;
  final List<String> roles;
  final double cpuPercent;
  final int heapUsedBytes;
  final int heapMaxBytes;
  final double heapPercent;
  final int diskUsedBytes;
  final int diskTotalBytes;
  final double diskPercent;

  NodeStatItem({
    required this.id,
    required this.name,
    required this.roles,
    required this.cpuPercent,
    required this.heapUsedBytes,
    required this.heapMaxBytes,
    required this.heapPercent,
    required this.diskUsedBytes,
    required this.diskTotalBytes,
    required this.diskPercent,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'roles': roles,
    'cpuPercent': cpuPercent,
    'heapUsedBytes': heapUsedBytes,
    'heapMaxBytes': heapMaxBytes,
    'heapPercent': heapPercent,
    'diskUsedBytes': diskUsedBytes,
    'diskTotalBytes': diskTotalBytes,
    'diskPercent': diskPercent,
  };

  factory NodeStatItem.fromJson(Map<String, dynamic> json) => NodeStatItem(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    roles: (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    cpuPercent: (json['cpuPercent'] as num?)?.toDouble() ?? 0.0,
    heapUsedBytes: (json['heapUsedBytes'] as num?)?.toInt() ?? 0,
    heapMaxBytes: (json['heapMaxBytes'] as num?)?.toInt() ?? 0,
    heapPercent: (json['heapPercent'] as num?)?.toDouble() ?? 0.0,
    diskUsedBytes: (json['diskUsedBytes'] as num?)?.toInt() ?? 0,
    diskTotalBytes: (json['diskTotalBytes'] as num?)?.toInt() ?? 0,
    diskPercent: (json['diskPercent'] as num?)?.toDouble() ?? 0.0,
  );
}

class ClusterStats {
  final double cpuPercent;
  final int heapUsedBytes;
  final int heapMaxBytes;
  final double heapPercent;
  final int diskUsedBytes;
  final int diskTotalBytes;
  final double diskPercent;
  final int nodeCount;
  final String status; // green, yellow, red, unknown
  final DateTime timestamp;
  final List<NodeStatItem> nodes;

  ClusterStats({
    required this.cpuPercent,
    required this.heapUsedBytes,
    required this.heapMaxBytes,
    required this.heapPercent,
    required this.diskUsedBytes,
    required this.diskTotalBytes,
    required this.diskPercent,
    required this.nodeCount,
    required this.status,
    required this.timestamp,
    required this.nodes,
  });

  Map<String, dynamic> toJson() => {
    'cpuPercent': cpuPercent,
    'heapUsedBytes': heapUsedBytes,
    'heapMaxBytes': heapMaxBytes,
    'heapPercent': heapPercent,
    'diskUsedBytes': diskUsedBytes,
    'diskTotalBytes': diskTotalBytes,
    'diskPercent': diskPercent,
    'nodeCount': nodeCount,
    'status': status,
    'timestamp': timestamp.toIso8601String(),
    'nodes': nodes.map((n) => n.toJson()).toList(),
  };

  factory ClusterStats.fromJson(Map<String, dynamic> json) => ClusterStats(
    cpuPercent: (json['cpuPercent'] as num?)?.toDouble() ?? 0.0,
    heapUsedBytes: (json['heapUsedBytes'] as num?)?.toInt() ?? 0,
    heapMaxBytes: (json['heapMaxBytes'] as num?)?.toInt() ?? 0,
    heapPercent: (json['heapPercent'] as num?)?.toDouble() ?? 0.0,
    diskUsedBytes: (json['diskUsedBytes'] as num?)?.toInt() ?? 0,
    diskTotalBytes: (json['diskTotalBytes'] as num?)?.toInt() ?? 0,
    diskPercent: (json['diskPercent'] as num?)?.toDouble() ?? 0.0,
    nodeCount: (json['nodeCount'] as num?)?.toInt() ?? 0,
    status: json['status'] as String? ?? 'unknown',
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    nodes: (json['nodes'] as List<dynamic>?)
            ?.map((e) => NodeStatItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    int i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }
    return '${dBytes.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
