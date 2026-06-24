import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:b_net/pages/private/mission_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:b_net/widgets/ranking_update_card.dart';

class PlayerDashboardPage extends StatefulWidget {
  final String userUid;
  final List<String> userPosition;

  const PlayerDashboardPage({
    super.key,
    required this.userUid,
    required this.userPosition,
  });

  @override
  State<PlayerDashboardPage> createState() => _PlayerDashboardPageState();
}

class _PlayerDashboardPageState extends State<PlayerDashboardPage> {
  late final Future<List<DocumentSnapshot<Map<String, dynamic>>>> _statsFuture;
  late final Future<_PlayerRankingSummary> _rankingSummaryFuture;
  late final Future<QuerySnapshot<Map<String, dynamic>>> _yearGoalFuture;
  late final Future<QuerySnapshot<Map<String, dynamic>>> _monthGoalFuture;
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _seasonStatsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = Future.wait([
      _fetchSeasonStats(),
      _fetchMonthStats(),
    ]);
    _rankingSummaryFuture = _fetchPlayerRankingSummary();
    _yearGoalFuture = _fetchYearGoal();
    _monthGoalFuture = _fetchMonthGoal();
    _seasonStatsFuture = _fetchSeasonStats();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchYearGoal() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('goals')
        .where('period', isEqualTo: 'year')
        .where('year', isEqualTo: DateTime.now().year)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchMonthGoal() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('goals')
        .where('period', isEqualTo: 'month')
        .where(
          'month',
          isEqualTo: '${DateTime.now().year}-${DateTime.now().month}',
        )
        .get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchSeasonStats() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('stats')
        .doc('results_stats_${DateTime.now().year}_all')
        .get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchMonthStats() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('stats')
        .doc('results_stats_${DateTime.now().year}_${DateTime.now().month}')
        .get();
  }

  Future<_PlayerRankingSummary> _fetchPlayerRankingSummary() async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .get();

    final userData = userDoc.data() ?? <String, dynamic>{};
    final prefecture = (userData['prefecture'] ?? '').toString();
    final ageGroup = _ageGroupFromUserData(userData);
    final ageSuffix = ageGroup == null ? null : '_age_$ageGroup';

    if (prefecture.isEmpty) {
      return const _PlayerRankingSummary();
    }

    final seasonDoc = await FirebaseFirestore.instance
        .collection('battingAverageRanking')
        .doc('${year}_total')
        .collection(prefecture)
        .doc(widget.userUid)
        .get();

    final pitcherSeasonDoc = await FirebaseFirestore.instance
        .collection('pitcherRanking')
        .doc('${year}_total')
        .collection(prefecture)
        .doc(widget.userUid)
        .get();

    final monthDoc = await _fetchLatestMonthlyBattingRankingDoc(
      year: year,
      month: month,
      prefecture: prefecture,
    );

    return _PlayerRankingSummary(
      seasonBattingAverageRank:
          _asNullableInt(seasonDoc.data()?['battingAverageRank']),
      seasonHomeRunsRank: _asNullableInt(seasonDoc.data()?['homeRunsRank']),
      seasonEraRank: _asNullableInt(pitcherSeasonDoc.data()?['eraRank']),
      seasonStrikeoutsRank:
          _asNullableInt(pitcherSeasonDoc.data()?['totalPStrikeoutsRank']),
      ageBattingAverageRank: ageSuffix == null
          ? null
          : _asNullableInt(seasonDoc.data()?['battingAverageRank$ageSuffix']),
      ageHomeRunsRank: ageSuffix == null
          ? null
          : _asNullableInt(seasonDoc.data()?['homeRunsRank$ageSuffix']),
      ageEraRank: ageSuffix == null
          ? null
          : _asNullableInt(pitcherSeasonDoc.data()?['eraRank$ageSuffix']),
      ageStrikeoutsRank: ageSuffix == null
          ? null
          : _asNullableInt(
              pitcherSeasonDoc.data()?['totalPStrikeoutsRank$ageSuffix'],
            ),
      ageGroupLabel: _ageGroupLabel(ageGroup),
      monthBattingAverageRank:
          _asNullableInt(monthDoc.data()?['battingAverageRank']),
      monthHomeRunsRank: _asNullableInt(monthDoc.data()?['homeRunsRank']),
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>>
      _fetchLatestMonthlyBattingRankingDoc({
    required int year,
    required int month,
    required String prefecture,
  }) async {
    final candidates = <DateTime>[
      DateTime(year, month, 1),
      DateTime(year, month - 1, 1),
    ];

    for (final candidate in candidates) {
      final noPadDoc = await FirebaseFirestore.instance
          .collection('battingAverageRanking')
          .doc('${candidate.year}_${candidate.month}')
          .collection(prefecture)
          .doc(widget.userUid)
          .get();

      if (noPadDoc.exists) return noPadDoc;

      final padDoc = await FirebaseFirestore.instance
          .collection('battingAverageRanking')
          .doc('${candidate.year}_${candidate.month.toString().padLeft(2, '0')}')
          .collection(prefecture)
          .doc(widget.userUid)
          .get();

      if (padDoc.exists) return padDoc;
    }

    return FirebaseFirestore.instance
        .collection('battingAverageRanking')
        .doc('${year}_$month')
        .collection(prefecture)
        .doc(widget.userUid)
        .get();
  }

  bool get _isPitcher {
    return widget.userPosition.any((position) => position.contains('投手'));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RankingUpdateCard(userUid: widget.userUid),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.sports_baseball,
                      size: 32,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '選手カード',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'ランキングと規定到達状況',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  final seasonData =
                      snapshot.data?[0].data() ?? <String, dynamic>{};
                  final monthData =
                      snapshot.data?[1].data() ?? <String, dynamic>{};

                  final seasonAtBats = _statNumber(
                    seasonData,
                    ['totalBats', 'atBats', 'totalAtBats'],
                  );
                  final seasonInnings = _statNumber(seasonData, [
                    'inningsPitched',
                    'totalInningsPitched',
                    'innings',
                  ]);
                  final seasonBattingAverage = _statNumber(
                    seasonData,
                    ['battingAverage'],
                  );
                  final seasonHomeRuns = _statNumber(
                    seasonData,
                    ['totalHomeRuns', 'homeRuns'],
                  );
                  final seasonEra = _statNumber(seasonData, ['era']);
                  final seasonStrikeouts = _statNumber(
                    seasonData,
                    ['totalPStrikeouts', 'strikeouts'],
                  );
                  final monthAtBats = _statNumber(
                    monthData,
                    ['totalBats', 'atBats', 'totalAtBats'],
                  );
                  final monthInnings = _statNumber(monthData, [
                    'inningsPitched',
                    'totalInningsPitched',
                    'innings',
                  ]);
                  
                  return FutureBuilder<_PlayerRankingSummary>(
                    future: _rankingSummaryFuture,
                    builder: (context, rankingSnapshot) {
                      final summary =
                          rankingSnapshot.data ?? const _PlayerRankingSummary();

                      return Column(
                        children: [
                          _RankingSummaryCard(
                            summary: summary,
                            isPitcher: _isPitcher,
                            seasonBattingAverage: seasonBattingAverage,
                            seasonHomeRuns: seasonHomeRuns,
                            seasonEra: seasonEra,
                            seasonStrikeouts: seasonStrikeouts,
                            seasonAtBats: seasonAtBats,
                            requiredSeasonAtBats: _requiredSeasonAtBats(),
                            monthAtBats: monthAtBats,
                            requiredMonthAtBats: _requiredMonthAtBats(),
                            seasonInnings: seasonInnings,
                            requiredSeasonInnings: _requiredSeasonInnings(),
                            monthInnings: monthInnings,
                            requiredMonthInnings: _requiredMonthInnings(),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.flag_circle_outlined,
                    color: Color(0xFF1565C0),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '目標',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MissionPage(
                            userUid: widget.userUid,
                          ),
                        ),
                      );
                    },
                    child: const Text('設定する'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: _yearGoalFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const _GoalTile(
                      icon: Icons.flag_outlined,
                      label: '今年の目標',
                      value: '未設定',
                    );
                  }

                  final goalData = snapshot.data!.docs.first.data();
                  return _GoalTile(
                    icon: Icons.flag_outlined,
                    label: '今年の目標',
                    value: _goalTitle(goalData),
                    progressText: _goalProgressText(goalData),
                    isAchieved: goalData['isAchieved'] == true,
                    progress: _goalProgress(goalData),
                  );
                },
              ),
              FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: _monthGoalFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const _GoalTile(
                      icon: Icons.calendar_month_outlined,
                      label: '今月の目標',
                      value: '未設定',
                    );
                  }

                  final goalData = snapshot.data!.docs.first.data();
                  return _GoalTile(
                    icon: Icons.calendar_month_outlined,
                    label: '今月の目標',
                    value: _goalTitle(goalData),
                    progressText: _goalProgressText(goalData),
                    isAchieved: goalData['isAchieved'] == true,
                    progress: _goalProgress(goalData),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    color: Color(0xFF1565C0),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${DateTime.now().year}年 主要成績',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '今シーズンの成績サマリー',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _seasonStatsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Text(
                      '今シーズンの成績はまだありません',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }

                  final data = snapshot.data!.data() ?? {};
                  return Column(
                    children: [
                      _BattingStatsCard(data: data),
                      if (_isPitcher) ...[
                        const SizedBox(height: 10),
                        _PitchingStatsCard(data: data),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _goalTitle(Map<String, dynamic> goalData) {
  return (goalData['title'] ?? '未設定').toString();
}

String _goalProgressText(Map<String, dynamic> goalData) {
  final statField = goalData['statField'];
  final target = goalData['target'];
  final actual = goalData['actualValue'] ?? 0;

  if (statField == 'custom') {
    return '';
  }

  if (target == null) {
    return '現在 ${_formatGoalValue(statField, actual)}';
  }

  return '現在 ${_formatGoalValue(statField, actual)} / 目標 ${_formatGoalValue(statField, target)}';
}

double? _goalProgress(Map<String, dynamic> goalData) {
  final target = goalData['target'];
  final actual = goalData['actualValue'];

  if (target is! num || actual is! num || target <= 0) {
    return null;
  }

  return (actual / target).clamp(0.0, 1.0).toDouble();
}

String _formatGoalValue(dynamic statField, dynamic value) {
  if (value is! num) {
    return value.toString();
  }

  if (statField == 'era') {
    return value.toDouble().toStringAsFixed(2);
  }

  if ([
    'battingAverage',
    'onBasePercentage',
    'sluggingPercentage',
    'winRate',
  ].contains(statField)) {
    final formatted = value.toDouble().toStringAsFixed(3);
    return formatted.startsWith('0')
        ? formatted.replaceFirst('0', '')
        : formatted;
  }

  return value.toInt().toString();
}

int? _asNullableInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

String _rankText(int? rank) {
  if (rank == null) return '圏外';
  return '$rank位';
}

String? _ageGroupFromUserData(Map<String, dynamic> userData) {
  final rawAge = userData['age'];
  if (rawAge is num) {
    return _ageGroupFromAge(rawAge.toInt());
  }

  final rawBirthday = userData['birthday'] ??
      userData['birthDate'] ??
      userData['dateOfBirth'];

  final birthday = _dateTimeFromDynamic(rawBirthday);
  if (birthday == null) return null;

  final now = DateTime.now();
  var age = now.year - birthday.year;
  final hasNotHadBirthdayThisYear = now.month < birthday.month ||
      (now.month == birthday.month && now.day < birthday.day);
  if (hasNotHadBirthdayThisYear) age -= 1;

  return _ageGroupFromAge(age);
}

DateTime? _dateTimeFromDynamic(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String? _ageGroupFromAge(int age) {
  if (age < 20) return 'under_20';
  if (age < 30) return '20_29';
  if (age < 40) return '30_39';
  if (age < 50) return '40_49';
  if (age < 60) return '50_59';
  return '60_plus';
}

String? _ageGroupLabel(String? ageGroup) {
  switch (ageGroup) {
    case 'under_20':
      return '10代以下';
    case '20_29':
      return '20代';
    case '30_39':
      return '30代';
    case '40_49':
      return '40代';
    case '50_59':
      return '50代';
    case '60_plus':
      return '60代以上';
    default:
      return null;
  }
}

class _PlayerRankingSummary {
  final int? seasonBattingAverageRank;
  final int? seasonHomeRunsRank;
  final int? seasonEraRank;
  final int? seasonStrikeoutsRank;
  final int? ageBattingAverageRank;
  final int? ageHomeRunsRank;
  final int? ageEraRank;
  final int? ageStrikeoutsRank;
  final String? ageGroupLabel;
  final int? monthBattingAverageRank;
  final int? monthHomeRunsRank;

  const _PlayerRankingSummary({
    this.seasonBattingAverageRank,
    this.seasonHomeRunsRank,
    this.seasonEraRank,
    this.seasonStrikeoutsRank,
    this.ageBattingAverageRank,
    this.ageHomeRunsRank,
    this.ageEraRank,
    this.ageStrikeoutsRank,
    this.ageGroupLabel,
    this.monthBattingAverageRank,
    this.monthHomeRunsRank,
  });
}

class _RankingSummaryCard extends StatelessWidget {
  final _PlayerRankingSummary summary;
  final bool isPitcher;
  final num seasonBattingAverage;
  final num seasonHomeRuns;
  final num seasonEra;
  final num seasonStrikeouts;
  final num seasonAtBats;
  final num requiredSeasonAtBats;
  final num monthAtBats;
  final num requiredMonthAtBats;
  final num seasonInnings;
  final num requiredSeasonInnings;
  final num monthInnings;
  final num requiredMonthInnings;

  const _RankingSummaryCard({
    required this.summary,
    required this.isPitcher,
    required this.seasonBattingAverage,
    required this.seasonHomeRuns,
    required this.seasonEra,
    required this.seasonStrikeouts,
    required this.seasonAtBats,
    required this.requiredSeasonAtBats,
    required this.monthAtBats,
    required this.requiredMonthAtBats,
    required this.seasonInnings,
    required this.requiredSeasonInnings,
    required this.monthInnings,
    required this.requiredMonthInnings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RankingTypeCard(
          title: '打者ランキング',
          icon: FontAwesomeIcons.baseballBatBall,
          children: [
            _RankingGroup(
              title: 'シーズン',
              firstLabel: '打率',
              firstValue: _formatDashboardRate(seasonBattingAverage),
              firstRankText: _rankText(summary.seasonBattingAverageRank),
              secondLabel: '本塁打',
              secondValue: '${seasonHomeRuns.toInt()}本',
              secondRankText: _rankText(summary.seasonHomeRunsRank),
            ),
            if (summary.ageGroupLabel != null) ...[
              const SizedBox(height: 10),
              _RankingGroup(
                title: '年齢別（${summary.ageGroupLabel}）',
                firstLabel: '打率',
                firstValue: _formatDashboardRate(seasonBattingAverage),
                firstRankText: _rankText(summary.ageBattingAverageRank),
                secondLabel: '本塁打',
                secondValue: '${seasonHomeRuns.toInt()}本',
                secondRankText: _rankText(summary.ageHomeRunsRank),
              ),
            ],
            const SizedBox(height: 10),
            _QualificationTextLine(
              title: '規定打席',
              annualCurrent: seasonAtBats,
              annualRequired: requiredSeasonAtBats,
              monthlyCurrent: monthAtBats,
              monthlyRequired: requiredMonthAtBats,
              formatter: (value) => value.toInt().toString(),
            ),
          ],
        ),
        if (isPitcher) ...[
          const SizedBox(height: 10),
          _RankingTypeCard(
            title: '投手ランキング',
            icon: Icons.sports_baseball,
            children: [
              _RankingGroup(
                title: 'シーズン',
                firstLabel: '防御率',
                firstValue: _formatDashboardEra(seasonEra),
                firstRankText: _rankText(summary.seasonEraRank),
                secondLabel: '奪三振',
                secondValue: seasonStrikeouts.toInt().toString(),
                secondRankText: _rankText(summary.seasonStrikeoutsRank),
              ),
              if (summary.ageGroupLabel != null) ...[
                const SizedBox(height: 10),
                _RankingGroup(
                  title: '年齢別（${summary.ageGroupLabel}）',
                  firstLabel: '防御率',
                  firstValue: _formatDashboardEra(seasonEra),
                  firstRankText: _rankText(summary.ageEraRank),
                  secondLabel: '奪三振',
                  secondValue: seasonStrikeouts.toInt().toString(),
                  secondRankText: _rankText(summary.ageStrikeoutsRank),
                ),
              ],
              const SizedBox(height: 10),
              _QualificationTextLine(
                title: '規定投球回',
                annualCurrent: seasonInnings,
                annualRequired: requiredSeasonInnings,
                monthlyCurrent: monthInnings,
                monthlyRequired: requiredMonthInnings,
                formatter: _formatInnings,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RankingTypeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _RankingTypeCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: const Color(0xFF1565C0),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _RankingMiniItem extends StatelessWidget {
  final String title;
  final String value;
  final String rankText;

  const _RankingMiniItem({
    required this.title,
    required this.value,
    required this.rankText,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfRank = rankText == '圏外';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              color: Color(0xFF1565C0),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isOutOfRank ? 'ランキング対象外' : rankText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isOutOfRank ? Colors.black45 : Colors.black87,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

num _statNumber(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is num) return value;
  }
  return 0;
}

String _formatDashboardRate(num value) {
  final formatted = value.toDouble().toStringAsFixed(3);
  return formatted.startsWith('0') ? formatted.replaceFirst('0', '') : formatted;
}

String _formatDashboardEra(num value) {
  return value.toDouble().toStringAsFixed(2);
}

String _formatInnings(num value) {
  final doubleValue = value.toDouble();

  if (doubleValue == doubleValue.truncateToDouble()) {
    return doubleValue.toInt().toString();
  }

  final formatted = doubleValue.toStringAsFixed(1);

  if (formatted.endsWith('.0')) {
    return formatted.substring(0, formatted.length - 2);
  }

  return formatted;
}

int _requiredSeasonAtBats() {
  final now = DateTime.now();
  final year = now.year;

  final seasonStart = DateTime(year, 3, 1);
  final seasonEnd = DateTime(year, 11, 30, 23, 59, 59);

  double seasonProgress =
      (now.millisecondsSinceEpoch - seasonStart.millisecondsSinceEpoch)
          .toDouble();

  seasonProgress /=
      (seasonEnd.millisecondsSinceEpoch - seasonStart.millisecondsSinceEpoch);

  seasonProgress = seasonProgress.clamp(0.0, 1.0);

  return (72 * seasonProgress).ceil().clamp(2, 72);
}

num _requiredSeasonInnings() {
  final now = DateTime.now();
  final year = now.year;

  final seasonStart = DateTime(year, 3, 1);
  final seasonEnd = DateTime(year, 11, 30, 23, 59, 59);

  double seasonProgress =
      (now.millisecondsSinceEpoch - seasonStart.millisecondsSinceEpoch)
          .toDouble();

  seasonProgress /=
      (seasonEnd.millisecondsSinceEpoch - seasonStart.millisecondsSinceEpoch);

  seasonProgress = seasonProgress.clamp(0.0, 1.0);

  return (108 * seasonProgress).ceil().clamp(3, 108);
}

int _requiredMonthAtBats() {
  final now = DateTime.now();
  final year = now.year;
  final month = now.month;

  final maxRequiredBats =
      (month == 12 || month == 1 || month == 2) ? 4 : 8;

  final monthStart = DateTime(year, month, 1);
  final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);

  double monthProgress =
      (now.millisecondsSinceEpoch - monthStart.millisecondsSinceEpoch)
          .toDouble();

  monthProgress /=
      (monthEnd.millisecondsSinceEpoch - monthStart.millisecondsSinceEpoch);

  monthProgress = monthProgress.clamp(0.0, 1.0);

  return (maxRequiredBats * monthProgress)
      .ceil()
      .clamp(1, maxRequiredBats);
}

num _requiredMonthInnings() {
  final now = DateTime.now();
  final year = now.year;
  final month = now.month;

  final maxRequiredInnings =
      (month == 12 || month == 1 || month == 2) ? 6 : 12;

  final monthStart = DateTime(year, month, 1);
  final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);

  double monthProgress =
      (now.millisecondsSinceEpoch - monthStart.millisecondsSinceEpoch)
          .toDouble();

  monthProgress /=
      (monthEnd.millisecondsSinceEpoch - monthStart.millisecondsSinceEpoch);

  monthProgress = monthProgress.clamp(0.0, 1.0);

  return (maxRequiredInnings * monthProgress)
      .ceil()
      .clamp(1, maxRequiredInnings);
}

class _BattingStatsCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _BattingStatsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final average = _statNumber(data, ['battingAverage']);
    final atBats = _statNumber(data, ['atBats', 'totalAtBats']);
    final hits = _statNumber(data, ['hits', 'totalHits']);
    final homeRuns = _statNumber(data, ['homeRuns', 'totalHomeRuns']);
    final rbis = _statNumber(data, ['rbis', 'totalRbis', 'runsBattedIn']);

    return _StatsSummaryCard(
      title: '打撃成績',
      icon: FontAwesomeIcons.baseballBatBall,
      mainValue: _formatDashboardRate(average),
      mainLabel: '打率',
       subValue: '(${atBats.toInt()}-${hits.toInt()})',
      items: [
        _StatsSummaryItem(label: '安打', value: hits.toInt().toString()),
        _StatsSummaryItem(label: '本塁打', value: homeRuns.toInt().toString()),
        _StatsSummaryItem(label: '打点', value: rbis.toInt().toString()),
      ],
    );
  }
}

class _PitchingStatsCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _PitchingStatsCard({required this.data});

  @override
  Widget build(BuildContext context) {
   final era = _statNumber(data, ['era']);
   final appearances = _statNumber(data, ['totalAppearances', 'appearances']);
   final wins = _statNumber(data, ['wins', 'totalWins']);
   final strikeouts = _statNumber(data, ['totalPStrikeouts', 'strikeouts']);
   final earnedRuns = _statNumber(data, ['totalEarnedRuns', 'earnedRuns']);
   final innings = _statNumber(data, [
    'inningsPitched',
    'totalInningsPitched',
    'innings',
  ]);

    return _StatsSummaryCard(
      title: '投手成績',
      icon: Icons.sports_baseball,
      mainValue: _formatDashboardEra(era),
      mainLabel: '防御率',
      subValue: '(${_formatInnings(innings)}回)',
      items: [
               _StatsSummaryItem(label: '登板', value: appearances.toInt().toString()),
               _StatsSummaryItem(label: '勝利', value: wins.toInt().toString()),
               _StatsSummaryItem(label: '奪三振', value: strikeouts.toInt().toString()),
               _StatsSummaryItem(label: '自責点', value: earnedRuns.toInt().toString()),
      ],
    );
  }
}

class _StatsSummaryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String mainValue;
  final String mainLabel;
  final List<_StatsSummaryItem> items;
  final String? subValue;

  const _StatsSummaryCard({
    required this.title,
    required this.icon,
    required this.mainValue,
    required this.mainLabel,
    required this.items,
    this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  color: const Color(0xFFEAF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: const Color(0xFF1565C0),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mainLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      mainValue,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        height: 1.0,
                      ),
                    ),
                    if (subValue != null) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          subValue!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: items
                .map(
                  (item) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StatsSummaryItem {
  final String label;
  final String value;

  const _StatsSummaryItem({
    required this.label,
    required this.value,
  });
}

class _GoalTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String progressText;
  final bool isAchieved;
  final double? progress;

  const _GoalTile({
    required this.icon,
    required this.label,
    required this.value,
    this.progressText = '',
    this.isAchieved = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isAchieved
            ? const Color(0xFFEFFAF1)
            : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAchieved
              ? const Color(0xFFB7E4C7)
              : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isAchieved) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '達成済み',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.black12,
                    ),
                  ),
                ],
                if (progressText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    progressText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
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

class _RankingGroup extends StatelessWidget {
  final String title;
  final String firstLabel;
  final String firstValue;
  final String firstRankText;
  final String secondLabel;
  final String secondValue;
  final String secondRankText;

  const _RankingGroup({
    required this.title,
    required this.firstLabel,
    required this.firstValue,
    required this.firstRankText,
    required this.secondLabel,
    required this.secondValue,
    required this.secondRankText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black45,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _RankingMiniItem(
                title: firstLabel,
                value: firstValue,
                rankText: firstRankText,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RankingMiniItem(
                title: secondLabel,
                value: secondValue,
                rankText: secondRankText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
class _QualificationTextLine extends StatelessWidget {
  final String title;
  final num annualCurrent;
  final num annualRequired;
  final num monthlyCurrent;
  final num monthlyRequired;
  final String Function(num value) formatter;

  const _QualificationTextLine({
    required this.title,
    required this.annualCurrent,
    required this.annualRequired,
    required this.monthlyCurrent,
    required this.monthlyRequired,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final annualRemaining = (annualRequired - annualCurrent).clamp(0, annualRequired);
    final monthlyRemaining = (monthlyRequired - monthlyCurrent).clamp(0, monthlyRequired);
    final annualReached = annualRemaining <= 0;
    final monthlyReached = monthlyRemaining <= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _QualificationTextPart(
                  label: '年間',
                  value: '${formatter(annualCurrent)} / ${formatter(annualRequired)}',
                  status: annualReached ? '到達' : 'あと${formatter(annualRemaining)}',
                  isReached: annualReached,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QualificationTextPart(
                  label: '今月',
                  value: '${formatter(monthlyCurrent)} / ${formatter(monthlyRequired)}',
                  status: monthlyReached ? '到達' : 'あと${formatter(monthlyRemaining)}',
                  isReached: monthlyReached,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QualificationTextPart extends StatelessWidget {
  final String label;
  final String value;
  final String status;
  final bool isReached;

  const _QualificationTextPart({
    required this.label,
    required this.value,
    required this.status,
    required this.isReached,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isReached
                ? Colors.green
                : const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}