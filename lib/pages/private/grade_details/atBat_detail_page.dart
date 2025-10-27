import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AtbatDetailPage extends StatefulWidget {
  final String userUid;
  final String selectedPeriodFilter;
  final String selectedGameTypeFilter;
  final DateTime startDate;
  final DateTime endDate;
  final bool yearOnly;

  const AtbatDetailPage({
    super.key,
    required this.userUid,
    required this.selectedPeriodFilter,
    required this.selectedGameTypeFilter,
    required this.startDate,
    required this.endDate,
    required this.yearOnly,
  });

  @override
  State<AtbatDetailPage> createState() => _AtbatDetailPageState();
}

class _AtbatDetailPageState extends State<AtbatDetailPage> {
  final ValueNotifier<int?> _touchedIndex = ValueNotifier(null);
  final ValueNotifier<bool> _showPercentageNotifier = ValueNotifier(false);

  Future<Map<String, dynamic>> getFullStats() async {
    String year = widget.startDate.year.toString();
    String month = widget.startDate.month.toString();
    String gameType = widget.selectedGameTypeFilter;

    String docId;
    if (widget.yearOnly) {
      docId = gameType == '全試合'
          ? 'results_stats_${year}_all'
          : 'results_stats_${year}_${gameType}_all';
    } else if (widget.selectedPeriodFilter == '通算') {
      docId = gameType == '全試合'
          ? 'results_stats_all'
          : 'results_stats_${gameType}_all';
    } else if (widget.selectedPeriodFilter == '今年' ||
        widget.selectedPeriodFilter == '去年') {
      docId = gameType == '全試合'
          ? 'results_stats_${year}_all'
          : 'results_stats_${year}_${gameType}_all';
    } else {
      docId = 'results_stats_${year}_$month';
    }

    final statsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('stats')
        .doc(docId)
        .get();

    if (!statsSnapshot.exists) return {};

    return statsSnapshot.data() ?? {}; // ← ドキュメント全体を返す
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 251, 252),
      body: FutureBuilder<Map<String, dynamic>>(
        future: getFullStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('データがありません'));
          }

          final adv = snapshot.data!;
          final hitBreakdown = adv['advancedStats']?['hitBreakdown'] ?? {};
          final outBreakdown = adv['advancedStats']?['outBreakdown'] ?? {};
          final strikeoutBreakdown =
              adv['advancedStats']?['strikeoutBreakdown'] ?? {};
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      _buildAtBatBreakdownChart(adv),
                      _buildCategoryCard('安打内訳（${adv['hits'] ?? 0}安打）', [
                        _buildStatItem('内野安打', hitBreakdown['infieldHitsRate']),
                        _buildStatItem('単打', hitBreakdown['oneBaseHitsRate']),
                        _buildStatItem('二塁打', hitBreakdown['twoBaseHitsRate']),
                        _buildStatItem(
                            '三塁打', hitBreakdown['threeBaseHitsRate']),
                        _buildStatItem('本塁打', hitBreakdown['homeRunsRate']),
                      ]),
                      _buildCategoryCard('凡打の内訳（${adv['totalOuts'] ?? 0})', [
                        _buildStatItem('ゴロ', outBreakdown['grounderRate']),
                        _buildStatItem('ライナー', outBreakdown['linerRate']),
                        _buildStatItem('フライ', outBreakdown['flyBallRate']),
                        _buildStatItem('併殺打', outBreakdown['doublePlayRate']),
                        _buildStatItem('失策出塁', outBreakdown['errorReachRate']),
                        _buildStatItem(
                            '守備妨害', outBreakdown['interferenceRate']),
                        _buildStatItem('バント失敗', outBreakdown['buntOutsRate']),
                      ]),
                      _buildCategoryCard(
                          '三振の内訳（${adv['totalStrikeouts'] ?? 0})', [
                        _buildStatItem('空振り三振', strikeoutBreakdown['swinging']),
                        _buildStatItem(
                            '見逃し三振', strikeoutBreakdown['overlooking']),
                        _buildStatItem('振り逃げ', strikeoutBreakdown['swingAway']),
                        _buildStatItem(
                            'スリーバント失敗', strikeoutBreakdown['threeBuntFail']),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(String title, List<Widget> items) {
    return Card(
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: items,
      ),
    );
  }

  Widget _buildStatItem(String label, dynamic value) {
    print('DEBUG: $label -> $value');
    if (value == null) {
      return ListTile(
        title: Text(label),
        trailing:
            const Text('-', style: TextStyle(fontWeight: FontWeight.bold)),
      );
    }
    if (value is double) {
      double normalized = value.clamp(0.0, 1.0);
      String displayPercentage = (normalized * 100).toStringAsFixed(1) + '%';
      return ListTile(
        title: Text(label),
        subtitle: LinearProgressIndicator(
          value: normalized,
          backgroundColor: Colors.grey.shade300,
          color: Colors.blueAccent,
          minHeight: 8,
        ),
        trailing: Text(displayPercentage,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    } else if (value is int) {
      return ListTile(
        title: Text(label),
        trailing: Text(value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    } else {
      return ListTile(
        title: Text(label),
        trailing: Text(value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    }
  }

  Widget _buildAtBatBreakdownChart(Map<String, dynamic> stats) {
    final int hits = stats['hits'] ?? 0;
    final int outs = stats['totalOuts'] ?? 0;
    final int strikeouts = stats['totalStrikeouts'] ?? 0;
    final int fourBalls = stats['totalFourBalls'] ?? 0;
    final int hitByPitch = stats['totalHitByAPitch'] ?? 0;
    final int sacrifices = stats['totalSacrificeFly'] ?? 0;
    final int totalAllBuntSuccess = stats['totalAllBuntSuccess'] ?? 0;
    final int strikeInterferences = stats['totalStrikeInterferences'] ?? 0;
    final int totalBats = stats['totalBats'] ?? 0;

    final int total = hits +
        fourBalls +
        hitByPitch +
        sacrifices +
        strikeouts +
        outs +
        strikeInterferences +
        totalAllBuntSuccess;
    final int others = (totalBats - total).clamp(0, double.infinity).toInt();

    final int adjustedTotal = hits +
        fourBalls +
        hitByPitch +
        sacrifices +
        strikeouts +
        outs +
        totalAllBuntSuccess +
        strikeInterferences +
        others;

    final List<_PieChartSectionData> sections = [
      _PieChartSectionData('ヒット', hits, Colors.blue),
      _PieChartSectionData('凡打', outs, Colors.grey),
      _PieChartSectionData('三振', strikeouts, Colors.red),
      _PieChartSectionData('四死球', fourBalls + hitByPitch, Colors.orange),
      _PieChartSectionData(
          '犠打・犠飛', sacrifices + totalAllBuntSuccess, Colors.purple),
      _PieChartSectionData('打撃妨害', strikeInterferences, Colors.brown),
      if (others > 0) _PieChartSectionData('その他', others, Colors.teal),
    ];

    final filteredSections =
        sections.where((section) => section.count > 0).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('打席内訳',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ValueListenableBuilder<int?>(
                    valueListenable: _touchedIndex,
                    builder: (context, touchedIndex, _) {
                      return PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {
                              final index = pieTouchResponse
                                  ?.touchedSection?.touchedSectionIndex;
                              if (event is FlTapUpEvent && index != null) {
                                _touchedIndex.value =
                                    _touchedIndex.value == index ? null : index;
                              }
                            },
                          ),
                          sections:
                              filteredSections.asMap().entries.map((entry) {
                            final index = entry.key;
                            final section = entry.value;
                            final double percentage = adjustedTotal > 0
                                ? section.count / adjustedTotal
                                : 0;
                            final isTouched = index == touchedIndex;
                            final double radius = isTouched ? 70.0 : 60.0;

                            final String label = percentage < 0.05
                                ? ''
                                : '${(percentage * 100).toStringAsFixed(1)}%';
                            final double fontSize =
                                percentage < 0.05 ? 0 : (isTouched ? 18 : 14);

                            return PieChartSectionData(
                              color: section.color,
                              value: percentage,
                              title: label,
                              titleStyle: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              radius: radius,
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                        ),
                      );
                    },
                  ),
                  // 🔥ここで中心にテキストを重ねる！
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$totalBats', // ← 数字だけ
                        style: const TextStyle(
                          fontSize: 20, // 数字は少し大きめに
                        ),
                      ), // 数字と「打席」の間に少しスペース
                      const Text(
                        '打席',
                        style: TextStyle(
                          fontSize: 14, // 打席の文字は少し小さめに
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('割合表示'),
                ValueListenableBuilder<bool>(
                  valueListenable: _showPercentageNotifier,
                  builder: (context, value, _) {
                    return Switch(
                      value: value,
                      onChanged: (val) => _showPercentageNotifier.value = val,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: _showPercentageNotifier,
              builder: (context, value, _) {
                return ValueListenableBuilder<int?>(
                  valueListenable: _touchedIndex,
                  builder: (context, touchedIndex, __) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: filteredSections.asMap().entries.map((entry) {
                        final i = entry.key;
                        final section = entry.value;
                        final percent = adjustedTotal > 0
                            ? (section.count / adjustedTotal * 100)
                                .toStringAsFixed(1)
                            : '0.0';
                        final isSelected = touchedIndex == i;
                        return GestureDetector(
                          onTap: () {
                            _touchedIndex.value =
                                _touchedIndex.value == i ? null : i;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? section.color.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                    width: 16,
                                    height: 16,
                                    color: section.color),
                                const SizedBox(width: 6),
                                Text(
                                  value
                                      ? '${section.label} ($percent%)'
                                      : '${section.label} (${section.count})',
                                  style: TextStyle(
                                    fontSize: isSelected ? 16 : 14,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _touchedIndex.dispose();
    _showPercentageNotifier.dispose();
    super.dispose();
  }
}

class _PieChartSectionData {
  final String label;
  final int count;
  final Color color;

  _PieChartSectionData(this.label, this.count, this.color);
}
