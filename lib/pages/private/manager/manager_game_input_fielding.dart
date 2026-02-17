import 'package:flutter/cupertino.dart';

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManagerGameInputFielding extends StatefulWidget {
  final String userUid;
  final String teamId;
  final List<Map<String, dynamic>> members;
  final int matchIndex;

  const ManagerGameInputFielding({
    Key? key,
    required this.userUid,
    required this.teamId,
    required this.members,
    required this.matchIndex,
  }) : super(key: key);

  @override
  _ManagerGameInputFieldingState createState() =>
      _ManagerGameInputFieldingState();
}

class _ManagerGameInputFieldingState extends State<ManagerGameInputFielding> {
  late Map<String, Offset> memberPositions;

  Map<String, Offset> positionRatios = {
    '投手': Offset(0.36, 0.60),
    '捕手': Offset(0.36, 0.82),
    '一塁': Offset(0.60, 0.55),
    '二塁': Offset(0.50, 0.45),
    '三塁': Offset(0.13, 0.55),
    '遊撃': Offset(0.20, 0.45),
    '左翼': Offset(0.15, 0.32),
    '中堅': Offset(0.36, 0.25),
    '右翼': Offset(0.57, 0.32),
  };

  double fieldWidth = 0;
  double fieldHeight = 0;

  final ScrollController _scrollController = ScrollController();
  bool _isDragging = false;

  // --- Controllers for input fields ---
  late List<TextEditingController> _putoutsControllers;
  late List<TextEditingController> _assistsControllers;
  late List<TextEditingController> _errorsControllers;
  late List<TextEditingController> _stolenBaseAttemptsControllers;
  late List<TextEditingController> _caughtStealingControllers;

  late List<TextEditingController> _walksControllers;
  late List<TextEditingController> _hitByPitchControllers;
  late List<TextEditingController> _runsAllowedControllers;
  late List<TextEditingController> _earnedRunsControllers;
  late List<TextEditingController> _hitsAllowedControllers;
  late List<TextEditingController> _strikeoutsControllers;
  late List<TextEditingController> _homeRunsAllowedControllers;
  late List<TextEditingController> _pitchCountControllers;
  late List<TextEditingController> _battersFacedControllers;
  late List<TextEditingController> _inningsThrowControllers;
  late List<String?> _selectedAppearanceType;
  late List<bool> _isAppearanceSelected;
  late List<String?> _resultList;
  late List<String?> _outFractionList;
  late List<bool?> _isCompleteGame;
  late List<bool?> _isShutoutGame;
  late List<bool?> _isHold;
  late List<bool?> _isSave;

