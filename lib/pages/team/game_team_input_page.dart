import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class GameTeamInputPage extends StatefulWidget {
  final String teamId;
  final DateTime selectedDate;
  const GameTeamInputPage(
      {Key? key, required this.teamId, required this.selectedDate})
      : super(key: key);

  @override
  _GameTeamInputPageState createState() => _GameTeamInputPageState();
}

class _GameTeamInputPageState extends State<GameTeamInputPage> {
  bool _isSaving = false;

  int numberOfMatches = 0;
  final List<TextEditingController> _locationControllers = [];
  final List<TextEditingController> _opponentControllers = [];
  final List<String?> _selectedGameType = [];
  final List<TextEditingController> _scoreControllers = [];
  final List<TextEditingController> _runsAllowedControllers = [];
  final List<String?> _selectedResult = [];

  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDate;
  }

  Future<void> saveGamesToFunctions(
      String teamId, List<Map<String, dynamic>> games) async {
    try {
      // teamIdが文字列であることを確認
      final String teamIdStr = teamId.toString();
      print("Sending teamId: $teamIdStr (Type: ${teamId.runtimeType})");

      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('saveTeamGameData');
      final response = await callable.call(<String, dynamic>{
        'teamId': teamIdStr, // teamIdを文字列として送信
        'games': games,
      });

      // サーバーからのレスポンスをログに表示
      print("Games successfully saved: ${response.data}");
    } catch (e) {
      // エラーログを出力
      print("Failed to save games to functions: $e");
    }
  }

  Future<void> _saveDataToFirestore() async {
    final List<Map<String, dynamic>> games = [];

    // チームIDがnullまたは空文字の場合エラー処理を追加
    String teamIdString = widget.teamId;
    if (teamIdString.isEmpty) {
      print("Error: Team ID is invalid.");
      return; // 無効なteamIdが渡された場合は処理を中断
    }

    // ゲームデータの準備
    for (int i = 0; i < numberOfMatches; i++) {
      games.add({
        'game_date': _selectedDay?.toLocal().toIso8601String() ??
            DateTime.now().toLocal().toIso8601String(),
        'location': _locationControllers[i].text,
        'opponent': _opponentControllers[i].text,
        'game_type': _selectedGameType[i],
        'score': int.tryParse(_scoreControllers[i].text) ?? 0,
        'runs_allowed': int.tryParse(_runsAllowedControllers[i].text) ?? 0,
        'result': _selectedResult[i],
      });
    }

    // ゲームデータが準備できたことをログで確認
    print("Prepared ${games.length} game entries to send.");

    // データをFirebase Functionsに送信
    await saveGamesToFunctions(teamIdString, games);

    // 送信後に確認メッセージを表示
    print("Data has been sent to Firebase functions.");

    setState(() {
      _isSaving = false; // ✅ 保存完了
    });
    Navigator.pop(context, true);

    // 保存完了のデバッグメッセージ
    print("Saving process completed and state updated.");
  }

  Widget _buildGameTypePicker(int index, StateSetter setState) {
    return GestureDetector(
      onTap: () {
        _showCupertinoPicker(
          context,
          ['練習試合', '公式戦'],
          _selectedGameType[index] ?? '練習試合',
          (selected) {
            setState(() {
              _selectedGameType[index] = selected;
            });
          },
        );
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
              _selectedGameType[index] ?? '試合タイプを選択',
              style: const TextStyle(fontSize: 16),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showCupertinoPicker(BuildContext context, List<String> options,
      String selectedValue, Function(String) onSelected) {
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
                    onPressed: () {
                      Navigator.pop(context);
                      FocusScope.of(context).unfocus();
                    },
                    child: const Text('キャンセル', style: TextStyle(fontSize: 16)),
                  ),
                  const Text('選択してください',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton(
                    onPressed: () {
                      onSelected(tempSelected);
                      Navigator.pop(context);
                      FocusScope.of(context).unfocus();
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

  Widget _buildGameResultPicker(int index, StateSetter setState) {
    return GestureDetector(
      onTap: () {
        _showCupertinoPicker(
          context,
          ['勝利', '敗北', '引き分け'],
          _selectedResult[index] ?? '勝利',
          (selected) {
            setState(() {
              _selectedResult[index] = selected;
            });
          },
        );
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
              _selectedResult[index] ?? '試合結果を選択',
              style: const TextStyle(fontSize: 16),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  List<Widget> _generateGameWidgets(int numberOfMatches, StateSetter setState) {
    List<Widget> gameWidgets = [];
    for (int i = 0; i < numberOfMatches; i++) {
      if (_selectedGameType.length <= i) {
        _selectedGameType.add(null);
        _selectedResult.add(null);
      }
      if (_locationControllers.length <= i) {
        _locationControllers.add(TextEditingController());
        _opponentControllers.add(TextEditingController());
        _scoreControllers.add(TextEditingController());
        _runsAllowedControllers.add(TextEditingController());
      }

      gameWidgets.add(Container(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${i + 1}試合目',
              style: const TextStyle(
                fontSize: 40,
              ),
            ),
            _buildGameTypePicker(i, setState),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('場所',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('対戦相手',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    const Text('得点',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    SizedBox(
                      width: 50,
                      child: TextField(
                        controller: _scoreControllers[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Text('点',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
                Row(
                  children: [
                    const Text('失点',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    SizedBox(
                      width: 50,
                      child: TextField(
                        controller: _runsAllowedControllers[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Text('点',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('勝敗',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                _buildGameResultPicker(i, setState),
              ],
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
      appBar: AppBar(),
      body: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '試合数',
                      style: TextStyle(fontSize: 30),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(hintText: '0'),
                        style: const TextStyle(fontSize: 30),
                        onChanged: (value) {
                          setState(() {
                            numberOfMatches = int.tryParse(value) ?? 0;
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
                Column(
                  children: _generateGameWidgets(numberOfMatches, setState),
                ),
                if (numberOfMatches > 0) const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: _isSaving ||
                          _selectedGameType.contains(null) ||
                          _selectedResult.contains(null)
                      ? null
                      : () async {
                          setState(() {
                            _isSaving = true;
                          });

                          await _saveDataToFirestore();

                          setState(() {
                            _isSaving = false;
                          });
                        },
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('決定'),
                ),
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
