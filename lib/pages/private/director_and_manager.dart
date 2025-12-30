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
                      return Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Material(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1行目: 対戦相手 + 日付バッジ
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (memo['opponent'] != null &&
                          memo['opponent'].toString().isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.sports_baseball, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'vs ${memo['opponent']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (memo['location'] != null &&
                          memo['location'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.place_outlined,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  memo['location'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _DateBadge(
                  text: (memo['date'] as Timestamp)
                      .toDate()
                      .toString()
                      .split(' ')[0],
                ),
              ],
            ),

            // スコア/結果のチップ
            if ((memo['score'] != null &&
                    memo['score'].toString().isNotEmpty) ||
                (memo['result'] != null &&
                    memo['result'].toString().isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (memo['score'] != null &&
                        memo['score'].toString().isNotEmpty)
                      _InfoChip(
                        icon: Icons.scoreboard_outlined,
                        label: memo['score'].toString(),
                      ),
                    if (memo['result'] != null &&
                        memo['result'].toString().isNotEmpty)
                      _InfoChip(
                        icon: Icons.emoji_events_outlined,
                        label: memo['result'].toString(),
                      ),
                  ],
                ),
              ),

            // メモ本文
            if (memo['memo'] != null && memo['memo'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  memo['memo'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),

            // 重要/読み直しのバッジ
            if ((memo['isImportant'] == true) || (memo['shouldReread'] == true))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (memo['isImportant'] == true)
                      _TagPill(icon: Icons.star_rounded, label: '重要'),
                    if (memo['shouldReread'] == true)
                      _TagPill(icon: Icons.bookmark_added_rounded, label: '読み直し'),
                  ],
                ),
              ),
          ],
        ),
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

class _DateBadge extends StatelessWidget {
  final String text;
  const _DateBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
      ),
child: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    const Icon(
      Icons.calendar_today_outlined,
      size: 14,
      color: Colors.grey,
    ),
    const SizedBox(width: 6),
    Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        color: Colors.grey,
        fontWeight: FontWeight.w600,
      ),
    ),
  ],
),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TagPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.amber.withOpacity(0.12)
            : Colors.amber.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.amber.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.amber.shade200
                  : Colors.amber.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
