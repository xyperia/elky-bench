import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cluster_stats.dart';
import '../providers/cluster_provider.dart';
import '../theme/app_colors.dart';

class ClusterStatusBar extends StatelessWidget {
  const ClusterStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClusterProvider>(
      builder: (context, clusterProv, _) {
        final cluster = clusterProv.selectedCluster;
        final stats = clusterProv.currentStats;
        final error = clusterProv.statsError;

        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceWhite,
            border: Border(
              top: BorderSide(color: AppColors.borderLight, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Cluster Name and Status Dot
              if (cluster != null) ...[
                _buildStatusDot(error != null ? 'red' : (stats?.status ?? 'unknown')),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    cluster.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyDark,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  error != null
                      ? '(Unreachable)'
                      : (stats != null ? '(${stats.nodeCount} Nodes)' : '(Connecting...)'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: error != null ? AppColors.dangerRed : AppColors.textMuted,
                  ),
                ),
              ] else ...[
                const Icon(Icons.circle_outlined, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 8),
                const Text(
                  'No cluster active',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],

              const Spacer(),

              // Stats or Error
              if (cluster != null) ...[
                if (error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.dangerRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.dangerRed),
                        const SizedBox(width: 6),
                        const Text(
                          'Cluster Unreachable',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dangerRed,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => clusterProv.fetchStats(),
                          borderRadius: BorderRadius.circular(4),
                          child: const Tooltip(
                            message: 'Retry Connection',
                            child: Icon(Icons.refresh_rounded, size: 14, color: AppColors.dangerRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (stats != null) ...[
                  // CPU Metric
                  _buildMetricPill(
                    icon: Icons.memory_rounded,
                    label: 'CPU',
                    value: '${stats.cpuPercent.toStringAsFixed(1)}%',
                    percent: stats.cpuPercent,
                  ),
                  const SizedBox(width: 12),

                  // JVM Heap Metric
                  _buildMetricPill(
                    icon: Icons.layers_rounded,
                    label: 'JVM Heap',
                    value: '${stats.heapPercent.toStringAsFixed(1)}% (${ClusterStats.formatBytes(stats.heapUsedBytes)})',
                    percent: stats.heapPercent,
                  ),
                  const SizedBox(width: 12),

                  // Total Disk Metric
                  _buildMetricPill(
                    icon: Icons.storage_rounded,
                    label: 'Disk Used',
                    value: '${ClusterStats.formatBytes(stats.diskUsedBytes)} (${stats.diskPercent.toStringAsFixed(1)}%)',
                    percent: stats.diskPercent,
                  ),
                ] else ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Gathering cluster stats...',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ],

              const SizedBox(width: 16),
              // Poll frequency tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.slateBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  '${clusterProv.pollIntervalSec}s POLL',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusDot(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'green':
        color = const Color(0xFF10B981);
        break;
      case 'yellow':
        color = AppColors.yellowWarm;
        break;
      case 'red':
        color = AppColors.dangerRed;
        break;
      default:
        color = AppColors.textMuted;
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required String value,
    required double percent,
  }) {
    Color barColor;
    if (percent >= 85) {
      barColor = AppColors.dangerRed;
    } else if (percent >= 70) {
      barColor = AppColors.yellowWarm;
    } else {
      barColor = AppColors.tealAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.slateLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.navyDark),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: percent >= 85 ? AppColors.dangerRed : AppColors.navyDark,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: barColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
