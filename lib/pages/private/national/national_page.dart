import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:b_net/pages/private/national/national_batting.dart';
import 'package:b_net/pages/private/national/national_pitching.dart';
import 'package:b_net/pages/private/national/national_hit.dart';

class NationalPage extends StatefulWidget {
  final String uid;
  final String prefecture;

  const NationalPage({super.key, required this.uid, required this.prefecture});

  @override
  State<NationalPage> createState() => _NationalPageState();
}

class _NationalPageState extends State<NationalPage> {
  int _currentIndex = 0; // 現在のインデックス
  final List<String> selectTypes = [
    'みんなのヒット！',
    '打撃(各県上位1名)',
    '投手(各県上位1名)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          GestureDetector(
            onTap: () {
              _showCupertinoPicker(context); // ピッカーを表示
            },
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black54,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    selectTypes[_currentIndex], // 現在の選択タイプを表示
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // IndexedStackでページを切り替え
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                NationalHit(
                  uid: widget.uid,
                  prefecture: widget.prefecture,
                ),
                NationalBatting(
                  uid: widget.uid,
                  prefecture: widget.prefecture,
                ),
                NationalPitching(
                  uid: widget.uid,
                  prefecture: widget.prefecture,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCupertinoPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        int tempIndex = _currentIndex;

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
                          _currentIndex = tempIndex;
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
                  children: selectTypes.map((type) {
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
}
