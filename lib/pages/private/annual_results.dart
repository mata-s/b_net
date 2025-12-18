import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// 年間成績一覧ページ
///
/// 取得元:
/// - /users/{uid}/AnnualRanking/{year}/
///     - batting: Map<String, dynamic>
///     - pitcher: Map<String, dynamic>
/// - /prefecturePeople/{prefecture}/{year}/batting
///     - playersCount
///     - stats (List)
///     - totalPlayers_age_0_17 〜 totalPlayers_age_80_89
/// - /prefecturePeople/{prefecture}/{year}/pitcher
///     - pitchersCount
///     - stats (List)
///     - totalPlayers_age_0_17 〜 totalPlayers_age_80_89
class AnnualResultsPage extends StatefulWidget {
  final List<String> userPosition;
  const AnnualResultsPage({super.key, required this.userPosition});

  @override
  State<AnnualResultsPage> createState() => _AnnualResultsPageState();
}

class _AnnualResultsPageState extends State<AnnualResultsPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  /// prefecturePeople の stats をキャッシュする
  /// key: "$prefecture-$year-$type"
  final Map<String, Future<Map<String, dynamic>?>> _statsFutures = {};

  User? get _currentUser => _auth.currentUser;

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchAnnualDocs() async {
    final uid = _currentUser?.uid;
    if (uid == null) {
      throw Exception('ログインユーザーが見つかりません');
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('AnnualRanking')
        .orderBy('year', descending: true)
        .get();
  }

  Future<Map<String, dynamic>?> _fetchPrefectureStats({
    required String prefecture,
    required int year,
    required String type, // "batting" or "pitcher"
  }) {
    final key = '$prefecture-$year-$type';
    if (_statsFutures.containsKey(key)) {
      return _statsFutures[key]!;
    }

    final future = _firestore
        .collection('prefecturePeople')
        .doc(prefecture)
        .collection(year.toString())
        .doc(type)
        .get()
        .then((doc) => doc.data());

    _statsFutures[key] = future;
    return future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('年間成績'),
      ),
      body: _currentUser == null
          ? const Center(child: Text('ログインが必要です'))
          : FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                    child: Text('年間成績データがまだありません'),
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
                    final prefecture =
                        (data['prefecture'] ?? '') as String? ?? '';
                    final batting = data['batting'] is Map
                        ? Map<String, dynamic>.from(data['batting'] as Map)
                        : <String, dynamic>{};

                    final pitcher = data['pitcher'] is Map
                        ? Map<String, dynamic>.from(data['pitcher'] as Map)
                        : <String, dynamic>{};

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(
                          '${year}年の成績',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(prefecture.isEmpty
                            ? '都道府県未設定'
                            : '都道府県：$prefecture'),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          if (batting.isNotEmpty)
                            _buildBattingSection(
                              year: year,
                              prefecture: prefecture,
                              batting: batting,
                            ),
                          // 投手ポジションを持つ場合のみ表示
                          if (widget.userPosition.contains("投手") && pitcher.isNotEmpty)
                            const Divider(height: 32),
                          if (widget.userPosition.contains("投手") && pitcher.isNotEmpty)
                            _buildPitcherSection(
                              year: year,
                              prefecture: prefecture,
                              pitcher: pitcher,
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

  Widget _buildBattingSection({
    required int year,
    required String prefecture,
    required Map<String, dynamic> batting,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '打者成績',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildKeyValueRow('打率', _formatNumber(batting['battingAverage'])),
        _buildKeyValueRow('打率順位', batting['battingAverageRank']),
        _buildKeyValueRow('本塁打', batting['homeRuns']),
        _buildKeyValueRow('本塁打順位', batting['homeRunsRank']),
        _buildKeyValueRow(
            '出塁率', _formatNumber(batting['onBasePercentage'])),
        _buildKeyValueRow(
            '長打率', _formatNumber(batting['sluggingPercentage'])),
        _buildKeyValueRow('盗塁', batting['steals']),
        _buildKeyValueRow('打点', batting['totalRbis']),
        _buildKeyValueRow('打数', batting['atBats']),
        _buildKeyValueRow('安打', batting['totalHits']),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>?>(
          future: _fetchPrefectureStats(
            prefecture: prefecture,
            year: year,
            type: 'batting',
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
                '都道府県別の打者人数データはまだありません。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              );
            }
            return _buildPrefecturePeopleSection(
              title: '打者人数・年齢別内訳',
              stats: stats,
              isPitcher: false,
            );
          },
        ),
      ],
    );
  }

  Widget _buildPitcherSection({
    required int year,
    required String prefecture,
    required Map<String, dynamic> pitcher,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '投手成績',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildKeyValueRow('防御率', _formatNumber(pitcher['era'])),
        _buildKeyValueRow('防御率順位', pitcher['eraRank']),
        _buildKeyValueRow('ホールドポイント', pitcher['totalHoldPoints']),
        _buildKeyValueRow('セーブ数', pitcher['totalSaves']),
        _buildKeyValueRow('勝率', _formatNumber(pitcher['winRate'])),
        _buildKeyValueRow('登板数', pitcher['totalAppearances']),
        _buildKeyValueRow('投球回', pitcher['totalInningsPitched']),
        _buildKeyValueRow('奪三振', pitcher['totalPStrikeouts']),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>?>(
          future: _fetchPrefectureStats(
            prefecture: prefecture,
            year: year,
            type: 'pitcher',
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
                '都道府県別の投手人数データはまだありません。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              );
            }
            return _buildPrefecturePeopleSection(
              title: '投手人数・年齢別内訳',
              stats: stats,
              isPitcher: true,
            );
          },
        ),
      ],
    );
  }

  Widget _buildKeyValueRow(String label, Object? value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrefecturePeopleSection({
    required String title,
    required Map<String, dynamic> stats,
    required bool isPitcher,
  }) {
    final countKey = isPitcher ? 'pitchersCount' : 'playersCount';
    final count = stats[countKey];
    final list = stats['stats'];
    final statsLength = list is List ? list.length : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        _buildKeyValueRow(
          isPitcher ? '投手数' : '打者数',
          count,
        ),
        if (statsLength != null)
          _buildKeyValueRow('stats 配列数', '$statsLength 件'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _ageChip(stats, '0-17', 'totalPlayers_age_0_17'),
            _ageChip(stats, '18-29', 'totalPlayers_age_18_29'),
            _ageChip(stats, '30-39', 'totalPlayers_age_30_39'),
            _ageChip(stats, '40-49', 'totalPlayers_age_40_49'),
            _ageChip(stats, '50-59', 'totalPlayers_age_50_59'),
            _ageChip(stats, '60-69', 'totalPlayers_age_60_69'),
            _ageChip(stats, '70-79', 'totalPlayers_age_70_79'),
            _ageChip(stats, '80-89', 'totalPlayers_age_80_89'),
            if (stats.containsKey('totalPlayers_age_90_100'))
              _ageChip(stats, '90-100', 'totalPlayers_age_90_100'),
          ],
        ),
      ],
    );
  }

  Widget _ageChip(
    Map<String, dynamic> stats,
    String label,
    String key,
  ) {
    final value = stats[key];
    if (value == null) {
      return const SizedBox.shrink();
    }
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      // 打率や防御率などは小数第3位まで表示
      return value.toStringAsFixed(3);
    }
    return value.toString();
  }
}
