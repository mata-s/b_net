import 'package:b_net/pages/private/grade_details/grade_detail_tab.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'batting_tab.dart'; // 打撃タブ
import 'fielding_pitching_tab.dart'; // 守備/投手タブ

class IndividualHome extends StatefulWidget {
  final String userUid;
  final List<String> userPosition;
  final bool hasActiveSubscription;

  const IndividualHome(
      {super.key, required this.userUid, required this.userPosition, required this.hasActiveSubscription});

  @override
  _IndividualHomeState createState() => _IndividualHomeState();
}

class _IndividualHomeState extends State<IndividualHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String selectedPeriodFilter = '今年'; // 期間フィルタ（デフォは今年。データ0件なら通算に自動切替）
  String selectedGameTypeFilter = '全試合'; // 試合タイプフィルタ
  late DateTime _startDate; // フィルタ開始日
  late DateTime _endDate; // フィルタ終了日

  // 年オプションはFirestoreから取得するため空リストで初期化
  final List<String> _periodOptions = ['通算', '今月', '先月', '今年', '去年', '年を選択'];
  final List<String> _gameTypeOptions = ['全試合', '練習試合', '公式戦'];
  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setFilterDates(); // 初期のフィルタ設定
    fetchAvailableYears(); // Firestoreから年一覧取得
  }

  // Firestoreに存在する年を収集
  Future<void> fetchAvailableYears() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
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

    // ✅ 今年デフォ。ただし「今年のstatsが存在しない（0件）」なら通算に自動切替
    final currentYear = DateTime.now().year;
    final shouldFallbackToCareer = years.isEmpty || !years.contains(currentYear);

    setState(() {
      _availableYears = years;

      if (shouldFallbackToCareer && selectedPeriodFilter == '今年') {
        selectedPeriodFilter = '通算';
        _setFilterDates();
      }
    });
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
      case '通算':
        _startDate = DateTime(2000, 1, 1);
        _endDate = now;
        break;
      case '今月':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 1)
            .subtract(const Duration(days: 1));
        break;
      case '先月':
        _startDate = DateTime(now.year, now.month - 1, 1);
        _endDate =
            DateTime(now.year, now.month, 1).subtract(const Duration(days: 1));
        break;
      case '今年':
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31);
        break;
      case '去年':
        _startDate = DateTime(now.year - 1, 1, 1);
        _endDate = DateTime(now.year - 1, 12, 31);
        break;
    }
  }

  // **CupertinoPickerを表示する関数**
  void _showCupertinoPicker(
    BuildContext context,
    List<String> options,
    String selectedValue,
    Function(String) onSelected,
  ) {
    int selectedIndex = options.indexOf(selectedValue);
    if (selectedIndex == -1) selectedIndex = 0;
    String tempSelected = options[selectedIndex];

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
                      .collection('users')
                      .doc(widget.userUid)
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
                      .collection('users')
                      .doc(widget.userUid)
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
                            SizedBox(width: 10),
                            // **試合タイプフィルタ**
                            GestureDetector(
                              onTap: () => _showCupertinoPicker(
                                context,
                                _gameTypeOptions,
                                selectedGameTypeFilter,
                                (newValue) {
                                  setState(() {
                                    selectedGameTypeFilter = newValue;
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
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GradeDetailTab(
                                        userUid: widget.userUid,
                                        userPosition: widget.userPosition,
                                        hasActiveSubscription: widget.hasActiveSubscription
                                        ),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.swap_horiz,
                                    color: Colors.orange,
                                    size: 30,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
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
                      ],
                    ),
                    // 年を選択 横スクロール年セレクタ（Firestoreから取得した年がある場合のみ表示）
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
                                    _startDate = DateTime(year, 1, 1);
                                    _endDate = DateTime(year, 12, 31);
                                  });
                                },
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _startDate.year == year
                                        ? Colors.blue
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$year年',
                                      style: TextStyle(
                                        color: _startDate.year == year
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
            tabs: [
              const Tab(text: '打撃'),
              Tab(text: widget.userPosition.contains('投手') ? '投手/守備' : '守備'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                BattingTab(
                  userUid: widget.userUid,
                  selectedPeriodFilter: selectedPeriodFilter,
                  selectedGameTypeFilter: selectedGameTypeFilter,
                  startDate: _startDate,
                  endDate: _endDate,
                  yearOnly: selectedPeriodFilter == '年を選択',
                ),
                FieldingPitchingTab(
                  userUid: widget.userUid,
                  selectedPeriodFilter: selectedPeriodFilter,
                  selectedGameTypeFilter: selectedGameTypeFilter,
                  startDate: _startDate,
                  endDate: _endDate,
                  yearOnly: selectedPeriodFilter == '年を選択',
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