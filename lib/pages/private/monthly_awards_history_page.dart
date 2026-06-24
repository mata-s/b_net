import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyAwardsHistoryPage extends StatelessWidget {
  final String userUid;

  const MonthlyAwardsHistoryPage({
    super.key,
    required this.userUid,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('月間称号'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userUid)
            .collection('monthlyAwards')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = (snapshot.data?.docs ?? [])
              .where((doc) => doc.id != 'current')
              .toList();

          docs.sort((a, b) {
            final aKey = _monthKeyFromAwardDoc(a);
            final bKey = _monthKeyFromAwardDoc(b);
            return bKey.compareTo(aKey);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'まだ月間称号がありません',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
            );
          }

          final groupedDocs = <int, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
          for (final doc in docs) {
            final monthKey = _monthKeyFromAwardDoc(doc);
            final year = _yearFromMonthKey(monthKey);
            groupedDocs.putIfAbsent(year, () => []).add(doc);
          }

          final years = groupedDocs.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            itemCount: years.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, yearIndex) {
              final year = years[yearIndex];
              final yearDocs = groupedDocs[year] ?? [];
              yearDocs.sort((a, b) {
                final aKey = _monthKeyFromAwardDoc(a);
                final bKey = _monthKeyFromAwardDoc(b);
                return bKey.compareTo(aKey);
              });

              return _YearAwardsExpansion(
                year: year,
                docs: yearDocs,
                formatMonthKey: _formatMonthKey,
              );
            },
          );
        },
      ),
    );
  }

  static int _yearFromMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    final parsed = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    return parsed ?? 0;
  }
  static String _monthKeyFromAwardDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final monthKey = (data['monthKey'] as String?)?.trim();
    return monthKey != null && monthKey.isNotEmpty ? monthKey : doc.id;
  }

  static String _formatMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return monthKey;

    return '$year年$month月';
  }
}

class _YearAwardsExpansion extends StatelessWidget {
  final int year;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String Function(String monthKey) formatMonthKey;

  const _YearAwardsExpansion({
    required this.year,
    required this.docs,
    required this.formatMonthKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDE7DD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month,
              color: Color(0xFFFFA000),
              size: 20,
            ),
          ),
          title: Text(
            year == 0 ? 'その他' : '$year年',
            style: const TextStyle(
              color: Color(0xFF2B211A),
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          subtitle: Text(
            '${docs.length}件の称号',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: docs.map((doc) {
            final data = doc.data();
            final title = (data['title'] as String?)?.trim() ?? '月間称号';
            final description =
                (data['description'] as String?)?.trim() ?? '';
            final encourage = (data['encourage'] as String?)?.trim() ?? '';
            final monthKey =
                (data['monthKey'] as String?)?.trim().isNotEmpty == true
                    ? data['monthKey'] as String
                    : doc.id;
            final rawReasonHints = data['reasonHints'];
            final reasonHints = rawReasonHints is List
                ? rawReasonHints
                    .map((item) => item.toString().trim())
                    .where((item) => item.isNotEmpty)
                    .toList()
                : <String>[];
            final rawGrowthCandidates = data['growthCandidates'];
            final growthCandidates = rawGrowthCandidates is List
                ? rawGrowthCandidates.whereType<Map>().map((item) {
                    return Map<String, dynamic>.from(item);
                  }).toList()
                : <Map<String, dynamic>>[];

            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _MonthlyAwardHistoryCard(
                monthLabel: formatMonthKey(monthKey),
                title: title,
                description: description,
                encourage: encourage,
                reasonHints: reasonHints,
                growthCandidates: growthCandidates,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _MonthlyAwardHistoryCard extends StatelessWidget {
  final String monthLabel;
  final String title;
  final String description;
  final String encourage;
  final List<String> reasonHints;
  final List<Map<String, dynamic>> growthCandidates;

  const _MonthlyAwardHistoryCard({
    required this.monthLabel,
    required this.title,
    required this.description,
    required this.encourage,
    required this.reasonHints,
    required this.growthCandidates,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E2CF)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Color(0xFFFFA000),
              size: 19,
            ),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2B211A),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                Text(
                  monthLabel,
                  style: const TextStyle(
                    color: Color(0xFF6D4C41),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (growthCandidates.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '成長候補 ${growthCandidates.length}件',
                    style: const TextStyle(
                      color: Color(0xFFD84315),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
          children: [
            if (description.isNotEmpty) ...[
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (reasonHints.isNotEmpty) ...[
              const SizedBox(height: 14),
              _HistorySectionBox(
                icon: Icons.insights,
                iconColor: const Color(0xFF7C3AED),
                backgroundColor: const Color(0xFFF5F3FF),
                title: 'この称号の理由',
                children: reasonHints.map(_buildReasonHint).toList(),
              ),
            ],
            if (growthCandidates.isNotEmpty) ...[
              const SizedBox(height: 12),
              _HistorySectionBox(
                icon: Icons.trending_up,
                iconColor: const Color(0xFFD84315),
                backgroundColor: const Color(0xFFFFF7ED),
                title: '成長候補',
                children: growthCandidates.map(_buildGrowthPoint).toList(),
              ),
            ],
            if (encourage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFAF3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFE8CC)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xFF16A34A),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        encourage,
                        style: const TextStyle(
                          color: Color(0xFF15803D),
                          height: 1.45,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReasonHint(String reason) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: Color(0xFF7C3AED),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              reason,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthPoint(Map<String, dynamic> point) {
    final label = (point['label'] as String?)?.trim() ?? '';
    final detail = (point['detail'] as String?)?.trim() ?? '';
    final valueText = (point['valueText'] as String?)?.trim() ?? '';

    if (label.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                if (valueText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    valueText,
                    style: const TextStyle(
                      color: Color(0xFFD84315),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySectionBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String title;
  final List<Widget> children;

  const _HistorySectionBox({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2B211A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ...children,
        ],
      ),
    );
  }
}
