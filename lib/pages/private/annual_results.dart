import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

    final docRef = _firestore
    .collection('prefecturePeople')
    .doc(prefecture)
    .collection(year.toString())
    .doc(type); 

debugPrint('📦 _fetchPrefectureStats -> ${docRef.path}');

final future = docRef.get().then((doc) {
  debugPrint(doc.exists ? '✅ found ($type)' : '❌ NOT found ($type)');
  return doc.data();
});

    _statsFutures[key] = future;
    return future;
  }

  dynamic pickAgeValue(Map<String, dynamic> data, String baseKey) {
    for (final e in data.entries) {
      if (e.key.startsWith('${baseKey}_age_') && e.value != null) {
        return e.value;
      }
    }
    return data[baseKey]; // 念のためのフォールバック
  }

  ({dynamic value, String? ageKey}) pickAgeValueWithKey(
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

  String _ageLabel(String? ageKey) {
    if (ageKey == null) return '';
    switch (ageKey) {
      case 'age_0_19':
        return '（10代）';
      case 'age_20_29':
        return '（20代）';
      case 'age_30_39':
        return '（30代）';
      case 'age_40_49':
        return '（40代）';
      case 'age_50_59':
        return '（50代）';
      case 'age_60_69':
        return '（60代）';
      case 'age_70_79':
        return '（70代）';
      case 'age_80_89':
        return '（80代）';
      case 'age_90_100':
        return '（90代以上）';
      default:
        return '';
    }
  }

  String _rankText(Object? rank) {
    if (rank == null || rank.toString().isEmpty) {
      return '圏外';
    }
    return '${rank}位';
  }

  Widget _buildAgeRankRow({
    required String label,
    required Map<String, dynamic> data,
    required String baseKey,
  }) {
    final r = pickAgeValueWithKey(data, baseKey);

    final valueText = (r.value == null || r.value.toString().isEmpty)
        ? '圏外'
        : '${r.value}位';

    return _buildKeyValueRow(label, valueText);
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

        FutureBuilder<Map<String, dynamic>?>(
          future: _fetchPrefectureStats(
            prefecture: prefecture,
            year: year,
            type: 'batting',
          ),
          builder: (context, snapshot) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKeyValueRow(
                  '打率順位',
                  _rankText(
                    batting['battingAverageRank'],
                  ),
                ),

                _buildAgeRankRow(
                  label: '打率年齢順位',
                  data: batting,
                  baseKey: 'battingAverageRank',
                ),

                _buildKeyValueRow(
                  '本塁打',
                  batting['homeRuns'] != null ? '${batting['homeRuns']}本' : null,
                ),
                _buildKeyValueRow(
                  '本塁打順位',
                  _rankText(batting['homeRunsRank']),
                ),
                _buildAgeRankRow(
                  label: '本塁打年齢順位',
                  data: batting,
                  baseKey: 'homeRunsRank',
                ),

                _buildKeyValueRow(
                    '出塁率', _formatNumber(batting['onBasePercentage'])),
                _buildKeyValueRow(
                  '出塁率順位',
                  _rankText(batting['onBaseRank']),
                ),
                _buildAgeRankRow(
                  label: '出塁率年齢順位',
                  data: batting,
                  baseKey: 'onBaseRank',
                ),

                _buildKeyValueRow(
                    '長打率', _formatNumber(batting['sluggingPercentage'])),
                 _buildKeyValueRow(
                  '長打率順位',
                  _rankText(batting['sluggingRank']),
                ),
                _buildAgeRankRow(
                  label: '長打率年齢順位',
                  data: batting,
                  baseKey: 'sluggingRank',
                ),
                _buildKeyValueRow('盗塁', batting['steals'] != null ? '${batting['steals']}盗' : null,),
                _buildKeyValueRow(
                  '盗塁順位',
                  _rankText(batting['stealsRank']),
                ),
                _buildAgeRankRow(
                  label: '盗塁年齢順位',
                  data: batting,
                  baseKey: 'stealsRank',
                ),
                _buildKeyValueRow('打点', batting['totalRbis'] != null ? '${batting['totalRbis']}点' : null,),
                _buildKeyValueRow(
                  '打点順位',
                  _rankText(batting['totalRbisRank']),
                ),
                _buildAgeRankRow(
                  label: '打点年齢順位',
                  data: batting,
                  baseKey: 'totalRbisRank',
                ),
                _buildKeyValueRow('打数', batting['atBats']),
                _buildKeyValueRow('安打', batting['totalHits']),
                const SizedBox(height: 12),

                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: LinearProgressIndicator(),
                  )
                else if (snapshot.data == null)
                  const Text(
                    '都道府県別の打者人数データはまだありません。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  )
                else
                  _buildPrefecturePeopleSection(
                    title: '全体の参加数・年齢別内訳',
                    stats: snapshot.data!,
                    isPitcher: false,
                  ),
              ],
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
        _buildKeyValueRow('防御率順位', _rankText(pitcher['eraRank'])),
        _buildAgeRankRow(
          label: '防御率年齢順位',
          data: pitcher,
          baseKey: 'eraRank',
        ),
        
        _buildKeyValueRow('勝率', _formatNumber(pitcher['winRate'])),
        _buildKeyValueRow('勝率順位', _rankText(pitcher['winRateRank'])),
        _buildAgeRankRow(
          label: '勝率年齢順位',
          data: pitcher,
          baseKey: 'winRateRank',
        ),
        
        _buildKeyValueRow('奪三振', pitcher['totalPStrikeouts']),
        _buildKeyValueRow('奪三振順位', _rankText(pitcher['totalPStrikeoutsRank'])),
        _buildAgeRankRow(
          label: '奪三振年齢順位',
          data: pitcher,
          baseKey: 'totalPStrikeoutsRank',
        ),
        
        _buildKeyValueRow('HD', pitcher['totalHoldPoints']),
        _buildKeyValueRow('HD順位', _rankText(pitcher['totalHoldPointsRank'])),
        _buildAgeRankRow(
          label: 'HD年齢順位',
          data: pitcher,
          baseKey: 'totalHoldPointsRank',
        ),
        
        _buildKeyValueRow('セーブ数', pitcher['totalSaves']),
        _buildKeyValueRow('セーブ数順位', _rankText(pitcher['totalSavesRank'])),
        _buildAgeRankRow(
          label: 'セーブ数年齢順位',
          data: pitcher,
          baseKey: 'totalSavesRank',
        ),
        
        _buildKeyValueRow('登板数', pitcher['totalAppearances']),
        _buildKeyValueRow('投球回', pitcher['totalInningsPitched']),

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
    // 総数（batting: playersCount / pitcher: pitchersCount）
    final count = isPitcher
        ? (stats['pitchersCount'] ?? stats['playersCount'])
        : stats['playersCount'];

    // 年齢別は stats フィールドの中（Map）に入っている
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
          '全人数',
          count != null ? '${count}人' : null,
        ),

        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _ageChip(statsMap, '10代', 'totalPlayers_age_0_19'),
            _ageChip(statsMap, '20代', 'totalPlayers_age_20_29'),
            _ageChip(statsMap, '30代', 'totalPlayers_age_30_39'),
            _ageChip(statsMap, '40代', 'totalPlayers_age_40_49'),
            _ageChip(statsMap, '50代', 'totalPlayers_age_50_59'),
            _ageChip(statsMap, '60代', 'totalPlayers_age_60_69'),
            _ageChip(statsMap, '70代', 'totalPlayers_age_70_79'),
            _ageChip(statsMap, '80代', 'totalPlayers_age_80_89'),
            if (statsMap.containsKey('totalPlayers_age_90_100'))
              _ageChip(statsMap, '90代', 'totalPlayers_age_90_100'),
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
  if (value == null) return const SizedBox.shrink();

  final shortLabel = _ageShortLabelFromTotalKey(key);
  final displayLabel = shortLabel.isNotEmpty ? shortLabel : label;

  return Chip(
    backgroundColor: Colors.grey.shade200,
    label: Text(
      '$displayLabel：${value}人',
      style: const TextStyle(fontSize: 12),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8),
  );
}


  String _ageShortLabelFromTotalKey(String totalKey) {
    switch (totalKey) {
      case 'totalPlayers_age_0_19':
        return '10代';
      case 'totalPlayers_age_20_29':
        return '20代';
      case 'totalPlayers_age_30_39':
        return '30代';
      case 'totalPlayers_age_40_49':
        return '40代';
      case 'totalPlayers_age_50_59':
        return '50代';
      case 'totalPlayers_age_60_69':
        return '60代';
      case 'totalPlayers_age_70_79':
        return '70代';
      case 'totalPlayers_age_80_89':
        return '80代';
      case 'totalPlayers_age_90_100':
        return '90代以上';
      default:
        return '';
    }
  }

  String _ageLongLabelFromTotalKey(String totalKey) {
    final raw = totalKey.replaceFirst('totalPlayers_age_', '');
    return raw.replaceAll('_', '-');
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
