import 'package:b_net/pages/team/event_detail_page.dart';
import 'package:b_net/pages/team/input_schedule_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:collection';

class Event {
  final String id;
  final String title;
  final String opponent;
  final String location;
  final String details;
  final String? time;
  final String createdBy;
  final String createdName;
  List<Map<String, dynamic>> stamps;
  List<Map<String, dynamic>> comments;

  Event(
    this.id,
    this.title,
    this.opponent,
    this.location,
    this.details,
    this.time,
    this.createdBy,
    this.createdName,
    this.stamps,
    this.comments,
  );

  Event copyWith(
      {List<Map<String, dynamic>>? newStamps,
      List<Map<String, dynamic>>? newComments}) {
    return Event(
      id,
      title,
      opponent,
      location,
      details,
      time,
      createdBy,
      createdName,
      newStamps ?? stamps,
      newComments ?? comments,
    );
  }

  @override
  String toString() {
    return '予定: $title\n場所: $location\n対戦相手: $opponent\n詳細: $details';
  }

  String toDetailedString() {
    return '予定: $title\n場所: $location\n対戦相手: $opponent\n時間: $time\n詳細: $details';
  }
}

final kEvents = LinkedHashMap<DateTime, List<Event>>(
  equals: isSameDay,
  hashCode: getHashCode,
)..addAll(_kEventSource);

final Map<DateTime, List<Event>> _kEventSource = {};

int getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: TeamScheduleCalendar(teamId: 'YourTeamID'),
    );
  }
}

class TeamScheduleCalendar extends StatefulWidget {
  final String teamId;

  const TeamScheduleCalendar({super.key, required this.teamId});

  @override
  _TeamScheduleCalendarState createState() => _TeamScheduleCalendarState();
}

