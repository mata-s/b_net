import 'package:b_net/pages/team/team_grade_details/team_grade_detail_home.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'team_ranking.dart';
import 'team_performance_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamPerformanceHome extends StatefulWidget {
  final String teamId;
  final List<String> memberIds;
  final String selectedPeriodFilter;
  final String selectedGameTypeFilter;
  final DateTime startDate;
  final DateTime endDate;
  final bool hasActiveTeamSubscription;

  const TeamPerformanceHome({
    super.key,
    required this.teamId,
    required this.memberIds,
    required this.selectedPeriodFilter,
    required this.selectedGameTypeFilter,
    required this.startDate,
    required this.endDate,
    required this.hasActiveTeamSubscription,
  });

  @override
  _TeamPerformanceHomeState createState() => _TeamPerformanceHomeState();
}

class _TeamPerformanceHomeState extends State<TeamPerformanceHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String selectedPeriodFilter = '今年';
  String selectedGameTypeFilter = '全試合';
  late DateTime startDate;
  late DateTime endDate;

  final List<String> _periodOptions = ['通算', '今月', '先月', '今年', '去年', '年を選択'];
  final List<String> _gameTypeOptions = ['全試合', '練習試合', '公式戦'];

  List<int> _availableYears = [];
  int? _selectedYearForCustom;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setFilterDates();
    fetchAvailableYears();
    _autoFallbackToCareerIfNoThisYearData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // フィルタ選択に応じて日付範囲を設定
  void _setFilterDates() {
    final now = DateTime.now();
    switch (selectedPeriodFilter) {
      case '今月':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1)
            .subtract(const Duration(days: 1));
        break;
      case '先月':
        startDate = DateTime(now.year, now.month - 1, 1);
        endDate =
            DateTime(now.year, now.month, 1).subtract(const Duration(days: 1));
        break;
      case '今年':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31);
        break;
      case '去年':
        startDate = DateTime(now.year - 1, 1, 1);
        endDate = DateTime(now.year - 1, 12, 31);
        break;
      case '年を選択':
        if (_selectedYearForCustom != null) {
          startDate = DateTime(_selectedYearForCustom!, 1, 1);
          endDate = DateTime(_selectedYearForCustom!, 12, 31);
        } else {
          startDate = DateTime(now.year, 1, 1);
          endDate = DateTime(now.year, 12, 31);
        }
        break;
      case '通算':
      default:
        startDate = DateTime(2000, 1, 1);
        endDate = now;
        break;
    }
  }

  /// 今年がデフォルト。ただし今年のチームstatsが無い/実質0なら通算へ自動切替。
  Future<void> _autoFallbackToCareerIfNoThisYearData() async {
    // ユーザーが既に別の期間を選んでいる場合は触らない
    if (selectedPeriodFilter != '今年') return;

    final now = DateTime.now();
    final thisYearDocId = 'results_stats_${now.year}_all';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('stats')
          .doc(thisYearDocId)
          .get();

      if (!doc.exists) {
        if (!mounted) return;
        setState(() {
          selectedPeriodFilter = '通算';
          _setFilterDates();
        });
        return;
      }

      final data = doc.data();
      final totalGamesRaw = data?['totalGames'];
      final totalGames = (totalGamesRaw is num) ? totalGamesRaw.toInt() : 0;

      // 今年データが「実質0」なら通算へ
      if (totalGames <= 0) {
        if (!mounted) return;
        setState(() {
          selectedPeriodFilter = '通算';
          _setFilterDates();
        });
      }
    } catch (_) {
      // 失敗時はそのまま（今年）でOK
    }
  }

  Future<void> fetchAvailableYears() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('stats')
        .get();

    final years = snapshot.docs
        .map((doc) => doc.id)
        .where((id) => id.startsWith('results_stats_') && id.endsWith('_all'))
        .map((id) {
          final match = RegExp(r'results_stats_(\d+)_all').firstMatch(id);
          return match != null ? int.parse(match.group(1)!) : null;
        })
        .whereType<int>()
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // 降順にソート

    setState(() {
      _availableYears = years;
    });
  }

  void _showCupertinoPicker(
    BuildContext context,
    List<String> options,
    String selectedValue,
    Function(String) onSelected,
  ) {
    int selectedIndex = options.indexOf(selectedValue);
    String tempSelected = selectedValue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル', style: TextStyle(fontSize: 16)),
                  ),
                  const Text('選択してください',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        onSelected(tempSelected);
                        _setFilterDates();
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('決定',
                        style: TextStyle(fontSize: 16, color: Colors.blue)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 250,
              child: CupertinoPicker(
                scrollController:
                    FixedExtentScrollController(initialItem: selectedIndex),
                itemExtent: 40.0,
                onSelectedItemChanged: (int index) {
                  tempSelected = options[index];
                },
                children: options.map((option) {
                  return Center(
                    child: Text(
                      option,
                      style: const TextStyle(fontSize: 22),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            child: Column(
              children: [
                // 今年の目標
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('teams')
                      .doc(widget.teamId)
                      .collection('goals')
                      .where('period', isEqualTo: 'year')
                      .where('year', isEqualTo: DateTime.now().year)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox(height: 0);
                    }
                    final goalData = snapshot.data!.docs.first.data()
                        as Map<String, dynamic>;
                    final title = goalData['title'] ?? '';
                    final target = goalData['target'];
                    final statField = goalData['statField'];
                    final isAchieved = goalData['isAchieved'] ?? false;
                    final actual = goalData['actualValue'] ?? 0;
                    final isRatio = goalData['isRatio'] ?? false;
                    final compareType = goalData['compareType'] ?? '';
                    String isAchievedText = '';
                    if (isAchieved == true) {
                      if (isRatio == true ||
                          compareType.toString().trim() == 'less') {
                        isAchievedText = '達成中！';
                      } else {
                        isAchievedText = '達成！';
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          '今年の目標',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        if (isAchievedText.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          const Icon(Icons.auto_awesome,
                                              color: Colors.orange, size: 18),
                                          const SizedBox(width: 4),
                                          Text(
                                            isAchievedText,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      statField == 'custom'
                                          ? '$title'
                                          : ([
                                              'battingAverage',
                                              'onBasePercentage',
                                              'sluggingPercentage',
                                              'winRate',
                                              'era'
                                            ].contains(statField))
                                              ? '$title （${actual is num ? formatStatValue(statField, actual) : actual}）'
                                              : '$title（$actual / $target）',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // 今月の目標
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('teams')
                      .doc(widget.teamId)
                      .collection('goals')
                      .where('period', isEqualTo: 'month')
                      .where('month',
                          isEqualTo:
                              "${DateTime.now().year}-${DateTime.now().month}")
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox();
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox(height: 0);
                    }
                    final goalData = snapshot.data!.docs.first.data()
                        as Map<String, dynamic>;
                    final title = goalData['title'] ?? '';
                    final target = goalData['target'];
                    final statField = goalData['statField'];
                    final isAchieved = goalData['isAchieved'] ?? false;
                    final actual = goalData['actualValue'] ?? 0;
                    final isRatio = goalData['isRatio'] ?? false;
                    final compareType = goalData['compareType'] ?? '';
                    String isAchievedText = '';
                    if (isAchieved == true) {
                      if (isRatio == true ||
                          compareType.toString().trim() == 'less') {
                        isAchievedText = '達成中！';
                      } else {
                        isAchievedText = '達成！';
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          '今月の目標',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        if (isAchievedText.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Icon(Icons.auto_awesome,
                                              color: Colors.orange, size: 18),
                                          const SizedBox(width: 4),
                                          Text(
                                            isAchievedText,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      statField == 'custom'
                                          ? '$title'
                                          : ([
                                              'battingAverage',
                                              'onBasePercentage',
                                              'sluggingPercentage',
                                              'winRate',
                                              'era'
                                            ].contains(statField))
                                              ? '$title （${actual is num ? formatStatValue(statField, actual) : actual}）'
                                              : '$title（$actual / $target）',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // 期間フィルタ
                            GestureDetector(
                              onTap: () => _showCupertinoPicker(
                                context,
                                _periodOptions,
                                selectedPeriodFilter,
                                (newValue) {
                                  setState(() {
                                    selectedPeriodFilter = newValue;
                                    _setFilterDates();
                                  });
                                },
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Text(selectedPeriodFilter,
                                        style: const TextStyle(fontSize: 16)),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // 試合タイプフィルタ
                            GestureDetector(
                              onTap: () => _showCupertinoPicker(
                                context,
                                _gameTypeOptions,
                                selectedGameTypeFilter,
                                (newValue) {
                                  setState(() {
                                    selectedGameTypeFilter = newValue;
                                    _setFilterDates();
                                  });
                                },
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Text(selectedGameTypeFilter,
                                        style: const TextStyle(fontSize: 16)),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TeamGradeDetailHome(
                                  teamId: widget.teamId,
                                  hasActiveTeamSubscription: widget.hasActiveTeamSubscription,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            children: const [
                              Icon(
                                Icons.swap_horiz,
                                color: Colors.orange,
                                size: 30,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '詳細へ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (selectedPeriodFilter == '年を選択' &&
                        _availableYears.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _availableYears.length,
                            itemBuilder: (context, index) {
                              final int year = _availableYears[index];
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedPeriodFilter = '年を選択';
                                    _selectedYearForCustom = year;
                                    _setFilterDates();
                                  });
                                },
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _selectedYearForCustom == year
                                        ? Colors.blue
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$year年',
                                      style: TextStyle(
                                        color: _selectedYearForCustom == year
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'チーム成績'),
              Tab(text: 'ランキング'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ✅ TeamPerformancePage（デフォルト: 今年 / 0件なら通算へ自動切替）
                TeamPerformancePage(
                  teamId: widget.teamId,
                  selectedPeriodFilter: selectedPeriodFilter,
                  selectedGameTypeFilter: selectedGameTypeFilter,
                  startDate: startDate,
                  endDate: endDate,
                  yearOnly: selectedPeriodFilter == '年を選択',
                ),

                // ✅ TeamRankingPage（デフォルト: 今年）
                TeamRankingPage(
                  key:
                      ValueKey('$selectedPeriodFilter-$selectedGameTypeFilter'),
                  teamId: widget.teamId,
                  selectedPeriodFilter: selectedPeriodFilter,
                  selectedGameTypeFilter: selectedGameTypeFilter,
                  startDate: startDate,
                  endDate: endDate,
                  yearOnly: selectedPeriodFilter == '年を選択',
                  hasActiveTeamSubscription: widget.hasActiveTeamSubscription,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String formatPercentage(num value) {
  double doubleValue = value.toDouble();
  String formatted = doubleValue.toStringAsFixed(3);
  return formatted.startsWith("0")
      ? formatted.replaceFirst("0", "")
      : formatted;
}

String formatPercentageEra(num value) {
  double doubleValue = value.toDouble(); // num を double に変換
  return doubleValue.toStringAsFixed(2); // 小数点第2位までフォーマット
}

String formatStatValue(String statField, num value) {
  if (statField == 'era') {
    return formatPercentageEra(value);
  } else if ([
    'battingAverage',
    'onBasePercentage',
    'sluggingPercentage',
    'winRate'
  ].contains(statField)) {
    return formatPercentage(value);
  }
  return value.toString(); // それ以外はそのまま表示
}
