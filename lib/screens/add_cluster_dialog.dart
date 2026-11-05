import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/cluster_config.dart';
import '../services/elasticsearch_service.dart';
import '../theme/app_colors.dart';

class AddClusterDialog extends StatefulWidget {
  final ClusterConfig? initialConfig;

  const AddClusterDialog({super.key, this.initialConfig});

  @override
  State<AddClusterDialog> createState() => _AddClusterDialogState();
}

class _AddClusterDialogState extends State<AddClusterDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  String _authType = 'apikey'; // 'apikey' or 'basic'
  String _sslMode = 'bypass'; // 'bypass' or 'ca'
  String? _caCertPath;
  String? _caCertContent;

  bool _isTesting = false;
  String? _testSuccessMessage;
  String? _testErrorMessage;

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig;
    _nameController = TextEditingController(text: c?.name ?? '');
    _urlController = TextEditingController(text: c?.url ?? 'https://');
    _apiKeyController = TextEditingController(text: c?.apiKey ?? '');
    _usernameController = TextEditingController(text: c?.username ?? '');
    _passwordController = TextEditingController(text: c?.password ?? '');
    _authType = c?.authType ?? 'apikey';
    _sslMode = c?.sslMode ?? 'bypass';
    _caCertPath = c?.caCertPath;
    _caCertContent = c?.caCertContent;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  ClusterConfig _buildCurrentConfig() {
    return ClusterConfig(
      id: widget.initialConfig?.id ?? const Uuid().v4(),
      name: _nameController.text.trim().isEmpty ? 'Elasticsearch Cluster' : _nameController.text.trim(),
      url: _urlController.text.trim(),
      authType: _authType,
      apiKey: _authType == 'apikey' ? _apiKeyController.text.trim() : null,
      username: _authType == 'basic' ? _usernameController.text.trim() : null,
      password: _authType == 'basic' ? _passwordController.text : null,
      sslMode: _sslMode,
      caCertPath: _caCertPath,
      caCertContent: _caCertContent,
      createdAt: widget.initialConfig?.createdAt ?? DateTime.now(),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _testSuccessMessage = null;
      _testErrorMessage = null;
    });

    final testConfig = _buildCurrentConfig();
    final es = ElasticsearchService(testConfig);

    try {
      final conn = await es.testConnection();
      final health = await es.getClusterHealth();
      es.close();

      final version = conn['version']?['number'] ?? 'Unknown';
      final clusterName = conn['cluster_name'] ?? 'Cluster';
      final nodes = health['number_of_nodes'] ?? '1';
      final status = health['status'] ?? 'green';

      setState(() {
        _isTesting = false;
        _testSuccessMessage = 'Connected! $clusterName (v$version, $nodes nodes, $status status)';
      });
    } catch (e) {
      es.close();
      setState(() {
        _isTesting = false;
        _testErrorMessage = e.toString();
      });
    }
  }

  Future<void> _pickCaCertificate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pem', 'crt', 'cer'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final content = await File(path).readAsString();
      setState(() {
        _caCertPath = path;
        _caCertContent = content;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialConfig != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon badge
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.dns_rounded, size: 20, color: AppColors.primaryBlue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Cluster' : 'Add Elasticsearch Cluster',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navyDark,
                            ),
                          ),
                          const Text(
                            'Enter endpoint details and credentials',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Cluster Name
                _buildFieldLabel('Cluster Name'),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Production AWS Found',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a cluster name' : null,
                ),

                const SizedBox(height: 14),

                // Elasticsearch URL
                _buildFieldLabel('Elasticsearch URL'),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: 'https://cluster.es.io:443',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter an Elasticsearch URL';
                    if (!v.contains('://')) return 'URL must include http:// or https://';
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Auth Method Selector
                _buildFieldLabel('Authentication Method'),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceChip(
                        label: 'API Key',
                        selected: _authType == 'apikey',
                        onSelected: () => setState(() => _authType = 'apikey'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoiceChip(
                        label: 'Username / Password',
                        selected: _authType == 'basic',
                        onSelected: () => setState(() => _authType = 'basic'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Auth Fields
                if (_authType == 'apikey') ...[
                  _buildFieldLabel('API Key (Base64 Encoded)'),
                  TextFormField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. VGVzdEFwaUtleUlkOlRlc3RBcGlLZXlTZWNyZXQ=',
                    ),
                    validator: (v) => _authType == 'apikey' && (v == null || v.trim().isEmpty)
                        ? 'Please enter API Key'
                        : null,
                  ),
                ] else ...[
                  _buildFieldLabel('Username'),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(hintText: 'elastic'),
                    validator: (v) => _authType == 'basic' && (v == null || v.trim().isEmpty)
                        ? 'Please enter username'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _buildFieldLabel('Password'),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: '••••••••'),
                  ),
                ],

                const SizedBox(height: 14),

                // SSL Verification
                _buildFieldLabel('SSL Certificate Verification'),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceChip(
                        label: 'Bypass SSL',
                        selected: _sslMode == 'bypass',
                        onSelected: () => setState(() => _sslMode = 'bypass'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoiceChip(
                        label: 'Provide CA',
                        selected: _sslMode == 'ca',
                        onSelected: () => setState(() => _sslMode = 'ca'),
                      ),
                    ),
                  ],
                ),

                if (_sslMode == 'ca') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickCaCertificate,
                        icon: const Icon(Icons.attach_file_rounded, size: 16),
                        label: const Text('Select CA File (.pem, .crt)'),
                      ),
                    ],
                  ),
                  if (_caCertPath != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Loaded: ${_caCertPath!.split('/').last}',
                      style: const TextStyle(fontSize: 11, color: AppColors.successText),
                    ),
                  ],
                ],

                // Test Connection Feedback
                if (_testSuccessMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.successBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.successText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testSuccessMessage!,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.successText, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_testErrorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.dangerBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.dangerRed),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testErrorMessage!,
                            style: const TextStyle(fontSize: 11, color: AppColors.dangerRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Footer Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Test connection button
                    OutlinedButton(
                      onPressed: _isTesting ? null : _testConnection,
                      child: _isTesting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test Connection'),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              Navigator.of(context).pop(_buildCurrentConfig());
                            }
                          },
                          child: Text(isEditing ? 'Save Changes' : 'Add Cluster'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.navyDark,
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlue.withValues(alpha: 0.08) : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.borderLight,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primaryBlue : AppColors.navyDark,
            ),
          ),
        ),
      ),
    );
  }
}
