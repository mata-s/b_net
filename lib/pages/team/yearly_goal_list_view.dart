import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class YearlyGoalListView extends StatefulWidget {
  final String teamId;

  const YearlyGoalListView({Key? key, required this.teamId}) : super(key: key);

  @override
  State<YearlyGoalListView> createState() => _YearlyGoalListViewState();
}

class _YearlyGoalListViewState extends State<YearlyGoalListView> {
  String? _selectedYear = null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('teams')
            .doc(widget.teamId)
            .collection('goals')
            .where('period', isEqualTo: 'year')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data!.docs;

          final years = allDocs
              .map((doc) => (doc['year'] ?? '').toString())
              .where((y) => y.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

          List<QueryDocumentSnapshot> filteredDocs;
          if (_selectedYear == null) {
            filteredDocs = List<QueryDocumentSnapshot>.from(allDocs);
          } else {
            filteredDocs = allDocs.where((doc) {
              final year = (doc['year'] ?? '').toString();
              return year == _selectedYear;
            }).toList();
          }
          // Sort by year descending
          filteredDocs.sort((a, b) {
            final ayear = int.tryParse((a['year'] ?? '').toString()) ?? 0;
            final byear = int.tryParse((b['year'] ?? '').toString()) ?? 0;
            return byear.compareTo(ayear);
          });

          if (filteredDocs.isEmpty) {
            return Column(
              children: [
                _buildYearDropdown(years),
                const SizedBox(height: 16),
                const Center(child: Text('今月の目標はまだありません')),
              ],
            );
          }

          final goalWidgets = filteredDocs.map((goal) {
            final goalData = goal.data() as Map<String, dynamic>;
            final title = goalData['title'] ?? '';
            final statField = goalData['statField'];
            final goalTarget = goalData['target'] ?? 0;
            final isRatio = goalData['isRatio'] ?? false;
            final isAchieved = goalData['isAchieved'] ?? false;

            if (statField == 'custom') {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Colors.amber, width: 3)),
                    ),
                    child: Text('${goalData['year'] ?? '-'}年の目標',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!isAchieved) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final goalRef = FirebaseFirestore.instance
                                      .collection("teams")
                                      .doc(widget.teamId)
                                      .collection("goals")
                                      .doc(goal.id);
                                  try {
                                    await goalRef.update({'isAchieved': true});
                                  } catch (e) {
                                    print('Error updating isAchieved: $e');
                                  }
                                },
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('目標を達成した！'),
                              ),
                            ],
                          ),
                        ],
                        if (isAchieved) ...[
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.auto_awesome, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('目標達成！',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }

            final current = (goalData.containsKey('actualValue') &&
                    goalData['actualValue'] is num)
                ? goalData['actualValue']
                : 0;
            final percentage = (goalData.containsKey('achievementRate') &&
                    goalData['achievementRate'] is num)
                ? (goalData['achievementRate'] as num)
                    .toStringAsFixed(1)
                    .replaceFirst(RegExp(r'\.0$'), '')
                : '0';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: Colors.amber, width: 3)),
                  ),
                  child: Text('${goalData['year'] ?? '-'}年の目標',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if ((goalData['compareType'] == 'less') || isRatio) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isRatio
                                  ? '実績：${statField == 'era' ? formatPercentageEra(current) : formatPercentage(current)}'
                                  : '実績：$current / $goalTarget',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '実績：$current / $goalTarget',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                      color: Colors.blueAccent, width: 2),
                                ),
                              ),
                              child: Text(
                                '達成率：${percentage}%',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (isAchieved) ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.auto_awesome, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('目標達成！',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }).toList();

          return Column(
            children: [
              _buildYearDropdown(years),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: goalWidgets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => goalWidgets[index],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildYearDropdown(List<String> years) {
    return GestureDetector(
      onTap: () {
        if (years.isEmpty) return;
        _showCupertinoPicker(
          context,
          ['すべて'] + years,
          _selectedYear ?? 'すべて',
          (selected) {
            setState(() {
              _selectedYear = selected == 'すべて' ? null : selected;
            });
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedYear != null ? '$_selectedYear年' : 'すべての年',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCupertinoPicker(
    BuildContext context,
    List<String> options,
    String selectedValue,
    Function(String) onSelected,
  ) {
    int selectedIndex = options.indexOf(selectedValue);
    if (selectedIndex == -1) selectedIndex = 0;
    String tempSelected = options[selectedIndex];

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
                        onSelected(tempSelected);
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
                scrollController:
                    FixedExtentScrollController(initialItem: selectedIndex),
                itemExtent: 40.0,
                onSelectedItemChanged: (int index) {
                  tempSelected = options[index];
                },
                children: options.map((option) {
                  return Center(
                    child: Text(
                      option,
                      style:
                          const TextStyle(fontSize: 22), // Increased font size
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
}

String formatPercentage(num value) {
  double doubleValue = value.toDouble();
  String formatted = doubleValue.toStringAsFixed(3);
  return formatted.startsWith("0")
      ? formatted.replaceFirst("0", "")
      : formatted;
}

String formatPercentageEra(num value) {
  double doubleValue = value.toDouble(); // num を double に変換
  return doubleValue.toStringAsFixed(2); // 小数点第2位までフォーマット
}
