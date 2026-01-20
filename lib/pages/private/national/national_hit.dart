import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class NationalHit extends StatefulWidget {
  final String uid;
  final String prefecture;

  const NationalHit({Key? key, required this.uid, required this.prefecture})
      : super(key: key);

  @override
  _NationalHitState createState() => _NationalHitState();
}

class _NationalHitState extends State<NationalHit> {
  List<Map<String, dynamic>> _players = [];
  int _year = DateTime.now().year;
  int _totalNationwideHits = 0;

  @override
  void initState() {
    super.initState();
    _fetchPlayersData();
  }

  Future<void> _fetchPlayersData() async {
    try {
      final DateTime currentDate = DateTime.now();
      final int year =
          currentDate.month < 4 ? currentDate.year - 1 : currentDate.year;

      setState(() {
        _year = year;
      });

      final String docPath = 'battingAverageRanking/${year}_total/全国/hits';

      // print('Firestoreクエリパス: $docPath');

      final snapshot = await FirebaseFirestore.instance.doc(docPath).get();

      if (snapshot.exists) {
        final List<dynamic> prefectureHits =
            snapshot.data()?['prefectureHits'] ?? [];

        // ✅ 「全国」の合計ヒット数を取り出す
        final nationwideData = prefectureHits.firstWhere(
          (hit) => hit['prefecture'] == '全国',
          orElse: () => null,
        );
        if (nationwideData != null) {
          setState(() {
            _totalNationwideHits = nationwideData['totalHits'] ?? 0;
          });
        }

        final List<Map<String, dynamic>> players = prefectureHits
            .map((hit) => Map<String, dynamic>.from(hit))
            .where((player) => player['prefecture'] != '全国')
            .toList();

        // `totalHits` で降順にソート
        players.sort(
            (a, b) => (b['totalHits'] ?? 0).compareTo(a['totalHits'] ?? 0));

        setState(() {
          _players = players;
        });

        // print('取得した都道府県データ: $_players');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // タイトル
            Container(
              alignment: Alignment.center,
              child: const Text(
                '全国',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 5),

            // 年
            Text(
              '$_year年',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            // 全国合計ヒット数
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Text(
                '全国合計：$_totalNationwideHits本',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),

            // データが空ならメッセージ、それ以外ならテーブル表示
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

  List<DataRow> _buildPlayerRows() {
    return _players.map((player) {
      final isUser =
          player['prefecture'] == widget.prefecture; // ユーザー自身の都道府県チェック
      return DataRow(
        color: MaterialStateProperty.resolveWith<Color?>(
          (states) {
            if (isUser) {
              return const Color(0xFF1565C0).withOpacity(0.08);
            }
            return null;
          },
        ),
        cells: _buildDataCells(player, isUser: isUser),
      );
    }).toList();
  }

  List<DataColumn> _buildDataColumns() {
    return [
      DataColumn(
        label: Container(
          width: 100, // 選手列の幅を設定
          child: Center(child: _buildPlayerNational()),
        ),
      ),
      DataColumn(
        label: Container(
          width: 100, // 選手列の幅を設定
          child: Center(child: _nationalHits()),
        ),
      ),
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
      DataCell(Center(
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: player['totalHits']?.toString() ?? '0', // ヒット数の部分
                style: TextStyle(
                  fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                  color: isUser ? Colors.blue : Colors.black,
                  fontSize: 16, // 通常の文字サイズ
                ),
              ),
              TextSpan(
                text: '本', // 本の部分
                style: TextStyle(
                  fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                  color: isUser ? Colors.blue : Colors.black,
                  fontSize: 12, // 小さな文字サイズ
                ),
              ),
            ],
          ),
        ),
      )),
    ];
  }

  Widget _buildPlayerNational() {
    return const Center(
      child: Text(
        '都道府県',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _nationalHits() {
    return const Center(
      child: Text(
        'ヒット数',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
