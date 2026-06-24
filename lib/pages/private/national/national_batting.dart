import 'package:b_net/common/profile_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NationalBatting extends StatefulWidget {
  final String uid;
  final String prefecture;

  const NationalBatting({Key? key, required this.uid, required this.prefecture})
      : super(key: key);

  @override
  _NationalBattingState createState() => _NationalBattingState();
}

class _NationalBattingState extends State<NationalBatting> {
  List<Map<String, dynamic>> _players = [];
  String _selectedRankingType = '打率';
  int _year = DateTime.now().year;
  int _totalPlayersCount = 0;

  final List<String> rankingTypes = [
    '打率',
    '本塁打',
    '盗塁',
    '打点',
    '長打率',
    '出塁率',
  ];

  @override
  void initState() {
    super.initState();
    _fetchPlayersData();
    _fetchTotalPlayersCount();
  }

  Future<void> _fetchPlayersData() async {
    try {
      final DateTime currentDate = DateTime.now();
      final int year =
          currentDate.month < 4 ? currentDate.year - 1 : currentDate.year;

      setState(() {
        _year = year;
      });

      // Firestore パスを `_getRankingField` を使って構築
      final String rankingField = _getRankingField();
      if (rankingField.isEmpty) {
        print('無効なランキングタイプ: $_selectedRankingType');
        setState(() {
          _players = [];
        });
        return;
      }

      final String docPath =
          'battingAverageRanking/${year}_total/全国/$rankingField';
      // print('Firestoreクエリパス: $docPath');

      final snapshot = await FirebaseFirestore.instance.doc(docPath).get();

      if (snapshot.exists) {
        final List<dynamic> topPlayers = snapshot.data()?['top'] ?? [];
        final List<Map<String, dynamic>> players = topPlayers
            .map((player) => Map<String, dynamic>.from(player))
            .toList();

        players.sort((a, b) {
          final double valueA = (a['value'] ?? 0).toDouble();
          final double valueB = (b['value'] ?? 0).toDouble();
          return valueB.compareTo(valueA); // 降順にソート
        });

        setState(() {
          _players = players;
        });

        // print('取得したプレイヤーデータ: $_players');
      } else {
        print('データが存在しません: $docPath');
        setState(() {
          _players = [];
        });
      }
    } catch (e) {
      print('エラーが発生しました: $e');
      setState(() {
        _players = [];
      });
    }
  }

  String _getRankingField() {
    switch (_selectedRankingType) {
      case '打率':
        return 'battingAverageRank';
      case '本塁打':
        return 'homeRunsRank';
      case '盗塁':
        return 'stealsRank';
      case '打点':
        return 'totalRbisRank';
      case '長打率':
        return 'sluggingRank';
      case '出塁率':
        return 'onBaseRank';
      default:
        return '';
    }
  }

  String _getValueLabel() {
    switch (_selectedRankingType) {
      case '本塁打':
        return '本塁打';
      case '盗塁':
        return '盗塁';
      case '打点':
        return '打点';
      case '長打率':
        return '長打率';
      case '出塁率':
        return '出塁率';
      default:
        return '打率';
    }
  }

