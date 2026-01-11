import 'package:b_net/pages/private/game_input_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Event {
  final String id;
  final String opponent;
  final String location;

  const Event(this.id, this.opponent, this.location);

  @override
  String toString() => 'VS $opponent 場所: $location';
}

final kEvents = LinkedHashMap<DateTime, List<Event>>(
  equals: isSameDay,
  hashCode: getHashCode,
)..addAll(_kEventSource);

// 空のマップとして初期化
final Map<DateTime, List<Event>> _kEventSource = {};

int getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

/// 指定された期間内の日付のリストを返す関数
List<DateTime> daysInRange(DateTime first, DateTime last) {
  final dayCount = last.difference(first).inDays + 1;
  return List.generate(
    dayCount,
    (index) => DateTime.utc(first.year, first.month, first.day + index),
  );
}

final kToday = DateTime.now();
final kFirstDay = DateTime(kToday.year, kToday.month - 3, kToday.day);
final kLastDay = DateTime(kToday.year, kToday.month + 3, kToday.day);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const String userUid = "";
    return const MaterialApp(
      home: PrivateCalendar(
        userUid: userUid,
        positions: <String>[],
      ),
    );
  }
}

class PrivateCalendar extends StatefulWidget {
  final String userUid;
  final List<String> positions;
  final VoidCallback? onSaved;

  const PrivateCalendar({
    super.key,
    required this.userUid,
    required this.positions,
    this.onSaved,
  });

  @override
  _PrivateCalendarState createState() => _PrivateCalendarState();
}

