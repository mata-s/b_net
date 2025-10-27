import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamSacrificeFlyDetailPage extends StatefulWidget {
  final String teamId;
  final String selectedPeriodFilter;
  final String selectedGameTypeFilter;
  final DateTime startDate;
  final DateTime endDate;

  const TeamSacrificeFlyDetailPage({
    super.key,
    required this.teamId,
    required this.selectedPeriodFilter,
    required this.selectedGameTypeFilter,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<TeamSacrificeFlyDetailPage> createState() =>
      _TeamSacrificeFlyDetailPageState();
}

class _TeamSacrificeFlyDetailPageState
    extends State<TeamSacrificeFlyDetailPage> {
  late String selectedPeriodFilter;
  late String selectedGameTypeFilter;
  late DateTime _startDate;
  // ignore: unused_field
  late DateTime _endDate;

  final List<String> _periodOptions = ['通算', '今年', '去年', '年を選択'];
  final List<String> _gameTypeOptions = ['全試合', '練習試合', '公式戦'];

  Map<String, dynamic> sacFlyDirectionCounts = {};
  bool isLoading = true;

  final Map<String, Offset> customOffsets = {
    '右翼': Offset(0.78, 0.28),
    '中堅': Offset(0.50, 0.18),
    '左翼': Offset(0.20, 0.28),
    '三塁': Offset(0.30, 0.56),
    '遊撃': Offset(0.33, 0.40),
    '二塁': Offset(0.65, 0.40),
    '一塁': Offset(0.71, 0.55),
    '投手': Offset(0.50, 0.60),
    '捕手': Offset(0.50, 0.90),
  };

  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    selectedPeriodFilter = widget.selectedPeriodFilter;
    selectedGameTypeFilter = widget.selectedGameTypeFilter;
    _setFilterDates();
    fetchSacFlyDirectionData();
    fetchAvailableYears();
  }

  void _setFilterDates() {
    final now = DateTime.now();
    if (selectedPeriodFilter == '通算') {
      _startDate = DateTime(2000, 1, 1);
      _endDate = now;
    } else if (selectedPeriodFilter == '今年') {
      _startDate = DateTime(now.year, 1, 1);
      _endDate = now;
    } else if (selectedPeriodFilter == '去年') {
      _startDate = DateTime(now.year - 1, 1, 1);
      _endDate = DateTime(now.year - 1, 12, 31, 23, 59, 59);
    } else if (selectedPeriodFilter == '年を選択' && _availableYears.isNotEmpty) {
    } else {
      _startDate = widget.startDate;
      _endDate = widget.endDate;
    }
  }

  Future<void> fetchAvailableYears() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('stats')
        .get();

    final years = <int>{};
    for (var doc in snapshot.docs) {
      final docId = doc.id;
      final regex = RegExp(r'results_stats_(\d{4})');
      final match = regex.firstMatch(docId);
      if (match != null) {
        final year = int.tryParse(match.group(1)!);
        if (year != null) {
          years.add(year);
        }
      }
    }
    final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));
    setState(() {
      _availableYears = sortedYears;
    });
  }

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
                        fetchSacFlyDirectionData();
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

  Future<void> fetchSacFlyDirectionData() async {
    String year = _startDate.year.toString();
    String month = _startDate.month.toString();
    String gameType = selectedGameTypeFilter;

    String docId;

    if (selectedPeriodFilter == '通算') {
      docId = gameType == '全試合'
          ? 'results_stats_all'
          : 'results_stats_${gameType}_all';
    } else if (selectedPeriodFilter == '今年' ||
        selectedPeriodFilter == '去年' ||
        selectedPeriodFilter == '年を選択') {
      docId = gameType == '全試合'
          ? 'results_stats_${year}_all'
          : 'results_stats_${year}_${gameType}_all';
    } else {
      docId = 'results_stats_${year}_$month';
    }

    final Map<String, dynamic>? data = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('stats')
        .doc(docId)
        .get()
        .then((doc) => doc.data());

    print(
        "DEBUG: raw sacFlyDirectionCounts = ${data?['sacFlyDirectionCounts']}");

    if (data != null) {
      Map<String, String> directionKeyMap = {
        '左': '左翼',
        '中': '中堅',
        '右': '右翼',
        '三': '三塁',
        '遊': '遊撃',
        '二': '二塁',
        '一': '一塁',
        '投': '投手',
        '捕': '捕手',
      };

      Map<String, dynamic> originalCounts = {};
      if (data.containsKey('sacFlyDirectionCounts') &&
          data['sacFlyDirectionCounts'] is Map) {
        originalCounts =
            Map<String, dynamic>.from(data['sacFlyDirectionCounts'] as Map);
      } else {
        print("DEBUG: sacFlyDirectionCounts field is missing or invalid");
      }

      Map<String, double> filledCounts = {
        for (var uiLabel in customOffsets.keys) uiLabel: 0.0
      };

      originalCounts.forEach((key, value) {
        final uiLabel = directionKeyMap[key];
        if (uiLabel != null) {
          double count = 0.0;
          if (value is int) {
            count = value.toDouble();
          } else if (value is double) {
            count = value;
          } else if (value is String) {
            count = double.tryParse(value) ?? 0.0;
          }
          filledCounts[uiLabel] = count;
        }
      });

      print("DEBUG: filledCounts = $filledCounts");

      setState(() {
        sacFlyDirectionCounts = filledCounts;
        isLoading = false;
      });
    } else {
      setState(() {
        sacFlyDirectionCounts = {};
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 251, 252),
      appBar: AppBar(title: const Text('犠飛方向の詳細')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showCupertinoPicker(
                        context,
                        _periodOptions,
                        selectedPeriodFilter,
                        (newValue) {
                          setState(() {
                            selectedPeriodFilter = newValue;
                            _setFilterDates();
                            fetchSacFlyDirectionData();
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
                    GestureDetector(
                      onTap: () => _showCupertinoPicker(
                        context,
                        _gameTypeOptions,
                        selectedGameTypeFilter,
                        (newValue) {
                          setState(() {
                            selectedGameTypeFilter = newValue;
                            fetchSacFlyDirectionData();
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
                                fetchSacFlyDirectionData();
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
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : sacFlyDirectionCounts.isEmpty ||
                        sacFlyDirectionCounts.values.every((v) => v == 0.0)
                    ? const Center(child: Text('データがありません'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final double width = constraints.maxWidth;
                          final double height = width * 1.0;

                          final double total = sacFlyDirectionCounts.values
                              .fold(0.0, (sum, v) => sum + v);

                          return SizedBox(
                            width: width,
                            height: height,
                            child: Stack(
                              children: [
                                Image.asset(
                                  'assets/stadium.png',
                                  width: width,
                                  height: height,
                                  fit: BoxFit.contain,
                                ),
                                ...sacFlyDirectionCounts.entries
                                    .where((entry) => entry.value != 0.0)
                                    .map((entry) {
                                  final offset = customOffsets[entry.key];
                                  if (offset == null)
                                    return const SizedBox.shrink();

                                  final double count = entry.value as double;
                                  final double percentage =
                                      total > 0 ? (count / total) * 100 : 0.0;

                                  final double radius =
                                      28 + (percentage).clamp(0, 30);
                                  final double labelLeft =
                                      width * offset.dx - radius;
                                  final double labelTop =
                                      height * offset.dy - radius;

                                  return Positioned(
                                    left: labelLeft,
                                    top: labelTop,
                                    child: Container(
                                      width: radius * 2,
                                      height: radius * 2,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.orange.withOpacity(0.8),
                                      ),
                                      child: FittedBox(
                                        child: Text(
                                          '${percentage.toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(TeamSacrificeFlyDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPeriodFilter != oldWidget.selectedPeriodFilter ||
        widget.selectedGameTypeFilter != oldWidget.selectedGameTypeFilter ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      fetchSacFlyDirectionData();
    }
  }
}
