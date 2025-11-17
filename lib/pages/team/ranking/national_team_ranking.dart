import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class NationalTeamRanking extends StatefulWidget {
  final String teamId; // チームID
  final String teamPrefecture; // チームの都道府県

  const NationalTeamRanking({
    super.key,
    required this.teamId,
    required this.teamPrefecture, // 修正
  });

  @override
  _NationalTeamRankingState createState() => _NationalTeamRankingState();
}

class _NationalTeamRankingState extends State<NationalTeamRanking> {
  List<Map<String, dynamic>> _teams = [];
  String _selectedRankingType = '勝率';
  int _year = DateTime.now().year;

  final List<String> rankingTypes = [
    '勝率',
    '打率',
    '出塁率',
    '長打率',
    '防御率',
    '守備率',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTeamsData();
  }

  Future<void> _fetchTeamsData() async {
    try {
      final DateTime currentDate = DateTime.now();
      final int year =
          currentDate.month < 4 ? currentDate.year - 1 : currentDate.year;

      setState(() {
        _year = year;
      });

      final String rankingField = _getRankingField();
      if (rankingField.isEmpty) {
        print('無効なランキングタイプ: $_selectedRankingType');
        setState(() {
          _teams = [];
        });
        return;
      }

      final String docPath = 'teamRanking/${year}_all/全国/$rankingField';
      print('Firestoreクエリパス: $docPath');

      final snapshot = await FirebaseFirestore.instance.doc(docPath).get();

      if (snapshot.exists) {
        final List<dynamic> topTeams = snapshot.data()?['top'] ?? [];
        final List<Map<String, dynamic>> teams =
            topTeams.map((team) => Map<String, dynamic>.from(team)).toList();

        // **防御率のみ昇順、それ以外は降順でソート**
        teams.sort((a, b) {
          final double valueA = (a['value'] ?? 0).toDouble();
          final double valueB = (b['value'] ?? 0).toDouble();

          return _selectedRankingType == '防御率'
              ? valueA.compareTo(valueB) // **防御率（ERA）は低いほうが良い**
              : valueB.compareTo(valueA); // **他のランキングは高いほうが良い**
        });

        setState(() {
          _teams = teams;
        });

        print('取得したチームデータ: $_teams');
      } else {
        print('データが存在しません: $docPath');
        setState(() {
          _teams = [];
        });
      }
    } catch (e) {
      print('エラーが発生しました: $e');
      setState(() {
        _teams = [];
      });
    }
  }

  String _getRankingField() {
    switch (_selectedRankingType) {
      case '勝率':
        return 'winRateRank';
      case '打率':
        return 'battingAverageRank';
      case '出塁率':
        return 'onBaseRank';
      case '長打率':
        return 'sluggingRank';
      case '防御率':
        return 'eraRank';
      case '守備率':
        return 'fieldingPercentageRank';
      default:
        return '';
    }
  }