  Future<void> saveAllTentativeData({
    required List<Map<String, dynamic>> members,
    required List<Offset> playerPositions,
    required String gameId,
    required int matchIndex,
  }) async {
    for (int i = 0; i < members.length; i++) {
      final member = members[i];
      final uid = member['uid'];
      final positionLabel = member['position'] ?? '';
      // ignore: unused_local_variable
      final name = member['name']?.toString() ?? 'No Name';

      // 監督・マネージャーは保存対象外
      if (positionLabel.contains('監督') || positionLabel.contains('マネージャー'))
        continue;

      dynamic raw = member['positions'];
      // ignore: unused_local_variable
      final List<String> positionsList = (raw is String)
          ? [raw]
          : (raw is List)
              ? List<String>.from(raw)
              : [];

      // --- Store positions array into gameData ---
      // This line is added as per instructions:
      // Store the positions array into gameData

      // --- Firestore tentative document reuse logic ---
      final tentativeCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tentative');

      final querySnapshot = await tentativeCollection
          .orderBy('savedAt', descending: true)
          .limit(1)
          .get();

      DocumentReference docRef;

      if (querySnapshot.docs.isNotEmpty) {
        docRef = querySnapshot.docs.first.reference;
      } else {
        docRef = tentativeCollection.doc();
      }

      // Use matchIndex as gameIndex
      final int gameIndex = matchIndex;
      final Map<String, dynamic> gameData = {};

      // Store positions array in gameData
      gameData['positions'] = positionsList;

      final List<String> positionsListPitch = (raw is String)
          ? [raw]
          : (raw is List)
              ? List<String>.from(raw)
              : [];

      if (positionsListPitch.contains('投手')) {
        gameData['walks'] = int.tryParse(_walksControllers[i].text) ?? 0;
        gameData['hitByPitch'] =
            int.tryParse(_hitByPitchControllers[i].text) ?? 0;
        gameData['runsAllowed'] =
            int.tryParse(_runsAllowedControllers[i].text) ?? 0;
        gameData['earnedRuns'] =
            int.tryParse(_earnedRunsControllers[i].text) ?? 0;
        gameData['hitsAllowed'] =
            int.tryParse(_hitsAllowedControllers[i].text) ?? 0;
        gameData['strikeouts'] =
            int.tryParse(_strikeoutsControllers[i].text) ?? 0;
        gameData['homeRunsAllowed'] =
            int.tryParse(_homeRunsAllowedControllers[i].text) ?? 0;
        gameData['pitchCount'] =
            int.tryParse(_pitchCountControllers[i].text) ?? 0;
        gameData['battersFaced'] =
            int.tryParse(_battersFacedControllers[i].text) ?? 0;
        gameData['inningsThrow'] =
            double.tryParse(_inningsThrowControllers[i].text) ?? 0;
        gameData['appearanceType'] = _selectedAppearanceType[i];
        gameData['isCompleteGame'] = _isCompleteGame[i] ?? false;
        gameData['isShutoutGame'] = _isShutoutGame[i] ?? false;
        gameData['isHold'] = _isHold[i] ?? false;
        gameData['isSave'] = _isSave[i] ?? false;
        gameData['resultGame'] = _resultList[i] ?? '';
        gameData['outFraction'] = _outFractionList[i] ?? 0;
      }
      gameData['index'] = gameIndex;

      // Retrieve the existing games array
      final snapshot = await docRef.get();
      List<dynamic> existingGames = [];
      if (snapshot.exists) {
        final existingData = snapshot.data() as Map<String, dynamic>?;
        existingGames = (existingData?['data']?['games'] as List?) ?? [];
      }
      // Ensure the list is large enough
      while (existingGames.length <= gameIndex) {
        existingGames.add({});
      }
      // Update the specific index with merged game data, preserving fields like gameType, location, opponent
      Map<String, dynamic> mergedGame = {};
      if (existingGames[gameIndex] is Map<String, dynamic>) {
        mergedGame = Map<String, dynamic>.from(existingGames[gameIndex]);
      }
      mergedGame.addAll(gameData);
      existingGames[gameIndex] = mergedGame;

      await docRef.set({
        'data': {
          'games': existingGames,
        },
        'savedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

    @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    memberPositions = {};
    final memberCount = widget.members.length;
    _putoutsControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));
    _assistsControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));
    _errorsControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));
    _stolenBaseAttemptsControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));
    _caughtStealingControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));

    _walksControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));
    _hitByPitchControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));
    _runsAllowedControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));
    _earnedRunsControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));
    _hitsAllowedControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));
    _strikeoutsControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));
    _homeRunsAllowedControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));
    _pitchCountControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));
    _battersFacedControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));
    _inningsThrowControllers =
        List.generate(memberCount, (_) => TextEditingController(text: '0'));

    _selectedAppearanceType = List.filled(memberCount, null);
    _isAppearanceSelected = List.filled(memberCount, false);
    _resultList = List.filled(memberCount, null);
    _outFractionList = List.filled(memberCount, null);
    _isCompleteGame = List.filled(memberCount, false);
    _isShutoutGame = List.filled(memberCount, false);
    _isHold = List.filled(memberCount, false);
    _isSave = List.filled(memberCount, false);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (int i = 0; i < widget.members.length; i++) {
        final uid = widget.members[i]['uid'];
        await _loadFieldingDataFromPrefs(i, uid);
      }
    });
  }

  /// Save all fielding data for a given member (index, uid) to SharedPreferences.
  Future<void> saveFieldingDataToPrefs(int index, String uid) async {
    final prefs = await SharedPreferences.getInstance();

    void save(String key, String value) {
      prefs.setString('$uid-$key', value);
    }

    save('putouts_$index', _putoutsControllers[index].text);
    save('assists_$index', _assistsControllers[index].text);
    save('errors_$index', _errorsControllers[index].text);
    save('stolenBaseAttempts_$index',
        _stolenBaseAttemptsControllers[index].text);
    save('hitByPitch_$index', _hitByPitchControllers[index].text);
    save('walks_$index', _walksControllers[index].text);
    save('caughtStealing_$index', _caughtStealingControllers[index].text);
    save('runsAllowed_$index', _runsAllowedControllers[index].text);
    save('earnedRuns_$index', _earnedRunsControllers[index].text);
    save('hitsAllowed_$index', _hitsAllowedControllers[index].text);
    save('strikeouts_$index', _strikeoutsControllers[index].text);
    save('homeRunsAllowed_$index', _homeRunsAllowedControllers[index].text);
    save('pitchCount_$index', _pitchCountControllers[index].text);
    save('battersFaced_$index', _battersFacedControllers[index].text);
    save('inningsThrow_$index', _inningsThrowControllers[index].text);
    save('appearanceType_$index', _selectedAppearanceType[index] ?? '');
    save('isCompleteGame_$index', (_isCompleteGame[index] ?? false).toString());
    save('isShutoutGame_$index', (_isShutoutGame[index] ?? false).toString());
    save('isHold_$index', (_isHold[index] ?? false).toString());
    save('isSave_$index', (_isSave[index] ?? false).toString());
    // Add result and outFraction
    save('result_$index', _resultList[index] ?? '');
    save('outFraction_$index', _outFractionList[index] ?? '');
  }

  /// Load all fielding data for a given member (index, uid) from SharedPreferences.
  /// Also ensures SharedPreferences are updated with default values if none exist.
  Future<void> _loadFieldingDataFromPrefs(int index, String uid) async {
    final prefs = await SharedPreferences.getInstance();

    String get(String key) => prefs.getString('$uid-$key') ?? '';

    _putoutsControllers[index].text = get('putouts_$index');
    _assistsControllers[index].text = get('assists_$index');
    _errorsControllers[index].text = get('errors_$index');
    _stolenBaseAttemptsControllers[index].text =
        get('stolenBaseAttempts_$index');
    _hitByPitchControllers[index].text = get('hitByPitch_$index');
    _walksControllers[index].text = get('walks_$index');
    _caughtStealingControllers[index].text = get('caughtStealing_$index');
    _runsAllowedControllers[index].text = get('runsAllowed_$index');
    _earnedRunsControllers[index].text = get('earnedRuns_$index');
    _hitsAllowedControllers[index].text = get('hitsAllowed_$index');
    _strikeoutsControllers[index].text = get('strikeouts_$index');
    _homeRunsAllowedControllers[index].text = get('homeRunsAllowed_$index');
    _pitchCountControllers[index].text = get('pitchCount_$index');
    _battersFacedControllers[index].text = get('battersFaced_$index');
    _inningsThrowControllers[index].text = get('inningsThrow_$index');
    _selectedAppearanceType[index] = get('appearanceType_$index');
    _isAppearanceSelected[index] = _selectedAppearanceType[index] != null &&
        _selectedAppearanceType[index]!.isNotEmpty;
    _isCompleteGame[index] = get('isCompleteGame_$index') == 'true';
    _isShutoutGame[index] = get('isShutoutGame_$index') == 'true';
    _isHold[index] = get('isHold_$index') == 'true';
    _isSave[index] = get('isSave_$index') == 'true';
    _resultList[index] = get('result_$index');
    _outFractionList[index] = get('outFraction_$index');
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

  Widget _buildAppearanceTypePicker(int index, StateSetter setState) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode()); // フォーカスを即時解除
        Future.delayed(const Duration(milliseconds: 150), () {
          _showCupertinoPicker(
            context,
            ['先発', '中継ぎ', '抑え'],
            _selectedAppearanceType[index] ?? '登板タイプを選択',
            (selected) {
              setState(() {
                _selectedAppearanceType[index] = selected;
                _isAppearanceSelected[index] = true;
              });
              final uid = widget.members[index]['uid'];
              saveFieldingDataToPrefs(index, uid);
            },
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedAppearanceType[index] ?? '選択',
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildResultPicker(int index, StateSetter setState) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
        Future.delayed(const Duration(milliseconds: 150), () {
          _showCupertinoPicker(
            context,
            ['勝利', '敗北', 'なし'],
            _resultList[index] ?? '勝敗を選択',
            (selected) {
              setState(() {
                _resultList[index] = selected;
              });
              final uid = widget.members[index]['uid'];
              saveFieldingDataToPrefs(index, uid);
            },
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _resultList[index] ?? '選択',
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildOutFractionPicker(int index, StateSetter setState) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
        Future.delayed(const Duration(milliseconds: 150), () {
          _showCupertinoPicker(
            context,
            ['0', '1/3', '2/3'],
            _outFractionList[index] ?? '選択',
            (selected) {
              setState(() {
                _outFractionList[index] = selected;
              });
              final uid = widget.members[index]['uid'];
              saveFieldingDataToPrefs(index, uid);
            },
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _outFractionList[index] ?? '選択',
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> saveMemberPositions() async {
    final prefs = await SharedPreferences.getInstance();
    final positionsJson = memberPositions.map((uid, offset) {
      // Store as ratios directly
      return MapEntry(uid, {'dx': offset.dx, 'dy': offset.dy});
    });
    await prefs.setString(
        'member_positions_${widget.teamId}', json.encode(positionsJson));
  }

  Future<void> loadMemberPositions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('member_positions_${widget.teamId}');
    if (jsonString != null && fieldWidth > 0 && fieldHeight > 0) {
      final Map<String, dynamic> decoded = json.decode(jsonString);
      setState(() {
        memberPositions = decoded.map((uid, value) {
          double dx = value['dx'];
          double dy = value['dy'];
          // Values are ratios now
          return MapEntry(uid, Offset(dx, dy));
        });
      });
    }
  }

  void _showTentativeInputDialog(
      String uid, String name, int matchIndex) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final positions = List<String>.from(doc['positions'] ?? []);

    // Find the member's index in the members list
    int i = widget.members.indexWhere((m) => m['uid'] == uid);

    showDialog(
      context: context,
      builder: (context) {
        return TentativeInputDialog(
          uid: uid,
          name: name,
          positions: positions,
          matchIndex: matchIndex,
          index: i,
          loadFieldingDataFromPrefs: _loadFieldingDataFromPrefs,
          saveFieldingDataToPrefs: saveFieldingDataToPrefs,
          putoutsController: _putoutsControllers[i],
          assistsController: _assistsControllers[i],
          errorsController: _errorsControllers[i],
          stolenBaseAttemptsController: _stolenBaseAttemptsControllers[i],
          caughtStealingController: _caughtStealingControllers[i],
        );
      },
    );
  }

  Widget buildCounterField({
    required String label,
    required TextEditingController controller,
    int? index, // indexを追加
  }) {
    final bool isLarge = label == '球数' || label == '対戦打者';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 18 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(
          width: isLarge ? 160 : 120,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove, size: isLarge ? 24 : 16),
                onPressed: () {
                  final current = int.tryParse(controller.text) ?? 0;
                  if (current > 0) {
                    controller.text = (current - 1).toString();
                    if (index != null) {
                      final uid = widget.members[index]['uid'];
                      saveFieldingDataToPrefs(index, uid);
                    }
                  }
                },
              ),
              SizedBox(
                width: isLarge ? 60 : 20,
                child: TextField(
                  controller: controller,
                  readOnly: true, // ★ これでキーボードを開かなくする
                  showCursor: false, // カーソル非表示（任意）
                  focusNode:
                      FocusNode(skipTraversal: true, canRequestFocus: false),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isLarge ? 18 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                  // --- onChangedでPrefs保存 ---
                  onChanged: (value) {
                    if (index != null) {
                      final uid = widget.members[index]['uid'];
                      saveFieldingDataToPrefs(index, uid);
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.add, size: isLarge ? 24 : 16),
                onPressed: () {
                  final current = int.tryParse(controller.text) ?? 0;
                  controller.text = (current + 1).toString();
                  if (index != null) {
                    final uid = widget.members[index]['uid'];
                    saveFieldingDataToPrefs(index, uid);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> buildPitcherStatsWidgets() {
    List<Widget> widgets = [];

    const pitcherOffset = Offset(0.36, 0.60); // 投手の配置座標

    for (int i = 0; i < widget.members.length; i++) {
      final user = widget.members[i];
      final uid = user['uid'];
      final name = user['name'] ?? 'No Name';
      final positions = user['positions'];
      final List<String> positionsList = (positions is String)
          ? [positions]
          : (positions is List)
              ? List<String>.from(positions)
              : [];

      final offset = memberPositions[uid];

      final isPitcherAtCorrectPosition = offset != null &&
          (offset.dx - pitcherOffset.dx).abs() < 0.01 &&
          (offset.dy - pitcherOffset.dy).abs() < 0.01 &&
          positionsList.contains('投手');

      if (!isPitcherAtCorrectPosition) continue;

      widgets.add(Text(
        '投手【$name】',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ));
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '投球イニング',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(
                width: 160,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        final current =
                            int.tryParse(_inningsThrowControllers[i].text) ?? 0;
                        if (current > 0) {
                          _inningsThrowControllers[i].text =
                              (current - 1).toString();
                          final uid = widget.members[i]['uid'];
                          saveFieldingDataToPrefs(i, uid);
                        }
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _inningsThrowControllers[i],
                        readOnly: true, // ★ これでキーボードを開かなくする
                        showCursor: false, // カーソル非表示（任意）
                        focusNode: FocusNode(
                            skipTraversal: true, canRequestFocus: false),
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
                        final current =
                            int.tryParse(_inningsThrowControllers[i].text) ?? 0;
                        _inningsThrowControllers[i].text =
                            (current + 1).toString();
                        final uid = widget.members[i]['uid'];
                        saveFieldingDataToPrefs(i, uid);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      // --- Inserted code block ---
      widgets.addAll([
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Text(
                        '登板',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 5),
                      _buildAppearanceTypePicker(i, setState),
                      const SizedBox(width: 5),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        '勝敗',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 5),
                      _buildResultPicker(i, setState),
                    ],
                  ),
                  if (_selectedAppearanceType[i] == '先発') ...[
                    Row(
                      children: [
                        Checkbox(
                          value: _isCompleteGame[i],
                          onChanged: (bool? value) {
                            setState(() {
                              _isCompleteGame[i] = value;
                            });
                            final uid = widget.members[i]['uid'];
                            saveFieldingDataToPrefs(i, uid);
                          },
                        ),
                        const Text('完投'),
                      ],
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: _isShutoutGame[i],
                          onChanged: (bool? value) {
                            setState(() {
                              _isShutoutGame[i] = value;
                            });
                            final uid = widget.members[i]['uid'];
                            saveFieldingDataToPrefs(i, uid);
                          },
                        ),
                        const Text('完封'),
                      ],
                    ),
                  ],
                  if (_selectedAppearanceType[i] == '中継ぎ') ...[
                    Row(
                      children: [
                        Checkbox(
                          value: _isHold[i],
                          onChanged: (bool? value) {
                            setState(() {
                              _isHold[i] = value;
                            });
                            final uid = widget.members[i]['uid'];
                            saveFieldingDataToPrefs(i, uid);
                          },
                        ),
                        const Text('ホールド'),
                      ],
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: _isSave[i],
                          onChanged: (bool? value) {
                            setState(() {
                              _isSave[i] = value;
                            });
                            final uid = widget.members[i]['uid'];
                            saveFieldingDataToPrefs(i, uid);
                          },
                        ),
                        const Text('セーブ'),
                      ],
                    ),
                  ],
                  if (_selectedAppearanceType[i] == '抑え') ...[
                    Row(
                      children: [
                        Checkbox(
                          value: _isSave[i],
                          onChanged: (bool? value) {
                            setState(() {
                              _isSave[i] = value;
                            });
                            final uid = widget.members[i]['uid'];
                            saveFieldingDataToPrefs(i, uid);
                          },
                        ),
                        const Text('セーブ'),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ]);

      widgets.addAll([
        const SizedBox(height: 10),
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Text(
                    'アウト',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 5),
                  _buildOutFractionPicker(i, setState),
                ],
              ),
            ),
            Expanded(
                child: buildCounterField(
                    label: '被本塁打',
                    controller: _homeRunsAllowedControllers[i],
                    index: i)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
                child: buildCounterField(
                    label: '被安打',
                    controller: _hitsAllowedControllers[i],
                    index: i)),
            Expanded(
                child: buildCounterField(
                    label: '失点',
                    controller: _runsAllowedControllers[i],
                    index: i)),
            Expanded(
                child: buildCounterField(
                    label: '自責点',
                    controller: _earnedRunsControllers[i],
                    index: i)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
                child: buildCounterField(
                    label: '与四球', controller: _walksControllers[i], index: i)),
            Expanded(
                child: buildCounterField(
                    label: '与死球',
                    controller: _hitByPitchControllers[i],
                    index: i)),
            Expanded(
                child: buildCounterField(
                    label: '奪三振',
                    controller: _strikeoutsControllers[i],
                    index: i)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            buildCounterField(
                label: '球数', controller: _pitchCountControllers[i], index: i),
            buildCounterField(
                label: '対戦打者',
                controller: _battersFacedControllers[i],
                index: i),
          ],
        ),
      ]);
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double height = constraints.maxHeight * 0.8;
        final double width = height; // 正方形表示
        fieldWidth = width;
        fieldHeight = height;
        final rectWidth = fieldWidth * 0.20;
        final rectHeight = fieldHeight * 0.06;

        // Load member positions once field size is known
        if (memberPositions.isEmpty) {
          loadMemberPositions();
        }

        // 投手が該当位置にいる場合に「投手」と表示
        bool shouldShowPitcherLabel = false;
        const pitcherOffset = Offset(0.36, 0.60);
        widget.members.forEach((member) {
          final uid = member['uid'];
          final positions = member['positions'];
          final List<String> positionsList = (positions is String)
              ? [positions]
              : (positions is List)
                  ? List<String>.from(positions)
                  : [];
          final offset = memberPositions[uid];
          if (offset != null &&
              (offset.dx - pitcherOffset.dx).abs() < 0.01 &&
              (offset.dy - pitcherOffset.dy).abs() < 0.01 &&
              positionsList.contains('投手')) {
            shouldShowPitcherLabel = true;
          }
        });

        // return SingleChildScrollView(
        return Scaffold(
          body: Listener(
            onPointerMove: (event) {
              // Only auto-scroll while dragging
              if (!_isDragging) return;

              final position = event.position.dy;
              final mediaQuery = MediaQuery.of(context);
              final screenHeight = mediaQuery.size.height;

              const edgeThreshold = 100; // distance from edge to trigger scroll
              const scrollSpeed = 15.0;

              // Start the top auto-scroll zone below status bar + (potential) AppBar height
              final topTriggerY = mediaQuery.padding.top + kToolbarHeight;
              // Start bottom auto-scroll after passing bench area (rough offset adjustment)
              final bottomTriggerY =
                  screenHeight - mediaQuery.padding.bottom - 200;

              if (!_scrollController.hasClients) return;

              if (position < topTriggerY + edgeThreshold) {
                // Scroll up
                final target = (_scrollController.offset - scrollSpeed)
                    .clamp(0.0, _scrollController.position.maxScrollExtent);
                _scrollController.jumpTo(target);
              } else if (position > bottomTriggerY - edgeThreshold) {
                // Scroll down
                final target = (_scrollController.offset + scrollSpeed)
                    .clamp(0.0, _scrollController.position.maxScrollExtent);
                _scrollController.jumpTo(target);
              }
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                if (shouldShowPitcherLabel) ...[
                  ...buildPitcherStatsWidgets(),
                ],
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
                      ...positionRatios.entries.map((entry) {
                        final ratio = entry.value;
                        final centerX = width * ratio.dx;
                        final centerY = height * ratio.dy;
                        final left = centerX - rectWidth / 2;
                        final top = centerY - rectHeight / 2;
                        return Positioned(
                          left: left,
                          top: top,
                          width: rectWidth,
                          height: rectHeight,
                          child: DragTarget<String>(
                            onWillAccept: (data) => true,
                            onAccept: (data) {
                              setState(() {
                                String? overlappingUid;
                                final draggedRect = Rect.fromLTWH(
                                    left, top, rectWidth, rectHeight);

                                for (final entry in memberPositions.entries) {
                                  if (entry.key == data) continue;
                                  final otherOffset = entry.value;
                                  final otherRect = Rect.fromLTWH(
                                      otherOffset.dx * fieldWidth,
                                      otherOffset.dy * fieldHeight,
                                      rectWidth,
                                      rectHeight);
                                  if (draggedRect.overlaps(otherRect)) {
                                    overlappingUid = entry.key;
                                    break;
                                  }
                                }

                                if (overlappingUid != null) {
                                  final previousOffset = memberPositions[data];
                                  if (previousOffset != null) {
                                    memberPositions[overlappingUid] =
                                        previousOffset;
                                  }
                                }

                                final centerOffset = Offset(
                                    left + rectWidth / 2, top + rectHeight / 2);
                                final dxRatio = centerOffset.dx / fieldWidth;
                                final dyRatio = centerOffset.dy / fieldHeight;
                                memberPositions[data] =
                                    Offset(dxRatio, dyRatio);
                              });
                              saveMemberPositions();
                            },
                            builder: (context, candidateData, rejectedData) {
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blueAccent),
                                  color: candidateData.isNotEmpty
                                      ? Colors.blue.withOpacity(0.3)
                                      : Colors.transparent,
                                ),
                              );
                            },
                          ),
                        );
                      }),
                      ...memberPositions.entries.map((entry) {
                        final uid = entry.key;
                        final member = widget.members.firstWhere(
                          (m) => m['uid'] == uid,
                          orElse: () => <String, dynamic>{},
                        );
                        if (member.isEmpty) return const SizedBox.shrink();
                        final name = member['name'] ?? '名前未設定';
                        final offset = entry.value;

                        final dx = offset.dx * fieldWidth;
                        final dy = offset.dy * fieldHeight;

                        return Positioned(
                          left: dx - rectWidth / 2,
                          top: dy - rectHeight / 2,
                          width: rectWidth,
                          height: rectHeight,
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                _showTentativeInputDialog(
                                    uid, name, widget.matchIndex);
                              },
                              child: Draggable<String>(
                                data: uid,
                                onDragStarted: () {
                                  _isDragging = true;
                                },
                                onDragEnd: (_) {
                                  _isDragging = false;
                                },
                                onDraggableCanceled: (_, __) {
                                  _isDragging = false;
                                },
                                feedback: Material(
                                  type: MaterialType.transparency,
                                  child: Chip(
                                    label: Text(name,
                                        style: const TextStyle(fontSize: 12)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                  ),
                                ),
                                childWhenDragging: Container(),
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: Chip(
                                    label: Text(name,
                                        style: const TextStyle(fontSize: 12)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const Text('ベンチ',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DragTarget<String>(
                  onWillAccept: (data) => true,
                  onAccept: (data) {
                    setState(() {
                      memberPositions.remove(data); // Remove from field
                    });
                    saveMemberPositions();
                  },
                  builder: (context, candidateData, rejectedData) {
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
                        children: widget.members
                            .where(
                                (m) => !memberPositions.containsKey(m['uid']))
                            .map((member) {
                          final uid = member['uid'];
                          final name = member['name'] ?? '名前未設定';
                          return GestureDetector(
                            onTap: () {
                              _showTentativeInputDialog(
                                  uid, name, widget.matchIndex);
                            },
                            child: Draggable<String>(
                              data: uid,
                              onDragStarted: () {
                                _isDragging = true;
                              },
                              onDragEnd: (_) {
                                _isDragging = false;
                              },
                              onDraggableCanceled: (_, __) {
                                _isDragging = false;
                              },
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
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 48),
                // 保存ボタン
                ElevatedButton(
                  onPressed: () async {
                    // Use matchIndex to generate a default gameId
                    final gameId = 'match_${widget.matchIndex}';
                    await saveAllTentativeData(
                      members: widget.members,
                      playerPositions: [], // 必要に応じて渡す
                      gameId: gameId,
                      matchIndex: widget.matchIndex,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('成績を仮保存しました'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Text('メンバーの成績を仮保存する'),
                ),
                const SizedBox(height: 16),
                // リセットボタン
                TextButton(
                  onPressed: () async {
                    for (int i = 0; i < widget.members.length; i++) {
                      final uid = widget.members[i]['uid'];
                      final prefs = await SharedPreferences.getInstance();
                      List<String> keys = [
                        'putouts_$i',
                        'assists_$i',
                        'errors_$i',
                        'stolenBaseAttempts_$i',
                        'caughtStealing_$i',
                        'walks_$i',
                        'hitByPitch_$i',
                        'runsAllowed_$i',
                        'earnedRuns_$i',
                        'hitsAllowed_$i',
                        'strikeouts_$i',
                        'homeRunsAllowed_$i',
                        'pitchCount_$i',
                        'battersFaced_$i',
                        'inningsThrow_$i',
                        'appearanceType_$i',
                        'isCompleteGame_$i',
                        'isShutoutGame_$i',
                        'isHold_$i',
                        'isSave_$i',
                        'result_$i',
                        'outFraction_$i',
                      ];

                      for (final key in keys) {
                        await prefs.remove('$uid-$key');
                      }

                      _putoutsControllers[i].text = '0';
                      _assistsControllers[i].text = '0';
                      _errorsControllers[i].text = '0';
                      _stolenBaseAttemptsControllers[i].text = '0';
                      _caughtStealingControllers[i].text = '0';
                      _walksControllers[i].text = '0';
                      _hitByPitchControllers[i].text = '0';
                      _runsAllowedControllers[i].text = '0';
                      _earnedRunsControllers[i].text = '0';
                      _hitsAllowedControllers[i].text = '0';
                      _strikeoutsControllers[i].text = '0';
                      _homeRunsAllowedControllers[i].text = '0';
                      _pitchCountControllers[i].text = '0';
                      _battersFacedControllers[i].text = '0';
                      _inningsThrowControllers[i].text = '0';
                      _selectedAppearanceType[i] = null;
                      _resultList[i] = null;
                      _outFractionList[i] = null;
                      _isCompleteGame[i] = false;
                      _isShutoutGame[i] = false;
                      _isHold[i] = false;
                      _isSave[i] = false;
                    }

                    setState(() {});
                  },
                  child: const Text(
                    'データをリセット',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
      },
    );
  }
}

class TentativeInputDialog extends StatefulWidget {
  final String uid;
  final String name;
  final List<dynamic> positions;
  final int matchIndex;
  final int index;
  final Future<void> Function(int index, String uid) loadFieldingDataFromPrefs;
  final Future<void> Function(int index, String uid) saveFieldingDataToPrefs;
  final TextEditingController putoutsController;
  final TextEditingController assistsController;
  final TextEditingController errorsController;
  final TextEditingController stolenBaseAttemptsController;
  final TextEditingController caughtStealingController;

  const TentativeInputDialog({
    Key? key,
    required this.uid,
    required this.name,
    required this.positions,
    required this.matchIndex,
    required this.index,
    required this.loadFieldingDataFromPrefs,
    required this.saveFieldingDataToPrefs,
    required this.putoutsController,
    required this.assistsController,
    required this.errorsController,
    required this.stolenBaseAttemptsController,
    required this.caughtStealingController,
  }) : super(key: key);

  @override
  _TentativeInputDialogState createState() => _TentativeInputDialogState();
}

class _TentativeInputDialogState extends State<TentativeInputDialog> {
  late String gameId;

  @override
  void initState() {
    super.initState();
    (() async {
      final tentativeCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('tentative');

      final querySnapshot = await tentativeCollection
          .orderBy('savedAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        gameId = querySnapshot.docs.first.id;
      } else {
        gameId = tentativeCollection.doc().id;
      }

      await widget.loadFieldingDataFromPrefs(widget.index, widget.uid);
      setState(() {});
    })();
  }

  Future<void> saveAllTentativeData() async {
    final Map<String, dynamic> gameStats = {
      'putouts': int.tryParse(widget.putoutsController.text) ?? 0,
      'assists': int.tryParse(widget.assistsController.text) ?? 0,
      'errors': int.tryParse(widget.errorsController.text) ?? 0,
    };

    if (widget.positions.contains('捕手')) {
      gameStats['stolenBaseAttempts'] =
          int.tryParse(widget.stolenBaseAttemptsController.text) ?? 0;
      gameStats['caughtStealing'] =
          int.tryParse(widget.caughtStealingController.text) ?? 0;
    }

    // Save values using shared method passed from parent
    await widget.saveFieldingDataToPrefs(widget.index, widget.uid);

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('tentative')
        .doc(gameId);

    final snapshot = await docRef.get();
    Map<String, dynamic> existingData = {};
    List<dynamic> existingGames = [];

    if (snapshot.exists) {
      existingData = snapshot.data()?['data'] ?? {};
      existingGames = (existingData['games'] as List?) ?? [];
    }

    // Ensure the list is large enough for the current matchIndex
    while (existingGames.length <= widget.matchIndex) {
      existingGames.add({});
    }

    Map<String, dynamic> mergedGame = {};
    if (existingGames[widget.matchIndex] is Map<String, dynamic>) {
      mergedGame = Map<String, dynamic>.from(existingGames[widget.matchIndex]);
    }
    mergedGame.addAll(gameStats);
    existingGames[widget.matchIndex] = mergedGame;

    await docRef.set({
      'data': {
        'games': existingGames,
      },
      'savedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCounterRow('刺殺', controller: widget.putoutsController),
          const SizedBox(height: 8),
          _buildCounterRow('捕殺', controller: widget.assistsController),
          const SizedBox(height: 8),
          _buildCounterRow('失策', controller: widget.errorsController),
          if (widget.positions.contains('捕手')) ...[
            const SizedBox(height: 8),
            _buildCounterRow('盗塁企図',
                controller: widget.stolenBaseAttemptsController),
            const SizedBox(height: 8),
            _buildCounterRow('盗塁刺',
                controller: widget.caughtStealingController),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await saveAllTentativeData();
            Navigator.of(context).pop();
          },
          child: const Text('保存して閉じる'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  Widget _buildCounterRow(
    String label, {
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(
          width: 160,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove, size: 24),
                onPressed: () {
                  final current = int.tryParse(controller.text) ?? 0;
                  if (current > 0) {
                    setState(() {
                      controller.text = (current - 1).toString();
                    });
                  }
                },
              ),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: controller,
                  readOnly: true,
                  showCursor: false,
                  focusNode: FocusNode(
                    skipTraversal: true,
                    canRequestFocus: false,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (value) {
                    setState(() {}); // 反映
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.add, size: 24),
                onPressed: () {
                  final current = int.tryParse(controller.text) ?? 0;
                  setState(() {
                    controller.text = (current + 1).toString();
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PositionedDraggableChip extends StatefulWidget {
  final Offset offset;
  final String uid;
  final String name;

  const PositionedDraggableChip({
    Key? key,
    required this.offset,
    required this.uid,
    required this.name,
  }) : super(key: key);

  @override
  State<PositionedDraggableChip> createState() =>
      _PositionedDraggableChipState();
}

class _PositionedDraggableChipState extends State<PositionedDraggableChip> {
  final GlobalKey _chipKey = GlobalKey();
  Offset _adjust = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _chipKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && mounted) {
        final size = box.size;
        setState(() {
          _adjust = Offset(-size.width / 2, -size.height / 2);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.offset.dx + _adjust.dx,
      top: widget.offset.dy + _adjust.dy,
      child: Draggable<String>(
        data: widget.uid,
        feedback: Material(
          color: Colors.transparent,
          child: Chip(
              key: _chipKey,
              label: Text(widget.name, style: const TextStyle(fontSize: 12)),
              elevation: 6),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: Material(
            color: Colors.transparent,
            child: Chip(
                label: Text(widget.name, style: const TextStyle(fontSize: 12))),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Chip(
              key: _chipKey,
              label: Text(widget.name, style: const TextStyle(fontSize: 12))),
        ),
      ),
    );
  }
}
