import 'package:b_net/pages/explanation/pitcher_info_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class GameInputPage extends StatefulWidget {
  final DateTime selectedDate;
  final List<String> positions;
  const GameInputPage({super.key, required this.selectedDate, required this.positions,});

  @override
  State<GameInputPage> createState() => _GameInputPageState();
}

class _GameInputPageState extends State<GameInputPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _eventController = TextEditingController();
  DateTime? _selectedDay;
  int numberOfMatches = 0;
  String? errorMessage;
  bool _isSaving = false;
  List<String> _positions = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDate;
    _positions = widget.positions;
    _initFromTentative();
  }

  Future<void> _initFromTentative() async {
    // まず仮保存データから試合数や各種フィールドを復元
    await _initializeFields();
    // その後、各コントローラ類を詳細に復元
    await _loadTentativeData();
  }

  // Firestoreからtentativeデータを取得し、状態を復元する
  Future<void> _loadTentativeData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('tentative')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final docData = snapshot.docs.first.data();
      // 仮保存データの形式により'data'キーの有無をチェック
      final data = docData['data'] ?? docData;

      // 1. Parse tentative data and store in local variables
      // 2. Set each field using the retrieved data
      // 3. After setting all fields, call setState to update the UI
      // 4. If numberOfMatches is needed, extract from games length
      final List<dynamic> games = data['games'] ?? [];
      final int loadedNumberOfMatches = games.length;

      // Prepare local lists for each field to avoid partial update before setState
      List<String?> loadedGameType = [];
      List<TextEditingController> loadedLocationControllers = [];
      List<TextEditingController> loadedOpponentControllers = [];
      List<TextEditingController> loadedStealsControllers = [];
      List<TextEditingController> loadedRbisControllers = [];
      List<TextEditingController> loadedRunsControllers = [];
      List<TextEditingController> loadedMemoControllers = [];
      List<TextEditingController> loadedInningsThrowControllers = [];
      List<TextEditingController> loadedStrikeoutsControllers = [];
      List<TextEditingController> loadedWalksControllers = [];
      List<TextEditingController> loadedHitByPitchControllers = [];
      List<TextEditingController> loadedEarnedRunsControllers = [];
      List<TextEditingController> loadedRunsAllowedControllers = [];
      List<TextEditingController> loadedHitsAllowedControllers = [];
      List<TextEditingController> loadedPutoutsControllers = [];
      List<TextEditingController> loadedAssistsControllers = [];
      List<TextEditingController> loadedErrorsControllers = [];
      List<TextEditingController> loadedCaughtStealingByRunnerControllers = [];
      List<TextEditingController> loadedCaughtStealingControllers = [];
      List<TextEditingController> loadedStolenBaseAttemptsControllers = [];
      List<TextEditingController> loadedStealsAttemptsControllers = [];
      List<TextEditingController> loadedHomeRunsAllowedControllers = [];
      List<TextEditingController> loadedPitchCountControllers = [];
      List<String?> loadedResultList = [];
      List<String?> loadedOutFractionList = [];
      List<String?> loadedAppearanceType = [];
      List<bool?> loadedIsCompleteGame = [];
      List<bool?> loadedIsShutoutGame = [];
      List<bool?> loadedIsSave = [];
      List<bool?> loadedIsHold = [];
      List<bool> loadedIsAppearanceSelected = [];
      List<TextEditingController> loadedBattersFacedControllers = [];
      List<int> loadedAtBatList = [];
      List<TextEditingController> loadedAtBatControllers = [];
      List<List<String?>> loadedSelectedLeftList = [];
      List<List<String?>> loadedSelectedRightList = [];
      List<List<String?>> loadedSelectedBuntDetail = [];
      List<List<TextEditingController>> loadedSwingControllers = [];
      List<List<TextEditingController>> loadedMissSwingControllers = [];
      List<List<TextEditingController>> loadedBatterPitchCountControllers = [];
      List<List<bool>> loadedFirstPitchSwingFlags = [];

      for (int i = 0; i < loadedNumberOfMatches; i++) {
        // Use games[i] if available, otherwise fallback to default
        final game = (games.length > i) ? games[i] as Map<String, dynamic> : {};
        loadedGameType.add(game['gameType'] ?? null);
        loadedLocationControllers
            .add(TextEditingController(text: game['location'] ?? ''));
        loadedOpponentControllers
            .add(TextEditingController(text: game['opponent'] ?? ''));
        loadedStealsControllers.add(
            TextEditingController(text: (game['steals']?.toString() ?? '')));
        loadedRbisControllers
            .add(TextEditingController(text: (game['rbis']?.toString() ?? '')));
        loadedRunsControllers
            .add(TextEditingController(text: (game['runs']?.toString() ?? '')));
        loadedMemoControllers
            .add(TextEditingController(text: game['memo'] ?? ''));
        loadedInningsThrowControllers.add(TextEditingController(
            text: (game['inningsThrow'] is num
                ? game['inningsThrow'].toInt().toString()
                : (game['inningsThrow']?.toString() ?? ''))));
        loadedStrikeoutsControllers.add(TextEditingController(
            text: (game['strikeouts']?.toString() ?? '')));
        loadedWalksControllers.add(
            TextEditingController(text: (game['walks']?.toString() ?? '')));
        loadedHitByPitchControllers.add(TextEditingController(
            text: (game['hitByPitch']?.toString() ?? '')));
        loadedEarnedRunsControllers.add(TextEditingController(
            text: (game['earnedRuns']?.toString() ?? '')));
        loadedRunsAllowedControllers.add(TextEditingController(
            text: (game['runsAllowed']?.toString() ?? '')));
        loadedHitsAllowedControllers.add(TextEditingController(
            text: (game['hitsAllowed']?.toString() ?? '')));
        loadedPutoutsControllers.add(
            TextEditingController(text: (game['putouts']?.toString() ?? '')));
        loadedAssistsControllers.add(
            TextEditingController(text: (game['assists']?.toString() ?? '')));
        loadedErrorsControllers.add(
            TextEditingController(text: (game['errors']?.toString() ?? '')));
        loadedCaughtStealingByRunnerControllers.add(TextEditingController(
            text: (game['caughtStealingByRunner']?.toString() ?? '')));
        loadedCaughtStealingControllers.add(TextEditingController(
            text: (game['caughtStealing']?.toString() ?? '')));
        loadedStolenBaseAttemptsControllers.add(TextEditingController(
            text: (game['stolenBaseAttempts']?.toString() ?? '')));
        loadedStealsAttemptsControllers.add(TextEditingController(
            text: (game['stealsAttempts']?.toString() ?? '')));
        loadedHomeRunsAllowedControllers.add(TextEditingController(
            text: (game['homeRunsAllowed']?.toString() ?? '')));
        loadedPitchCountControllers.add(TextEditingController(
            text: (game['pitchCount']?.toString() ?? '')));
        loadedResultList.add(game['resultGame'] ?? null);
        loadedOutFractionList.add(game['outFraction']?.toString());
        // loadedOutFractionList.add(game['outFraction'] ?? null);
        loadedAppearanceType.add(game['appearanceType'] ?? null);
        loadedIsCompleteGame.add(game['isCompleteGame'] ?? false);
        loadedIsShutoutGame.add(game['isShutoutGame'] ?? false);
        loadedIsSave.add(game['isSave'] ?? false);
        loadedIsHold.add(game['isHold'] ?? false);
        loadedIsAppearanceSelected.add(false); // UI flag, set false by default
        loadedBattersFacedControllers.add(TextEditingController(
            text: (game['battersFaced']?.toString() ?? '')));
        // atBatList and _atBatControllers
        int atBat = 0;
        if (game['atBats'] != null && game['atBats'] is List) {
          atBat = (game['atBats'] as List).length;
        }
        loadedAtBatList.add(atBat);
        loadedAtBatControllers.add(
            TextEditingController(text: atBat > 0 ? atBat.toString() : ''));
        // Restore per-at-bat fields
        List<String?> leftList = [];
        List<String?> rightList = [];
        List<String?> buntDetailList = [];
        List<TextEditingController> swingList = [];
        List<TextEditingController> missSwingList = [];
        List<TextEditingController> batterPitchCountList = [];
        List<bool> firstPitchSwingList = [];
        if (game['atBats'] != null && game['atBats'] is List) {
          for (var ab in (game['atBats'] as List)) {
            leftList.add(ab['position'] ?? null);
            rightList.add(ab['result'] ?? null);
            buntDetailList.add(ab['buntDetail'] ?? null);
            swingList.add(TextEditingController(
                text: (ab['swingCount']?.toString() ?? '')));
            missSwingList.add(TextEditingController(
                text: (ab['missSwingCount']?.toString() ?? '')));
            batterPitchCountList.add(TextEditingController(
                text: (ab['batterPitchCount']?.toString() ?? '')));
            firstPitchSwingList.add(ab['firstPitchSwing'] ?? false);
          }
        }
        loadedSelectedLeftList.add(leftList);
        loadedSelectedRightList.add(rightList);
        loadedSelectedBuntDetail.add(buntDetailList);
        loadedSwingControllers.add(swingList);
        loadedMissSwingControllers.add(missSwingList);
        loadedBatterPitchCountControllers.add(batterPitchCountList);
        loadedFirstPitchSwingFlags.add(firstPitchSwingList);
      }

      setState(() {
        numberOfMatches = loadedNumberOfMatches;
        _selectedGameType
          ..clear()
          ..addAll(loadedGameType);
        _locationControllers
          ..clear()
          ..addAll(loadedLocationControllers);
        _opponentControllers
          ..clear()
          ..addAll(loadedOpponentControllers);
        _stealsControllers
          ..clear()
          ..addAll(loadedStealsControllers);
        _rbisControllers
          ..clear()
          ..addAll(loadedRbisControllers);
        _runsControllers
          ..clear()
          ..addAll(loadedRunsControllers);
        _memoControllers
          ..clear()
          ..addAll(loadedMemoControllers);
        _inningsThrowControllers
          ..clear()
          ..addAll(loadedInningsThrowControllers);
        _strikeoutsControllers
          ..clear()
          ..addAll(loadedStrikeoutsControllers);
        _walksControllers
          ..clear()
          ..addAll(loadedWalksControllers);
        _hitByPitchControllers
          ..clear()
          ..addAll(loadedHitByPitchControllers);
        _earnedRunsControllers
          ..clear()
          ..addAll(loadedEarnedRunsControllers);
        _runsAllowedControllers
          ..clear()
          ..addAll(loadedRunsAllowedControllers);
        _hitsAllowedControllers
          ..clear()
          ..addAll(loadedHitsAllowedControllers);
        _putoutsControllers
          ..clear()
          ..addAll(loadedPutoutsControllers);
        _assistsControllers
          ..clear()
          ..addAll(loadedAssistsControllers);
        _errorsControllers
          ..clear()
          ..addAll(loadedErrorsControllers);
        _caughtStealingByRunnerControllers
          ..clear()
          ..addAll(loadedCaughtStealingByRunnerControllers);
        _caughtStealingControllers
          ..clear()
          ..addAll(loadedCaughtStealingControllers);
        _stolenBaseAttemptsControllers
          ..clear()
          ..addAll(loadedStolenBaseAttemptsControllers);
        _stealsAttemptsControllers
          ..clear()
          ..addAll(loadedStealsAttemptsControllers);
        _homeRunsAllowedControllers
          ..clear()
          ..addAll(loadedHomeRunsAllowedControllers);
        _pitchCountControllers
          ..clear()
          ..addAll(loadedPitchCountControllers);
        _resultList
          ..clear()
          ..addAll(loadedResultList);
        _outFractionList
          ..clear()
          ..addAll(loadedOutFractionList);
        _selectedAppearanceType
          ..clear()
          ..addAll(loadedAppearanceType);
        _isCompleteGame
          ..clear()
          ..addAll(loadedIsCompleteGame);
        _isShutoutGame
          ..clear()
          ..addAll(loadedIsShutoutGame);
        _isSave
          ..clear()
          ..addAll(loadedIsSave);
        _isHold
          ..clear()
          ..addAll(loadedIsHold);
        _isAppearanceSelected
          ..clear()
          ..addAll(loadedIsAppearanceSelected);
        _battersFacedControllers
          ..clear()
          ..addAll(loadedBattersFacedControllers);
        atBatList
          ..clear()
          ..addAll(loadedAtBatList);
        _atBatControllers
          ..clear()
          ..addAll(loadedAtBatControllers);
        _selectedLeftList
          ..clear()
          ..addAll(loadedSelectedLeftList);
        _selectedRightList
          ..clear()
          ..addAll(loadedSelectedRightList);
        _selectedBuntDetail
          ..clear()
          ..addAll(loadedSelectedBuntDetail);
        _swingControllers
          ..clear()
          ..addAll(loadedSwingControllers);
        _missSwingControllers
          ..clear()
          ..addAll(loadedMissSwingControllers);
        _batterPitchCountControllers
          ..clear()
          ..addAll(loadedBatterPitchCountControllers);
        _firstPitchSwingFlags
          ..clear()
          ..addAll(loadedFirstPitchSwingFlags);
      });
    }
  }

  Future<void> _initializeFields() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tentative')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final docData = snapshot.docs.first.data();
      // 仮保存データの形式により'data'キーの有無をチェック
      final data = docData['data'] ?? docData;
      if (mounted) {
        setState(() {
          // 試合数
          numberOfMatches = data['games'] != null ? data['games'].length : 1;
          // ポジションは前画面から渡されたもの(widget.positions)を優先し、
          // tentative からは上書きしない
          // ゲームタイプ
          _selectedGameType.clear();
          if (data['games'] != null) {
            for (var g in data['games']) {
              _selectedGameType.add(g['gameType']);
            }
          } else if (data['selectedGameType'] != null) {
            _selectedGameType
                .addAll(List<String?>.from(data['selectedGameType']));
          }
          // 他のフィールドも同様に可能な限り復元
          // チーム・場所・日付
          // _selectedTeam
          if (data['selectedTeam'] != null) {
            _selectedTeam.clear();
            _selectedTeam.addAll(List<String?>.from(data['selectedTeam']));
          }
          // _selectedLocation
          if (data['selectedLocation'] != null) {
            _selectedLocation.clear();
            _selectedLocation
                .addAll(List<String?>.from(data['selectedLocation']));
          }
          // _selectedDate
          if (data['selectedDate'] != null) {
            _selectedDate.clear();
            _selectedDate.addAll(List<DateTime?>.from(
                (data['selectedDate'] as List)
                    .map((ts) => ts is Timestamp ? ts.toDate() : ts)));
          }
          // _gameControllers
          if (data['gameControllers'] != null) {
            _gameControllers.clear();
            _gameControllers.addAll((data['gameControllers'] as List)
                .map<TextEditingController>(
                    (text) => TextEditingController(text: text))
                .toList());
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _eventController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Widget buildCupertinoPickerField({
    required BuildContext context,
    required List<String> options,
    required String? selectedValue,
    required String hintText,
    required void Function(String) onSelected,
  }) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
        Future.delayed(const Duration(milliseconds: 100), () {
          _showCupertinoPicker(
            context,
            options,
            selectedValue ?? hintText,
            onSelected,
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedValue ?? hintText,
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildGameTypePicker(int index, StateSetter setState) {
    return buildCupertinoPickerField(
      context: context,
      options: ['練習試合','公式戦'],
      selectedValue: _selectedGameType[index],
      hintText: '試合タイプを選択',
      onSelected: (selected) {
        setState(() {
          _selectedGameType[index] = selected;
        });
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

  final List<TextEditingController> _atBatControllers = [];
  List<int> atBatList = [];
  final List<String?> _selectedGameType = [];

  // 以下、仮保存復元用の追加フィールド
  final List<String?> _selectedTeam = [];
  final List<String?> _selectedLocation = [];
  final List<DateTime?> _selectedDate = [];
  final List<TextEditingController> _gameControllers = [];

  final List<List<String?>> _selectedLeftList = [];
  final List<List<String?>> _selectedRightList = [];

  final List<List<String?>> _selectedBuntDetail = [];
  final List<List<TextEditingController>> _swingControllers = [];
  final List<List<TextEditingController>> _missSwingControllers = [];
  final List<List<TextEditingController>> _batterPitchCountControllers = [];

  final List<TextEditingController> _locationControllers = [];
  final List<TextEditingController> _opponentControllers = [];
  final List<TextEditingController> _stealsControllers = [];
  final List<TextEditingController> _rbisControllers = [];
  final List<TextEditingController> _runsControllers = [];
  final List<TextEditingController> _memoControllers = [];

  final List<TextEditingController> _stealsAttemptsControllers = [];
  final List<TextEditingController> _caughtStealingByRunnerControllers = [];
  final List<TextEditingController> _caughtStealingControllers = [];
  final List<TextEditingController> _stolenBaseAttemptsControllers = [];

  final List<TextEditingController> _inningsThrowControllers = [];
  final List<TextEditingController> _strikeoutsControllers = [];
  final List<TextEditingController> _walksControllers = [];
  final List<TextEditingController> _hitByPitchControllers = [];
  final List<TextEditingController> _earnedRunsControllers = [];
  final List<TextEditingController> _runsAllowedControllers = [];
  final List<TextEditingController> _hitsAllowedControllers = [];
  final List<TextEditingController> _homeRunsAllowedControllers = [];
  final List<TextEditingController> _pitchCountControllers = [];
  final List<String?> _resultList = [];
  final List<String?> _outFractionList = [];
  final List<TextEditingController> _putoutsControllers = [];
  final List<TextEditingController> _assistsControllers = [];
  final List<TextEditingController> _errorsControllers = [];
  final List<String?> _selectedAppearanceType = [];
  final List<bool?> _isCompleteGame = [];
  final List<bool?> _isShutoutGame = [];
  final List<bool?> _isSave = [];
  final List<bool?> _isHold = [];
  final List<bool> _isAppearanceSelected = []; // UI表示フラグ
  final List<TextEditingController> _battersFacedControllers = [];
  final List<List<bool>> _firstPitchSwingFlags = [];

  Future<void> _saveDataToFirestore() async {
    setState(() {
      _isSaving = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final String uid = user.uid;

      for (int matchIndex = 0; matchIndex < numberOfMatches; matchIndex++) {
        // 試合タイプが選択されていない場合、スキップ
        if (_selectedGameType[matchIndex] == null ||
            _selectedGameType[matchIndex]!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('試合タイプを選択してください')),
          );
          continue;
        }
        print('🚩 _saveDataToFirestore: start building gameData for matchIndex=$matchIndex, gameType=${_selectedGameType[matchIndex]}');

        // 各試合の共通情報を取得
        final location = _locationControllers[matchIndex].text.isNotEmpty
            ? _locationControllers[matchIndex].text
            : '';
        final opponent = _opponentControllers[matchIndex].text.isNotEmpty
            ? _opponentControllers[matchIndex].text
            : '';
        final steals = int.tryParse(_stealsControllers[matchIndex].text) ?? 0;
        final rbis = int.tryParse(_rbisControllers[matchIndex].text) ?? 0;
        final runs = int.tryParse(_runsControllers[matchIndex].text) ?? 0;
        final memo = _memoControllers[matchIndex].text.isNotEmpty
            ? _memoControllers[matchIndex].text
            : '';

        // 打席データをリストにまとめる
        List<Map<String, dynamic>> atBats = [];

        // 打席数が0の場合、データを送信しない
        if (atBatList[matchIndex] > 0) {
          for (int i = 0; i < atBatList[matchIndex]; i++) {
            final position = _selectedLeftList[matchIndex][i] ?? '';
            final result = _selectedRightList[matchIndex][i] ?? '';

            // 各打席のデータをリストに追加
            atBats.add({
              'at_bat': i + 1,
              'position': position,
              'result': result,
              'buntDetail': _selectedBuntDetail[matchIndex][i],
              'swingCount':
                  int.tryParse(_swingControllers[matchIndex][i].text) ?? 0,
              'missSwingCount':
                  int.tryParse(_missSwingControllers[matchIndex][i].text) ?? 0,
              'batterPitchCount': int.tryParse(
                      _batterPitchCountControllers[matchIndex][i].text) ??
                  0,
              'firstPitchSwing': _firstPitchSwingFlags[matchIndex][i],
            });
          }
        }

        DateTime selectedDate = _selectedDay ?? DateTime.now();
        DateTime gameDateUTC = DateTime.utc(
            selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);

        try {
          // HttpsCallableを取得
          HttpsCallable callable =
              FirebaseFunctions.instance.httpsCallable('addGameData');

          final Map<String, dynamic> gameData = {
            'uid': uid,
            'positions': _positions,
            'matchIndex': matchIndex,
            'gameDate': gameDateUTC.toIso8601String(),
            'gameType': _selectedGameType[matchIndex],
            'location': location,
            'opponent': opponent,
            'steals': steals,
            'rbis': rbis,
            'runs': runs,
            'memo': memo,
            'resultGame': _resultList[matchIndex] ?? '',
            'outFraction': _outFractionList[matchIndex] ?? '',
            'putouts': int.tryParse(_putoutsControllers[matchIndex].text) ?? 0,
            'assists': int.tryParse(_assistsControllers[matchIndex].text) ?? 0,
            'errors': int.tryParse(_errorsControllers[matchIndex].text) ?? 0,
            'caughtStealingByRunner': int.tryParse(
                    _caughtStealingByRunnerControllers[matchIndex].text) ??
                0,
            'stealsAttempts':
                int.tryParse(_stealsAttemptsControllers[matchIndex].text) ?? 0,
            'atBats': atBats,
          };

          if (_positions.contains('捕手')) {
            gameData.addAll({
              'caughtStealing':
                  int.tryParse(_caughtStealingControllers[matchIndex].text) ??
                      0,
              'stolenBaseAttempts': int.tryParse(
                      _stolenBaseAttemptsControllers[matchIndex].text) ??
                  0,
            });
          }

          if (_positions.contains('投手')) {
            gameData.addAll({
              'inningsThrow':
                  int.tryParse(_inningsThrowControllers[matchIndex].text) ?? 0,
              'strikeouts':
                  int.tryParse(_strikeoutsControllers[matchIndex].text) ?? 0,
              'walks': int.tryParse(_walksControllers[matchIndex].text) ?? 0,
              'hitByPitch':
                  int.tryParse(_hitByPitchControllers[matchIndex].text) ?? 0,
              'earnedRuns':
                  int.tryParse(_earnedRunsControllers[matchIndex].text) ?? 0,
              'runsAllowed':
                  int.tryParse(_runsAllowedControllers[matchIndex].text) ?? 0,
              'hitsAllowed':
                  int.tryParse(_hitsAllowedControllers[matchIndex].text) ?? 0,
              'isCompleteGame': _isCompleteGame[matchIndex] ?? false,
              'isShutoutGame': _isShutoutGame[matchIndex] ?? false,
              'isSave': _isSave[matchIndex] ?? false,
              'isHold': _isHold[matchIndex] ?? false,
              'appearanceType': _selectedAppearanceType[matchIndex] ?? '',
              'battersFaced':
                  int.tryParse(_battersFacedControllers[matchIndex].text) ?? 0,
              'homeRunsAllowed':
                  int.tryParse(_homeRunsAllowedControllers[matchIndex].text) ??
                      0,
              'pitchCount':
                  int.tryParse(_pitchCountControllers[matchIndex].text) ?? 0,
            });
          }

          final response = await callable.call(gameData);

          print('🚀 _saveDataToFirestore: sending gameData for matchIndex=$matchIndex → $gameData');

          print("Cloud Functions response: ${response.data}");
        } catch (e) {
          print("Error saving game data: $e");
        }
      }
    }

    setState(() {
      _isSaving = false;
    });
  }

  /// 仮保存データをFirestoreに保存
  Future<void> saveTentativeData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final data = _buildGameData();

      print('📝 saveTentativeData: uid=$uid, data keys=${data.keys.toList()}');

    final tentativeCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tentative');

    final existingDocs = await tentativeCollection
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (existingDocs.docs.isNotEmpty) {
      // Overwrite the latest document
      final latestDocId = existingDocs.docs.first.id;
      await tentativeCollection.doc(latestDocId).set({
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Add new document
      await tentativeCollection.add({
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('仮保存しました')));
  }

  /// 仮保存データを削除
  Future<void> deleteTentativeData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tentative')
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// 現在のフォームデータをMapとして構築
  Map<String, dynamic> _buildGameData() {
    // ここは _saveDataToFirestore() の gameData 構築ロジックを参考に必要な情報をまとめる
    // 複数試合分をまとめて保存する
    List<Map<String, dynamic>> games = [];
    final user = FirebaseAuth.instance.currentUser;
    final String uid = user?.uid ?? '';
    for (int matchIndex = 0; matchIndex < numberOfMatches; matchIndex++) {
      // 各試合の共通情報を取得
      final location = _locationControllers.length > matchIndex
          ? _locationControllers[matchIndex].text
          : '';
      final opponent = _opponentControllers.length > matchIndex
          ? _opponentControllers[matchIndex].text
          : '';
      final steals = _stealsControllers.length > matchIndex
          ? int.tryParse(_stealsControllers[matchIndex].text) ?? 0
          : 0;
      final rbis = _rbisControllers.length > matchIndex
          ? int.tryParse(_rbisControllers[matchIndex].text) ?? 0
          : 0;
      final runs = _runsControllers.length > matchIndex
          ? int.tryParse(_runsControllers[matchIndex].text) ?? 0
          : 0;
      final memo = _memoControllers.length > matchIndex &&
              _memoControllers[matchIndex].text.isNotEmpty
          ? _memoControllers[matchIndex].text
          : '';

      List<Map<String, dynamic>> atBats = [];
      if (atBatList.length > matchIndex && atBatList[matchIndex] > 0) {
        for (int i = 0; i < atBatList[matchIndex]; i++) {
          final position = (_selectedLeftList.length > matchIndex &&
                  _selectedLeftList[matchIndex].length > i)
              ? _selectedLeftList[matchIndex][i] ?? ''
              : '';
          final result = (_selectedRightList.length > matchIndex &&
                  _selectedRightList[matchIndex].length > i)
              ? _selectedRightList[matchIndex][i] ?? ''
              : '';
          atBats.add({
            'at_bat': i + 1,
            'position': position,
            'result': result,
            'buntDetail': (_selectedBuntDetail.length > matchIndex &&
                    _selectedBuntDetail[matchIndex].length > i)
                ? _selectedBuntDetail[matchIndex][i]
                : null,
            'swingCount': (_swingControllers.length > matchIndex &&
                    _swingControllers[matchIndex].length > i)
                ? int.tryParse(_swingControllers[matchIndex][i].text) ?? 0
                : 0,
            'missSwingCount': (_missSwingControllers.length > matchIndex &&
                    _missSwingControllers[matchIndex].length > i)
                ? int.tryParse(_missSwingControllers[matchIndex][i].text) ?? 0
                : 0,
            'batterPitchCount':
                (_batterPitchCountControllers.length > matchIndex &&
                        _batterPitchCountControllers[matchIndex].length > i)
                    ? int.tryParse(
                            _batterPitchCountControllers[matchIndex][i].text) ??
                        0
                    : 0,
            'firstPitchSwing': (_firstPitchSwingFlags.length > matchIndex &&
                    _firstPitchSwingFlags[matchIndex].length > i)
                ? _firstPitchSwingFlags[matchIndex][i]
                : false,
          });
        }
      }

      DateTime selectedDate = _selectedDay ?? DateTime.now();
      DateTime gameDateUTC = DateTime.utc(
          selectedDate.year, selectedDate.month, selectedDate.day, 0, 0, 0);

      final Map<String, dynamic> gameData = {
        'uid': uid,
        'positions': _positions,
        'matchIndex': matchIndex,
        'gameDate': gameDateUTC.toIso8601String(),
        'gameType': _selectedGameType.length > matchIndex
            ? _selectedGameType[matchIndex]
            : null,
        'location': location,
        'opponent': opponent,
        'steals': steals,
        'rbis': rbis,
        'runs': runs,
        'memo': memo,
        'resultGame': _resultList.length > matchIndex
            ? _resultList[matchIndex] ?? ''
            : '',
        'outFraction': _outFractionList.length > matchIndex
            ? _outFractionList[matchIndex] ?? ''
            : '',
        'putouts': _putoutsControllers.length > matchIndex
            ? int.tryParse(_putoutsControllers[matchIndex].text) ?? 0
            : 0,
        'assists': _assistsControllers.length > matchIndex
            ? int.tryParse(_assistsControllers[matchIndex].text) ?? 0
            : 0,
        'errors': _errorsControllers.length > matchIndex
            ? int.tryParse(_errorsControllers[matchIndex].text) ?? 0
            : 0,
        'caughtStealingByRunner':
            _caughtStealingByRunnerControllers.length > matchIndex
                ? int.tryParse(
                        _caughtStealingByRunnerControllers[matchIndex].text) ??
                    0
                : 0,
        'stealsAttempts': _stealsAttemptsControllers.length > matchIndex
            ? int.tryParse(_stealsAttemptsControllers[matchIndex].text) ?? 0
            : 0,
        'atBats': atBats,
      };

      if (_positions.contains('捕手')) {
        gameData.addAll({
          'caughtStealing': _caughtStealingControllers.length > matchIndex
              ? int.tryParse(_caughtStealingControllers[matchIndex].text) ?? 0
              : 0,
          'stolenBaseAttempts': _stolenBaseAttemptsControllers.length >
                  matchIndex
              ? int.tryParse(_stolenBaseAttemptsControllers[matchIndex].text) ??
                  0
              : 0,
        });
      }

      if (_positions.contains('投手')) {
        gameData.addAll({
          'inningsThrow': _inningsThrowControllers.length > matchIndex
              ? int.tryParse(_inningsThrowControllers[matchIndex].text) ?? 0
              : 0,
          'strikeouts': _strikeoutsControllers.length > matchIndex
              ? int.tryParse(_strikeoutsControllers[matchIndex].text) ?? 0
              : 0,
          'walks': _walksControllers.length > matchIndex
              ? int.tryParse(_walksControllers[matchIndex].text) ?? 0
              : 0,
          'hitByPitch': _hitByPitchControllers.length > matchIndex
              ? int.tryParse(_hitByPitchControllers[matchIndex].text) ?? 0
              : 0,
          'earnedRuns': _earnedRunsControllers.length > matchIndex
              ? int.tryParse(_earnedRunsControllers[matchIndex].text) ?? 0
              : 0,
          'runsAllowed': _runsAllowedControllers.length > matchIndex
              ? int.tryParse(_runsAllowedControllers[matchIndex].text) ?? 0
              : 0,
          'hitsAllowed': _hitsAllowedControllers.length > matchIndex
              ? int.tryParse(_hitsAllowedControllers[matchIndex].text) ?? 0
              : 0,
          'isCompleteGame': _isCompleteGame.length > matchIndex
              ? _isCompleteGame[matchIndex] ?? false
              : false,
          'isShutoutGame': _isShutoutGame.length > matchIndex
              ? _isShutoutGame[matchIndex] ?? false
              : false,
          'isSave': _isSave.length > matchIndex
              ? _isSave[matchIndex] ?? false
              : false,
          'isHold': _isHold.length > matchIndex
              ? _isHold[matchIndex] ?? false
              : false,
          'appearanceType': _selectedAppearanceType.length > matchIndex
              ? _selectedAppearanceType[matchIndex] ?? ''
              : '',
          'battersFaced': _battersFacedControllers.length > matchIndex
              ? int.tryParse(_battersFacedControllers[matchIndex].text) ?? 0
              : 0,
          'homeRunsAllowed': _homeRunsAllowedControllers.length > matchIndex
              ? int.tryParse(_homeRunsAllowedControllers[matchIndex].text) ?? 0
              : 0,
          'pitchCount': _pitchCountControllers.length > matchIndex
              ? int.tryParse(_pitchCountControllers[matchIndex].text) ?? 0
              : 0,
        });
      }

      games.add(gameData);
    }
    return {
      'games': games,
      'numberOfMatches': games.length,
      'positions': _positions,
      'savedAt': Timestamp.now(),
    };
  }

  void _resetData() {
    setState(() {
      numberOfMatches = 0;
      errorMessage = null;
    });
    // リセットしたいリストやコントローラを初期化
    numberOfMatches = 0;
    _selectedGameType.clear();
    _locationControllers.clear();
    _opponentControllers.clear();
    _stealsControllers.clear();
    _rbisControllers.clear();
    _runsControllers.clear();
    _memoControllers.clear();
    _atBatControllers.clear();
    _selectedLeftList.clear();
    _selectedRightList.clear();
    _inningsThrowControllers.clear();
    _strikeoutsControllers.clear();
    _walksControllers.clear();
    _hitByPitchControllers.clear();
    _earnedRunsControllers.clear();
    _runsAllowedControllers.clear();
    _hitsAllowedControllers.clear();
    _resultList.clear();
    _outFractionList.clear();
    _putoutsControllers.clear();
    _assistsControllers.clear();
    _errorsControllers.clear();
    atBatList.clear();
    _eventController.clear();
    _selectedAppearanceType.clear();
    _isAppearanceSelected.clear();
    _isCompleteGame.clear();
    _isShutoutGame.clear();
    _isSave.clear();
    _isHold.clear();
    _battersFacedControllers.clear();
  }

  List<Widget> _atBatGameWidgets(
      int matchIndex, int atBat, StateSetter setState) {
    // Initialize the lists if they are not long enough
    while (_selectedLeftList.length <= matchIndex) {
      _selectedLeftList.add([]);
      _selectedRightList.add([]);
      _selectedBuntDetail.add([]);
    }

    while (_selectedLeftList[matchIndex].length < atBat) {
      _selectedLeftList[matchIndex].add(null);
      _selectedRightList[matchIndex].add(null);
      _selectedBuntDetail[matchIndex].add(null);
    }

    while (_selectedBuntDetail.length <= matchIndex) {
      _selectedBuntDetail.add([]);
    }
    while (_selectedBuntDetail[matchIndex].length < atBat) {
      _selectedBuntDetail[matchIndex].add(null);
    }

    while (_swingControllers.length <= matchIndex) _swingControllers.add([]);
    while (_swingControllers[matchIndex].length < atBat)
      _swingControllers[matchIndex].add(TextEditingController());

    while (_missSwingControllers.length <= matchIndex)
      _missSwingControllers.add([]);
    while (_missSwingControllers[matchIndex].length < atBat)
      _missSwingControllers[matchIndex].add(TextEditingController());

    while (_batterPitchCountControllers.length <= matchIndex)
      _batterPitchCountControllers.add([]);
    while (_batterPitchCountControllers[matchIndex].length < atBat)
      _batterPitchCountControllers[matchIndex].add(TextEditingController());

    while (_firstPitchSwingFlags.length <= matchIndex) {
      _firstPitchSwingFlags.add([]);
    }
    while (_firstPitchSwingFlags[matchIndex].length < atBat) {
      _firstPitchSwingFlags[matchIndex].add(false);
    }

    return List.generate(atBat, (i) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${i + 1}打席目',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
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
                // 守の選択肢
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).requestFocus(FocusNode());
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _showCupertinoPicker(
                        context,
                        _rightOptions.keys.toList(), // 守の選択肢
                        _selectedLeftList[matchIndex][i] ?? '',
                        (selected) {
                          setState(() {
                            _selectedLeftList[matchIndex][i] = selected;
                            _selectedRightList[matchIndex][i] =
                                null; // 左の選択が変わったら右をリセット
                          });
                        },
                      );
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Colors.grey, width: 1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedLeftList[matchIndex][i] ?? '守',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // 打球の選択肢
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).requestFocus(FocusNode());
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _showCupertinoPicker(
                        context,
                        _selectedLeftList[matchIndex][i] != null
                            ? _rightOptions[_selectedLeftList[matchIndex][i]] ??
                                []
                            : [],
                        _selectedRightList[matchIndex][i] ?? '',
                        (selected) {
                          setState(() {
                            _selectedRightList[matchIndex][i] = selected;
                          });
                        },
                      );
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Colors.grey, width: 1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedRightList[matchIndex][i] ?? '打球',
                          style: const TextStyle(fontSize: 16),
                        ),
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
                  ChoiceChip(
                    label: const Text('犠打成功'),
                    selected: _selectedBuntDetail[matchIndex][i] == '犠打成功',
                    onSelected: (_) {
                      setState(() {
                        _selectedBuntDetail[matchIndex][i] = '犠打成功';
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('犠打失敗'),
                    selected: _selectedBuntDetail[matchIndex][i] == '犠打失敗',
                    onSelected: (_) {
                      setState(() {
                        _selectedBuntDetail[matchIndex][i] = '犠打失敗';
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('バント併殺'),
                    selected: _selectedBuntDetail[matchIndex][i] == 'バント併殺',
                    onSelected: (_) {
                      setState(() {
                        _selectedBuntDetail[matchIndex][i] = 'バント併殺';
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('スクイズ成功'),
                    selected: _selectedBuntDetail[matchIndex][i] == 'スクイズ成功',
                    onSelected: (_) {
                      setState(() {
                        _selectedBuntDetail[matchIndex][i] = 'スクイズ成功';
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('スクイズ失敗'),
                    selected: _selectedBuntDetail[matchIndex][i] == 'スクイズ失敗',
                    onSelected: (_) {
                      setState(() {
                        _selectedBuntDetail[matchIndex][i] = 'スクイズ失敗';
                      });
                    },
                  ),
                  if (_selectedLeftList[matchIndex][i] == '一' ||
                      _selectedLeftList[matchIndex][i] == '三' ||
                      _selectedLeftList[matchIndex][i] == '捕')
                    ChoiceChip(
                      label: const Text('スリーバント失敗'),
                      selected:
                          _selectedBuntDetail[matchIndex][i] == 'スリーバント失敗',
                      onSelected: (_) {
                        setState(() {
                          _selectedBuntDetail[matchIndex][i] = 'スリーバント失敗';
                        });
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('スイング数', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _swingControllers[matchIndex][i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ),
                const SizedBox(width: 20),
                const Text('空振り数', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _missSwingControllers[matchIndex][i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Row(
                  children: [
                    const Text('球数', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 50,
                      child: TextField(
                        controller: _batterPitchCountControllers[matchIndex][i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(hintText: '0'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Row(
                  children: [
                    const Text('初球スイング', style: TextStyle(fontSize: 16)),
                    Checkbox(
                      value: _firstPitchSwingFlags[matchIndex][i],
                      onChanged: (value) {
                        setState(() {
                          _firstPitchSwingFlags[matchIndex][i] = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _generateGameWidgets(int numberOfMatches, StateSetter setState) {
    List<Widget> gameWidgets = [];
    for (int i = 0; i < numberOfMatches; i++) {
      while (_caughtStealingByRunnerControllers.length <= i) {
        _caughtStealingByRunnerControllers.add(TextEditingController());
      }

      while (_caughtStealingControllers.length <= i) {
        _caughtStealingControllers.add(TextEditingController());
      }
      while (_stolenBaseAttemptsControllers.length <= i) {
        _stolenBaseAttemptsControllers.add(TextEditingController());
      }
      while (_stealsAttemptsControllers.length <= i) {
        _stealsAttemptsControllers.add(TextEditingController());
      }
      // ゲームタイプリストが足りない場合、初期化
      if (_selectedGameType.length <= i) {
        _selectedGameType.add(null); // ゲームタイプを初期化
      }

      if (_resultList.length <= i) {
        _resultList.add(null); // 勝敗を初期化
      }

      if (_outFractionList.length <= i) {
        _outFractionList.add(null); // 勝敗を初期化
      }

      if (_selectedAppearanceType.length <= i) {
        _selectedAppearanceType.add(null); // 登板タイプを初期化
      }

      if (_isAppearanceSelected.length <= i) {
        _isAppearanceSelected.add(false); // 最初は非表示
      }

      if (_isCompleteGame.length <= i) {
        _isCompleteGame.add(false); // 完投初期化
      }

      if (_isShutoutGame.length <= i) {
        _isShutoutGame.add(false); // 完封初期化
      }

      if (_isSave.length <= i) {
        _isSave.add(false); // セーブ初期化
      }

      if (_isHold.length <= i) {
        _isHold.add(false); // ホールド初期化
      }

      if (_battersFacedControllers.length <= i) {
        _battersFacedControllers.add(TextEditingController());
      }

      if (_homeRunsAllowedControllers.length <= i) {
        _homeRunsAllowedControllers.add(TextEditingController());
      }
      if (_pitchCountControllers.length <= i) {
        _pitchCountControllers.add(TextEditingController());
      }

      // データコントローラの初期化
      if (atBatList.length <= i) {
        atBatList.add(0);
      }
      while (_locationControllers.length <= i) {
        _locationControllers.add(TextEditingController());
        _opponentControllers.add(TextEditingController());
        _stealsControllers.add(TextEditingController());
        _rbisControllers.add(TextEditingController());
        _runsControllers.add(TextEditingController());
        _memoControllers.add(TextEditingController());
        _inningsThrowControllers.add(TextEditingController());
        _strikeoutsControllers.add(TextEditingController());
        _walksControllers.add(TextEditingController());
        _hitByPitchControllers.add(TextEditingController());
        _earnedRunsControllers.add(TextEditingController());
        _runsAllowedControllers.add(TextEditingController());
        _hitsAllowedControllers.add(TextEditingController());
        _putoutsControllers.add(TextEditingController());
        _assistsControllers.add(TextEditingController());
        _errorsControllers.add(TextEditingController());
      }
      while (_atBatControllers.length <= i) {
        _atBatControllers.add(TextEditingController());
      }
      gameWidgets.add(Container(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            const Text(
              '試合タイプは必須項目',
              style: TextStyle(fontSize: 10, color: Colors.red),
            ),
            const Text(
              '0の場合は記入しなくてもよい',
              style: TextStyle(fontSize: 10, color: Colors.red),
            ),
            Text(
              '${i + 1}試合目',
              style: const TextStyle(
                fontSize: 40,
              ),
            ),
            Container(margin: const EdgeInsets.only(top: 5)),
            _buildGameTypePicker(i, setState),
            Container(margin: const EdgeInsets.only(top: 15)),
            Row(
              children: [
                const Text(
                  '場所',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 45),
                Expanded(
                  child: TextField(
                    controller: _locationControllers[i],
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Container(margin: const EdgeInsets.only(top: 15)),
            Row(
              children: [
                const Text(
                  '対戦相手',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _opponentControllers[i],
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Container(margin: const EdgeInsets.only(top: 30)),
            if (_positions.contains('投手'))
              const Row(
                children: [
                  Expanded(
                    child: Divider(
                      thickness: 1, // 線の太さ
                      color: Colors.black, // 線の色
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      '【投手】',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      thickness: 1,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            if (_positions.contains('投手'))
              Column(
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
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const PitcherInfoScreen()),
                              );
                            },
                            child: Row(
                              children: const [
                                Icon(Icons.help_outline, size: 14), // アイコン
                                SizedBox(width: 5),
                                Text(
                                  '投手について',
                                  style: TextStyle(
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
            // if (_isAppearanceSelected[i])
            if ((_selectedAppearanceType[i]?.isNotEmpty ?? false))
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '投球回',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _inningsThrowControllers[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
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
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '与四球',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _walksControllers[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text(
                            '与死球',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _hitByPitchControllers[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '失点',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _runsAllowedControllers[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text(
                            '自責点',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _earnedRunsControllers[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '被安打',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _hitsAllowedControllers[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text(
                            '奪三振',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _strikeoutsControllers[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '被本塁打',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _homeRunsAllowedControllers[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text(
                            '球数',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _pitchCountControllers[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        '対戦打者',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 5),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _battersFacedControllers[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Text(
                        '人',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 30),
            const Row(
              children: [
                Expanded(
                  child: Divider(
                    thickness: 1, // 線の太さ
                    color: Colors.black, // 線の色
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '【打者】',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    thickness: 1,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  '打席数',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _atBatControllers[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    onChanged: (value) {
                      setState(() {
                        atBatList[i] = int.tryParse(value) ?? 0;
                      });
                    },
                  ),
                ),
              ],
            ),
            Column(
              children: _atBatGameWidgets(i, atBatList[i], setState),
            ),
            Container(margin: const EdgeInsets.only(top: 15)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      '打点',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _rbisControllers[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text(
                      '得点',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _runsControllers[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  '盗塁企図数',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _stealsAttemptsControllers[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                      '盗塁成功',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _stealsControllers[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text(
                      '盗塁死',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _caughtStealingByRunnerControllers[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(margin: const EdgeInsets.only(top: 30)),
            const Row(
              children: [
                Expanded(
                  child: Divider(
                    thickness: 1, // 線の太さ
                    color: Colors.black, // 線の色
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '【守備】',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    thickness: 1,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '刺殺',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _putoutsControllers[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Text(
                  '捕殺',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _assistsControllers[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Text(
                  '失策',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _errorsControllers[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (_positions.contains('捕手'))
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '盗塁企図',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: TextField(
                        controller: _stolenBaseAttemptsControllers[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Text(
                      '盗塁刺',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: TextField(
                        controller: _caughtStealingControllers[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'メモ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _memoControllers[i],
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    maxLines: 3,
                    onChanged: (String value) {
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ));
    }
    return gameWidgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('試合入力'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0), // 右側に8pxの余白
            child: OutlinedButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                      await saveTentativeData();
                    },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              ),
              child: const Text(
                '仮保存',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '試合数',
                      style: TextStyle(fontSize: 30),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _eventController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          hintText: '0',
                        ),
                        style: const TextStyle(fontSize: 30),
                        onChanged: (value) {
                          setState(() {
                            numberOfMatches = int.tryParse(value) ?? 0;
                            while (_atBatControllers.length < numberOfMatches) {
                              _atBatControllers.add(TextEditingController());
                              atBatList.add(0);
                              _selectedLeftList.add([]);
                              _selectedRightList.add([]);
                            }

                            while (_selectedGameType.length < numberOfMatches) {
                              _selectedGameType.add(null);
                            }

                            // 減らす（重要）
                            while (_selectedGameType.length > numberOfMatches) {
                              _selectedGameType.removeLast();
                            }

                            while (_resultList.length > numberOfMatches) {
                              _resultList.removeLast();
                            }
                            while (_outFractionList.length > numberOfMatches) {
                              _outFractionList.removeLast();
                            }
                            while (_selectedAppearanceType.length >
                                numberOfMatches) {
                              _selectedAppearanceType.removeLast();
                            }
                            while (_isAppearanceSelected.length >
                                numberOfMatches) {
                              _isAppearanceSelected.removeLast();
                            }
                            while (_isCompleteGame.length > numberOfMatches) {
                              _isCompleteGame.removeLast();
                            }
                            while (_isShutoutGame.length > numberOfMatches) {
                              _isShutoutGame.removeLast();
                            }
                            while (_isSave.length > numberOfMatches) {
                              _isSave.removeLast();
                            }
                            while (_isHold.length > numberOfMatches) {
                              _isHold.removeLast();
                            }
                            while (_battersFacedControllers.length >
                                numberOfMatches) {
                              _battersFacedControllers.removeLast();
                            }

                            while (
                                _locationControllers.length > numberOfMatches) {
                              _locationControllers.removeLast();
                              _opponentControllers.removeLast();
                              _stealsControllers.removeLast();
                              _rbisControllers.removeLast();
                              _runsControllers.removeLast();
                              _memoControllers.removeLast();
                              _inningsThrowControllers.removeLast();
                              _strikeoutsControllers.removeLast();
                              _walksControllers.removeLast();
                              _hitByPitchControllers.removeLast();
                              _earnedRunsControllers.removeLast();
                              _runsAllowedControllers.removeLast();
                              _hitsAllowedControllers.removeLast();
                              _putoutsControllers.removeLast();
                              _assistsControllers.removeLast();
                              _errorsControllers.removeLast();
                            }

                            while (_atBatControllers.length > numberOfMatches) {
                              _atBatControllers.removeLast();
                              atBatList.removeLast();
                              _selectedLeftList.removeLast();
                              _selectedRightList.removeLast();
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  '※後から修正ができませんので、内容に誤りがないか十分ご確認ください。',
                  style: TextStyle(color: Colors.red, fontSize: 10),
                ),
                const SizedBox(height: 20),

                // 試合ごとの入力フォームを表示
                Column(
                  children: _generateGameWidgets(numberOfMatches, setState),
                ),

                const SizedBox(height: 30),

                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (numberOfMatches > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(150, 50),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () async {
                                bool hasMissingGameType =
                                    _selectedGameType.contains(null);
                                if (hasMissingGameType) {
                                  setState(() {
                                    errorMessage = '試合タイプを選択してください';
                                  });
                                } else {
                                  setState(() {
                                    _isSaving = true;
                                    errorMessage = null;
                                  });
                                  await deleteTentativeData();
                                  await _saveDataToFirestore();
                                  if (mounted) {
                                    setState(() {
                                      _isSaving = false;
                                    });
                                    Navigator.of(context).pop(true);
                                  }
                                }
                              },
                        child: _isSaving
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                      color: Colors.white),
                                  SizedBox(width: 10),
                                  Text("計算して保存しています..."),
                                ],
                              )
                            : const Text('保存'),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0
          ? Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: 44,
                color: Colors.grey[100],
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: const Text(
                        '完了',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
