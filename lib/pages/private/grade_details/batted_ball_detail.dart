import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BattedBallDetailPage extends StatefulWidget {
  final String userUid;
  final String selectedPeriodFilter;
  final String selectedGameTypeFilter;
  final DateTime startDate;
  final DateTime endDate;
  final bool yearOnly;

  const BattedBallDetailPage({
    super.key,
    required this.userUid,
    required this.selectedPeriodFilter,
    required this.selectedGameTypeFilter,
    required this.startDate,
    required this.endDate,
    required this.yearOnly,
  });

  @override
  State<BattedBallDetailPage> createState() => _BattedBallDetailPageState();
}

class _BattedBallDetailPageState extends State<BattedBallDetailPage> {
  Map<String, dynamic> hitDirectionCounts = {};
  Map<String, Map<String, int>> hitDirectionDetails = {};
  bool isLoading = true;

  final Map<String, Offset> customOffsets = {
    '左翼': Offset(0.20, 0.28),
    '中堅': Offset(0.50, 0.18),
    '右翼': Offset(0.78, 0.28),
    '三塁': Offset(0.30, 0.56),
    '遊撃': Offset(0.33, 0.40),
    '二塁': Offset(0.65, 0.40),
    '一塁': Offset(0.71, 0.55),
    '投手': Offset(0.50, 0.60),
    '捕手': Offset(0.50, 0.90),
  };

  @override
  void initState() {
    super.initState();
    fetchHitDirectionData();
  }

