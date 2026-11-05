import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class EyebrowPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color border;
  final Color text;

  const EyebrowPill({
    super.key,
    required this.label,
    this.bg = AppColors.purpleBg,
    this.border = AppColors.purpleBorder,
    this.text = AppColors.purpleText,
  });

  factory EyebrowPill.blue({required String label}) => EyebrowPill(
    label: label,
    bg: const Color(0xFFEFF6FF),
    border: const Color(0xFFBFDBFE),
    text: AppColors.primaryBlue,
  );

  factory EyebrowPill.teal({required String label}) => EyebrowPill(
    label: label,
    bg: AppColors.successBg,
    border: AppColors.successBorder,
    text: AppColors.successText,
  );

  factory EyebrowPill.purple({required String label}) => EyebrowPill(
    label: label,
    bg: AppColors.purpleBg,
    border: AppColors.purpleBorder,
    text: AppColors.purpleText,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: text,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
