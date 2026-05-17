import 'package:flutter/material.dart';
import '../theme/flux_theme.dart';

/// Shows the extraction pipeline steps: detect → capture → merge → optimize.
class PipelineSteps extends StatelessWidget {
  /// 0-based index of the currently active step.
  final int activeStep;
  final String url;

  const PipelineSteps({
    super.key,
    required this.activeStep,
    required this.url,
  });

  static const _steps = [
    'Detecting media source',
    'Capturing stream data',
    'Merging audio & video',
    'Optimizing download',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FluxColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FluxColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // URL row
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: FluxColors.cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: FluxColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Steps
          ..._steps.asMap().entries.map((entry) {
            final i = entry.key;
            final label = entry.value;
            final isDone = i < activeStep;
            final isActive = i == activeStep;
            final isPending = i > activeStep;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? FluxColors.stepDone
                          : isActive
                              ? FluxColors.stepActive
                              : FluxColors.stepPending,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: (isDone || isActive)
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isPending
                          ? FluxColors.textMuted
                          : FluxColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
