import 'package:b_net/pages/private/goal_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalType { hits, scores, custom }

class MissionPage extends StatefulWidget {
  final String userUid;

  const MissionPage({Key? key, required this.userUid}) : super(key: key);

  @override
  _MissionPageState createState() => _MissionPageState();
}

enum CompareTypeOption { greater, less }

class _MissionPageState extends State<MissionPage> {
  CompareTypeOption? _compareTypeMonth;
  CompareTypeOption? _compareTypeYear;
  final TextEditingController _targetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSelectedCompareTypes();
  }

  Future<void> _initSelectedCompareTypes() async {
    // 月
    final now = DateTime.now();
    final monthKey =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString()}";
    final monthSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('goals')
        .where('period', isEqualTo: 'month')
        .where('month', isEqualTo: monthKey)
        .get();
    if (monthSnapshot.docs.isNotEmpty) {
      final doc = monthSnapshot.docs.first;
      final data = doc.data();
      if (data.containsKey('compareType')) {
        setState(() {
          _compareTypeMonth = data['compareType'] == 'less'
              ? CompareTypeOption.less
              : CompareTypeOption.greater;
        });
      }
    }
    // 年
    final yearSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('goals')
        .where('period', isEqualTo: 'year')
        .where('year', isEqualTo: now.year)
        .get();
    if (yearSnapshot.docs.isNotEmpty) {
      final doc = yearSnapshot.docs.first;
      final data = doc.data();
      if (data.containsKey('compareType')) {
        setState(() {
          _compareTypeYear = data['compareType'] == 'less'
              ? CompareTypeOption.less
              : CompareTypeOption.greater;
        });
      }
    }
  }

  void _updateCompareType(String period, CompareTypeOption value) {
    final now = DateTime.now();
    final dateKey = period == 'month'
        ? '${now.year.toString().padLeft(4, '0')}-${now.month.toString()}'
        : now.year.toString();
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('goals')
        .where('period', isEqualTo: period)
        .where(period == 'month' ? 'month' : 'year', isEqualTo: dateKey);
    query.get().then((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final goal = snapshot.docs.first;
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userUid)
            .collection('goals')
            .doc(goal.id)
            .update({'compareType': value.name});
      }
    });
  }

  DateTime get selectedEndDate {
    return DateTime(DateTime.now().year, 12, 31, 23, 59, 59);
  }

  bool get periodEnded {
    final now = DateTime.now();
    return now.isAfter(selectedEndDate);
  }

  bool get _isCustomYearGoal => _selectedYearStatField == 'custom';

  bool get _isCustomMonthGoal => _selectedMonthStatField == 'custom';

  /// Auto-save expired goals with debugging output.
  Future<void> _autoSaveExpiredGoals() async {
    // No-op: auto-save logic removed as per requirements.
    return;
  }

  // Firestoreから指定フィールドの今年の値を取得
  Future<int> _calculateActual(dynamic type, dynamic field) async {
    final year = DateTime.now().year;
    final statsDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('stats')
        .doc('results_stats_${year}_all')
        .get();

    if (statsDoc.exists) {
      final stats = statsDoc.data() ?? {};
      final raw = stats[field];
      return raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
    }
    return 0;
  }

  final TextEditingController _yearTitleController = TextEditingController();
  final TextEditingController _yearValueController = TextEditingController();
  final TextEditingController _monthValueController = TextEditingController();
  final TextEditingController _monthTitleController = TextEditingController();
  final TextEditingController _yearCustomController = TextEditingController();
  final TextEditingController _monthCustomController = TextEditingController();
  String? _selectedYearStatField;
  String? _selectedMonthStatField;
  String? _selectedYearCategory;
  String? _selectedMonthCategory;

  final Map<String, Map<String, String>> categorizedStatFieldOptions = {
    '試合': {
      '試合数': 'totalGames',
      '得点': 'totalScore',
      '失点': 'totalRunsAllowed',
      '勝ち数': 'totalWins',
      '負け数': 'totalLosses',
      '勝率': 'winRate',
    },
    '打撃': {
      '打率': 'battingAverage',
      'ヒット数': 'hits',
      'ホームラン数': 'totalHomeRuns',
      '四球数': 'totalFourBalls',
      '三振数': 'totalStrikeouts',
      'バント成功数': 'totalAllBuntSuccess',
      '盗塁数': 'totalSteals',
      '打点': 'totalRbis',
      '出塁率': 'onBasePercentage',
      '長打率': 'sluggingPercentage',
      '二塁打以上': 'total2hits + total3hits + totalHomeRuns',
      '球数（打者）': 'batterPitchCount',
    },
    '守備': {
      'エラー': 'totalPutouts + totalAssists + totalErrors',
      '盗塁刺': 'totalCaughtStealing',
    },
    '投手': {
      '奪三振（投手）': 'totalPStrikeouts',
      '与四球': 'totalWalks',
      '与死球': 'totalHitByPitch',
      '自責点': 'totalEarnedRuns',
      '被安打': 'totalHitsAllowed',
      '勝利': 'totalWins',
      '敗北': 'totalLosses',
      '球数（投手）': 'totalPitchCount',
      '防御率': 'era',
    },
    '自由に決める': {
      '自由に決める': 'custom',
    }
  };

  void _showDualCupertinoPicker({
    required BuildContext context,
    required List<String> leftOptions,
    required Map<String, List<String>> rightOptionsMap,
    String? selectedLeftValue,
    String? selectedRightValue,
    required Function(String, String) onSelected,
  }) {
    int leftIndex =
        selectedLeftValue != null ? leftOptions.indexOf(selectedLeftValue) : 0;
    String currentLeft = selectedLeftValue ?? leftOptions[0];

    List<String> rightOptions = rightOptionsMap[currentLeft] ?? [];
    int rightIndex =
        selectedRightValue != null && rightOptions.contains(selectedRightValue)
            ? rightOptions.indexOf(selectedRightValue)
            : 0;
    String currentRight =
        rightOptions.isNotEmpty ? rightOptions[rightIndex] : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // FocusScope.of(context).unfocus(); // Removed for picker close
                        },
                        child:
                            const Text('キャンセル', style: TextStyle(fontSize: 16)),
                      ),
                      const Text('選択してください',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton(
                        onPressed: () {
                          onSelected(currentLeft, currentRight);
                          Navigator.pop(context);
                          // FocusScope.of(context).unfocus(); // Removed for picker close
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
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                              initialItem: leftIndex),
                          itemExtent: 40.0,
                          onSelectedItemChanged: (int index) {
                            setState(() {
                              currentLeft = leftOptions[index];
                              rightOptions = rightOptionsMap[currentLeft] ?? [];
                              currentRight = rightOptions.isNotEmpty
                                  ? rightOptions[0]
                                  : '';
                            });
                          },
                          children: leftOptions
                              .map((option) => Center(child: Text(option)))
                              .toList(),
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                              initialItem: rightIndex),
                          itemExtent: 40.0,
                          onSelectedItemChanged: (int index) {
                            setState(() {
                              currentRight = rightOptions[index];
                            });
                          },
                          children: rightOptions
                              .map((option) => Center(child: Text(option)))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _saveYearMission() async {
    // バリデーション: タイトル・指標・カテゴリ必須
    if (_yearTitleController.text.isEmpty ||
        _selectedYearStatField == null ||
        _selectedYearCategory == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('全ての項目を入力してください')));
      return;
    }
    // バリデーション: 目標数値必須（自由に決める以外）
    if (_selectedYearStatField != 'custom' &&
        _yearValueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目標数値を入力してください')),
      );
      return;
    }
    // 「自由に決める」選択時はTextField未入力でもOK

    final goalId = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('goals')
        .doc()
        .id;

    // Handle value parsing for ratio and normal fields
    String input = _yearValueController.text.trim();
    String correctedInput = input;

    // Ratio-based fields use double, others use int
    const ratioStatFields = [
      'battingAverage',
      'onBasePercentage',
      'sluggingPercentage',
      'winRate',
      'era',
    ];
    bool isRatioGoal = _selectedYearStatField != null &&
        ratioStatFields.contains(_selectedYearStatField);

    // Enhanced ratio input correction
    if (isRatioGoal) {
      if (correctedInput.startsWith('.')) {
        correctedInput = '0$correctedInput';
      } else if (!correctedInput.contains('.')) {
        final numeric = double.tryParse(correctedInput);
        if (numeric != null) {
          if (numeric < 10) {
            correctedInput = (numeric / 10).toStringAsFixed(3); // 3 → 0.300
          } else {
            correctedInput = (numeric / 100).toStringAsFixed(3); // 30 → 0.300
          }
        }
      }
    }

    final parsedTarget = isRatioGoal
        ? double.tryParse(correctedInput)
        : int.tryParse(correctedInput);
    if (_selectedYearStatField != 'custom' && parsedTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数値だけを入力してください')),
      );
      return;
    }
    num targetValue = parsedTarget ?? 0;

    final now = DateTime.now();
    final data = {
      'title': _yearTitleController.text,
      'statField': _selectedYearStatField,
      'category': _selectedYearCategory,
      'period': 'year',
      'createdAt': Timestamp.now(),
      'year': now.year,
      'update': _selectedYearStatField == 'custom' ? true : false,
      if (isRatioGoal) 'isRatio': true,
      if (_selectedYearStatField == 'custom')
        'customText': _yearCustomController.text,
    };
    if (_selectedYearStatField != 'custom') {
      data.addAll({
        'target': targetValue,
        'endDate': Timestamp.fromDate(
            DateTime(DateTime.now().year, 12, 31, 23, 59, 59)),
        'compareType': _compareTypeYear?.name ?? 'greater',
      });
    }
    // Add isAchieved=false for custom year goal
    if (_selectedYearStatField == "custom") {
      data['isAchieved'] = false;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('goals')
        .doc(goalId)
        .set(data);
    setState(() {});
  }

  void _saveMonthMission() async {
    // バリデーション: タイトル・指標・カテゴリ必須
    if (_monthTitleController.text.isEmpty ||
        _selectedMonthStatField == null ||
        _selectedMonthCategory == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('全ての項目を入力してください')));
      return;
    }
    // バリデーション: 目標数値必須（自由に決める以外）
    if (_selectedMonthStatField != 'custom' &&
        _monthValueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目標数値を入力してください')),
      );
      return;
    }
    // 「自由に決める」選択時はTextField未入力でもOK

    final goalId = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('goals')
        .doc()
        .id;

    // Handle value parsing for ratio and normal fields
    String input = _monthValueController.text.trim();
    String correctedInput = input;

    // Ratio-based fields use double, others use int
    const ratioStatFields = [
      'battingAverage',
      'onBasePercentage',
      'sluggingPercentage',
      'winRate',
      'era',
    ];
    bool isRatioGoal = _selectedMonthStatField != null &&
        ratioStatFields.contains(_selectedMonthStatField);

    // Enhanced ratio input correction
    if (isRatioGoal) {
      if (correctedInput.startsWith('.')) {
        correctedInput = '0$correctedInput';
      } else if (!correctedInput.contains('.')) {
        final numeric = double.tryParse(correctedInput);
        if (numeric != null) {
          if (numeric < 10) {
            correctedInput = (numeric / 10).toStringAsFixed(3); // 3 → 0.300
          } else {
            correctedInput = (numeric / 100).toStringAsFixed(3); // 30 → 0.300
          }
        }
      }
    }

    final parsedTarget = isRatioGoal
        ? double.tryParse(correctedInput)
        : int.tryParse(correctedInput);
    if (_selectedMonthStatField != 'custom' && parsedTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数値だけを入力してください')),
      );
      return;
    }
    num targetValue = parsedTarget ?? 0;

    final now = DateTime.now();
    final data = {
      'title': _monthTitleController.text,
      'statField': _selectedMonthStatField,
      'category': _selectedMonthCategory,
      'period': 'month',
      'createdAt': Timestamp.now(),
      'month': "${now.year.toString().padLeft(4, '0')}-${now.month.toString()}",
      'update': _selectedMonthStatField == 'custom' ? true : false,
      if (isRatioGoal) 'isRatio': true,
      if (_selectedMonthStatField == 'custom')
        'customText': _monthCustomController.text,
    };
    if (_selectedMonthStatField != 'custom') {
      data.addAll({
        'target': targetValue,
        'endDate': Timestamp.fromDate(DateTime(
            DateTime.now().year, DateTime.now().month + 1, 0, 23, 59, 59)),
        'compareType': _compareTypeMonth?.name ?? 'greater',
      });
    }
    // Add isAchieved=false for custom month goal
    if (_selectedMonthStatField == "custom") {
      data['isAchieved'] = false;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('goals')
        .doc(goalId)
        .set(data);
    setState(() {});
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チーム目標'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 今年の目標をFirestoreから取得して表示
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.userUid)
                    .collection('goals')
                    .where('period', isEqualTo: 'year')
                    .where('year', isEqualTo: DateTime.now().year)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // --- 自動保存処理ロジックは削除されました ---
                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    // 目標が未設定ならフォームを表示
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('今年の目標',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          const Text('目標タイトル'),
                          TextField(
                            controller: _yearTitleController,
                            decoration: const InputDecoration(
                                hintText: '例: ヒット100本以上！'),
                          ),
                          const SizedBox(height: 16),
                          const Text('達成指標'),
                          GestureDetector(
                            onTap: () {
                              final leftOptions =
                                  categorizedStatFieldOptions.keys.toList();
                              final rightOptionsMap = <String, List<String>>{};
                              categorizedStatFieldOptions.forEach((cat, map) {
                                rightOptionsMap[cat] = map.keys.toList();
                              });
                              String? selectedLeft;
                              String? selectedRight;
                              if (_selectedYearCategory != null) {
                                selectedLeft = _selectedYearCategory;
                                if (_selectedYearStatField != null) {
                                  final entries = categorizedStatFieldOptions[
                                          _selectedYearCategory!]!
                                      .entries
                                      .toList();
                                  final entry = entries.firstWhere(
                                    (e) => e.value == _selectedYearStatField,
                                    orElse: () => entries[0],
                                  );
                                  selectedRight = entry.key;
                                }
                              }
                              _showDualCupertinoPicker(
                                context: context,
                                leftOptions: leftOptions,
                                rightOptionsMap: rightOptionsMap,
                                selectedLeftValue: selectedLeft,
                                selectedRightValue: selectedRight,
                                onSelected: (cat, item) {
                                  setState(() {
                                    _selectedYearCategory = cat;
                                    if (categorizedStatFieldOptions[cat] !=
                                            null &&
                                        categorizedStatFieldOptions[cat]!
                                            .containsKey(item)) {
                                      _selectedYearStatField =
                                          categorizedStatFieldOptions[cat]![
                                              item];
                                    } else {
                                      _selectedYearStatField = null;
                                    }
                                  });
                                },
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    (_selectedYearCategory == null ||
                                            _selectedYearStatField == null)
                                        ? '選択してください'
                                        : '${_selectedYearCategory!} / ${categorizedStatFieldOptions[_selectedYearCategory!]!.entries.firstWhere((e) => e.value == _selectedYearStatField, orElse: () => MapEntry("選択してください", "")).key}',
                                    style: TextStyle(
                                      color: (_selectedYearCategory == null ||
                                              _selectedYearStatField == null)
                                          ? Colors.grey
                                          : Colors.black,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!_isCustomYearGoal)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: TextField(
                                controller: _yearValueController,
                                decoration: InputDecoration(
                                  labelText: '目標数値を入力',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          if (!_isCustomYearGoal)
                            Row(
                              children: [
                                Radio<CompareTypeOption>(
                                  value: CompareTypeOption.greater,
                                  groupValue: _compareTypeYear,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _compareTypeYear = val;
                                      });
                                      _updateCompareType('year', val);
                                    }
                                  },
                                ),
                                const Text('以上'),
                                SizedBox(width: 16),
                                Radio<CompareTypeOption>(
                                  value: CompareTypeOption.less,
                                  groupValue: _compareTypeYear,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _compareTypeYear = val;
                                      });
                                      _updateCompareType('year', val);
                                    }
                                  },
                                ),
                                const Text('以下'),
                              ],
                            ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton(
                              onPressed: _saveYearMission,
                              child: const Text('今年の目標を保存'),
                            ),
                          )
                        ],
                      ),
                    );
                  }
                  // 目標が存在する場合は表示のみ
                  final goal = snapshot.data!.docs.first;
                  final goalData = goal.data() as Map<String, dynamic>;
                  final title = goalData['title'] ?? '';
                  final goalTarget = goalData['target'] ?? 0;
                  final statField = goalData['statField'];
                  final isRatio = goalData.containsKey('isRatio')
                      ? goalData['isRatio']
                      : false;
                  // ignore: unused_local_variable
                  final period = goalData['period'];

                  // カスタム目標の場合
                  if (statField == 'custom') {
                    final isAchieved = goalData['isAchieved'] ?? false;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            border: Border(
                                bottom:
                                    BorderSide(color: Colors.amber, width: 3)),
                          ),
                          child: const Text('今年の目標',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  '$title',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (goal['statField'] == 'custom' &&
                                      isAchieved == false) ...[
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final goalRef = FirebaseFirestore
                                            .instance
                                            .collection("users")
                                            .doc(widget.userUid)
                                            .collection("goals")
                                            .doc(goal.id);
                                        try {
                                          await goalRef
                                              .update({'isAchieved': true});
                                          setState(() {});
                                        } catch (e) {
                                          print(
                                              'Error updating isAchieved: $e');
                                        }
                                      },
                                      icon: const Icon(
                                          Icons.check_circle_outline),
                                      label: const Text('目標を達成した！'),
                                    ),
                                  ],
                                ],
                              ),
                              if (isAchieved ?? false) ...[
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.auto_awesome,
                                        color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('目標達成！',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  // 直接Firestoreの値を利用して表示（static current/target/percentage）
                  final current = (goalData.containsKey('actualValue') &&
                          goalData['actualValue'] is num)
                      ? goalData['actualValue']
                      : 0;
                  final percentage = (goalData.containsKey('achievementRate') &&
                          goalData['achievementRate'] is num)
                      ? (goalData['achievementRate'] as num)
                          .toStringAsFixed(1)
                          .replaceFirst(RegExp(r'\.0$'), '')
                      : '0';
                  final hideStats =
                      isRatio && !(goalData['period'] == 'year' ? false : true);
                  final isAchieved = goalData['isAchieved'] ?? false;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: Colors.amber, width: 3)),
                        ),
                        child: const Text('今年の目標',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                '$title',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (isRatio == true) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    '実績：${statField == 'era' ? formatPercentageEra(current) : formatPercentage(current)}',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ] else ...[
                              if (statField != null &&
                                  statField != 'custom' &&
                                  !hideStats) ...[
                                if (goalData['compareType'] == 'less') ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_circle,
                                          color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        '実績：$current / $goalTarget',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle,
                                              color: Colors.green, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            '実績：$current / $goalTarget',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                                color: Colors.blueAccent,
                                                width: 2),
                                          ),
                                        ),
                                        child: Text(
                                          '達成率：${percentage}%',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ] else if (hideStats)
                                const SizedBox.shrink()
                              else
                                const Text('達成率：- %',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              // --- Achieved UI and Button Logic for Year Goal ---
                              if (isAchieved ?? false) ...[
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.auto_awesome,
                                        color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('目標達成！',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green)),
                                  ],
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // 今月の目標をFirestoreから取得して表示
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userUid)
                  .collection('goals')
                  .where('period', isEqualTo: 'month')
                  .where(
                    'month',
                    isEqualTo:
                        "${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString()}",
                  )
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  // 目標が未設定ならフォームを表示
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('今月の目標',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        const Text('目標タイトル'),
                        TextField(
                          controller: _monthTitleController,
                          decoration: const InputDecoration(
                            hintText: '例: 四球数10以下！',
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('達成指標'),
                        GestureDetector(
                          onTap: () {
                            final leftOptions =
                                categorizedStatFieldOptions.keys.toList();
                            final rightOptionsMap = <String, List<String>>{};
                            categorizedStatFieldOptions.forEach((cat, map) {
                              rightOptionsMap[cat] = map.keys.toList();
                            });
                            String? selectedLeft;
                            String? selectedRight;
                            if (_selectedMonthCategory != null) {
                              selectedLeft = _selectedMonthCategory;
                              if (_selectedMonthStatField != null) {
                                final entries = categorizedStatFieldOptions[
                                        _selectedMonthCategory!]!
                                    .entries
                                    .toList();
                                final entry = entries.firstWhere(
                                  (e) => e.value == _selectedMonthStatField,
                                  orElse: () => entries[0],
                                );
                                selectedRight = entry.key;
                              }
                            }
                            _showDualCupertinoPicker(
                              context: context,
                              leftOptions: leftOptions,
                              rightOptionsMap: rightOptionsMap,
                              selectedLeftValue: selectedLeft,
                              selectedRightValue: selectedRight,
                              onSelected: (cat, item) {
                                setState(() {
                                  _selectedMonthCategory = cat;
                                  if (categorizedStatFieldOptions[cat] !=
                                          null &&
                                      categorizedStatFieldOptions[cat]!
                                          .containsKey(item)) {
                                    _selectedMonthStatField =
                                        categorizedStatFieldOptions[cat]![item];
                                  } else {
                                    _selectedMonthStatField = null;
                                  }
                                });
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  (_selectedMonthCategory == null ||
                                          _selectedMonthStatField == null)
                                      ? '選択してください'
                                      : '${_selectedMonthCategory!} / ${categorizedStatFieldOptions[_selectedMonthCategory!]!.entries.firstWhere((e) => e.value == _selectedMonthStatField, orElse: () => MapEntry("選択してください", "")).key}',
                                  style: TextStyle(
                                    color: (_selectedMonthCategory == null ||
                                            _selectedMonthStatField == null)
                                        ? Colors.grey
                                        : Colors.black,
                                    fontSize: 14,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!_isCustomMonthGoal)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: TextField(
                              controller: _monthValueController,
                              decoration: const InputDecoration(
                                labelText: '目標数値',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        if (!_isCustomMonthGoal)
                          Row(
                            children: [
                              Radio<CompareTypeOption>(
                                value: CompareTypeOption.greater,
                                groupValue: _compareTypeMonth,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _compareTypeMonth = val;
                                    });
                                    _updateCompareType('month', val);
                                  }
                                },
                              ),
                              const Text('以上'),
                              SizedBox(width: 16),
                              Radio<CompareTypeOption>(
                                value: CompareTypeOption.less,
                                groupValue: _compareTypeMonth,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _compareTypeMonth = val;
                                    });
                                    _updateCompareType('month', val);
                                  }
                                },
                              ),
                              const Text('以下'),
                            ],
                          ),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton(
                            onPressed: _saveMonthMission,
                            child: const Text('今月の目標を保存'),
                          ),
                        )
                      ],
                    ),
                  );
                }
                // 目標が存在する場合は表示のみ
                final goal = snapshot.data!.docs.first;
                final goalData = goal.data() as Map<String, dynamic>;
                final title = goalData['title'] ?? '';
                final goalTarget = goalData['target'] ?? 0;
                final statField = goalData['statField'];
                final isRatio = goalData.containsKey('isRatio')
                    ? goalData['isRatio']
                    : false;
                // カスタム目標の場合
                if (statField == 'custom') {
                  final isAchieved = goalData['isAchieved'] ?? false;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: Colors.amber, width: 3)),
                        ),
                        child: const Text('今月の目標',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                '$title',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (goal['statField'] == 'custom' &&
                                isAchieved == false) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final goalRef = FirebaseFirestore.instance
                                          .collection("users")
                                          .doc(widget.userUid)
                                          .collection("goals")
                                          .doc(goal.id);
                                      try {
                                        await goalRef
                                            .update({'isAchieved': true});
                                        setState(() {});
                                      } catch (e) {
                                        print('Error updating isAchieved: $e');
                                      }
                                    },
                                    icon:
                                        const Icon(Icons.check_circle_outline),
                                    label: const Text('目標を達成した！'),
                                  ),
                                ],
                              ),
                            ],
                            if (isAchieved ?? false) ...[
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.auto_awesome,
                                      color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('目標達成！',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }
                // 直接Firestoreの値を利用して表示（static current/target/percentage）
                final current = (goalData.containsKey('actualValue') &&
                        goalData['actualValue'] is num)
                    ? goalData['actualValue']
                    : 0;
                final percentage = (goalData.containsKey('achievementRate') &&
                        goalData['achievementRate'] is num)
                    ? (goalData['achievementRate'] as num)
                        .toStringAsFixed(1)
                        .replaceFirst(RegExp(r'\.0$'), '')
                    : '0';
                // final hideStats =
                //     isRatio && !(goalData['period'] == 'month' ? false : true);
                final isAchieved = goalData['isAchieved'] ?? false;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: Colors.amber, width: 3)),
                      ),
                      child: const Text('今月の目標',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              '$title',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // --- Unified display for 'less' and isRatio ---
                          if ((goalData['compareType'] == 'less') ||
                              isRatio == true) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  isRatio == true
                                      ? '実績：${statField == 'era' ? formatPercentageEra(current) : formatPercentage(current)}'
                                      : '実績：$current / $goalTarget',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        color: Colors.green, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      '実績：$current / $goalTarget',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                Container(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                          color: Colors.blueAccent, width: 2),
                                    ),
                                  ),
                                  child: Text(
                                    '達成率：${percentage}%',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (isAchieved ?? false) ...[
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.auto_awesome, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('目標達成！',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            // 目標リストページへの遷移ボタン
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    // 目標一覧ページへの遷移など
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => GoalListPage(
                                userUid: widget.userUid,
                              )),
                    );
                  },
                  child: const Text(
                    '目標一覧を見る',
                    style: TextStyle(
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