  Future<void> fetchHitDirectionData() async {
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

    final Map<String, dynamic>? data = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('stats')
        .doc(docId)
        .get()
        .then((doc) => doc.data());

    final advancedStats = data?['advancedStats'] as Map<String, dynamic>? ?? {};
    print(
        "DEBUG: raw hitDirectionPercentage = ${advancedStats['hitDirectionPercentage']}");

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

      Map<String, dynamic> originalPercentages = {};
      if (advancedStats.containsKey('hitDirectionPercentage') &&
          advancedStats['hitDirectionPercentage'] is Map) {
        originalPercentages = Map<String, dynamic>.from(
            advancedStats['hitDirectionPercentage'] as Map);
      } else {
        print("DEBUG: hitDirectionPercentage field is missing or invalid");
      }

      Map<String, double> filledPercentages = {
        for (var uiLabel in customOffsets.keys) uiLabel: 0.0
      };

      originalPercentages.forEach((key, value) {
        final uiLabel = directionKeyMap[key];
        if (uiLabel != null) {
          double percent = 0.0;
          if (value is int) {
            percent = value.toDouble();
          } else if (value is double) {
            percent = value;
          } else if (value is String) {
            percent = double.tryParse(value) ?? 0.0;
          }
          filledPercentages[uiLabel] = percent * 100;
        }
      });

      print("DEBUG: filledPercentages = $filledPercentages");

      final rawDetails =
          data['hitDirectionDetails'] as Map<String, dynamic>? ?? {};
      final parsedDetails = <String, Map<String, int>>{};
      rawDetails.forEach((pos, resultMap) {
        if (resultMap is Map) {
          parsedDetails[pos] = {};
          resultMap.forEach((result, count) {
            parsedDetails[pos]![result.toString()] =
                (count is int) ? count : int.tryParse(count.toString()) ?? 0;
          });
        }
      });

      setState(() {
        hitDirectionCounts = filledPercentages;
        hitDirectionDetails = parsedDetails;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  List<String> _collectAllResults(Map<String, Map<String, int>> details) {
    const fixedOrder = [
      'ゴロ',
      'フライ',
      'ライナー',
      '併殺',
      '失策出塁',
      '犠打',
      '内野安打',
      '犠飛',
      '単打',
      '二塁打',
      '三塁打',
      '本塁打',
    ];
    final actualResults = <String>{};
    for (final posEntry in details.values) {
      actualResults.addAll(posEntry.keys);
    }
    return fixedOrder.where((r) => actualResults.contains(r)).toList();
  }

  String verticalText(String text) {
    return text.replaceAll('ー', '｜').split('').join('\n');
  }

  @override
  Widget build(BuildContext context) {
    // hitDirectionCounts already holds percentages now

    return Scaffold(
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : hitDirectionCounts.values.every((v) => v == 0.0)
                ? const Text('データがありません')
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final double width = constraints.maxWidth;
                      final double height = width * 1.0; // 画像比率が正方形の場合

                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
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
                                  ...hitDirectionCounts.entries.map((entry) {
                                    final offset = customOffsets[entry.key];
                                    if (offset == null)
                                      return const SizedBox.shrink();

                                    final double percentage =
                                        entry.value as double;
                                    final double radius =
                                        22 + (percentage / 100) * 24;
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
                                            '${percentage.toStringAsFixed(1)}%',
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
                            ),
                            if (hitDirectionDetails.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '打球方向 × 結果（件数）',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 12),
                                    Builder(
                                      builder: (context) {
                                        final resultTypes = _collectAllResults(
                                            hitDirectionDetails);
                                        final positionOrder = [
                                          '投',
                                          '捕',
                                          '一',
                                          '二',
                                          '三',
                                          '遊',
                                          '左',
                                          '中',
                                          '右'
                                        ];
                                        final rowHeight = 50.0;
                                        final cellWidth = 60.0;

                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  height: rowHeight + 80,
                                                  width: cellWidth,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    border: Border(
                                                      right: BorderSide(
                                                          color: Colors
                                                              .grey.shade300),
                                                      bottom: BorderSide(
                                                          color: Colors
                                                              .grey.shade300),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    verticalText('ポジション'),
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16),
                                                  ),
                                                ),
                                                ...positionOrder
                                                    .where((pos) =>
                                                        hitDirectionDetails
                                                            .containsKey(pos))
                                                    .map(
                                                      (pos) => Container(
                                                        height: rowHeight,
                                                        width: cellWidth,
                                                        alignment:
                                                            Alignment.center,
                                                        decoration:
                                                            BoxDecoration(
                                                          border: Border.all(
                                                              color: Colors.grey
                                                                  .shade300),
                                                        ),
                                                        child: Text(
                                                          pos,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: const TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                      ),
                                                    ),
                                                // 合計行（計）ラベル
                                                Container(
                                                  height: rowHeight,
                                                  width: cellWidth,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: Colors
                                                            .grey.shade300),
                                                  ),
                                                  child: Text(
                                                    '合計',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.deepOrange,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        ...resultTypes.map(
                                                          (result) => Container(
                                                            width: cellWidth,
                                                            height:
                                                                rowHeight + 80,
                                                            alignment: Alignment
                                                                .center,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors.grey
                                                                  .shade200,
                                                              border: Border(
                                                                right: BorderSide(
                                                                    color: Colors
                                                                        .grey
                                                                        .shade300),
                                                                bottom: BorderSide(
                                                                    color: Colors
                                                                        .grey
                                                                        .shade300),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              verticalText(
                                                                  result),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16),
                                                            ),
                                                          ),
                                                        ),
                                                        // 最終列: 各行合計用の空白
                                                        Container(
                                                          width: cellWidth,
                                                          height:
                                                              rowHeight + 80,
                                                          alignment:
                                                              Alignment.center,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .grey.shade200,
                                                            border: Border(
                                                              right: BorderSide(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade300),
                                                              bottom: BorderSide(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade300),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            verticalText('計'),
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    ...positionOrder
                                                        .where((pos) =>
                                                            hitDirectionDetails
                                                                .containsKey(
                                                                    pos))
                                                        .map(
                                                      (pos) {
                                                        final results =
                                                            hitDirectionDetails[
                                                                pos]!;
                                                        // Add total per position
                                                        final rowTotal =
                                                            resultTypes.fold<
                                                                    int>(0,
                                                                (sum, result) {
                                                          final value =
                                                              results[result] ??
                                                                  0;
                                                          final isInvalid = (([
                                                                    '単打',
                                                                    '二塁打',
                                                                    '三塁打',
                                                                    '本塁打',
                                                                    '犠飛'
                                                                  ].contains(
                                                                      result) &&
                                                                  [
                                                                    '投',
                                                                    '捕',
                                                                    '一',
                                                                    '二',
                                                                    '三',
                                                                    '遊'
                                                                  ].contains(
                                                                      pos)) ||
                                                              ([
                                                                    '犠打',
                                                                    '内野安打'
                                                                  ].contains(
                                                                      result) &&
                                                                  [
                                                                    '左',
                                                                    '中',
                                                                    '右'
                                                                  ].contains(
                                                                      pos)));
                                                          return isInvalid
                                                              ? sum
                                                              : sum + value;
                                                        });
                                                        return Row(
                                                          children: [
                                                            ...resultTypes
                                                                .map((result) {
                                                              final isInvalid = (([
                                                                        '単打',
                                                                        '二塁打',
                                                                        '三塁打',
                                                                        '本塁打',
                                                                        '犠飛'
                                                                      ].contains(
                                                                          result) &&
                                                                      [
                                                                        '投',
                                                                        '捕',
                                                                        '一',
                                                                        '二',
                                                                        '三',
                                                                        '遊'
                                                                      ].contains(
                                                                          pos)) ||
                                                                  ([
                                                                        '犠打',
                                                                        '内野安打'
                                                                      ].contains(
                                                                          result) &&
                                                                      [
                                                                        '左',
                                                                        '中',
                                                                        '右'
                                                                      ].contains(
                                                                          pos)));
                                                              return Container(
                                                                width:
                                                                    cellWidth,
                                                                height:
                                                                    rowHeight,
                                                                alignment:
                                                                    Alignment
                                                                        .center,
                                                                decoration:
                                                                    BoxDecoration(
                                                                  border: Border.all(
                                                                      color: Colors
                                                                          .grey
                                                                          .shade300),
                                                                ),
                                                                child: Text(
                                                                  isInvalid
                                                                      ? ''
                                                                      : '${results[result] ?? 0}',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold),
                                                                ),
                                                              );
                                                            }),
                                                            // 合計列
                                                            Container(
                                                              width: cellWidth,
                                                              height: rowHeight,
                                                              alignment:
                                                                  Alignment
                                                                      .center,
                                                              decoration:
                                                                  BoxDecoration(
                                                                border: Border.all(
                                                                    color: Colors
                                                                        .grey
                                                                        .shade300),
                                                              ),
                                                              child: Text(
                                                                '$rowTotal',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Colors
                                                                        .deepOrange),
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                    // 合計行（計）
                                                    Builder(
                                                      builder: (_) {
                                                        // Add grand total column after all result columns
                                                        int grandTotal = 0;
                                                        for (final pos
                                                            in positionOrder) {
                                                          final rowMap =
                                                              hitDirectionDetails[
                                                                      pos] ??
                                                                  {};
                                                          for (final result
                                                              in resultTypes) {
                                                            final value =
                                                                rowMap[result] ??
                                                                    0;
                                                            final isInvalid = (([
                                                                      '単打',
                                                                      '二塁打',
                                                                      '三塁打',
                                                                      '本塁打',
                                                                      '犠飛'
                                                                    ].contains(
                                                                        result) &&
                                                                    [
                                                                      '投',
                                                                      '捕',
                                                                      '一',
                                                                      '二',
                                                                      '三',
                                                                      '遊'
                                                                    ].contains(
                                                                        pos)) ||
                                                                ([
                                                                      '犠打',
                                                                      '内野安打'
                                                                    ].contains(
                                                                        result) &&
                                                                    [
                                                                      '左',
                                                                      '中',
                                                                      '右'
                                                                    ].contains(
                                                                        pos)));
                                                            if (!isInvalid) {
                                                              grandTotal +=
                                                                  value;
                                                            }
                                                          }
                                                        }
                                                        return Row(
                                                          children: [
                                                            ...resultTypes
                                                                .map((result) {
                                                              int total = 0;
                                                              for (final pos
                                                                  in positionOrder) {
                                                                final value =
                                                                    hitDirectionDetails[pos]
                                                                            ?[
                                                                            result] ??
                                                                        0;
                                                                final isInvalid = (([
                                                                          '単打',
                                                                          '二塁打',
                                                                          '三塁打',
                                                                          '本塁打',
                                                                          '犠飛'
                                                                        ].contains(
                                                                            result) &&
                                                                        [
                                                                          '投',
                                                                          '捕',
                                                                          '一',
                                                                          '二',
                                                                          '三',
                                                                          '遊'
                                                                        ].contains(
                                                                            pos)) ||
                                                                    ([
                                                                          '犠打',
                                                                          '内野安打'
                                                                        ].contains(
                                                                            result) &&
                                                                        [
                                                                          '左',
                                                                          '中',
                                                                          '右'
                                                                        ].contains(
                                                                            pos)));
                                                                if (!isInvalid) {
                                                                  total +=
                                                                      value;
                                                                }
                                                              }
                                                              return Container(
                                                                width:
                                                                    cellWidth,
                                                                height:
                                                                    rowHeight,
                                                                alignment:
                                                                    Alignment
                                                                        .center,
                                                                decoration:
                                                                    BoxDecoration(
                                                                  border: Border.all(
                                                                      color: Colors
                                                                          .grey
                                                                          .shade300),
                                                                ),
                                                                child: Text(
                                                                  '$total',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Colors
                                                                        .deepOrange,
                                                                  ),
                                                                ),
                                                              );
                                                            }),
                                                            // grandTotal cell
                                                            Container(
                                                              width: cellWidth,
                                                              height: rowHeight,
                                                              alignment:
                                                                  Alignment
                                                                      .center,
                                                              decoration:
                                                                  BoxDecoration(
                                                                border: Border.all(
                                                                    color: Colors
                                                                        .grey
                                                                        .shade300),
                                                              ),
                                                              child: Text(
                                                                '$grandTotal',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .deepOrange,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  @override
  void didUpdateWidget(BattedBallDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPeriodFilter != oldWidget.selectedPeriodFilter ||
        widget.selectedGameTypeFilter != oldWidget.selectedGameTypeFilter ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      fetchHitDirectionData();
    }
  }
}
