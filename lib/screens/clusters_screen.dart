import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/cluster_config.dart';
import '../providers/benchmark_provider.dart';
import '../providers/cluster_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/eyebrow_pill.dart';
import 'add_cluster_dialog.dart';

class ClustersScreen extends StatelessWidget {
  const ClustersScreen({super.key});

  void _showAddClusterDialog(BuildContext context, [ClusterConfig? existing]) async {
    final result = await showDialog<ClusterConfig>(
      context: context,
      builder: (ctx) => AddClusterDialog(initialConfig: existing),
    );

    if (result != null && context.mounted) {
      final prov = Provider.of<ClusterProvider>(context, listen: false);
      if (existing != null) {
        await prov.updateCluster(result);
      } else {
        await prov.addCluster(result);
      }
    }
  }

  void _confirmDeleteCluster(BuildContext context, ClusterConfig cluster) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Cluster', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text('Are you sure you want to remove "${cluster.name}" from saved clusters?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await Provider.of<ClusterProvider>(context, listen: false).deleteCluster(cluster.id);
    }
  }

  void _cleanClusterResources(BuildContext context, ClusterConfig cluster) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Clean Cluster Resources', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text(
          'This will remove all benchmark indices (elkybench-*), ingest pipelines, and enrich policies from cluster "${cluster.name}".\n\nAre you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clean Resources'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final benchProv = Provider.of<BenchmarkProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cleaning cluster benchmark resources...')),
      );
      try {
        final res = await benchProv.cleanCluster(cluster);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.successText,
              content: Text(
                'Cluster cleaned! Removed ${res['indices']} indices, ${res['pipelines']} pipelines, and ${res['policies']} enrich policies.',
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: AppColors.dangerRed, content: Text('Cleanup failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClusterProvider>(
      builder: (context, clusterProv, _) {
        final clusters = clusterProv.clusters;
        final selected = clusterProv.selectedCluster;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            EyebrowPill.blue(label: 'ELASTIC CLUSTER ARCHITECTURE'),
                            const SizedBox(height: 8),
                            const Text(
                              'Clusters Management',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navyDark,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Configure endpoints, authentication credentials, and monitor real-time resource state.',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddClusterDialog(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Cluster'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (clusters.isEmpty) ...[
                    // Empty state
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.dns_rounded, size: 28, color: AppColors.primaryBlue),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Clusters Added Yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navyDark),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add an Elasticsearch cluster to start benchmarking ingest throughput and query latency.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _showAddClusterDialog(context),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add Your First Cluster'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Clusters List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: clusters.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final cluster = clusters[index];
                        final isSelected = selected?.id == cluster.id;

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryBlue.withValues(alpha: 0.10)
                                      : AppColors.slateBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.cloud_rounded,
                                    color: isSelected ? AppColors.primaryBlue : AppColors.navyDark,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            cluster.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.navyDark,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (isSelected)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.successBg,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.successBorder),
                                            ),
                                            child: const Text(
                                              'ACTIVE TARGET',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.successText,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Tooltip(
                                            message: cluster.url,
                                            child: Text(
                                              cluster.url,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontFamily: 'monospace',
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: cluster.url));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('URL copied to clipboard')),
                                            );
                                          },
                                          child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        _buildTag(
                                          label: cluster.authType == 'apikey' ? 'API Key Auth' : 'Basic Auth',
                                          color: AppColors.purpleBg,
                                          borderColor: AppColors.purpleBorder,
                                          textColor: AppColors.purpleText,
                                        ),
                                        _buildTag(
                                          label: cluster.sslMode == 'bypass' ? 'SSL Bypass' : 'Custom CA',
                                          color: AppColors.slateBg,
                                          borderColor: AppColors.borderLight,
                                          textColor: AppColors.slateText,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Action Buttons
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isSelected)
                                    OutlinedButton(
                                      onPressed: () => clusterProv.selectCluster(cluster),
                                      child: const Text('Set as Active'),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      onPressed: null,
                                      icon: const Icon(Icons.check_rounded, size: 16),
                                      label: const Text('Active'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.successText,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _cleanClusterResources(context, cluster),
                                    icon: const Icon(Icons.cleaning_services_rounded, size: 15, color: AppColors.textMuted),
                                    label: const Text('Clean', style: TextStyle(color: AppColors.textMuted)),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryBlue),
                                    onPressed: () => _showAddClusterDialog(context, cluster),
                                    tooltip: 'Edit Cluster',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.dangerRed),
                                    onPressed: () => _confirmDeleteCluster(context, cluster),
                                    tooltip: 'Delete Cluster',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTag({
    required String label,
    required Color color,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