  Future<void> _fetchTotalPlayersCount() async {
    try {
      final docPath = 'battingAverageRanking/${_year}_total/全国/stats';
      final snapshot = await FirebaseFirestore.instance.doc(docPath).get();

      if (snapshot.exists) {
        final data = snapshot.data();
        setState(() {
          _totalPlayersCount = data?['totalPlayersCount'] ?? 0;
        });
      }
    } catch (e) {
      print('👀 totalPlayersCountの取得エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              '全国トップ打者',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_year年シーズン',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.navigate_before, size: 24.0),
                        onPressed: () {
                          final currentIndex =
                              rankingTypes.indexOf(_selectedRankingType);
                          final previousIndex =
                              (currentIndex - 1 + rankingTypes.length) %
                                  rankingTypes.length;
                          setState(() {
                            _selectedRankingType = rankingTypes[previousIndex];
                            _fetchPlayersData();
                          });
                        },
                      ),
                      InkWell(
                        onTap: () => _showCupertinoPicker(context),
                        child: Row(
                          children: [
                            Container(
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
                      ),
                      IconButton(
                        icon: Icon(Icons.navigate_next, size: 24.0),
                        onPressed: () {
                          final currentIndex =
                              rankingTypes.indexOf(_selectedRankingType);
                          final nextIndex =
                              (currentIndex + 1) % rankingTypes.length;
                          setState(() {
                            _selectedRankingType = rankingTypes[nextIndex];
                            _fetchPlayersData();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
              ),
              child: Center(
                child: Text(
                  '$_totalPlayersCount人がランキングに参加中',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            _players.isEmpty
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
                      rows: _buildPlayerRows(),
                    ),
                  ),
          ],
        ),
      ),
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
                          _fetchPlayersData();
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
                    tempIndex = index; // スクロール中に選択インデックスを更新
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
          ),
        );
      },
    );
  }

  List<DataRow> _buildPlayerRows() {
    return _players.map((player) {
      final isUser = player['id'] == widget.uid;
      final String playerPrefecture = (player['prefecture'] ?? '').toString();
      final bool isMyPrefecture = widget.prefecture.trim().isNotEmpty &&
          playerPrefecture.trim().isNotEmpty &&
          playerPrefecture.trim() == widget.prefecture.trim();

      return DataRow(
        color: MaterialStateProperty.resolveWith<Color?>(
          (states) {
            if (isUser) {
              return const Color(0xFF1565C0).withOpacity(0.08);
            }
            if (isMyPrefecture) {
              return const Color(0xFF1565C0).withOpacity(0.04);
            }
            return null;
          },
        ),
        cells: _buildDataCells(player, isUser: isUser),
      );
    }).toList();
  }

  List<DataColumn> _buildDataColumns() {
    if (_selectedRankingType == '打率') {
      return [
        DataColumn(
          label: Container(
            child: Center(child: _buildPlayerNational()),
          ),
        ),
        DataColumn(
          label: Container(
            width: 100, // 選手列の幅を設定
            child: Center(child: _buildPlayerHeader()),
          ),
        ), // 選手
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildPlayerHeaderTeam()),
          ),
        ), // チーム
        DataColumn(label: Center(child: _buildVerticalText('打率'))),
        DataColumn(label: Center(child: _buildVerticalText('打数'))),
        DataColumn(label: Center(child: _buildVerticalText('安打'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == '出塁率') {
      return [
        DataColumn(
          label: Container(
            child: Center(child: _buildPlayerNational()),
          ),
        ),
        DataColumn(
          label: Container(
            width: 100, // 選手列の幅を設定
            child: Center(child: _buildPlayerHeader()),
          ),
        ), // 選手
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildPlayerHeaderTeam()),
          ),
        ), // チーム
        DataColumn(label: Center(child: _buildVerticalText('出塁率'))),
        DataColumn(label: Center(child: _buildVerticalText('打席'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else if (_selectedRankingType == '長打率') {
      return [
        DataColumn(
          label: Container(
            child: Center(child: _buildPlayerNational()),
          ),
        ),
        DataColumn(
          label: Container(
            width: 100, // 選手列の幅を設定
            child: Center(child: _buildPlayerHeader()),
          ),
        ), // 選手
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildPlayerHeaderTeam()),
          ),
        ), // チーム
        DataColumn(label: Center(child: _buildVerticalText('長打率'))),
        DataColumn(label: Center(child: _buildVerticalText('打数'))),
        DataColumn(label: Center(child: _buildVerticalText('単打'))),
        DataColumn(label: Center(child: _buildVerticalText('二塁打'))),
        DataColumn(label: Center(child: _buildVerticalText('三塁打'))),
        DataColumn(label: Center(child: _buildVerticalText('本塁打'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    } else {
      return [
        DataColumn(
          label: Container(
            child: Center(child: _buildPlayerNational()),
          ),
        ),
        DataColumn(
          label: Container(
            width: 100, // 選手列の幅を設定
            child: Center(child: _buildPlayerHeader()),
          ),
        ), // 選手
        DataColumn(
          label: Container(
            width: 100, // チーム列の幅を設定
            child: Center(child: _buildPlayerHeaderTeam()),
          ),
        ),
        DataColumn(
          label: Center(
            child: _buildVerticalText(_getValueLabel()),
          ),
        ),
        if (_selectedRankingType != '盗塁')
          DataColumn(label: Center(child: _buildVerticalText('打数'))),
        DataColumn(label: Center(child: _buildVerticalText('年齢'))),
      ];
    }
  }

  List<DataCell> _buildDataCells(Map<String, dynamic> player,
      {bool isUser = false}) {
    if (_selectedRankingType == '打率') {
      return [
        DataCell(Center(
          child: Text(
            player['prefecture']?.toString() ?? '不明',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              if (player['id'] != null) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  player['id'].toString(),
                  false,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Text(
                (player['name'] ?? '選手名不明').length > 8
                    ? (player['name'] as String).substring(0, 8) + '…'
                    : player['name'] ?? '選手名不明',
                style: TextStyle(
                  fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                  color: isUser ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamIDs = player['teamID'] as List<dynamic>? ?? [];
              if (teamIDs.isNotEmpty) {
                // 最初の teamID を使用してチームプロフィールを表示
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  teamIDs.first.toString(),
                  true,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: (player['team'] as List<dynamic>? ?? ['チーム名不明'])
                    .take(2) // 最大2つまで表示
                    .map((team) {
                  final displayTeam =
                      team.length > 8 ? '${team.substring(0, 8)}…' : team;
                  return Text(
                    displayTeam,
                    style: TextStyle(
                      fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                      color: isUser ? Colors.blue : Colors.black,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            formatPercentage(player['value'] ?? 0.0),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['atBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalHits']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['age']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '本塁打' ||
        _selectedRankingType == '盗塁' ||
        _selectedRankingType == '打点') {
      return [
        DataCell(Center(
          child: Text(
            player['prefecture']?.toString() ?? '不明',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              if (player['id'] != null) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  player['id'].toString(),
                  false,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Text(
                (player['name'] ?? '選手名不明').length > 8
                    ? (player['name'] as String).substring(0, 8) + '…'
                    : player['name'] ?? '選手名不明',
                style: TextStyle(
                  fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                  color: isUser ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamIDs = player['teamID'] as List<dynamic>? ?? [];
              if (teamIDs.isNotEmpty) {
                // 最初の teamID を使用してチームプロフィールを表示
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  teamIDs.first.toString(),
                  true,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: (player['team'] as List<dynamic>? ?? ['チーム名不明'])
                    .take(2) // 最大2つまで表示
                    .map((team) {
                  final displayTeam =
                      team.length > 8 ? '${team.substring(0, 8)}…' : team;
                  return Text(
                    displayTeam,
                    style: TextStyle(
                      fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                      color: isUser ? Colors.blue : Colors.black,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            player['value']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        if (_selectedRankingType != '盗塁')
          DataCell(Center(
            child: Text(
              player['atBats']?.toString() ?? '0',
              style: TextStyle(
                fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                color: isUser ? Colors.blue : Colors.black,
              ),
            ),
          )),
        DataCell(Center(
          child: Text(
            player['age']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '長打率') {
      return [
        DataCell(Center(
          child: Text(
            player['prefecture']?.toString() ?? '不明',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              if (player['id'] != null) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  player['id'].toString(),
                  false,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Text(
                (player['name'] ?? '選手名不明').length > 8
                    ? (player['name'] as String).substring(0, 8) + '…'
                    : player['name'] ?? '選手名不明',
                style: TextStyle(
                  fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                  color: isUser ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamIDs = player['teamID'] as List<dynamic>? ?? [];
              if (teamIDs.isNotEmpty) {
                // 最初の teamID を使用してチームプロフィールを表示
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  teamIDs.first.toString(),
                  true,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: (player['team'] as List<dynamic>? ?? ['チーム名不明'])
                    .take(2) // 最大2つまで表示
                    .map((team) {
                  final displayTeam =
                      team.length > 8 ? '${team.substring(0, 8)}…' : team;
                  return Text(
                    displayTeam,
                    style: TextStyle(
                      fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                      color: isUser ? Colors.blue : Colors.black,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            formatPercentage(player['value'] ?? 0.0),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['atBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['single']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['doubles']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['triples']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['homeRuns']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['age']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
      ];
    } else if (_selectedRankingType == '出塁率') {
      return [
        DataCell(Center(
          child: Text(
            player['prefecture']?.toString() ?? '不明',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(
          GestureDetector(
            onLongPress: () {
              if (player['id'] != null) {
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  player['id'].toString(),
                  false,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Text(
                (player['name'] ?? '選手名不明').length > 8
                    ? (player['name'] as String).substring(0, 8) + '…'
                    : player['name'] ?? '選手名不明',
                style: TextStyle(
                  fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                  color: isUser ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          GestureDetector(
            onLongPress: () {
              final teamIDs = player['teamID'] as List<dynamic>? ?? [];
              if (teamIDs.isNotEmpty) {
                // 最初の teamID を使用してチームプロフィールを表示
                final user = FirebaseAuth.instance.currentUser;
                showProfileDialog(
                  context,
                  teamIDs.first.toString(),
                  true,
                  currentUserUid: user?.uid,
                  currentUserName: user?.displayName,
                );
              }
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: (player['team'] as List<dynamic>? ?? ['チーム名不明'])
                    .take(2) // 最大2つまで表示
                    .map((team) {
                  final displayTeam =
                      team.length > 8 ? '${team.substring(0, 8)}…' : team;
                  return Text(
                    displayTeam,
                    style: TextStyle(
                      fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                      color: isUser ? Colors.blue : Colors.black,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        DataCell(Center(
          child: Text(
            formatPercentage(player['value'] ?? 0.0),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['totalBats']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
        DataCell(Center(
          child: Text(
            player['age']?.toString() ?? '0',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
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

  Widget _buildPlayerNational() {
    return const Center(
      child: Text(
        '都道府県',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  // 選手名のヘッダー
  static Widget _buildPlayerHeader() {
    return const Center(
      child: Text(
        '選手',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  // チーム名のヘッダー
  static Widget _buildPlayerHeaderTeam() {
    return const Center(
      child: Text(
        'チーム',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
