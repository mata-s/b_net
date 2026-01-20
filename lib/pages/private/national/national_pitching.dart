import 'package:b_net/common/profile_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NationalPitching extends StatefulWidget {
  final String uid;
  final String prefecture;

  const NationalPitching(
      {Key? key, required this.uid, required this.prefecture})
      : super(key: key);

  @override
  _NationalPitchingState createState() => _NationalPitchingState();
}

class _NationalPitchingState extends State<NationalPitching> {
  List<Map<String, dynamic>> _players = [];
  String _selectedRankingType = '防御率';
  int _year = DateTime.now().year;
  int _totalPitchersCount = 0;

  final List<String> rankingTypes = [
    '防御率',
    '奪三振',
    'ホールドポイント',
    'セーブ',
    '勝率',
  ];

  @override
  void initState() {
    super.initState();
    _fetchPlayersData();
    _fetchTotalPitchersCount();
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

      final String docPath = 'pitcherRanking/${year}_total/全国/$rankingField';
      // print('Firestoreクエリパス: $docPath');

      final snapshot = await FirebaseFirestore.instance.doc(docPath).get();

      if (snapshot.exists) {
        final List<dynamic> topPlayers = snapshot.data()?['top'] ?? [];
        final List<Map<String, dynamic>> players = topPlayers
            .map((player) => Map<String, dynamic>.from(player))
            .toList();

        players.sort((a, b) {
          final double valueA = (a['value'] ?? 0.0).toDouble();
          final double valueB = (b['value'] ?? 0.0).toDouble();
          return _selectedRankingType == '防御率'
              ? valueA.compareTo(valueB) // 昇順（低い順）
              : valueB.compareTo(valueA); // 降順（高い順）
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
      case '防御率':
        return 'eraRank';
      case '奪三振':
        return 'totalPStrikeoutsRank';
      case 'ホールドポイント':
        return 'totalHoldPointsRank';
      case 'セーブ':
        return 'totalSavesRank';
      case '勝率':
        return 'winRateRank';
      default:
        return '';
    }
  }

  String _getValueLabel() {
    switch (_selectedRankingType) {
      case '防御率':
        return '防御率';
      case '奪三振':
        return '奪三振';
      case 'ホールドポイント':
        return 'HD';
      case 'セーブ':
        return 'セーブ';
      case '勝率':
        return '勝率';
      default:
        return '防御率';
    }
  }

  Future<void> _fetchTotalPitchersCount() async {
    try {
      final docPath = 'pitcherRanking/${_year}_total/全国/stats';
      final snapshot = await FirebaseFirestore.instance.doc(docPath).get();

      if (snapshot.exists) {
        final data = snapshot.data();
        setState(() {
          _totalPitchersCount = data?['totalPitchersCount'] ?? 0;
        });
      }
    } catch (e) {
      print('👀 ttotalPitchersCountの取得エラー: $e');
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
            // ▼▼▼ 常にドロップダウン＋矢印UIを表示 ▼▼▼
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.navigate_before, size: 28.0),
                            onPressed: () {
                              final currentIndex =
                                  rankingTypes.indexOf(_selectedRankingType);
                              final previousIndex =
                                  (currentIndex - 1 + rankingTypes.length) %
                                      rankingTypes.length;
                              setState(() {
                                _selectedRankingType =
                                    rankingTypes[previousIndex];
                                _fetchPlayersData();
                              });
                            },
                          ),
                          InkWell(
                            onTap: () => _showCupertinoPicker(context),
                            child: Row(
                              children: [
                                Container(
                                  // decoration: const BoxDecoration(
                                  //   border: Border(bottom: BorderSide(color: Colors.grey)),
                                  // ),
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
                            icon: Icon(Icons.navigate_next, size: 28.0),
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
              ],
            ),
            // ▲▲▲ ここまで差し替え ▲▲▲
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Text(
                '$_totalPitchersCount人ランキングに参加中',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
        int tempIndex = rankingTypes.indexOf(_selectedRankingType);

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
                  scrollController:
                      FixedExtentScrollController(initialItem: tempIndex),
                  onSelectedItemChanged: (int index) {
                    tempIndex = index;
                  },
                  children: rankingTypes.map((type) {
                    return Center(
                      child: Text(type, style: TextStyle(fontSize: 22)),
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
      final String playerPref = (player['prefecture']?.toString() ?? '').trim();
      final String userPref = widget.prefecture.trim();
      final bool isSamePrefecture = !isUser && userPref.isNotEmpty && playerPref == userPref;

      return DataRow(
        color: MaterialStateProperty.resolveWith<Color?>((states) {
          if (isUser) {
            return const Color(0xFF1565C0).withOpacity(0.08);
          }
          if (isSamePrefecture) {
            return const Color(0xFF1565C0).withOpacity(0.04);
          }
          return null;
        }),
        cells: _buildDataCells(player, isUser: isUser),
      );
    }).toList();
  }

  List<DataColumn> _buildDataColumns() {
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
      DataColumn(label: Center(child: _buildVerticalText('登板'))),
      if (_selectedRankingType == '防御率')
        DataColumn(label: Center(child: _buildVerticalText('投球回'))),
    ];
  }

  List<DataCell> _buildDataCells(Map<String, dynamic> player,
      {bool isUser = false}) {
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
      if (_selectedRankingType == '防御率')
        DataCell(Center(
          child: Text(
            formatPercentageEra(player['value'] ?? 0.0),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
      if (_selectedRankingType == '勝率')
        DataCell(Center(
          child: Text(
            formatPercentage(player['value'] ?? 0.0),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
      // 他のランキングには共通のフォーマットを適用
      if (_selectedRankingType != '防御率' && _selectedRankingType != '勝率')
        DataCell(Center(
          child: Text(
            player['value']?.toString() ?? '0.00',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
      DataCell(Center(
        child: Text(
          player['totalAppearances']?.toString() ?? '0',
          style: TextStyle(
            fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
            color: isUser ? Colors.blue : Colors.black,
          ),
        ),
      )),
      if (_selectedRankingType == '防御率')
        DataCell(Center(
          child: Text(
            (player['totalInningsPitched'] != null
                ? (player['totalInningsPitched'] as num).toStringAsFixed(1)
                : '0.0'),
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        )),
    ];
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
