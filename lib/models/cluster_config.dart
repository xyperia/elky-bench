class ClusterConfig {
  final String id;
  final String name;
  final String url;
  final String authType; // 'apikey' or 'basic'
  final String? apiKey;
  final String? username;
  final String? password;
  final String sslMode; // 'bypass' or 'ca'
  final String? caCertContent;
  final String? caCertPath;
  final DateTime createdAt;

  ClusterConfig({
    required this.id,
    required this.name,
    required this.url,
    required this.authType,
    this.apiKey,
    this.username,
    this.password,
    required this.sslMode,
    this.caCertContent,
    this.caCertPath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'authType': authType,
    'apiKey': apiKey,
    'username': username,
    'password': password,
    'sslMode': sslMode,
    'caCertContent': caCertContent,
    'caCertPath': caCertPath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ClusterConfig.fromJson(Map<String, dynamic> json) => ClusterConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    authType: json['authType'] as String? ?? 'apikey',
    apiKey: json['apiKey'] as String?,
    username: json['username'] as String?,
    password: json['password'] as String?,
    sslMode: json['sslMode'] as String? ?? 'bypass',
    caCertContent: json['caCertContent'] as String?,
    caCertPath: json['caCertPath'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  ClusterConfig copyWith({
    String? id,
    String? name,
    String? url,
    String? authType,
    String? apiKey,
    String? username,
    String? password,
    String? sslMode,
    String? caCertContent,
    String? caCertPath,
    DateTime? createdAt,
  }) {
    return ClusterConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      authType: authType ?? this.authType,
      apiKey: apiKey ?? this.apiKey,
      username: username ?? this.username,
      password: password ?? this.password,
      sslMode: sslMode ?? this.sslMode,
      caCertContent: caCertContent ?? this.caCertContent,
      caCertPath: caCertPath ?? this.caCertPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
