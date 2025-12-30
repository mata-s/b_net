import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeamAnnualResultsPage extends StatefulWidget {
  const TeamAnnualResultsPage({
    super.key,
    required this.teamId,
  });

  final String teamId;

  @override
  State<TeamAnnualResultsPage> createState() => _TeamAnnualResultsPageState();
}

class _TeamAnnualResultsPageState extends State<TeamAnnualResultsPage> {
  final _firestore = FirebaseFirestore.instance;

  final Map<String, Future<Map<String, dynamic>?>> _numberOfTeamsFutures = {};

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchAnnualDocs() {
    return _firestore
        .collection('teams')
        .doc(widget.teamId)
        .collection('AnnualRanking')
        .orderBy('year', descending: true)
        .get();
  }

  Future<Map<String, dynamic>?> _fetchNumberOfTeamsStats({
    required String prefecture,
    required int year,
  }) {
    final key = '$prefecture-$year';
    if (_numberOfTeamsFutures.containsKey(key)) {
      return _numberOfTeamsFutures[key]!;
    }

    final docRef = _firestore
        .collection('numberOfTeams')
        .doc(prefecture)
        .collection(year.toString())
        .doc('stats');

    debugPrint('📦 _fetchNumberOfTeamsStats -> ${docRef.path}');

    final future = docRef.get().then((doc) {
      debugPrint(doc.exists
          ? '✅ numberOfTeams found'
          : '❌ numberOfTeams NOT found');
      return doc.data();
    });

    _numberOfTeamsFutures[key] = future;
    return future;
  }

