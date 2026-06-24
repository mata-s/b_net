import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:b_net/pages/private/national/national_batting.dart';
import 'package:b_net/pages/private/national/national_pitching.dart';
import 'package:b_net/pages/private/national/national_hit.dart';

class NationalPage extends StatefulWidget {
  final String uid;
  final String prefecture;

  const NationalPage({
    super.key,
    required this.uid,
    required this.prefecture,
  });

  @override
  State<NationalPage> createState() => _NationalPageState();
}

class _NationalPageState extends State<NationalPage> {
  int _currentIndex = 0; // 現在のインデックス
  final List<String> selectTypes = [
    'みんなのヒット',
    '各県トップ打者',
    '各県トップ投手',
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    selectTypes[_currentIndex],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
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

        return SizedBox(
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
                      child: Text(type, style: const TextStyle(fontSize: 22)),
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
