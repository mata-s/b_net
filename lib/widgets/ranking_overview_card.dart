import 'package:b_net/widgets/ranking_next_update_label.dart';
import 'package:flutter/material.dart';

class RankingOverviewCard extends StatelessWidget {
  const RankingOverviewCard({
    super.key,
    required this.title,
    required this.periodLabel,
    required this.isSeasonMode,
    required this.modeLabel,
    required this.ageLabel,
    required this.metricLabel,
    required this.participantsCount,
    required this.onModeTap,
    required this.onAgeTap,
    required this.onMetricTap,
    required this.onPreviousMetric,
    required this.onNextMetric,
  });

  final String title;
  final String periodLabel;
  final bool isSeasonMode;
  final String modeLabel;
  final String ageLabel;
  final String metricLabel;
  final int participantsCount;
  final VoidCallback onModeTap;
  final VoidCallback onAgeTap;
  final VoidCallback onMetricTap;
  final VoidCallback onPreviousMetric;
  final VoidCallback onNextMetric;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF126BC2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                periodLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              RankingNextUpdateLabel(isSeasonMode: isSeasonMode),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0x1F000000)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OverviewFilterButton(
                  label: modeLabel,
                  onTap: onModeTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewFilterButton(
                  label: ageLabel,
                  onTap: onAgeTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7FC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD7E5F2)),
            ),
            child: Row(
              children: [
                if (isSeasonMode)
                  IconButton(
                    onPressed: onPreviousMetric,
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: accent,
                    visualDensity: VisualDensity.compact,
                  )
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: isSeasonMode ? onMetricTap : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              metricLabel,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (isSeasonMode) ...[
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.expand_more_rounded,
                              size: 19,
                              color: Colors.black45,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (isSeasonMode)
                  IconButton(
                    onPressed: onNextMetric,
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: accent,
                    visualDensity: VisualDensity.compact,
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Text(
            '$participantsCount人がランキングに参加中',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewFilterButton extends StatelessWidget {
  const _OverviewFilterButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F9FB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE1E5EA)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.expand_more_rounded,
                size: 17,
                color: Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
