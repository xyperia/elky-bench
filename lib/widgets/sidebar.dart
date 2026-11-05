import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cluster_provider.dart';
import '../theme/app_colors.dart';

enum NavigationTab { clusters, benchmark, history, settings }

class AppSidebar extends StatelessWidget {
  final NavigationTab activeTab;
  final ValueChanged<NavigationTab> onTabSelected;

  const AppSidebar({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(
          right: BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.04),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.asset(
                      'assets/images/elky_mascot.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elky Bench',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navyDark,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        'Elasticsearch Benchmark',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Category Overline
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              'MAIN NAVIGATION',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.1,
              ),
            ),
          ),

          // Nav Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _buildNavItem(
                  tab: NavigationTab.clusters,
                  icon: Icons.dns_rounded,
                  label: 'Clusters',
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  tab: NavigationTab.benchmark,
                  icon: Icons.speed_rounded,
                  label: 'Benchmark',
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  tab: NavigationTab.history,
                  icon: Icons.history_rounded,
                  label: 'History & Reports',
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  tab: NavigationTab.settings,
                  icon: Icons.tune_rounded,
                  label: 'Settings',
                ),
              ],
            ),
          ),

          const Spacer(),

          // Active Cluster Pill at bottom
          Consumer<ClusterProvider>(
            builder: (context, clusterProv, _) {
              final cluster = clusterProv.selectedCluster;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.borderLight, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.cloud_queue_rounded, size: 16, color: AppColors.primaryBlue),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cluster?.name ?? 'No Cluster',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navyDark,
                            ),
                          ),
                          Text(
                            cluster != null ? 'Active Target' : 'Configure cluster',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required NavigationTab tab,
    required IconData icon,
    required String label,
  }) {
    final isActive = activeTab == tab;

    return InkWell(
      onTap: () => onTabSelected(tab),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryBlue.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.20))
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? AppColors.primaryBlue : AppColors.navyDark.withValues(alpha: 0.70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.primaryBlue : AppColors.navyDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
