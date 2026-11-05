import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/history_provider.dart';
import '../services/pdf_report_service.dart';
import '../theme/app_colors.dart';
import '../widgets/eyebrow_pill.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  void _openPdf(BuildContext context, String? path) {
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No PDF path available')),
      );
      return;
    }
    if (Platform.isMacOS) {
      Process.run('open', [path]);
    } else if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    }
  }

  void _confirmDelete(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Result', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text('Are you sure you want to delete this benchmark record?'),
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
      await Provider.of<HistoryProvider>(context, listen: false).deleteResult(id);
    }
  }

  void _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Clear All History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text('Are you sure you want to delete all past benchmark results? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await Provider.of<HistoryProvider>(context, listen: false).clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Consumer<HistoryProvider>(
      builder: (context, historyProv, _) {
        final history = historyProv.history;

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
                            EyebrowPill.teal(label: 'HISTORICAL ARCHIVES'),
                            const SizedBox(height: 8),
                            const Text(
                              'Benchmark Reports & History',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navyDark,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Review previous performance runs, examine latency profiles, and re-export technical verification reports.',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (history.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          onPressed: () => _confirmClearAll(context),
                          icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: AppColors.dangerRed),
                          label: const Text('Clear All History', style: TextStyle(color: AppColors.dangerRed)),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (history.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(48),
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
                                color: AppColors.tealAccent.withValues(alpha: 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history_rounded, size: 28, color: AppColors.tealAccent),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Benchmark Runs Yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navyDark),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Execute an Ingest or Search scenario to generate performance reports and historical records.',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: history.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = history[index];
                        final isIngest = item.scenarioType.toLowerCase() == 'ingest';

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isIngest
                                      ? AppColors.purpleBg
                                      : AppColors.successBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isIngest
                                        ? AppColors.purpleBorder
                                        : AppColors.successBorder,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    isIngest ? Icons.upload_file_rounded : Icons.search_rounded,
                                    color: isIngest ? AppColors.purpleText : AppColors.successText,
                                    size: 22,
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
                                            isIngest ? 'Ingest & Reindex Benchmark' : 'Complex Aggregation Search',
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: item.status == 'completed'
                                                ? AppColors.successBg
                                                : AppColors.warningBg,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: item.status == 'completed'
                                                  ? AppColors.successBorder
                                                  : AppColors.warningBorder,
                                            ),
                                          ),
                                          child: Text(
                                            item.status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: item.status == 'completed'
                                                  ? AppColors.successText
                                                  : AppColors.warningText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Cluster: ${item.clusterName} • Executed: ${dateFormat.format(item.startTime)} • Total Time: ${(item.totalDurationMs / 1000).toStringAsFixed(1)}s',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        _buildMetricBadge('Iterations', '${item.iterationsCompleted}'),
                                        _buildMetricBadge('Avg Duration', '${(item.avgIterationMs / 1000).toStringAsFixed(2)}s'),
                                        _buildMetricBadge('p95', '${(item.p95Ms / 1000).toStringAsFixed(2)}s'),
                                        _buildMetricBadge('p99', '${(item.p99Ms / 1000).toStringAsFixed(2)}s'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // PDF and Delete Actions
                              Row(
                                children: [
                                  if (item.pdfPath != null) ...[
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                                      onPressed: () => _openPdf(context, item.pdfPath),
                                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                      label: const Text('Open PDF'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => PdfReportService.exportReportToDirectory(context, item.pdfPath!),
                                      icon: const Icon(Icons.drive_file_move_rounded, size: 15),
                                      label: const Text('Save To...'),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Generating PDF Report...')),
                                      );
                                      final path = await historyProv.regeneratePdf(item);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: AppColors.successText,
                                            content: Text('PDF Generated: $path'),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.refresh_rounded, size: 15),
                                    label: const Text('Re-Export'),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.dangerRed),
                                    onPressed: () => _confirmDelete(context, item.id),
                                    tooltip: 'Delete Record',
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

  Widget _buildMetricBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.slateLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.navyDark)),
        ],
      ),
    );
  }
}