  String _rankText(Object? rank) {
    if (rank == null || rank.toString().isEmpty) {
      return '圏外';
    }
    return '${rank}位';
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      // 打率や勝率などは小数第3位まで表示
      return value.toStringAsFixed(3);
    }
    return value.toString();
  }

  ({dynamic value, String? ageKey}) _pickAgeValueWithKey(
    Map<String, dynamic> data,
    String baseKey,
  ) {
    for (final e in data.entries) {
      if (e.key.startsWith('${baseKey}_age_') && e.value != null) {
        final ageKey = e.key.substring('${baseKey}_'.length);
        return (value: e.value, ageKey: ageKey);
      }
    }
    return (value: data[baseKey], ageKey: null);
  }

  Widget _buildAgeRankRow({
    required String label,
    required Map<String, dynamic> data,
    required String baseKey,
  }) {
    final r = _pickAgeValueWithKey(data, baseKey);
    final valueText = (r.value == null || r.value.toString().isEmpty)
        ? '圏外'
        : '${r.value}位';

    return _buildKeyValueRow(label, valueText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チーム年間成績'),
      ),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: _fetchAnnualDocs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('読み込みエラーが発生しました: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('チームの年間成績データがまだありません'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final year = data['year'] is int
                  ? data['year'] as int
                  : int.tryParse(doc.id) ?? 0;

              final prefecture = (data['prefecture'] ?? '') as String? ?? '';

              // CF 側で teamRanking にまとめて保存している場合はそれを優先的に使う
              final Map<String, dynamic> ranking =
                  (data['teamRanking'] is Map)
                      ? Map<String, dynamic>.from(
                          data['teamRanking'] as Map,
                        )
                      : Map<String, dynamic>.from(data);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(
                    '${year}年のチーム成績',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    prefecture.isEmpty
                        ? '都道府県未設定'
                        : '都道府県：$prefecture',
                  ),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _buildTeamSection(
                      year: year,
                      prefecture: prefecture,
                      ranking: ranking,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTeamSection({
    required int year,
    required String prefecture,
    required Map<String, dynamic> ranking,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'チーム成績',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildKeyValueRow(
          'リーグ / カテゴリ',
          ranking['category'],
        ),
        _buildKeyValueRow(
          '試合数',
          ranking['games'] ?? ranking['totalGames'],
        ),
        _buildKeyValueRow(
          '勝率',
          _formatNumber(ranking['winRate']),
        ),
        _buildKeyValueRow(
          '勝率順位',
          _rankText(ranking['winRateRank']),
        ),
        _buildAgeRankRow(
          label: '勝率年齢順位',
          data: ranking,
          baseKey: 'winRateRank',
        ),
        const SizedBox(height: 4),
        _buildKeyValueRow(
          'チーム打率',
          _formatNumber(
            ranking['battingAverage'] ?? ranking['teamBattingAverage'],
          ),
        ),
        _buildKeyValueRow(
          '打率順位',
          _rankText(ranking['battingAverageRank']),
        ),
        _buildAgeRankRow(
          label: '打率年齢順位',
          data: ranking,
          baseKey: 'battingAverageRank',
        ),
        const SizedBox(height: 4),
        _buildKeyValueRow(
          'チーム出塁率',
          _formatNumber(
            ranking['onBasePercentage'] ?? ranking['onBasePercentage'],
          ),
        ),
        _buildKeyValueRow(
          '出塁率順位',
          _rankText(ranking['onBaseRank']),
        ),
        _buildAgeRankRow(
          label: '出塁率年齢順位',
          data: ranking,
          baseKey: 'onBaseRank',
        ),
        const SizedBox(height: 4),
        _buildKeyValueRow(
          'チーム長打率',
          _formatNumber(
            ranking['sluggingPercentage'] ?? ranking['sluggingPercentage'],
          ),
        ),
        _buildKeyValueRow(
          '長打率順位',
          _rankText(ranking['sluggingRank']),
        ),
        _buildAgeRankRow(
          label: '長打率年齢順位',
          data: ranking,
          baseKey: 'sluggingRank',
        ),
        const SizedBox(height: 4),
        _buildKeyValueRow(
          'チーム防御率',
          _formatNumber(
            ranking['era'] ?? ranking['era'],
          ),
        ),
        _buildKeyValueRow(
          '防御率順位',
          _rankText(ranking['eraRank']),
        ),
        _buildAgeRankRow(
          label: '防御率年齢順位',
          data: ranking,
          baseKey: 'eraRank',
        ),
        const SizedBox(height: 4),
        _buildKeyValueRow(
          'チーム守備率',
          _formatNumber(
            ranking['fieldingPercentage'] ?? ranking['fieldingPercentage'],
          ),
        ),
        _buildKeyValueRow(
          '守備率順位',
          _rankText(ranking['fieldingPercentageRank']),
        ),
        _buildAgeRankRow(
          label: '守備率年齢順位',
          data: ranking,
          baseKey: 'fieldingPercentageRank',
        ),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>?>(
          future: _fetchNumberOfTeamsStats(
            prefecture: prefecture,
            year: year,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: LinearProgressIndicator(),
              );
            }
            final stats = snapshot.data;
            if (stats == null) {
              return const Text(
                '都道府県別のチーム数データはまだありません。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              );
            }
            return _buildNumberOfTeamsSection(
              title: '全チーム数・年齢別内訳',
              stats: stats,
            );
          },
        ),
      ],
    );
  }

  Widget _buildNumberOfTeamsSection({
    required String title,
    required Map<String, dynamic> stats,
  }) {
    final count = stats['teamsCount'] ?? stats['totalTeamsCount'];

    final statsMapRaw = stats['stats'];
    final Map<String, dynamic> statsMap = (statsMapRaw is Map)
        ? Map<String, dynamic>.from(statsMapRaw as Map)
        : <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        _buildKeyValueRow(
          '全チーム数',
          count != null ? '${count}チーム' : null,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _teamAgeChip(statsMap, '10代', 'totalTeams_age_0_19'),
            _teamAgeChip(statsMap, '20代', 'totalTeams_age_20_29'),
            _teamAgeChip(statsMap, '30代', 'totalTeams_age_30_39'),
            _teamAgeChip(statsMap, '40代', 'totalTeams_age_40_49'),
            _teamAgeChip(statsMap, '50代', 'totalTeams_age_50_59'),
            _teamAgeChip(statsMap, '60代', 'totalTeams_age_60_69'),
            _teamAgeChip(statsMap, '70代', 'totalTeams_age_70_79'),
            _teamAgeChip(statsMap, '80代', 'totalTeams_age_80_89'),
            if (statsMap.containsKey('totalTeams_age_90_100'))
              _teamAgeChip(statsMap, '90代', 'totalTeams_age_90_100'),
          ],
        ),
      ],
    );
  }

  Widget _teamAgeChip(
    Map<String, dynamic> stats,
    String label,
    String key,
  ) {
    final value = stats[key];
    if (value == null) return const SizedBox.shrink();

    final shortLabel = _teamAgeShortLabelFromTotalKey(key);
    final displayLabel = shortLabel.isNotEmpty ? shortLabel : label;

    return Chip(
      backgroundColor: Colors.grey.shade200,
      label: Text(
        '$displayLabel：${value}チーム',
        style: const TextStyle(fontSize: 12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  String _teamAgeShortLabelFromTotalKey(String totalKey) {
    switch (totalKey) {
      case 'totalTeams_age_0_19':
        return '10代';
      case 'totalTeams_age_20_29':
        return '20代';
      case 'totalTeams_age_30_39':
        return '30代';
      case 'totalTeams_age_40_49':
        return '40代';
      case 'totalTeams_age_50_59':
        return '50代';
      case 'totalTeams_age_60_69':
        return '60代';
      case 'totalTeams_age_70_79':
        return '70代';
      case 'totalTeams_age_80_89':
        return '80代';
      case 'totalTeams_age_90_100':
        return '90代以上';
      default:
        return '';
    }
  }
}

Widget _buildKeyValueRow(String label, Object? value) {
  if (value == null || (value is String && value.isEmpty)) {
    return const SizedBox.shrink();
  }
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.toString(),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
