import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
            const SizedBox(height: 8),
            const Text(
              '都道府県ヒットバトル',
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
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.black12,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '全国合計 $_totalNationwideHits本',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ],
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
    return _players.asMap().entries.map((entry) {
      final rank = entry.key + 1;
      final player = entry.value;
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
        cells: _buildDataCells(
          player,
          rank: rank,
          isUser: isUser,
        ),
      );
    }).toList();
  }

  List<DataColumn> _buildDataColumns() {
    return [
      const DataColumn(
        label: SizedBox(
          width: 60,
          child: Center(
            child: Text(
              '順位',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      DataColumn(
        label: SizedBox(
          width: 100,
          child: Center(child: _buildPlayerNational()),
        ),
      ),
      DataColumn(
        label: SizedBox(
          width: 100,
          child: Center(child: _nationalHits()),
        ),
      ),
    ];
  }

  List<DataCell> _buildDataCells(
    Map<String, dynamic> player, {
    required int rank,
    bool isUser = false,
  }) {
    return [
      DataCell(
        Center(
          child: Text(
            '${rank}位',
            style: TextStyle(
              fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
              color: isUser ? Colors.blue : Colors.black,
            ),
          ),
        ),
      ),
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
