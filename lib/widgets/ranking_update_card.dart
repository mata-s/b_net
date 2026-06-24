import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RankingUpdateCard extends StatefulWidget {
  final String userUid;

  const RankingUpdateCard({
    super.key,
    required this.userUid,
  });

  @override
  State<RankingUpdateCard> createState() => _RankingUpdateCardState();
}

class _RankingUpdateCardState extends State<RankingUpdateCard> {
  bool _isDismissed = false;
  bool _isCheckingDismissed = true;

  String get _dismissKey {
    final now = DateTime.now();
    final weekNumber = _weekNumber(now);
    return 'dismissed_ranking_update_${now.year}_$weekNumber';
  }

  @override
  void initState() {
    super.initState();
    _loadDismissState();
  }

  Future<void> _loadDismissState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _isDismissed = prefs.getBool(_dismissKey) ?? false;
      _isCheckingDismissed = false;
    });
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissKey, true);

    if (!mounted) return;
    setState(() {
      _isDismissed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
        if (_isCheckingDismissed || _isDismissed) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('rankingUpdates')
          .doc('current')
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() ?? <String, dynamic>{};
        final rawItems = data['items'];
        final items = rawItems is List
            ? rawItems
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];

        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6FF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFB9E2FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.trending_up,
                      color: Color(0xFF1565C0),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今週のランキング更新',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '順位が上がった項目があります',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _dismiss,
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...items.map(_buildUpdateItem),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpdateItem(Map<String, dynamic> item) {
    final label = (item['label'] ?? 'ランキング').toString();
    final previousRank = item['previousRank'];
    final currentRank = item['currentRank'];
    final change = item['change'];
    final isFirstPlace = item['isFirstPlace'] == true;
    final isNewRankIn = item['isNewRankIn'] == true;

    final rankEmoji = currentRank == 1
        ? '🥇'
        : currentRank == 2
            ? '🥈'
            : currentRank == 3
                ? '🥉'
                : isNewRankIn
                    ? '🎉'
                    : '📈';

    final title = isFirstPlace
        ? '$labelで1位になりました！'
        : isNewRankIn
            ? '$labelで初ランクイン！'
            : '$labelが${change ?? ''}ランクアップ！';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            rankEmoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isNewRankIn
                      ? '${currentRank ?? '-'}位にランクイン'
                      : '${previousRank ?? '-'}位 → ${currentRank ?? '-'}位',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

int _weekNumber(DateTime date) {
  final firstDayOfYear = DateTime(date.year, 1, 1);
  final daysOffset = firstDayOfYear.weekday - DateTime.monday;
  final firstMonday = firstDayOfYear.subtract(Duration(days: daysOffset));
  final diff = date.difference(firstMonday).inDays;
  return (diff / 7).floor() + 1;
}