  String _getValueLabel() {
    switch (_selectedRankingType) {
      case '打率':
        return '打率';
      case '出塁率':
        return '出塁率';
      case '長打率':
        return '長打率';
      case '防御率':
        return '防御率';
      case '守備率':
        return '守備率';
      default:
        return '勝率';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              alignment: Alignment.center,
              child: Text(
                '全国',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$_year年',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.navigate_before, size: 32.0),
                    onPressed: _previousRankingType,
                  ),
                  GestureDetector(
                    onTap: () {
                      _showCupertinoPicker(context);
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey,
                            width: 1,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            _selectedRankingType,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down,
                              color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.navigate_next, size: 32.0),
                    onPressed: _nextRankingType,
                  ),
                ],
              ),
            ),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('teamRanking')
                  .doc('${_year}_all')
                  .collection('全国')
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
                  final totalTeamsCount = data['totalTeamsCount'] ?? 0;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    child: Text(
                      '$totalTeamsCountチームランキングに参加中',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  );
                }
              },
            ),
            _teams.isEmpty
                ? const Center(
                    child: Text(
                      'データが見つかりません',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 10,
                      columns: _buildDataColumns(),
                      rows: _buildTeamRows(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _previousRankingType() {
    final currentIndex = rankingTypes.indexOf(_selectedRankingType);
    final prevIndex =
        (currentIndex - 1 + rankingTypes.length) % rankingTypes.length;

    setState(() {
      _selectedRankingType = rankingTypes[prevIndex];
    });

    _fetchTeamsData();
  }

  void _nextRankingType() {
    final currentIndex = rankingTypes.indexOf(_selectedRankingType);
    final nextIndex = (currentIndex + 1) % rankingTypes.length;

    setState(() {
      _selectedRankingType = rankingTypes[nextIndex];
    });

    _fetchTeamsData();
  }

  void _showCupertinoPicker(BuildContext context) {
    int tempIndex = rankingTypes.indexOf(_selectedRankingType);

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
            SizedBox(
              height: 250,
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

  List<DataRow> _buildTeamRows() {
    return _teams.map((team) {
      final isTeam = team['id'] == widget.teamId;

      return DataRow(
        cells: _buildDataCells(team, isTeam: isTeam),
      );
    }).toList();
  }

  List<DataColumn> _buildDataColumns() {
    List<DataColumn> columns = [
      DataColumn(
        label: Container(
          width: 100,
          child: Center(child: _buildTeamNational()),
        ),
      ),
      DataColumn(
        label: Container(
          width: 100,
          child: Center(child: _buildTeamHeaderTeam()),
        ),
      ),
      DataColumn(label: Center(child: _buildVerticalText(_getValueLabel()))),
    ];

    if (_selectedRankingType == '勝率') {
      columns.add(DataColumn(label: Center(child: _buildVerticalText('試合'))));
      columns.add(DataColumn(label: Center(child: _buildVerticalText('勝利'))));
      columns.add(DataColumn(label: Center(child: _buildVerticalText('敗北'))));
      columns.add(DataColumn(label: Center(child: _buildVerticalText('引き分'))));
      columns.add(DataColumn(label: Center(child: _buildVerticalText('得点'))));
      columns.add(DataColumn(label: Center(child: _buildVerticalText('失点'))));
    }

    if (_selectedRankingType == '出塁率' ||
        _selectedRankingType == '長打率' ||
        _selectedRankingType == '打率') {
      columns.add(DataColumn(label: Center(child: _buildVerticalText('打数'))));
    }

    if (_selectedRankingType == '打率') {
      columns.add(DataColumn(label: Center(child: _buildVerticalText('安打'))));
    }

    if (_selectedRankingType == '防御率') {
      columns.add(DataColumn(label: Center(child: _buildVerticalText('投球回'))));
    }

    if (_selectedRankingType == '守備率') {
      columns.add(DataColumn(label: Center(child: _buildVerticalText('刺殺'))));
      columns.add(DataColumn(label: Center(child: _buildVerticalText('捕殺'))));
      columns.add(DataColumn(label: Center(child: _buildVerticalText('失策'))));
    }
    columns.add(DataColumn(label: Center(child: _buildVerticalText('年齢'))));

    return columns;
  }

  List<DataCell> _buildDataCells(Map<String, dynamic> team,
      {bool isTeam = false}) {
    List<DataCell> cells = [
      DataCell(Center(
        child: Text(
          team['prefecture']?.toString() ?? '不明',
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
          _selectedRankingType == '防御率'
              ? formatPercentageEra(team['value'] ?? 0.0)
              : formatPercentage(team['value'] ?? 0.0),
          style: TextStyle(
            fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
            color: isTeam ? Colors.blue : Colors.black,
          ),
        ),
      )),
    ];

    if (_selectedRankingType == '勝率') {
      cells.add(DataCell(Center(
        child: Text(
          team['totalGames']?.toString() ?? '0',
          style: TextStyle(
            fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
            color: isTeam ? Colors.blue : Colors.black,
          ),
        ),
      )));
      cells.add(DataCell(Center(
        child: Text(
          team['totalWins']?.toString() ?? '0',
          style: TextStyle(
            fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
            color: isTeam ? Colors.blue : Colors.black,
          ),
        ),
      )));
      cells.add(DataCell(Center(
        child: Text(
          team['totalLosses']?.toString() ?? '0',
          style: TextStyle(
            fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
            color: isTeam ? Colors.blue : Colors.black,
          ),
        ),
      )));
      cells.add(DataCell(Center(
        child: Text(
          team['totalDraws']?.toString() ?? '0',
          style: TextStyle(
            fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
            color: isTeam ? Colors.blue : Colors.black,
          ),
        ),
      )));
      cells.add(DataCell(Center(
        child: Text(
          team['totalScore']?.toString() ?? '0',
          style: TextStyle(
            fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
            color: isTeam ? Colors.blue : Colors.black,
          ),
        ),
      )));
      cells.add(DataCell(Center(
        child: Text(
          team['totalRunsAllowed']?.toString() ?? '0',
          style: TextStyle(
            fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
            color: isTeam ? Colors.blue : Colors.black,
          ),
        ),
      )));
    }

    if (_selectedRankingType == '出塁率' ||
        _selectedRankingType == '長打率' ||
        _selectedRankingType == '打率') {
      cells.add(DataCell(Center(
        child: Text(
          team['atBats']?.toString() ?? '0',
          style: TextStyle(
            fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
            color: isTeam ? Colors.blue : Colors.black,
          ),
        ),
      )));
    }

    if (_selectedRankingType == '打率') {
      cells.add(DataCell(Center(
        child: Text(
          team['hits']?.toString() ?? '0',
          style: TextStyle(
            fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
            color: isTeam ? Colors.blue : Colors.black,
          ),
        ),
      )));
    }

    if (_selectedRankingType == '防御率') {
      final inningsRaw = team['totalInningsPitched'];
      final innings = (inningsRaw is num)
          ? inningsRaw.toDouble()
          : double.tryParse(inningsRaw?.toString() ?? '0') ?? 0.0;

      cells.add(DataCell(Center(
        child: Text(
          innings.toStringAsFixed(1),
          style: TextStyle(
            fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
            color: isTeam ? Colors.blue : Colors.black,
          ),
        ),
      )));
    }

    if (_selectedRankingType == '守備率') {
      cells.add(DataCell(Center(
        child: Text(
          team['totalPutouts']?.toString() ?? '0',
          style: TextStyle(
            fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
            color: isTeam ? Colors.blue : Colors.black,
          ),
        ),
      )));
      cells.add(DataCell(Center(
        child: Text(
          team['totalAssists']?.toString() ?? '0',
          style: TextStyle(
            fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
            color: isTeam ? Colors.blue : Colors.black,
          ),
        ),
      )));
      cells.add(DataCell(Center(
        child: Text(
          team['totalErrors']?.toString() ?? '0',
          style: TextStyle(
            fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
            color: isTeam ? Colors.blue : Colors.black,
          ),
        ),
      )));
    }

    // 共通の年齢セル（全ランキング共通で最後の列）
    cells.add(DataCell(Center(
      child: Text(
        team['averageAge']?.toString() ?? '0',
        style: TextStyle(
          fontWeight: isTeam ? FontWeight.bold : FontWeight.normal,
          color: isTeam ? Colors.blue : Colors.black,
        ),
      ),
    )));
    return cells;
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
              child: Text(
                char,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTeamNational() {
    return const Center(
      child: Text(
        '都道府県',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  // 選手名のヘッダー
  static Widget _buildTeamHeader() {
    return const Center(
      child: Text(
        '選手',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
