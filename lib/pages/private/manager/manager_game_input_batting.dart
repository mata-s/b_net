import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerGameInputBatting extends StatefulWidget {
  final int matchIndex;
  final String userUid;
  final String teamId;
  final List<Map<String, dynamic>> members;

  const ManagerGameInputBatting({
    Key? key,
    required this.matchIndex,
    required this.userUid,
    required this.teamId,
    required this.members,
  }) : super(key: key);

  @override
  State<ManagerGameInputBatting> createState() =>
      _ManagerGameInputBattingState();
}

class _ManagerGameInputBattingState extends State<ManagerGameInputBatting> {
  // 打席ごとの詳細入力データ
  List<List<String?>> _selectedLeftList = List.generate(
    9,
    (_) => List.filled(10, null),
  );

  List<List<String?>> _selectedRightList = List.generate(
    9,
    (_) => List.filled(10, null),
  );

  List<List<String?>> _selectedBuntDetail = List.generate(
    9,
    (_) => List.filled(10, null),
  );

  List<List<TextEditingController>> _swingControllers = List.generate(
    9,
    (_) => List.generate(10, (_) => TextEditingController(text: '0')),
  );

  List<List<TextEditingController>> _missSwingControllers = List.generate(
    9,
    (_) => List.generate(10, (_) => TextEditingController(text: '0')),
  );
  // 9打順 (0〜8) × 最大10打席分を想定
  List<List<TextEditingController>> _batterPitchCountControllers =
      List.generate(
    9,
    (_) => List.generate(10, (_) => TextEditingController(text: '0')),
  );

  List<List<bool>> _firstPitchSwingFlags = List.generate(
    9,
    (_) => List.generate(10, (_) => false),
  );

  // --- Add per-at-bat controllers for 追加打撃情報 ---
  List<List<TextEditingController>> _rbisControllers = List.generate(
    9,
    (_) => List.generate(10, (_) => TextEditingController(text: '0')),
  );
  List<List<TextEditingController>> _runsControllers = List.generate(
    9,
    (_) => List.generate(10, (_) => TextEditingController(text: '0')),
  );
  List<List<TextEditingController>> _stealsAttemptsControllers = List.generate(
    9,
    (_) => List.generate(10, (_) => TextEditingController(text: '0')),
  );
  List<List<TextEditingController>> _stealsControllers = List.generate(
    9,
    (_) => List.generate(10, (_) => TextEditingController(text: '0')),
  );
  List<List<TextEditingController>> _caughtStealingByRunnerControllers =
      List.generate(
    9,
    (_) => List.generate(10, (_) => TextEditingController(text: '0')),
  );
  // List to keep track of assigned members for each batting order slot (9 slots)
  List<Map<String, dynamic>?> battingOrderMembers = List.filled(9, null);
  List<int> atBatList = List.filled(9, 0);
  int? selectedIndex;

  Set<int> _expandedAtBatIndexes = {};

  @override
  void initState() {
    super.initState();
    _loadBattingOrder();
    _loadFormData();
  }