class _PrivateCalendarState extends State<PrivateCalendar> {
  late final ValueNotifier<List<Event>> _selectedEvents;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadUserData();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    kEvents.clear();
    super.dispose();
  }

  List<Event> _getEventsForDay(DateTime day) {
    return kEvents[day] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        // 新しい日付のイベントのみを表示するようにする
        _selectedEvents.value = _getEventsForDay(selectedDay);
      });
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final String uid = user.uid;

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('games')
          .get();

      // kEventsをクリアしてから、新しいデータを追加
      kEvents.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data()
            as Map<String, dynamic>?; // データをMap<String, dynamic>にキャスト
        if (data != null && data.containsKey('gameDate')) {
          DateTime gameDate = (data['gameDate'] as Timestamp).toDate();
          String opponent = data['opponent'] ?? '不明';
          String location = data['location'] ?? '不明';
          String id = doc.id;

          List<Event> events = [
            Event(id, opponent, location),
          ];

          if (kEvents.containsKey(gameDate)) {
            kEvents[gameDate]!.addAll(events);
          } else {
            kEvents[gameDate] = events;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
      });
    }
  }

  void _resetDataDay() {
    _selectedDay = _focusedDay;
    _selectedEvents.value = _getEventsForDay(_selectedDay!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedDay == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameInputPage(
                selectedDate: _selectedDay!,
                positions: widget.positions,
              ),
            ),
          ).then((result) {
            if (result == true) {
              print('▶ GameInputPage から戻り → データ再読み込み');
              _loadUserData(); // 🔄 試合データ再取得
            }
          });
        },
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableCalendar<Event>(
                  firstDay: kFirstDay,
                  lastDay: kLastDay,
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: CalendarFormat.month, // 月表示を固定
                  eventLoader: _getEventsForDay,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarStyle: const CalendarStyle(
                    outsideDaysVisible: false,
                    markersMaxCount: 1,
                  ),
                  onDaySelected: _onDaySelected,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  locale: 'ja_JP',
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isNotEmpty) {
                        return Positioned(
                          bottom: 1,
                          child: _buildEventsMarker(date, events),
                        );
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: ValueListenableBuilder<List<Event>>(
                    valueListenable: _selectedEvents,
                    builder: (context, value, _) {
                      if (value.isEmpty) {
                        return const Center(
                          child: Text("イベントなし"),
                        );
                      }
                      return ListView.builder(
                        itemCount: value.length,
                        itemBuilder: (context, index) {
                          final event = value[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: ListTile(
                              title: Text(event.toString()),
                              onTap: () {
                                _showEventDetailsBottomSheet(context, event.id);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEventsMarker(DateTime date, List events) {
    return Container(
      width: 7.0,
      height: 7.0,
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
    );
  }
}

void _showEventDetailsBottomSheet(BuildContext context, String eventId) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) return;

  final String uid = user.uid;

  // Firestoreから指定のイベントIDのデータを取得
  final DocumentSnapshot eventSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('games')
      .doc(eventId)
      .get();

  if (!eventSnapshot.exists) return;

  final eventData = eventSnapshot.data() as Map<String, dynamic>;

  // ユーザー情報を取得してポジションを確認
  final DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();

  final List<dynamic> userPositions = (userDoc.data() as Map<String, dynamic>?)
          ?['positions'] as List<dynamic>? ??
      [];

  final bool isTablet = MediaQuery.of(context).size.width >= 600;

  Widget content(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // iPadは横幅を抑えて読みやすく
          maxWidth: isTablet ? 720 : double.infinity,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '試合詳細',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 試合の基本情報
              Text(
                '${eventData['gameType'] ?? '不明'}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                '対戦相手: ${eventData['opponent'] ?? '不明'}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                '場所: ${eventData['location'] ?? '不明'}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),

              // 投手成績（もし投手なら）
              if (userPositions.contains('投手')) ...[
                const Text(
                  '投手成績',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '投球回: ${eventData['inningsThrow'] ?? 0}回',
                    ),

                    if (eventData['outFraction'] != null &&
                        eventData['outFraction'] != '0' &&
                        eventData['outFraction'].isNotEmpty)
                      Text(
                        'と${eventData['outFraction']}',
                      ),
                    const SizedBox(
                      width: 45,
                    ),

                    if (eventData['resultGame'] != null &&
                        eventData['resultGame'] != '0' &&
                        eventData['resultGame'].isNotEmpty)
                      Text('${eventData['resultGame']}投手'),
                    // 完投がtrueの場合
                    if (eventData['isCompleteGame'] == true) ...[
                      const SizedBox(width: 10),
                      const Text('完投'),
                    ],
                    // 完封がtrueの場合
                    if (eventData['isShutoutGame'] == true) ...[
                      const SizedBox(width: 10),
                      const Text('完封'),
                    ],
                    // セーブがtrueの場合
                    if (eventData['isSave'] == true) ...[
                      const SizedBox(width: 10),
                      const Text('セーブ'),
                    ],
                    // ホールドがtrueの場合
                    if (eventData['isHold'] == true) ...[
                      const SizedBox(width: 10),
                      const Text('ホールド'),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('登板: ${eventData['appearanceType'] ?? 0}'),
                    const SizedBox(
                      width: 45,
                    ),
                    Text('対戦打者: ${eventData['battersFaced'] ?? 0}人'),
                    const SizedBox(
                      width: 45,
                    ),
                    Text('球数: ${eventData['pitchCount'] ?? 0}球'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('与四球: ${eventData['walks'] ?? 0}'),
                    ),
                    Expanded(
                      child: Text('与死球: ${eventData['hitByPitch'] ?? 0}'),
                    ),
                    Expanded(
                      child: Text('失点: ${eventData['runsAllowed'] ?? 0}'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('自責点: ${eventData['earnedRuns'] ?? 0}'),
                    ),
                    Expanded(
                      child: Text('被安打: ${eventData['hitsAllowed'] ?? 0}'),
                    ),
                    Expanded(
                      child: Text('奪三振: ${eventData['strikeouts'] ?? 0}'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // 打席結果
              const Text('打席結果',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (eventData['atBats'] != null && eventData['atBats'] is List)
                ...List.generate((eventData['atBats'] as List).length, (index) {
                  final atBat = eventData['atBats'][index];
                  final swingCount = atBat['swingCount'];
                  final batterPitchCount = atBat['batterPitchCount'];

                  String extraInfo = '';
                  if (swingCount != null) {
                    extraInfo += 'スイング数: $swingCount';
                  }
                  if (batterPitchCount != null) {
                    if (extraInfo.isNotEmpty) extraInfo += ' / ';
                    extraInfo += '球数: $batterPitchCount';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${atBat['at_bat']}打席目: '
                      '${atBat['position'] ?? '不明'} - '
                      '${atBat['result'] ?? '不明'}'
                      '${extraInfo.isNotEmpty ? '（$extraInfo）' : ''}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('盗塁: ${eventData['steals'] ?? 0}'),
                  Text('打点: ${eventData['rbis'] ?? 0}'),
                  Text('得点: ${eventData['runs'] ?? 0}'),
                ],
              ),
              const SizedBox(height: 20),

              // 守備成績
              const Text(
                '守備成績',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('刺殺: ${eventData['putouts'] ?? 0}'),
                  Text('捕殺: ${eventData['assists'] ?? 0}'),
                  Text('失策: ${eventData['errors'] ?? 0}'),
                ],
              ),
              if (userPositions.contains('捕手')) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('盗塁刺し: ${eventData['caughtStealing'] ?? 0}'),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // メモ
              const Text(
                'メモ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(eventData['memo'] ?? 'メモなし'),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('閉じる'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  if (isTablet) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            // 画面の高さに対して適度なサイズ
            height: MediaQuery.of(dialogContext).size.height * 0.82,
            child: Center(child: content(dialogContext)),
          ),
        );
      },
    );
  } else {
    // スマホはボトムシート
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.8,
          width: MediaQuery.of(sheetContext).size.width,
          child: content(sheetContext),
        );
      },
    );
  }
}
