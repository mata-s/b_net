import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class PrefectureTeamRanking extends StatefulWidget {
  final String teamId; // チームID
  final String teamPrefecture; // チームの都道府県

  const PrefectureTeamRanking({
    super.key,
    required this.teamId,
    required this.teamPrefecture, // 修正
  });

  @override
  State<PrefectureTeamRanking> createState() => _PrefectureTeamRankingState();
}

class _PrefectureTeamRankingState extends State<PrefectureTeamRanking> {
  bool get _isLastMonth => !_isSeasonMode;
  List<Map<String, dynamic>> _teams = []; // チームデータを保持
  Map<String, dynamic>? _teamData; // チーム自身のデータを保持
  String _selectedRankingType = '勝率ランキング';
  int _year = DateTime.now().year;
  bool _isSeasonMode = true;

  final List<String> rankingTypes = [
    // 選択肢リスト
    '勝率ランキング',
    '打率ランキング',
    '出塁率ランキング',
    '長打率ランキング',
    '防御率ランキング',
    '守備率ランキング',
  ];

  @override
  void initState() {
    super.initState();
    _isSeasonMode = true; // 初期状態をシーズンモードに設定
    _fetchTeamsData(); // データを取得
  }

  Future<void> _fetchTeamsData() async {
    try {
      DateTime currentDate = DateTime.now();
      int year;
      int lastMonth = 0; // 初期値を設定

      // シーズンまたは先月モードに基づいて年と月を設定
      if (_isSeasonMode) {
        year = currentDate.year;
        if (currentDate.month <= 3) {
          year -= 1; // シーズンの場合、1月〜3月は前年のデータを使用
        }
      } else {
        year = currentDate.year;
        lastMonth = currentDate.month - 1;
        if (lastMonth == 0) {
          lastMonth = 12;
          year -= 1;
        }
      }

      setState(() {
        _year = year; // 年を設定
      });

      // Firestoreのパスを構築
      String basePath;
      if (_isSeasonMode) {
        basePath = 'teamRanking/${year}_all/${widget.teamPrefecture}';
      } else {
        basePath = 'teamRanking/${year}_${lastMonth}/${widget.teamPrefecture}';

        // 先月モードで「勝率ランキング」以外を選択している場合、何も表示しない
        if (_selectedRankingType != '勝率ランキング') {
          setState(() {
            _teams = [];
            _teamData = null;
          });
          return;
        }
      }

      List<Map<String, dynamic>> teams = [];
      Map<String, dynamic>? teamData;

      if (_selectedRankingType == '勝率ランキング') {
        final snapshot =
            await FirebaseFirestore.instance.collection(basePath).get();
        teams = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();

        teams.sort(
            (a, b) => (a['winRateRank'] ?? 0).compareTo(b['winRateRank'] ?? 0));

        teamData = teams.firstWhere(
          (team) =>
              team['id']?.toString() ==
              widget.teamId.toString(), // teamId を id で比較
          orElse: () {
            print('ユーザーのデータが見つかりません。デフォルト値を適用します。');
            return {
              'winRateRank': '圏外',
              'teamName': 'チーム名不明',
            };
          },
        );
      } else if (_selectedRankingType == '打率ランキング') {
        final docSnapshot = await FirebaseFirestore.instance
            .doc('$basePath/battingAverageRank')
            .get();

        if (docSnapshot.exists) {
          teams = List<Map<String, dynamic>>.from(
              docSnapshot.data()?['top10'] ?? []);
        }
        teams.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDがtop10に含まれているか確認
        final teamInTop10 = teams.firstWhere(
          (team) => team['id']?.toString() == widget.teamId.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (teamInTop10.isNotEmpty) {
          teamData = teamInTop10;
        } else {
          // top10に含まれていない場合は全データから探す
          final snapshot =
              await FirebaseFirestore.instance.collection(basePath).get();
          final allTeams = snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

          teamData = allTeams.firstWhere(
            (team) => team['id']?.toString() == widget.teamId.toString(),
            orElse: () => {
              'teamName': 'チーム名不明',
              'battingAverage': 0,
              'battingAverageRank': '圏外',
            },
          );
        }
      } else if (_selectedRankingType == '出塁率ランキング') {
        final docSnapshot =
            await FirebaseFirestore.instance.doc('$basePath/onBaseRank').get();

        if (docSnapshot.exists) {
          teams = List<Map<String, dynamic>>.from(
              docSnapshot.data()?['top10'] ?? []);
        }
        teams.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDが`top10`に含まれているか確認
        final teamInTop10 = teams.firstWhere(
          (team) => team['id']?.toString() == widget.teamId.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (teamInTop10.isNotEmpty) {
          teamData = teamInTop10;
        } else {
          // top10に含まれていない場合は全データから探す
          final snapshot =
              await FirebaseFirestore.instance.collection(basePath).get();
          final allTeams = snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

          teamData = allTeams.firstWhere(
            (team) => team['id']?.toString() == widget.teamId.toString(),
            orElse: () => {
              'teamName': 'チーム名不明',
              'onBasePercentage': 0,
              'onBaseRank': '圏外',
            },
          );
        }
      } else if (_selectedRankingType == '長打率ランキング') {
        final docSnapshot = await FirebaseFirestore.instance
            .doc('$basePath/sluggingRank')
            .get();

        if (docSnapshot.exists) {
          teams = List<Map<String, dynamic>>.from(
              docSnapshot.data()?['top10'] ?? []);
        }
        teams.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDが`top10`に含まれているか確認
        final teamInTop10 = teams.firstWhere(
          (team) => team['id']?.toString() == widget.teamId.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (teamInTop10.isNotEmpty) {
          teamData = teamInTop10;
        } else {
          // top10に含まれていない場合は全データから探す
          final snapshot =
              await FirebaseFirestore.instance.collection(basePath).get();
          final allTeams = snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

          teamData = allTeams.firstWhere(
            (team) => team['id']?.toString() == widget.teamId.toString(),
            orElse: () => {
              'teamName': 'チーム名不明',
              'sluggingPercentage': 0,
              'sluggingRank': '圏外',
            },
          );
        }
      } else if (_selectedRankingType == '防御率ランキング') {
        final docSnapshot =
            await FirebaseFirestore.instance.doc('$basePath/eraRank').get();

        if (docSnapshot.exists) {
          teams = List<Map<String, dynamic>>.from(
              docSnapshot.data()?['top10'] ?? []);
        }
        teams.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDが`top10`に含まれているか確認
        final teamInTop10 = teams.firstWhere(
          (team) => team['id']?.toString() == widget.teamId.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (teamInTop10.isNotEmpty) {
          teamData = teamInTop10;
        } else {
          // top10に含まれていない場合は全データから探す
          final snapshot =
              await FirebaseFirestore.instance.collection(basePath).get();
          final allTeams = snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

          teamData = allTeams.firstWhere(
            (team) => team['id']?.toString() == widget.teamId.toString(),
            orElse: () => {
              'teamName': 'チーム名不明',
              'era': 0,
              'eraRank': '圏外',
            },
          );
        }
      } else if (_selectedRankingType == '守備率ランキング') {
        final docSnapshot = await FirebaseFirestore.instance
            .doc('$basePath/fieldingPercentageRank')
            .get();

        if (docSnapshot.exists) {
          teams = List<Map<String, dynamic>>.from(
              docSnapshot.data()?['top10'] ?? []);
        }
        teams.sort((a, b) => (a['rank'] ?? double.infinity)
            .compareTo(b['rank'] ?? double.infinity));

        // ユーザーのIDが`top10`に含まれているか確認
        final teamInTop10 = teams.firstWhere(
          (team) => team['id']?.toString() == widget.teamId.toString(),
          orElse: () => <String, dynamic>{}, // 空のマップを返す
        );

        if (teamInTop10.isNotEmpty) {
          teamData = teamInTop10;
        } else {
          // top10に含まれていない場合は全データから探す
          final snapshot =
              await FirebaseFirestore.instance.collection(basePath).get();
          final allTeams = snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

          teamData = allTeams.firstWhere(
            (team) => team['id']?.toString() == widget.teamId.toString(),
            orElse: () => {
              'teamName': 'チーム名不明',
              'fieldingPercentage': 0,
              'fieldingPercentageRank': '圏外',
            },
          );
        }
      }

      setState(() {
        _teams = teams;
        _teamData = teamData;
      });

      print('最終的なプレイヤーデータ: $_teams'); // 最終的なプレイヤーデータ確認
      print('最終的なユーザー自身のデータ: $_teamData'); // 最終的なユーザーデータ確認
    } catch (e) {
      print('Firestoreからのデータ取得中にエラーが発生しました: $e');
      setState(() {
        _teams = [];
        _teamData = null;
      });
    }
  }

  List<DataRow> _buildTop10Rows() {
    List<DataRow> result = [];

    if (_selectedRankingType == '勝率ランキング') {
      // TOP10を表示（圏外を除外し、rankが10以下の選手を表示）
      for (var team in _teams) {
        // rankが10以下で、かつ圏外でないことを確認
        if (team['winRateRank'] != null &&
            team['winRateRank'] != '' &&
            (int.tryParse(team['winRateRank'].toString()) ?? 0) <= 10) {
          result.add(DataRow(
              cells: _buildDataCells(team,
                  isTeam: team['id'] == widget.teamId))); // ユーザー自身のデータを太字で表示
        }
      }
    } else if (_selectedRankingType == '打率ランキング' ||
        _selectedRankingType == '出塁率ランキング' ||
        _selectedRankingType == '長打率ランキング' ||
        _selectedRankingType == '防御率ランキング' ||
        _selectedRankingType == '守備率ランキング') {
      for (var team in _teams) {
        if (team['rank'] != null &&
            team['rank'] != '' &&
            (int.tryParse(team['rank'].toString()) ?? 0) <= 10) {
          result.add(
            DataRow(
                cells:
                    _buildDataCells(team, isTeam: team['id'] == widget.teamId)),
          );
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // ユーザーのランクを取得
    int teamRank = -1; // デフォルト値として-1を設定

    if (_selectedRankingType == '勝率ランキング' &&
        _teamData != null &&
        _teamData!['winRateRank'] != '圏外') {
      teamRank = int.tryParse(_teamData!['winRateRank'].toString()) ?? -1;
    }

    final bool isTeamOutsideTop10 = (_selectedRankingType == '打率ランキング' ||
            _selectedRankingType == '出塁率ランキング' ||
            _selectedRankingType == '長打率ランキング' ||
            _selectedRankingType == '防御率ランキング' ||
            _selectedRankingType == '守備率ランキング') &&
        _teamData != null &&
        !_teams.any((team) =>
            team['id']?.toString() == widget.teamId.toString() &&
            (int.tryParse(team['rank']?.toString() ?? '0') ?? 0) <= 10);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              alignment: Alignment.center,
              child: Text(
                '${widget.teamPrefecture}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _showModePicker(context), // モード選択ピッカーを表示
                  child: Container(
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.black54, width: 1), // 控えめな枠線
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Text(
                          _isSeasonMode ? 'シーズン' : '先月',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  _isSeasonMode
                      ? '$_year年' // シーズンの場合は「年」のみ表示
                      : '${_year}年${DateTime.now().month - 1 == 0 ? 12 : DateTime.now().month - 1}月', // 先月の場合「年+月」
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isLastMonth)
                      IconButton(
                        icon: Icon(Icons.navigate_before, size: 32.0),
                        onPressed: () {
                          final currentIndex =
                              rankingTypes.indexOf(_selectedRankingType);
                          final previousIndex =
                              (currentIndex - 1 + rankingTypes.length) %
                                  rankingTypes.length;
                          setState(() {
                            _selectedRankingType = rankingTypes[previousIndex];
                            _fetchTeamsData();
                          });
                        },
                      ),
                    if (!_isLastMonth)
                      InkWell(
                        onTap: () => _showCupertinoPicker(context),
                        child: Row(
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(color: Colors.grey)),
                              ),
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                _selectedRankingType,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Colors.grey)),
                            ),
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              _selectedRankingType,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (!_isLastMonth)
                      IconButton(
                        icon: Icon(Icons.navigate_next, size: 32.0),
                        onPressed: () {
                          final currentIndex =
                              rankingTypes.indexOf(_selectedRankingType);
                          final nextIndex =
                              (currentIndex + 1) % rankingTypes.length;
                          setState(() {
                            _selectedRankingType = rankingTypes[nextIndex];
                            _fetchTeamsData();
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(width: 5),
            (() {
              // Always fetch from /teamRanking/{_year}_all/{prefecture}/stats
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('teamRanking')
                    .doc('${_year}_all')
                    .collection(widget.teamPrefecture)
                    .doc('stats')
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  } else if (snapshot.hasError ||
                      !snapshot.hasData ||
                      !snapshot.data!.exists) {
                    return const SizedBox.shrink();
                  } else {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final teamsCount = data['teamsCount'] ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(top: 5, bottom: 10),
                      alignment: Alignment.center,
                      child: Text(
                        '$teamsCountチームランキングに参加中',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                },
              );
            })(),
            // データがない場合の表示（全てのランキングに適用）
            if (_teams.isEmpty) ...[
              Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.only(top: 20),
                child: const Text(
                  'データが見つかりません',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ] else if (_selectedRankingType == '勝率ランキング') ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 10,
                  columns: _buildDataColumns(),
                  rows: _buildTop10Rows(),
                ),
              ),
              // ユーザーがTOP10に入っていない場合のみ三つのドットを表示
              if (teamRank > 10 || teamRank == -1) ...[
                // 三つのドットの表示（縦並び）
                Container(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('・', style: const TextStyle(fontSize: 20)),
                      Text('・', style: const TextStyle(fontSize: 20)),
                      Text('・', style: const TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
                // ユーザー自身と前後の選手を表示するテーブル
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 10,
                    columns: _buildDataColumns(),
                    rows: _buildTeamAndPreviousRows(teamRank),
                  ),
                ),
              ],
            ] else if (isTeamOutsideTop10) ...[
              // 他のランキングでTOP10外のユーザー表示
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 10,
                  columns: _buildDataColumns(),
                  rows: _buildTop10Rows(),
                ),
              ),
              Container(
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('・', style: const TextStyle(fontSize: 20)),
                    Text('・', style: const TextStyle(fontSize: 20)),
                    Text('・', style: const TextStyle(fontSize: 20)),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 10,
                  columns: _buildDataColumns(),
                  rows: [
                    DataRow(cells: _buildDataCells(_teamData!, isTeam: true)),
                  ],
                ),
              ),
            ] else
              // 他のランキング表示（ユーザーがTOP10以内の場合）
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 10,
                  columns: _buildDataColumns(),
                  rows: _buildTop10Rows(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showModePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        int tempIndex = _isSeasonMode ? 0 : 1; // シーズン=0, 先月=1

        return Container(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child:
                          const Text('キャンセル', style: TextStyle(fontSize: 16)),
                    ),
                    const Text('選択してください',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isSeasonMode = tempIndex == 0;
                          _selectedRankingType = '勝率ランキング';
                          _fetchTeamsData();
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
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: Colors.white,
                  itemExtent: 40.0,
                  scrollController: FixedExtentScrollController(
                    initialItem: tempIndex,
                  ),
                  onSelectedItemChanged: (int index) {
                    tempIndex = index;
                  },
                  children: const [
                    Center(child: Text('シーズン', style: TextStyle(fontSize: 24))),
                    Center(child: Text('先月', style: TextStyle(fontSize: 24))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCupertinoPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        int tempIndex =
            rankingTypes.indexOf(_selectedRankingType); // 一時的な選択インデックス

        return Container(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child:
                          const Text('キャンセル', style: TextStyle(fontSize: 16)),
                    ),
                    const Text('選択してください',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedRankingType = rankingTypes[tempIndex];
                          _fetchTeamsData();
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
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: Colors.white,
                  itemExtent: 40.0,
                  scrollController: FixedExtentScrollController(
                    initialItem: tempIndex,
                  ),
                  onSelectedItemChanged: (int index) {
                    tempIndex = index;
                  },
                  children: rankingTypes.map((type) {
                    return Center(
                      child: Text(
                        type,
                        style: TextStyle(fontSize: 22),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<DataColumn> _buildDataColumns() {
    if (_selectedRankingType == '勝率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildTeamHeaderTeam()),
          ),
        ), // チーム
        DataColumn(label: Center(child: _buildVerticalText('勝率'))),
        DataColumn(label: Center(child: _buildVerticalText('試合'))),
        DataColumn(label: Center(child: _buildVerticalText('勝利'))),
        DataColumn(label: Center(child: _buildVerticalText('敗北'))),
        DataColumn(label: Center(child: _buildVerticalText('引き分'))),
        DataColumn(label: Center(child: _buildVerticalText('得点'))),
        DataColumn(label: Center(child: _buildVerticalText('失点'))),
        DataColumn(label: Center(child: _buildVerticalText('打率'))),
        DataColumn(label: Center(child: _buildVerticalText('出塁率'))),
        DataColumn(label: Center(child: _buildVerticalText('長打率'))),
        DataColumn(label: Center(child: _buildVerticalText('防御率'))),
        DataColumn(label: Center(child: _buildVerticalText('守備率'))),
      ];
    } else if (_selectedRankingType == '打率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildTeamHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('打率'))),
        DataColumn(label: Center(child: _buildVerticalText('打数'))),
        DataColumn(label: Center(child: _buildVerticalText('安打'))),
      ];
    } else if (_selectedRankingType == '出塁率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildTeamHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('出塁率'))),
        DataColumn(label: Center(child: _buildVerticalText('打数'))),
      ];
    } else if (_selectedRankingType == '長打率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildTeamHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('長打率'))),
        DataColumn(label: Center(child: _buildVerticalText('打数'))),
      ];
    } else if (_selectedRankingType == '防御率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildTeamHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('防御率'))),
        DataColumn(label: Center(child: _buildVerticalText('投球回'))),
      ];
    } else if (_selectedRankingType == '守備率ランキング') {
      return [
        DataColumn(label: Center(child: _buildVerticalText('順位'))),
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildTeamHeaderTeam()),
          ),
        ),
        DataColumn(label: Center(child: _buildVerticalText('守備率'))),
        DataColumn(label: Center(child: _buildVerticalText('刺殺'))),
        DataColumn(label: Center(child: _buildVerticalText('捕殺'))),
        DataColumn(label: Center(child: _buildVerticalText('失策'))),
      ];
    } else {
      // デフォルト値を返す
      return [
        DataColumn(
            label: Center(
                child: Text('エラー',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)))),
      ];
    }
  }

  List<DataRow> _buildTopRankedRows() {
    List<DataRow> result = [];

    if (_selectedRankingType == '勝率ランキング') {
      // rankが10以下の選手を表示
      for (var team in _teams) {
        int teamRank = int.tryParse(team['winRateRank'].toString()) ?? -1;
        if (teamRank <= 10) {
          result.add(DataRow(
              cells: _buildDataCells(team,
                  isTeam: team['id'] == widget.teamId))); // ユーザー自身のデータを太字で表示
        }
      }
    }

    return result;
  }

  List<DataRow> _buildTeamAndPreviousRows(int teamRank) {
    List<DataRow> result = [];

    if (_selectedRankingType == '勝率ランキング') {
      // ユーザー自身のデータを追加
      if (_teamData != null) {
        result.add(DataRow(
            cells: _buildDataCells(_teamData!, isTeam: true))); // ユーザー自身を太字で表示
      }

      // 前の選手を追加（最大2人）
      int upperCount = 0;
      for (var team in _teams) {
        int teamRank = int.tryParse(team['winRateRank'].toString()) ?? -1;
        if (teamRank == teamRank - 1 && upperCount < 2) {
          result.insert(0, DataRow(cells: _buildDataCells(team))); // 上に追加
          upperCount++;
        }
      }

      // 次の選手を追加（最大2人）
      int lowerCount = 0;
      for (var team in _teams) {
        int teamRank = int.tryParse(team['winRateRank'].toString()) ?? -1;
        if (teamRank == teamRank + 1 && lowerCount < 2) {
          result.add(DataRow(cells: _buildDataCells(team))); // 下に追加
          lowerCount++;
        }
      }
    }

    return result;
  }

  List<DataCell> _buildDataCells(Map<String, dynamic> team,
      {bool isTeam = false}) {
    final rankKey = _selectedRankingType == '打率ランキング'
        ? (team.containsKey('rank') ? 'rank' : 'battingAverageRank')
        : _selectedRankingType == '出塁率ランキング'
            ? (team.containsKey('rank') ? 'rank' : 'onBaseRank')
            : _selectedRankingType == '長打率ランキング'
                ? (team.containsKey('rank') ? 'rank' : 'sluggingRank')
                : _selectedRankingType == '防御率ランキング'
                    ? (team.containsKey('rank') ? 'rank' : 'eraRank')
                    : _selectedRankingType == '守備率ランキング'
                        ? (team.containsKey('rank')
                            ? 'rank'
                            : 'fieldingPercentageRank')
                        : 'winRateRank';

    final valueKey = _selectedRankingType == '打率ランキング'
        ? (team.containsKey('value') ? 'value' : 'battingAverage')
        : _selectedRankingType == '出塁率ランキング'
            ? (team.containsKey('value') ? 'value' : 'onBasePercentage')
            : _selectedRankingType == '長打率ランキング'
                ? (team.containsKey('value') ? 'value' : 'sluggingPercentage')
                : _selectedRankingType == '防御率ランキング'
                    ? (team.containsKey('value') ? 'value' : 'era')
                    : _selectedRankingType == '守備率ランキング'
                        ? (team.containsKey('value')
                            ? 'value'
                            : 'fieldingPercentage')
                        : 'winRate';

    if (_selectedRankingType == '勝率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            team['winRateRank']?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            (team['teamName'] ?? 'チーム名不明').toString().length > 8
                ? '${team['teamName'].toString().substring(0, 8)}…'
                : team['teamName'].toString(),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(team['winRate'] ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalGames']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalWins']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalLosses']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalDraws']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalScore']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalRunsAllowed']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(team['battingAverage'] ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(team['onBasePercentage'] ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(team['sluggingPercentage'] ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentageEra(team['era'] ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(team['fieldingPercentage'] ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '打率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            team[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            (team['teamName'] ?? 'チーム名不明').toString().length > 8
                ? '${team['teamName'].toString().substring(0, 8)}…'
                : team['teamName'].toString(),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(
                num.tryParse(team[valueKey]?.toString() ?? '0.0') ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['atBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['hits']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '出塁率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            team[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            (team['teamName'] ?? 'チーム名不明').toString().length > 8
                ? '${team['teamName'].toString().substring(0, 8)}…'
                : team['teamName'].toString(),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(
                num.tryParse(team[valueKey]?.toString() ?? '0.0') ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['atBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '長打率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            team[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            (team['teamName'] ?? 'チーム名不明').toString().length > 8
                ? '${team['teamName'].toString().substring(0, 8)}…'
                : team['teamName'].toString(),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(
                num.tryParse(team[valueKey]?.toString() ?? '0.0') ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['atBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '防御率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            team[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            (team['teamName'] ?? 'チーム名不明').toString().length > 8
                ? '${team['teamName'].toString().substring(0, 8)}…'
                : team['teamName'].toString(),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentageEra(
                num.tryParse(team[valueKey]?.toString() ?? '0.0') ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            (team['totalInningsPitched'] is num)
                ? (team['totalInningsPitched'] as num).toStringAsFixed(1)
                : '0.0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '守備率ランキング') {
      return [
        DataCell(Center(
          child: Text(
            team[rankKey]?.toString() ?? '圏外',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            (team['teamName'] ?? 'チーム名不明').toString().length > 8
                ? '${team['teamName'].toString().substring(0, 8)}…'
                : team['teamName'].toString(),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            formatPercentage(
                num.tryParse(team[valueKey]?.toString() ?? '0.0') ?? 0.0),
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalPutouts']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalAssists']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            team['totalErrors']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
              color: isTeam ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    }
    return [];
  }

  String formatPercentage(num value) {
    double doubleValue = value.toDouble(); // intをdoubleに変換
    String formatted = doubleValue.toStringAsFixed(3);
    return formatted.startsWith("0")
        ? formatted.replaceFirst("0", "")
        : formatted; // 先頭の0を削除
  }

  String formatPercentageEra(num value) {
    double doubleValue = value.toDouble(); // num を double に変換
    return doubleValue.toStringAsFixed(2); // 小数点第2位までフォーマット
  }

  // 縦書きテキストウィジェット
  static Widget _buildVerticalText(String text) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: text.split('').map((char) {
          return Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.rotate(
                angle: char == 'ー' ? 90 * 3.14159 / 180 : 0, // 「ー」の場合90度回転
                child: Text(
                  char,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // チーム名のヘッダー
  static Widget _buildTeamHeaderTeam() {
    return const Center(
      child: Text(
        'チーム',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