  Future<void> _saveFormData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
        'atBatList_${widget.matchIndex}', atBatList.join(','));

    for (int i = 0; i < 9; i++) {
      await prefs.setString(
          'selectedLeft_$i', jsonEncode(_selectedLeftList[i]));
      await prefs.setString(
          'selectedRight_$i', jsonEncode(_selectedRightList[i]));
      await prefs.setString(
          'buntDetail_$i', jsonEncode(_selectedBuntDetail[i]));
      await prefs.setString('swing_$i',
          jsonEncode(_swingControllers[i].map((c) => c.text).toList()));
      await prefs.setString('missSwing_$i',
          jsonEncode(_missSwingControllers[i].map((c) => c.text).toList()));
      await prefs.setString(
          'pitchCount_$i',
          jsonEncode(
              _batterPitchCountControllers[i].map((c) => c.text).toList()));
      await prefs.setString(
          'firstPitch_$i', jsonEncode(_firstPitchSwingFlags[i]));
      // Save additional batting info controllers
      await prefs.setString('rbis_$i',
          jsonEncode(_rbisControllers[i].map((c) => c.text).toList()));
      await prefs.setString('runs_$i',
          jsonEncode(_runsControllers[i].map((c) => c.text).toList()));
      await prefs.setString(
          'stealsAttempts_$i',
          jsonEncode(
              _stealsAttemptsControllers[i].map((c) => c.text).toList()));
      await prefs.setString('steals_$i',
          jsonEncode(_stealsControllers[i].map((c) => c.text).toList()));
      await prefs.setString(
          'caughtStealingByRunner_$i',
          jsonEncode(_caughtStealingByRunnerControllers[i]
              .map((c) => c.text)
              .toList()));
    }
  }

  Future<void> _loadFormData() async {
    final prefs = await SharedPreferences.getInstance();

    final atBatRaw = prefs.getString('atBatList_${widget.matchIndex}');
    if (atBatRaw != null) {
      setState(() {
        atBatList =
            atBatRaw.split(',').map((e) => int.tryParse(e) ?? 0).toList();
      });
    }

    for (int i = 0; i < 9; i++) {
      final left = prefs.getString('selectedLeft_$i');
      final right = prefs.getString('selectedRight_$i');
      final bunt = prefs.getString('buntDetail_$i');
      final swing = prefs.getString('swing_$i');
      final miss = prefs.getString('missSwing_$i');
      final pitch = prefs.getString('pitchCount_$i');
      final first = prefs.getString('firstPitch_$i');
      // Additional batting info
      final rbis = prefs.getString('rbis_$i');
      final runs = prefs.getString('runs_$i');
      final stealsAttempts = prefs.getString('stealsAttempts_$i');
      final steals = prefs.getString('steals_$i');
      final caughtStealingByRunner =
          prefs.getString('caughtStealingByRunner_$i');

      if (left != null)
        _selectedLeftList[i] = List<String?>.from(jsonDecode(left));
      if (right != null)
        _selectedRightList[i] = List<String?>.from(jsonDecode(right));
      if (bunt != null)
        _selectedBuntDetail[i] = List<String?>.from(jsonDecode(bunt));
      if (swing != null) {
        final values = List<String>.from(jsonDecode(swing));
        for (int j = 0; j < values.length; j++) {
          _swingControllers[i][j].text = values[j];
        }
      }
      if (miss != null) {
        final values = List<String>.from(jsonDecode(miss));
        for (int j = 0; j < values.length; j++) {
          _missSwingControllers[i][j].text = values[j];
        }
      }
      if (pitch != null) {
        final values = List<String>.from(jsonDecode(pitch));
        for (int j = 0; j < values.length; j++) {
          _batterPitchCountControllers[i][j].text = values[j];
        }
      }
      if (first != null)
        _firstPitchSwingFlags[i] = List<bool>.from(jsonDecode(first));
      // Load additional batting info
      if (rbis != null) {
        final values = List<String>.from(jsonDecode(rbis));
        for (int j = 0; j < values.length; j++) {
          _rbisControllers[i][j].text = values[j];
        }
      }
      if (runs != null) {
        final values = List<String>.from(jsonDecode(runs));
        for (int j = 0; j < values.length; j++) {
          _runsControllers[i][j].text = values[j];
        }
      }
      if (stealsAttempts != null) {
        final values = List<String>.from(jsonDecode(stealsAttempts));
        for (int j = 0; j < values.length; j++) {
          _stealsAttemptsControllers[i][j].text = values[j];
        }
      }
      if (steals != null) {
        final values = List<String>.from(jsonDecode(steals));
        for (int j = 0; j < values.length; j++) {
          _stealsControllers[i][j].text = values[j];
        }
      }
      if (caughtStealingByRunner != null) {
        final values = List<String>.from(jsonDecode(caughtStealingByRunner));
        for (int j = 0; j < values.length; j++) {
          _caughtStealingByRunnerControllers[i][j].text = values[j];
        }
      }
    }

    setState(() {});
  }

  Future<void> _saveBattingOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> uids =
        battingOrderMembers.map((e) => (e?['uid'] ?? '').toString()).toList();
    await prefs.setStringList('batting_order_${widget.matchIndex}', uids);
  }

  Future<void> _loadBattingOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUids = prefs.getStringList('batting_order_${widget.matchIndex}');
    if (savedUids == null) return;

    setState(() {
      for (int i = 0;
          i < savedUids.length && i < battingOrderMembers.length;
          i++) {
        final uid = savedUids[i];
        if (uid.isEmpty) {
          battingOrderMembers[i] = null;
        } else {
          final member = widget.members
              .firstWhere((m) => m['uid'] == uid, orElse: () => {});
          if (member.isNotEmpty) {
            battingOrderMembers[i] = member;
          }
        }
      }
    });
  }

  final Map<String, List<String>> _rightOptions = {
    '打': ['四球', '死球', '見逃し三振', '空振り三振', '振り逃げ', 'スリーバント失敗', '打撃妨害', '守備妨害'],
    '投': [
      'ゴロ',
      'ライナー',
      'フライ',
      '内野安打',
      '犠打',
      '失策出塁',
      '併殺',
    ],
    '捕': ['ゴロ', 'フライ', '内野安打', '犠打', '失策出塁', '併殺'],
    '一': ['ゴロ', 'ライナー', 'フライ', '内野安打', '犠打', '失策出塁', '併殺'],
    '二': ['ゴロ', 'ライナー', 'フライ', '内野安打', '犠打', '失策出塁', '併殺'],
    '三': [
      'ゴロ',
      'ライナー',
      'フライ',
      '内野安打',
      '犠打',
      '失策出塁',
      '併殺',
    ],
    '遊': ['ゴロ', 'ライナー', 'フライ', '内野安打', '犠打', '失策出塁', '併殺'],
    '左': ['ライナー', 'フライ', '単打', '二塁打', '三塁打', '本塁打', '犠飛', '失策出塁'],
    '中': ['ライナー', 'フライ', '単打', '二塁打', '三塁打', '本塁打', '犠飛', '失策出塁'],
    '右': ['ライナー', 'フライ', '単打', '二塁打', '三塁打', '本塁打', '犠飛', '失策出塁'],
  };

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
                      onSelected(tempSelected);
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

  Widget buildCounterField({
    required String label,
    required TextEditingController controller,
    int? index,
    bool readOnly = true,
    void Function()? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 20),
              onPressed: () {
                final current = int.tryParse(controller.text) ?? 0;
                if (current > 0) {
                  controller.text = (current - 1).toString();
                  if (onChanged != null) onChanged();
                  // 追加: 値が変わったら保存
                  _saveFormData();
                }
              },
            ),
            Expanded(
              child: TextField(
                controller: controller,
                readOnly: readOnly,
                showCursor: !readOnly,
                focusNode: readOnly
                    ? FocusNode(skipTraversal: true, canRequestFocus: false)
                    : null,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: (_) {
                  if (onChanged != null) onChanged();
                  // 追加: 値が変わったら保存
                  _saveFormData();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: () {
                final current = int.tryParse(controller.text) ?? 0;
                controller.text = (current + 1).toString();
                if (onChanged != null) onChanged();
                // 追加: 値が変わったら保存
                _saveFormData();
              },
            ),
          ],
        ),
      ],
    );
  }

  // --- 入力UI再利用のための打席入力ウィジェット ---
  Widget buildAtBatInput(int matchIndex, int i, VoidCallback onClose) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${i + 1}打席目',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.edit_note),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('追加打撃情報'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildCounterField(
                          label: '打点',
                          controller: _rbisControllers[matchIndex][i],
                        ),
                        const SizedBox(height: 12),
                        buildCounterField(
                          label: '得点',
                          controller: _runsControllers[matchIndex][i],
                        ),
                        const SizedBox(height: 12),
                        buildCounterField(
                          label: '盗塁企図数',
                          controller: _stealsAttemptsControllers[matchIndex][i],
                        ),
                        const SizedBox(height: 12),
                        buildCounterField(
                          label: '盗塁成功',
                          controller: _stealsControllers[matchIndex][i],
                        ),
                        const SizedBox(height: 12),
                        buildCounterField(
                          label: '盗塁死',
                          controller:
                              _caughtStealingByRunnerControllers[matchIndex][i],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('閉じる'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '守: ${_selectedLeftList[matchIndex][i] ?? '未選択'}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 12),
            Text(
              '打球: ${_selectedRightList[matchIndex][i] ?? '未選択'}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const Divider(thickness: 1),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                FocusScope.of(context).requestFocus(FocusNode());
                Future.delayed(const Duration(milliseconds: 100), () {
                  _showCupertinoPicker(
                    context,
                    _rightOptions.keys.toList(),
                    _selectedLeftList[matchIndex][i] ?? '',
                    (selected) {
                      setState(() {
                        _selectedLeftList[matchIndex][i] = selected;
                        _selectedRightList[matchIndex][i] = null;
                      });
                      _saveFormData();
                    },
                  );
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_selectedLeftList[matchIndex][i] ?? '守',
                        style: const TextStyle(fontSize: 16)),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () {
                FocusScope.of(context).requestFocus(FocusNode());
                Future.delayed(const Duration(milliseconds: 100), () {
                  _showCupertinoPicker(
                    context,
                    _selectedLeftList[matchIndex][i] != null
                        ? _rightOptions[_selectedLeftList[matchIndex][i]] ?? []
                        : [],
                    _selectedRightList[matchIndex][i] ?? '',
                    (selected) {
                      setState(() {
                        _selectedRightList[matchIndex][i] = selected;
                      });
                      _saveFormData();
                    },
                  );
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_selectedRightList[matchIndex][i] ?? '打球',
                        style: const TextStyle(fontSize: 16)),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_selectedRightList[matchIndex][i] == '犠打') ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              for (final label in [
                '犠打成功',
                '犠打失敗',
                'バント併殺',
                'スクイズ成功',
                'スクイズ失敗',
                if (_selectedLeftList[matchIndex][i] == '一' ||
                    _selectedLeftList[matchIndex][i] == '三' ||
                    _selectedLeftList[matchIndex][i] == '捕')
                  'スリーバント失敗'
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _selectedBuntDetail[matchIndex][i] == label,
                  onSelected: (_) {
                    setState(() {
                      _selectedBuntDetail[matchIndex][i] = label;
                    });
                    _saveFormData();
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Column(
          children: [
            buildCounterField(
              label: 'スイング数',
              controller: _swingControllers[matchIndex][i],
              index: i,
            ),
            const SizedBox(height: 20),
            buildCounterField(
              label: '空振り数',
              controller: _missSwingControllers[matchIndex][i],
              index: i,
            ),
            const SizedBox(height: 20),
            buildCounterField(
              label: '球数',
              controller: _batterPitchCountControllers[matchIndex][i],
              index: i,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('初球スイング', style: TextStyle(fontSize: 18)),
            Checkbox(
              value: _firstPitchSwingFlags[matchIndex][i],
              onChanged: (value) {
                setState(() {
                  _firstPitchSwingFlags[matchIndex][i] = value ?? false;
                });
                _saveFormData();
              },
            ),
          ],
        ),
        const Divider(thickness: 1),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onClose,
            child: const Text('この打席を閉じる'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                '打順',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Column(
                children: List.generate(9, (index) {
                  final assigned = battingOrderMembers[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Row to hold batting order box and (optionally) the edit icon
                        Expanded(
                          child: DragTarget<Map<String, dynamic>>(
                            onAccept: (member) {
                              setState(() {
                                // Remove the member from any previous slot
                                for (int i = 0;
                                    i < battingOrderMembers.length;
                                    i++) {
                                  if (battingOrderMembers[i]?['uid'] ==
                                      member['uid']) {
                                    battingOrderMembers[i] = null;
                                  }
                                }
                                battingOrderMembers[index] = member;
                              });
                              _saveBattingOrder();
                            },
                            builder: (context, candidateData, rejectedData) {
                              return Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.black, width: 2),
                                  color: assigned != null
                                      ? Colors.green[100]
                                      : Colors.white,
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  children: [
                                    if (assigned != null)
                                      Expanded(
                                        child: Draggable<Map<String, dynamic>>(
                                          data: assigned,
                                          feedback: Material(
                                            color: Colors.transparent,
                                            child: Container(
                                              width: 200,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.transparent,
                                                border: Border.all(
                                                    color: Colors.black,
                                                    width: 2),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                assigned['name'],
                                                style: const TextStyle(
                                                    fontSize: 16),
                                              ),
                                            ),
                                          ),
                                          childWhenDragging: Opacity(
                                            opacity: 0.5,
                                            child: Container(
                                              alignment: Alignment.center,
                                              child: Text(
                                                assigned['name'],
                                                style: const TextStyle(
                                                    fontSize: 16),
                                              ),
                                            ),
                                          ),
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                selectedIndex = index;
                                              });
                                            },
                                            child: Text(
                                              assigned['name'],
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        // Move the IconButton OUTSIDE the Expanded batting order box
                        if (assigned != null)
                          IconButton(
                            icon: const Icon(Icons.edit_note),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(battingOrderMembers[index]
                                          ?['name'] ??
                                      ''),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        buildCounterField(
                                          label: '打点',
                                          controller: _rbisControllers[index]
                                              [0],
                                        ),
                                        const SizedBox(height: 12),
                                        buildCounterField(
                                          label: '得点',
                                          controller: _runsControllers[index]
                                              [0],
                                        ),
                                        const SizedBox(height: 12),
                                        buildCounterField(
                                          label: '盗塁企図数',
                                          controller:
                                              _stealsAttemptsControllers[index]
                                                  [0],
                                        ),
                                        const SizedBox(height: 12),
                                        buildCounterField(
                                          label: '盗塁成功',
                                          controller: _stealsControllers[index]
                                              [0],
                                        ),
                                        const SizedBox(height: 12),
                                        buildCounterField(
                                          label: '盗塁死',
                                          controller:
                                              _caughtStealingByRunnerControllers[
                                                  index][0],
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('閉じる'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                }),
              ),
              if (selectedIndex != null &&
                  battingOrderMembers[selectedIndex!] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Player name above 打席数 row
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          battingOrderMembers[selectedIndex!]?['name'] ?? '',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            '打席数',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 160,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () {
                                    setState(() {
                                      if (atBatList[selectedIndex!] > 0) {
                                        atBatList[selectedIndex!]--;
                                        // Remove expanded at-bat indexes that are now out of range
                                        _expandedAtBatIndexes.removeWhere(
                                            (idx) =>
                                                idx >=
                                                atBatList[selectedIndex!]);
                                      }
                                    });
                                    _saveFormData();
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    atBatList[selectedIndex!].toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    setState(() {
                                      atBatList[selectedIndex!]++;
                                      _expandedAtBatIndexes
                                          .add(atBatList[selectedIndex!] - 1);
                                    });
                                    _saveFormData();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              selectedIndex = null;
                            });
                          },
                          child: const Text('閉じる'),
                        ),
                      ),
                      // --- Per-at-bat input form widgets ---
                      if (atBatList[selectedIndex!] > 0)
                        Column(
                          children: List.generate(
                            atBatList[selectedIndex!],
                            (i) {
                              if (_expandedAtBatIndexes.contains(i)) {
                                return buildAtBatInput(selectedIndex!, i, () {
                                  setState(() {
                                    _expandedAtBatIndexes.remove(i);
                                  });
                                });
                              } else {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _expandedAtBatIndexes.add(i);
                                      });
                                    },
                                    child: Text('${i + 1}打席目を表示'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Text('ベンチ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DragTarget<Map<String, dynamic>>(
                onWillAccept: (data) => true,
                onAccept: (data) {
                  setState(() {
                    for (int i = 0; i < battingOrderMembers.length; i++) {
                      if (battingOrderMembers[i]?['uid'] == data['uid']) {
                        battingOrderMembers[i] = null;
                      }
                    }
                  });
                  _saveBattingOrder();
                },
                builder: (context, candidateData, rejectedData) {
                  final benchMembers = widget.members
                      .where((m) => !battingOrderMembers
                          .any((b) => b?['uid'] == m['uid']))
                      .toList();
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: candidateData.isNotEmpty
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.transparent,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: benchMembers.map((member) {
                        final name = member['name'] ?? '名前未設定';
                        return Draggable<Map<String, dynamic>>(
                          data: member,
                          feedback: Material(
                            color: Colors.transparent,
                            child: Chip(
                                label: Text(name,
                                    style: const TextStyle(fontSize: 12)),
                                elevation: 6),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.5,
                            child: Material(
                              color: Colors.transparent,
                              child: Chip(
                                label: Text(name,
                                    style: const TextStyle(fontSize: 12)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                              ),
                            ),
                          ),
                          child: Chip(
                            label: Text(name,
                                style: const TextStyle(fontSize: 12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _saveTentativeData,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: const Text(
                        'メンバーの成績を仮保存する',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          // Clear all relevant input fields and lists
                          for (int i = 0; i < 9; i++) {
                            atBatList[i] = 0;
                            _selectedLeftList[i] = List.filled(10, null);
                            _selectedRightList[i] = List.filled(10, null);
                            _selectedBuntDetail[i] = List.filled(10, null);
                            _firstPitchSwingFlags[i] = List.filled(10, false);

                            for (int j = 0; j < 10; j++) {
                              _swingControllers[i][j].text = '0';
                              _missSwingControllers[i][j].text = '0';
                              _batterPitchCountControllers[i][j].text = '0';
                              _rbisControllers[i][j].text = '0';
                              _runsControllers[i][j].text = '0';
                              _stealsAttemptsControllers[i][j].text = '0';
                              _stealsControllers[i][j].text = '0';
                              _caughtStealingByRunnerControllers[i][j].text =
                                  '0';
                            }
                          }
                          _expandedAtBatIndexes.clear();
                          selectedIndex = null;
                        });
                        _saveFormData();
                      },
                      child: const Text(
                        'データをリセット',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTentativeData() async {
    for (int i = 0; i < battingOrderMembers.length; i++) {
      final member = battingOrderMembers[i];
      if (member == null) continue;
      final String role = member['role'] ?? '';
      if (role.contains('監督') || role.contains('マネージャー')) continue;

      final String uid = member['uid'];
      final collectionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tentative');

      final querySnapshot = await collectionRef.limit(1).get();
      if (querySnapshot.docs.isEmpty) continue;

      final docRef = collectionRef.doc(querySnapshot.docs.first.id);

      List<Map<String, dynamic>> atBats = [];
      for (int j = 0; j < atBatList[i]; j++) {
        atBats.add({
          'at_bat': j + 1,
          'position': _selectedLeftList[i][j] ?? '',
          'result': _selectedRightList[i][j] ?? '',
          'buntDetail': _selectedBuntDetail[i][j],
          'swingCount': int.tryParse(_swingControllers[i][j].text) ?? 0,
          'missSwingCount': int.tryParse(_missSwingControllers[i][j].text) ?? 0,
          'batterPitchCount':
              int.tryParse(_batterPitchCountControllers[i][j].text) ?? 0,
          'firstPitchSwing': _firstPitchSwingFlags[i][j],
        });
      }

      // --- PATCH: update atBats and extra stats as top-level fields in games array ---
      final snapshot = await docRef.get();
      final games = (snapshot.data()?['data']['games'] ?? []) as List<dynamic>;

      if (widget.matchIndex < games.length) {
        final updatedGames = [...games];
        final currentGame =
            Map<String, dynamic>.from(games[widget.matchIndex] ?? {});
        currentGame['atBats'] = atBats;
        currentGame['rbis'] = int.tryParse(_rbisControllers[i][0].text) ?? 0;
        currentGame['runs'] = int.tryParse(_runsControllers[i][0].text) ?? 0;
        currentGame['stealsAttempts'] =
            int.tryParse(_stealsAttemptsControllers[i][0].text) ?? 0;
        currentGame['steals'] =
            int.tryParse(_stealsControllers[i][0].text) ?? 0;
        currentGame['caughtStealingByRunner'] =
            int.tryParse(_caughtStealingByRunnerControllers[i][0].text) ?? 0;
        updatedGames[widget.matchIndex] = currentGame;

        await docRef.update({
          'data.games': updatedGames,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      // --- END PATCH ---
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('仮保存しました')),
    );
  }
}
