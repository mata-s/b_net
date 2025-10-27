import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PitchingDetailTab extends StatefulWidget {
  final String teamId;
  final String selectedPeriodFilter;
  final String selectedGameTypeFilter;
  final DateTime startDate;
  final DateTime endDate;
  final bool yearOnly;

  const PitchingDetailTab({
    super.key,
    required this.teamId,
    required this.selectedPeriodFilter,
    required this.selectedGameTypeFilter,
    required this.startDate,
    required this.endDate,
    required this.yearOnly,
  });

  @override
  _PitchingDetailTabState createState() => _PitchingDetailTabState();
}

class _PitchingDetailTabState extends State<PitchingDetailTab> {
  Future<Map<String, dynamic>?>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = getFullStats();
  }

  Future<Map<String, dynamic>?> getFullStats() async {
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
        .collection('teams')
        .doc(widget.teamId)
        .collection('stats')
        .doc(docId)
        .get();

    return statsSnapshot.data();
  }

  String formatPercentage(dynamic value) {
    if (value == null) return '0%';
    if (value is num) {
      double percent = value * 100;
      return percent % 1 == 0
          ? '${percent.toInt()}%'
          : '${percent.toStringAsFixed(1)}%';
    }
    return value.toString();
  }

  Widget _buildStatItem(String label, dynamic value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) Icon(icon, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ${value != null ? (value is num ? value.toStringAsFixed(3) : value.toString()) : '0.000'}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, dynamic value,
      [double underlineWidth = 40]) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value != null
              ? (value is num ? value.toStringAsFixed(3) : value.toString())
              : '0.000',
          style: const TextStyle(
            fontSize: 20,
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: underlineWidth,
              height: 1,
              color: Colors.black,
            ),
          ],
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(covariant PitchingDetailTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPeriodFilter != oldWidget.selectedPeriodFilter ||
        widget.selectedGameTypeFilter != oldWidget.selectedGameTypeFilter ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      setState(() {
        _statsFuture = getFullStats();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 251, 252),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('データがありません'));
          }
          final stats = snapshot.data!;
          final adv = stats['advancedStats'] ?? {};
          final totalInningsPitched = stats['totalInningsPitched'] ?? 0;
          final totalPitchCount = stats['totalPitchCount'] ?? 0;

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                    top: 60), // make space for the fixed header
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatColumn(
                                      'WHIP',
                                      (adv['whip'] ?? 0).toStringAsFixed(2),
                                      80),
                                  _buildStatColumn(
                                      'QS',
                                      (adv['qsRate'] ?? 0).toStringAsFixed(1),
                                      80),
                                  _buildStatColumn('LOB%',
                                      formatPercentage(adv['lobRate']), 80),
                                ],
                              ),
                              SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatColumn(
                                      '1試合あたりの平均打者数',
                                      (adv['avgBattersFacedPerGame'] ?? 0)
                                          .toStringAsFixed(1),
                                      80),
                                ],
                              ),
                              SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatColumn(
                                      '1試合あたりの平均失点',
                                      (adv['avgRunsAllowedPerGame'] ?? 0)
                                          .toStringAsFixed(1),
                                      80),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '奪三振率',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 20, thickness: 1.5),
                              Center(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildStatColumn(
                                        '奪三振率(１試合)',
                                        formatPercentageEra(
                                            adv['strikeoutsPerNineInnings']),
                                        100),
                                    SizedBox(height: 20),
                                    _buildStatColumn(
                                        '奪三振率(１イニングあたり)',
                                        formatPercentageEra(
                                            adv['pitcherStrikeoutsPerInning']),
                                        100),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '球数',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 20, thickness: 1.5),
                              Center(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildStatColumn(
                                        '球数',
                                        totalPitchCount?.toString() ?? '0',
                                        100),
                                  ],
                                ),
                              ),
                              SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatColumn(
                                      '平均球数(試合)',
                                      (adv['avgPitchesPerGame'] ?? 0)
                                          .toStringAsFixed(1),
                                      80),
                                  _buildStatColumn(
                                      '平均球数(1人あたり)',
                                      (adv['avgPitchesPerBatter'] ?? 0)
                                          .toStringAsFixed(1),
                                      80),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '四球・死球',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 20, thickness: 1.5),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatColumn(
                                    '平均四球(１試合)',
                                    ((adv['avgWalksPerGame'] ?? 0) as num)
                                        .floor()
                                        .toString(),
                                    80,
                                  ),
                                  _buildStatColumn(
                                    '平均死球(１試合)',
                                    ((adv['avgHitByPitchPerGame'] ?? 0) as num)
                                        .floor()
                                        .toString(),
                                    80,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.only(bottom: 30),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '被打率・被本塁打率',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 20, thickness: 1.5),
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn(
                                            '被打率',
                                            formatAverage(
                                                adv['battingAverageAllowed']),
                                            80),
                                        _buildStatColumn(
                                            '被本塁打率',
                                            formatAverage(adv['homeRunRate']),
                                            80),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 240, 251, 252),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                              '投球回: ${totalInningsPitched.toStringAsFixed(1)}回',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String formatAverage(num value) {
  // num型にすることでintとdouble両方を受け入れられる
  double doubleValue = value.toDouble(); // intをdoubleに変換
  String formatted = doubleValue.toStringAsFixed(3);
  return formatted.startsWith("0")
      ? formatted.replaceFirst("0", "")
      : formatted;
}

String formatPercentageEra(num value) {
  double doubleValue = value.toDouble(); // num を double に変換
  return doubleValue.toStringAsFixed(2); // 小数点第2位までフォーマット
}
