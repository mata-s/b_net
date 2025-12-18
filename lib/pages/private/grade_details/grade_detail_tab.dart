import 'package:b_net/common/subscription_guard.dart';
import 'package:b_net/pages/private/grade_details/atBat_detail_page.dart';
import 'package:b_net/pages/private/grade_details/batted_ball_detail.dart';
import 'package:b_net/pages/private/grade_details/batting_detail_page.dart';
import 'package:b_net/pages/private/grade_details/pitching_detail_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class GradeDetailTab extends StatefulWidget {
  final String userUid;
  final List<String> userPosition;
  final bool hasActiveSubscription;

  const GradeDetailTab(
      {super.key, required this.userUid, required this.userPosition, required this.hasActiveSubscription});

  @override
  _GradeDetailTabState createState() => _GradeDetailTabState();
}

class _GradeDetailTabState extends State<GradeDetailTab>
    with SingleTickerProviderStateMixin {
  List<int> _availableYears = [];
  late TabController _tabController;
  String selectedPeriodFilter = '通算'; // 期間フィルタ
  String selectedGameTypeFilter = '全試合'; // 試合タイプフィルタ
  late DateTime _startDate; // フィルタ開始日
  late DateTime _endDate; // フィルタ終了日

  bool _isPitcher = false;

  final List<String> _periodOptions = ['通算', '今年', '去年', '年を選択'];
  final List<String> _gameTypeOptions = ['全試合', '練習試合', '公式戦'];

  @override
  void initState() {
    super.initState();
    _setFilterDates(); // 初期のフィルタ設定
    _loadPitcherStatus(); // Check if the user is a pitcher
    fetchAvailableYears();
  }

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

    setState(() {
      _availableYears = years;
    });
  }

  Future<void> _loadPitcherStatus() async {
    _isPitcher = widget.userPosition.contains('投手');
    _tabController = TabController(length: _isPitcher ? 4 : 3, vsync: this);
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setFilterDates() {
    final now = DateTime.now();
    switch (selectedPeriodFilter) {
      case '通算':
        _startDate = DateTime(2000, 1, 1);
        _endDate = now;
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
    if (!widget.hasActiveSubscription) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const SubscriptionGuard(
          isLocked: true,
          initialPage: 3,
          showCloseButton: true,
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 251, 252),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 0, // Hides the default AppBar space
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // フィルタRow with return controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.swap_horiz,
                            color: Colors.orange, size: 30),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4.0),
                        child: Text(
                          '戻る',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 年セレクタ
          if (selectedPeriodFilter == '年を選択' && _availableYears.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
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
                        margin: const EdgeInsets.symmetric(horizontal: 6),
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
          // タブバー
          TabBar(
            controller: _tabController,
            tabs: [
              const Tab(text: '打席'),
              const Tab(text: '打撃'),
              const Tab(text: '打球'),
              if (_isPitcher) const Tab(text: '投手'),
            ],
          ),
          // ExpandedでTabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                AtbatDetailPage(
                  userUid: widget.userUid,
                  selectedPeriodFilter: selectedPeriodFilter,
                  selectedGameTypeFilter: selectedGameTypeFilter,
                  startDate: _startDate,
                  endDate: _endDate,
                  yearOnly: selectedPeriodFilter == '年を選択',
                ),
                BattingDetailPage(
                  userUid: widget.userUid,
                  selectedPeriodFilter: selectedPeriodFilter,
                  selectedGameTypeFilter: selectedGameTypeFilter,
                  startDate: _startDate,
                  endDate: _endDate,
                  yearOnly: selectedPeriodFilter == '年を選択',
                ),
                BattedBallDetailPage(
                  userUid: widget.userUid,
                  selectedPeriodFilter: selectedPeriodFilter,
                  selectedGameTypeFilter: selectedGameTypeFilter,
                  startDate: _startDate,
                  endDate: _endDate,
                  yearOnly: selectedPeriodFilter == '年を選択',
                ),
                if (_isPitcher)
                  PitchingDetailPage(
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
