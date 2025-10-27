import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BuntDetailPage extends StatefulWidget {
  final String userUid;
  final String selectedPeriodFilter;
  final String selectedGameTypeFilter;
  final DateTime startDate;
  final DateTime endDate;

  const BuntDetailPage({
    Key? key,
    required this.userUid,
    required this.selectedPeriodFilter,
    required this.selectedGameTypeFilter,
    required this.startDate,
    required this.endDate,
  }) : super(key: key);

  @override
  _BuntDetailPageState createState() => _BuntDetailPageState();
}

class _BuntDetailPageState extends State<BuntDetailPage> {
  int? _selectedYearForCustom;
  List<int> _availableYears = [];
  late String selectedPeriodFilter;
  late String selectedGameTypeFilter;
  late DateTime _startDate;
  // ignore: unused_field
  late DateTime _endDate;

  final List<String> _periodOptions = ['通算', '今年', '去年', '年を選択'];
  final List<String> _gameTypeOptions = ['全試合', '練習試合', '公式戦'];

  String _selectedDisplayFilter = 'すべて';
  final List<String> _displayFilterOptions = ['すべて', 'バント成功', 'バント失敗'];

  Map<String, Map<String, double>> buntDirectionDetailCounts = {};
  bool isLoading = true;
  Map<String, dynamic> advancedStats = {};

  // --- Pie chart selection and toggle state moved to class level ---
  final ValueNotifier<int?> _touchedIndex = ValueNotifier(null);
  final ValueNotifier<bool> _showPercentageNotifier = ValueNotifier(false);
  @override
  void dispose() {
    _touchedIndex.dispose();
    _showPercentageNotifier.dispose();
    super.dispose();
  }

  final Map<String, Offset> buntOffsets = {
    '左翼': Offset(0.20, 0.28),
    '中堅': Offset(0.50, 0.18),
    '右翼': Offset(0.78, 0.28),
    '三塁': Offset(0.30, 0.56),
    '遊撃': Offset(0.33, 0.40),
    '二塁': Offset(0.65, 0.40),
    '一塁': Offset(0.71, 0.55),
    '投手': Offset(0.50, 0.60),
    '捕手': Offset(0.50, 0.90),
    '打者': Offset(0.30, 0.87),
  };

  @override
  void initState() {
    super.initState();
    selectedPeriodFilter = widget.selectedPeriodFilter;
    selectedGameTypeFilter = widget.selectedGameTypeFilter;
    _setFilterDates();
    fetchBuntDirectionData();
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
      ..sort((a, b) => b.compareTo(a));

    setState(() {
      _availableYears = years;
    });
  }

  Future<void> fetchBuntDirectionData() async {
    String year = (_selectedYearForCustom ?? _startDate.year).toString();
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

    final data = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('stats')
        .doc(docId)
        .get()
        .then((doc) => doc.data());

    final adv = data?['advancedStats'] as Map<String, dynamic>? ?? {};
    final rawMap = data?['buntDirectionCounts'] as Map<String, dynamic>? ?? {};

    Map<String, String> map = {
      '左': '左翼',
      '中': '中堅',
      '右': '右翼',
      '三': '三塁',
      '遊': '遊撃',
      '二': '二塁',
      '一': '一塁',
      '投': '投手',
      '捕': '捕手',
      '打': '打者',
    };

    final Map<String, Map<String, double>> result = {};
    for (final category in rawMap.entries) {
      final directionMap = category.value as Map<String, dynamic>? ?? {};
      result[category.key] = {};
      for (final entry in directionMap.entries) {
        final label = map[entry.key];
        if (label != null) {
          result[category.key]![label] = (result[category.key]![label] ?? 0) +
              (entry.value as num).toDouble();
        }
      }
    }
    // Extract top-level bunt-related fields from data and add to advancedStats
    adv['totalBuntAttempts'] = data?['totalBuntAttempts'] ?? 0;
    adv['totalBuntSuccesses'] = data?['totalBuntSuccesses'] ?? 0;
    adv['totalBuntFailures'] = data?['totalBuntFailures'] ?? 0;
    adv['totalBuntDoublePlays'] = data?['totalBuntDoublePlays'] ?? 0;
    adv['totalSqueezeSuccesses'] = data?['totalSqueezeSuccesses'] ?? 0;
    adv['totalSqueezeFailures'] = data?['totalSqueezeFailures'] ?? 0;
    adv['totalThreeBuntMissFailures'] =
        data?['totalThreeBuntMissFailures'] ?? 0;
    adv['totalThreeBuntFoulFailures'] =
        data?['totalThreeBuntFoulFailures'] ?? 0;
    setState(() {
      buntDirectionDetailCounts = result;
      advancedStats = adv;
      isLoading = false;
    });
  }

