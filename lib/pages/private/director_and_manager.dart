import 'package:b_net/pages/private/input_memo.dart';
import 'package:b_net/pages/private/view_memo.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DirectorAndManagerPage extends StatefulWidget {
  final String userUid;
  final List<String> userPosition;

  const DirectorAndManagerPage({
    Key? key,
    required this.userUid,
    required this.userPosition,
  }) : super(key: key);

  @override
  _DirectorAndManagerPageState createState() => _DirectorAndManagerPageState();
}

class _DirectorAndManagerPageState extends State<DirectorAndManagerPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  List<Map<String, dynamic>> _memos = [];
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  List<int> _availableYears = [];
  List<int> _availableMonths = [];

  bool _filterImportant = false;
  bool _filterReread = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
      _loadMemosForSelectedMonth(); // 検索時にも再読み込み
    });
    _loadMemosForSelectedMonth();
    _loadAvailableYearsAndMonths();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMemosForSelectedMonth() async {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('memos');

    // Updated filter logic for important/reread
    if (_filterImportant || _filterReread) {
      final filters = <Filter>[];
      if (_filterImportant) {
        filters.add(Filter('isImportant', isEqualTo: true));
      }
      if (_filterReread) {
        filters.add(Filter('shouldReread', isEqualTo: true));
      }
      query = query.where(
        Filter.or(
          filters[0],
          filters.length > 1 ? filters[1] : filters[0],
        ),
      );
    }

    // 検索・フィルターがない場合のみ、年月で絞り込む
    if (!_filterImportant && !_filterReread && _searchText.isEmpty) {
      final startOfMonth = DateTime(_selectedYear, _selectedMonth, 1);
      final startOfNextMonth = DateTime(_selectedYear, _selectedMonth + 1, 1);

      query = query
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThan: Timestamp.fromDate(startOfNextMonth));
    }

    final snapshot = await query.get();

    final allMemos =
        snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

    // 検索テキストに基づくフィルタリングはフィルターの有無に関係なく適用
    final filteredMemos = allMemos
        .where((memo) =>
            _searchText.isEmpty ||
            (memo['opponent']?.toString().contains(_searchText) ?? false) ||
            (memo['memo']?.toString().contains(_searchText) ?? false) ||
            (memo['result']?.toString().contains(_searchText) ?? false) ||
            (memo['location']?.toString().contains(_searchText) ?? false) ||
            (memo['score']?.toString().contains(_searchText) ?? false))
        .toList();

    setState(() {
      _memos = filteredMemos;
    });
  }

  Future<void> _loadAvailableYearsAndMonths() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('memos')
        .orderBy('date', descending: true)
        .get();

    final years = <int>{};
    final months = <int>{};

    for (var doc in snapshot.docs) {
      final timestamp = doc['date'] as Timestamp?;
      if (timestamp != null) {
        final date = timestamp.toDate();
        years.add(date.year);
        if (date.year == _selectedYear) {
          months.add(date.month);
        }
      }
    }

    setState(() {
      _availableYears = years.toList()..sort((a, b) => b.compareTo(a));
      _availableMonths = months.toList()..sort();
    });
  }

  void _showYearMonthPicker(BuildContext context) {
    int tempYear = _selectedYear;
    int tempMonth = _selectedMonth;

    showModalBottomSheet(
      context: context,
      builder: (context) {
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
                        child: Text('キャンセル')),
                    Text('年月を選択',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedYear = tempYear;
                          _selectedMonth = tempMonth;
                        });
                        Navigator.pop(context);
                        _loadMemosForSelectedMonth();
                      },
                      child: Text('決定', style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController: FixedExtentScrollController(
                            initialItem:
                                _availableYears.indexOf(_selectedYear)),
                        onSelectedItemChanged: (index) {
                          tempYear = _availableYears[index];
                        },
                        children: _availableYears
                            .map((y) => Center(child: Text('$y年')))
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController: FixedExtentScrollController(
                            initialItem:
                                _availableMonths.indexOf(_selectedMonth)),
                        onSelectedItemChanged: (index) {
                          tempMonth = _availableMonths[index];
                        },
                        children: _availableMonths
                            .map((m) => Center(child: Text('$m月')))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'キーワード検索',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchText = '';
                          });
                          _loadMemosForSelectedMonth();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Checkbox(
                value: _filterImportant,
                onChanged: (value) {
                  setState(() {
                    _filterImportant = value!;
                    _loadMemosForSelectedMonth();
                  });
                },
              ),
              const Text('重要'),
              const SizedBox(width: 16),
              Checkbox(
                value: _filterReread,
                onChanged: (value) {
                  setState(() {
                    _filterReread = value!;
                    _loadMemosForSelectedMonth();
                  });
                },
              ),
              const Text('読み直し'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_selectedYear年 $_selectedMonth月',
                    style: TextStyle(fontSize: 18)),
                TextButton(
                  onPressed: () => _showYearMonthPicker(context),
                  child: Text('変更', style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _memos.isEmpty
                ? Center(child: Text('今月のメモはありません'))
                : ListView.builder(
                    itemCount: _memos.length,
                    itemBuilder: (context, index) {
                      final memo = _memos[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewMemoPage(
                                memoData: memo,
                                userUid: widget.userUid,
                                userPosition: widget.userPosition,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (memo['opponent'] != null &&
                                    memo['opponent'].toString().isNotEmpty)
                                  Text(
                                    'vs ${memo['opponent']}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                const SizedBox(height: 4),
                                if (memo['location'] != null &&
                                    memo['location'].toString().isNotEmpty)
                                  Text(
                                    '@ ${memo['location']}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                const SizedBox(height: 4),
                                if ((memo['score'] != null &&
                                        memo['score'].toString().isNotEmpty) ||
                                    (memo['result'] != null &&
                                        memo['result'].toString().isNotEmpty))
                                  Row(
                                    children: [
                                      if (memo['score'] != null &&
                                          memo['score'].toString().isNotEmpty)
                                        Text(
                                          memo['score'],
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      if (memo['score'] != null &&
                                          memo['score'].toString().isNotEmpty &&
                                          memo['result'] != null &&
                                          memo['result'].toString().isNotEmpty)
                                        const SizedBox(width: 10),
                                      if (memo['result'] != null &&
                                          memo['result'].toString().isNotEmpty)
                                        Text(
                                          memo['result'],
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                    ],
                                  ),
                                if (memo['memo'] != null &&
                                    memo['memo'].toString().isNotEmpty)
                                  Text(
                                    memo['memo'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  (memo['date'] as Timestamp)
                                      .toDate()
                                      .toString()
                                      .split(' ')[0],
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InputMemoPage(
                userUid: widget.userUid,
                userPosition: widget.userPosition,
              ),
            ),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