class _TeamScheduleCalendarState extends State<TeamScheduleCalendar> {
  late final ValueNotifier<List<Event>> _selectedEvents;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadTeamData();
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
        _selectedEvents.value = _getEventsForDay(selectedDay);
      });
    }
  }

  Future<void> _loadTeamData() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('schedule')
        .get();

    for (var doc in snapshot.docs) {
      DateTime gameDate = (doc['game_date'] as Timestamp).toDate();
      String title = doc['title'] ?? 'タイトルなし';
      String opponent = doc['opponent'] ?? '不明';
      String location = doc['location'] ?? '不明';
      String details = doc['details'] ?? '';
      String? time = doc['time'] ?? '未設定';

      // 🔹 Firestore のデータを Map<String, dynamic> にキャスト
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      String createdBy =
          data.containsKey('createdBy') ? data['createdBy'] : '不明';
      String createdName =
          data.containsKey('createdName') ? data['createdName'] : '不明';

      // 🔹 stamps フィールドがあるか確認し、存在しない場合は空リストにする
      List<Map<String, dynamic>> stamps = data.containsKey('stamps')
          ? List<Map<String, dynamic>>.from(data['stamps'])
          : [];

      // 🔹 comments フィールドがあるか確認し、存在しない場合は空リストにする
      List<Map<String, dynamic>> comments = data.containsKey('comments')
          ? List<Map<String, dynamic>>.from(data['comments'])
          : [];

      String id = doc.id;

      List<Event> events = [
        Event(id, title, opponent, location, details, time, createdBy,
            createdName, stamps, comments),
      ];

      if (kEvents.containsKey(gameDate)) {
        kEvents[gameDate]!.addAll(events);
      } else {
        kEvents[gameDate] = events;
      }
    }

    setState(() {
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    });
  }

  Future<void> _saveDataToFirestore(String title, String location,
      String opponent, String details, String? time) async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    String userName = userDoc['name'] ?? '未設定';
    DocumentReference docRef = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('schedule')
        .add({
      'game_date': _selectedDay,
      'title': title,
      'location': location,
      'opponent': opponent,
      'details': details,
      'time': time,
      'createdBy': userId,
      'createdName': userName,
      'stamps': [],
      'comments': []
    });

    kEvents.update(
      _selectedDay!,
      (existingEvents) => existingEvents
        ..add(Event(docRef.id, title, opponent, location, details, time, userId,
            userName, [], [])),
      ifAbsent: () => [
        Event(docRef.id, title, opponent, location, details, time, userId,
            userName, [], [])
      ],
    );

    setState(() {
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    });
  }

  Future<void> _stampEvent(Event event, String stampType) async {
    String userId = FirebaseAuth.instance.currentUser!.uid;

    // 🔹 Firestore からユーザーの情報を取得
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    String userName = userDoc['name'] ?? '未設定';

    // 🔹 既存のスタンプリストを取得
    List<Map<String, dynamic>> updatedStamps =
        List<Map<String, dynamic>>.from(event.stamps);

    // 🔹 同じユーザーのスタンプがあるか確認し、削除
    updatedStamps.removeWhere((stamp) => stamp['userId'] == userId);

    // 🔹 新しいスタンプを追加
    Map<String, dynamic> newStamp = {
      'userId': userId,
      'userName': userName,
      'stampType': stampType
    };
    updatedStamps.add(newStamp);

    // 🔹 Firestore を更新
    await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('schedule')
        .doc(event.id)
        .update({'stamps': updatedStamps});

    // 🔹 UI を更新
    setState(() {
      event.stamps = updatedStamps;
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$userName がスタンプ「$stampType」に変更しました")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
              builder: (context) => InputScheduleCalendar(
                selectedDate: _selectedDay!,
                teamId: widget.teamId,
              ),
            ),
          );
          if (result != null &&
              result['saved'] == true &&
              result['selectedDate'] != null) {
            setState(() {
              _selectedDay = result['selectedDate'];
              _focusedDay = result['selectedDate'];
            });
            _loadTeamData(); // 🔹 再読込でカレンダーを更新
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TableCalendar<Event>(
            firstDay: DateTime.now().subtract(const Duration(days: 90)),
            lastDay: DateTime.now().add(const Duration(days: 90)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
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
                    String userId = FirebaseAuth.instance.currentUser!.uid;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        border: Border.all(),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: ListTile(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4), // タイトルとスタンプ・コメントの間隔

                            // スタンプ数 & コメント数を表示
                            Row(
                              children: [
                                // スタンプ数
                                const Icon(Icons.emoji_emotions,
                                    color: Colors.blue, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  "${event.stamps.length} 件",
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                ),

                                const SizedBox(width: 12), // スタンプとコメントの間隔

                                // コメント数
                                const Icon(Icons.comment,
                                    color: Colors.green, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  "${event.comments.length} 件",
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventDetailPage(
                                event: event,
                                teamId: widget.teamId,
                                onUpdate: (updatedEvent) {
                                  setState(() {
                                    value[index] =
                                        updatedEvent; // 🔹 親画面のイベントデータも更新
                                    _selectedEvents.value =
                                        List<Event>.from(value);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                        trailing: event.createdBy == userId
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.orange),
                                    onPressed: () async {
                                      final result = await Navigator.push<
                                          Map<String, dynamic>>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              InputScheduleCalendar(
                                            selectedDate: _selectedDay!,
                                            teamId: widget.teamId,
                                            existingId: event.id,
                                            initialTitle: event.title,
                                            initialLocation: event.location,
                                            initialOpponent: event.opponent,
                                            initialDetails: event.details,
                                            initialTime: event.time,
                                          ),
                                        ),
                                      );
                                      if (result != null &&
                                          result['saved'] == true &&
                                          result['selectedDate'] != null) {
                                        setState(() {
                                          _selectedDay = result['selectedDate'];
                                          _focusedDay = result['selectedDate'];
                                        });
                                        _loadTeamData();
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () async {
                                      await _deleteEvent(event.id);
                                      value.removeAt(index);
                                      _selectedEvents.value =
                                          List<Event>.from(value);
                                    },
                                  ),
                                ],
                              )
                            : null,
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

  Future<void> _deleteEvent(String eventId) async {
    await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('schedule')
        .doc(eventId)
        .delete();

    setState(() {
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    });
  }
}