  @override
  void didUpdateWidget(covariant BuntDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPeriodFilter != oldWidget.selectedPeriodFilter ||
        widget.selectedGameTypeFilter != oldWidget.selectedGameTypeFilter ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      fetchBuntDirectionData();
    }
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
    } else {
      _startDate = widget.startDate;
      _endDate = widget.endDate;
    }
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

  // Pie chart breakdown widget (refactored version, AtBatDetailPage style)
  Widget _buildAtBatBreakdownChart() {
    final total = (advancedStats['totalBuntAttempts'] ?? 0).toDouble();
    final List<PieChartSectionDataItem> sections = [
      PieChartSectionDataItem(
          '犠打成功', advancedStats['totalBuntSuccesses'], Colors.blue),
      PieChartSectionDataItem(
          '犠打失敗', advancedStats['totalBuntFailures'], Colors.red),
      PieChartSectionDataItem(
          'バント併殺', advancedStats['totalBuntDoublePlays'], Colors.orange),
      PieChartSectionDataItem(
          'スクイズ成功', advancedStats['totalSqueezeSuccesses'], Colors.green),
      PieChartSectionDataItem(
          'スクイズ失敗', advancedStats['totalSqueezeFailures'], Colors.purple),
      PieChartSectionDataItem('スリーバント失敗(空振り)',
          advancedStats['totalThreeBuntMissFailures'], Colors.teal),
      PieChartSectionDataItem('スリーバント失敗(ファル)',
          advancedStats['totalThreeBuntFoulFailures'], Colors.brown),
    ];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Pie chart stacked with toggle switch ---
            Stack(
              children: [
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      ValueListenableBuilder<int?>(
                        valueListenable: _touchedIndex,
                        builder: (context, touched, _) {
                          return PieChart(
                            PieChartData(
                              sections: List.generate(sections.length, (i) {
                                final data = sections[i];
                                final v = (data.value ?? 0).toDouble();
                                if (v <= 0) {
                                  return PieChartSectionData(
                                      value: 0, showTitle: false);
                                }
                                final percent =
                                    total > 0 ? (v / total) * 100 : 0;
                                final showLabel = percent >= 5;
                                final isTouched = i == touched;
                                // Always show percentage as label
                                return PieChartSectionData(
                                  value: v,
                                  title: showLabel
                                      ? '${percent.toStringAsFixed(1)}%'
                                      : '',
                                  color: data.color,
                                  radius: isTouched ? 72 : 60,
                                  titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                );
                              }),
                              sectionsSpace: 2,
                              centerSpaceRadius: 48,
                              pieTouchData: PieTouchData(
                                touchCallback: (event, response) {
                                  if (response != null &&
                                      response.touchedSection != null &&
                                      event is FlTapUpEvent) {
                                    final index = response
                                        .touchedSection!.touchedSectionIndex;
                                    // Toggle: tap again to deselect
                                    _touchedIndex.value =
                                        (_touchedIndex.value == index)
                                            ? null
                                            : index;
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      // Center total attempts/企図数 in the middle of the pie chart
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              total.toInt().toString(),
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              '企図数',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      // Switch positioned at bottom right
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _showPercentageNotifier,
                          builder: (context, showPercentage, _) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: showPercentage,
                                  onChanged: (val) {
                                    _showPercentageNotifier.value = val;
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Legend below the pie chart, showing count or percent based on toggle
            ValueListenableBuilder2<int?, bool>(
              first: _touchedIndex,
              second: _showPercentageNotifier,
              builder: (context, touched, showPercentage, _) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: List.generate(sections.length, (i) {
                    final data = sections[i];
                    final v = (data.value ?? 0).toDouble();
                    final percent = total > 0 ? (v / total) * 100 : 0;
                    final display = showPercentage
                        ? '${percent.toStringAsFixed(1)}%'
                        : '${v.toInt()}';
                    final isHighlighted = touched == i;
                    return GestureDetector(
                      onTap: () {
                        // Toggle: tap again to deselect
                        _touchedIndex.value =
                            (_touchedIndex.value == i) ? null : i;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? data.color.withOpacity(0.2)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: data.color,
                                shape: BoxShape.rectangle,
                                border: Border.all(
                                    color: isHighlighted
                                        ? Colors.black
                                        : Colors.grey.shade600,
                                    width: isHighlighted ? 2 : 1),
                              ),
                            ),
                            Text(
                              '${data.label} ($display)',
                              style: TextStyle(
                                fontWeight: isHighlighted
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                                color: isHighlighted
                                    ? Colors.black
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('バント方向データ'),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Period Filter
                GestureDetector(
                  onTap: () => _showCupertinoPicker(
                    context,
                    _periodOptions,
                    selectedPeriodFilter,
                    (newValue) {
                      setState(() {
                        selectedPeriodFilter = newValue;
                        if (newValue != '年を選択') {
                          _selectedYearForCustom = null;
                        }
                        _setFilterDates();
                        fetchBuntDirectionData();
                      });
                    },
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                // Game Type Filter
                GestureDetector(
                  onTap: () => _showCupertinoPicker(
                    context,
                    _gameTypeOptions,
                    selectedGameTypeFilter,
                    (newValue) {
                      setState(() {
                        selectedGameTypeFilter = newValue;
                        if (selectedPeriodFilter != '年を選択') {
                          _setFilterDates();
                        } else if (_selectedYearForCustom != null) {
                          _startDate = DateTime(_selectedYearForCustom!, 1, 1);
                          _endDate = DateTime(_selectedYearForCustom!, 12, 31);
                        }
                        fetchBuntDirectionData();
                      });
                    },
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          ),
          if (selectedPeriodFilter == '年を選択' && _availableYears.isNotEmpty)
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
                          _startDate = DateTime(year, 1, 1);
                          _endDate = DateTime(year, 12, 31);
                          fetchBuntDirectionData();
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
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
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : buntDirectionDetailCounts.values
                        .every((map) => map.values.every((v) => v == 0.0))
                    ? const Center(child: Text('データがありません'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          // バント種別ラベルと各ポジションのラベル表示位置・順序（動的に選択肢によって切り替え）
                          final Map<String, String> labelMap =
                              _selectedDisplayFilter == 'バント成功'
                                  ? {
                                      'sacSuccess': '犠打成功',
                                      'squeezeSuccess': 'スクイズ成功',
                                    }
                                  : _selectedDisplayFilter == 'バント失敗'
                                      ? {
                                          'sacFail': '犠打失敗',
                                          'squeezeFail': 'スクイズ失敗',
                                          'threeBuntFoulFail': 'スリーバント',
                                          'threeBuntMissFail': 'スリーバント空振り',
                                        }
                                      : {
                                          'successTotal': 'バント成功',
                                          'failTotal': 'バント失敗',
                                          'threeBuntMissFail': 'スリーバント空振り'
                                        };

                          final Map<String, Offset> baseLabelOffsets = {
                            '投手': Offset(0.40, 0.64),
                            '捕手': Offset(0.60, 0.85),
                            '一塁': Offset(0.74, 0.60),
                            '二塁': Offset(0.70, 0.25),
                            '三塁': Offset(0.10, 0.60),
                            '遊撃': Offset(0.10, 0.25),
                            '打者': Offset(0.10, 0.80),
                          };

                          final Map<String, List<String>>
                              labelOrderPerPosition =
                              _selectedDisplayFilter == 'バント成功'
                                  ? {
                                      '投手': ['sacSuccess', 'squeezeSuccess'],
                                      '捕手': ['sacSuccess', 'squeezeSuccess'],
                                      '一塁': ['sacSuccess', 'squeezeSuccess'],
                                      '二塁': ['sacSuccess', 'squeezeSuccess'],
                                      '三塁': ['sacSuccess', 'squeezeSuccess'],
                                      '遊撃': ['sacSuccess', 'squeezeSuccess'],
                                    }
                                  : _selectedDisplayFilter == 'バント失敗'
                                      ? {
                                          '投手': ['sacFail', 'squeezeFail'],
                                          '捕手': [
                                            'sacFail',
                                            'squeezeFail',
                                            'threeBuntFoulFail'
                                          ],
                                          '一塁': [
                                            'sacFail',
                                            'squeezeFail',
                                            'threeBuntFoulFail'
                                          ],
                                          '二塁': ['sacFail', 'squeezeFail'],
                                          '三塁': [
                                            'sacFail',
                                            'squeezeFail',
                                            'threeBuntFoulFail'
                                          ],
                                          '遊撃': ['sacFail', 'squeezeFail'],
                                          '打者': ['threeBuntMissFail'],
                                        }
                                      : {
                                          '投手': ['successTotal', 'failTotal'],
                                          '捕手': ['successTotal', 'failTotal'],
                                          '一塁': ['successTotal', 'failTotal'],
                                          '二塁': ['successTotal', 'failTotal'],
                                          '三塁': ['successTotal', 'failTotal'],
                                          '遊撃': ['successTotal', 'failTotal'],
                                          '打者': ['threeBuntMissFail'],
                                        };

                          final double width = constraints.maxWidth;
                          final double height = width * 1.0;

                          // Use fixed keys for bar chart (independent of _selectedDisplayFilter)
                          final List<String> barChartKeys = [
                            'sacSuccess',
                            'sacFail',
                            'squeezeSuccess',
                            'squeezeFail',
                            'threeBuntFoulFail',
                            'threeBuntMissFail'
                          ];
                          final Map<String, double> barChartRawCounts = {};
                          for (final key in barChartKeys) {
                            final map = buntDirectionDetailCounts[key] ?? {};
                            barChartRawCounts[key] =
                                map.values.fold(0.0, (a, b) => a + b);
                          }

                          final displayKeys = _selectedDisplayFilter == 'バント成功'
                              ? ['sacSuccess', 'squeezeSuccess']
                              : _selectedDisplayFilter == 'バント失敗'
                                  ? [
                                      'sacFail',
                                      'squeezeFail',
                                      'threeBuntFoulFail',
                                      'threeBuntMissFail'
                                    ]
                                  : [
                                      'sacSuccess',
                                      'sacFail',
                                      'squeezeSuccess',
                                      'squeezeFail',
                                      'threeBuntFoulFail',
                                      'threeBuntMissFail'
                                    ];

                          final Map<String, double> totalRawCounts = {};
                          buntOffsets
                              .forEach((pos, _) => totalRawCounts[pos] = 0);

                          for (final key in displayKeys) {
                            final map = buntDirectionDetailCounts[key] ?? {};
                            for (final entry in map.entries) {
                              totalRawCounts[entry.key] =
                                  totalRawCounts[entry.key]! + entry.value;
                            }
                          }

                          final double grandTotal = totalRawCounts.values
                              .fold(0, (sum, value) => sum + value);
                          final Map<String, double> totalCounts = {
                            for (final entry in totalRawCounts.entries)
                              entry.key: grandTotal > 0
                                  ? (entry.value / grandTotal) * 100
                                  : 0,
                          };

                          // successTotal/failTotal計算（各ポジションごと）
                          final Map<String, double> successTotals = {};
                          final Map<String, double> failTotals = {};
                          for (final pos in buntOffsets.keys) {
                            double success = 0;
                            double fail = 0;
                            for (final k in ['sacSuccess', 'squeezeSuccess']) {
                              success +=
                                  buntDirectionDetailCounts[k]?[pos] ?? 0;
                            }
                            for (final k in [
                              'sacFail',
                              'squeezeFail',
                              'threeBuntFoulFail'
                            ]) {
                              fail += buntDirectionDetailCounts[k]?[pos] ?? 0;
                            }
                            successTotals[pos] = success;
                            failTotals[pos] = fail;
                          }

                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                SizedBox(
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
                                      // Draw a single circle per position, sized by totalCounts
                                      for (final entry in totalCounts.entries)
                                        if (entry.value > 0)
                                          Builder(builder: (context) {
                                            final offset =
                                                buntOffsets[entry.key]!;
                                            final double radius =
                                                24 + (entry.value / 100) * 28;
                                            final double left =
                                                width * offset.dx - radius;
                                            final double top =
                                                height * offset.dy - radius;
                                            return Positioned(
                                              left: left,
                                              top: top,
                                              child: Container(
                                                width: radius * 2,
                                                height: radius * 2,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.blue
                                                      .withOpacity(0.6),
                                                ),
                                                child: Text(
                                                  '${entry.value.toStringAsFixed(1)}%',
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                      // バント種別ごとのラベルを各ポジションに動的に縦積み配置
                                      ...baseLabelOffsets.keys
                                          .expand((position) {
                                        final baseOffset =
                                            baseLabelOffsets[position];
                                        // Null check for baseOffset and labelOrderPerPosition
                                        if (baseOffset == null)
                                          return <Widget>[];
                                        final keys =
                                            labelOrderPerPosition[position] ??
                                                [];
                                        if (keys.isEmpty) return <Widget>[];
                                        int i = 0;
                                        final List<Widget> children = [];
                                        for (final key in keys) {
                                          final count = key == 'successTotal'
                                              ? successTotals[position] ?? 0
                                              : key == 'failTotal'
                                                  ? failTotals[position] ?? 0
                                                  : buntDirectionDetailCounts[
                                                          key]?[position] ??
                                                      0;
                                          if (count > 0) {
                                            final dx = baseOffset.dx;
                                            final dy = baseOffset.dy + 0.04 * i;
                                            children.add(Positioned(
                                              left: width * dx,
                                              top: height * dy,
                                              child: Text(
                                                '${labelMap[key]}: ${count.toInt()}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ));
                                            i++;
                                          }
                                        }
                                        return children;
                                      }),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: () => _showCupertinoPicker(
                                        context,
                                        _displayFilterOptions,
                                        _selectedDisplayFilter,
                                        (newValue) {
                                          setState(() {
                                            _selectedDisplayFilter = newValue;
                                          });
                                        },
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.grey),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(_selectedDisplayFilter,
                                                style: const TextStyle(
                                                    fontSize: 16)),
                                            const Icon(Icons.arrow_drop_down),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'バント企図数: ${advancedStats['totalBuntAttempts'] ?? 0}',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'バント成功数: ${(advancedStats['totalBuntSuccesses'] ?? 0) + (advancedStats['totalSqueezeSuccesses'] ?? 0)}',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'バント成功率: ${((advancedStats['buntSuccessRate'] ?? 0) * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                // --- Start Pie Chart Card ---
                                _buildAtBatBreakdownChart(),
                                // --- End Pie Chart Card ---
                                SizedBox(height: 20),
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
}

// PieChartSectionDataItem class moved to top-level
class PieChartSectionDataItem {
  final String label;
  final int? value;
  final Color color;
  PieChartSectionDataItem(this.label, this.value, this.color);
}

// Helper ValueListenableBuilder for two ValueNotifiers
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext, A, B, Widget?) builder;
  final Widget? child;
  const ValueListenableBuilder2({
    Key? key,
    required this.first,
    required this.second,
    required this.builder,
    this.child,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (context, a, _) {
        return ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, b, __) => builder(context, a, b, child),
        );
      },
    );
  }
}
