import 'package:b_net/pages/team/game_team_input_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String opponent;
  final String location;
  final String gameType;
  final int score;
  final int runsAllowed;
  final String result;

  const Event(this.id, this.opponent, this.location, this.gameType, this.score,
      this.runsAllowed, this.result);

  @override
  String toString() => 'VS $opponent 場所: $location';
}

final kEvents = LinkedHashMap<DateTime, List<Event>>(
  equals: isSameDay,
  hashCode: getHashCode,
)..addAll(_kEventSource);

final Map<DateTime, List<Event>> _kEventSource = {};

int getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

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
    return const MaterialApp(
      home: TeamGradesCalendar(teamId: 'YourTeamID'),
    );
  }
}

class TeamGradesCalendar extends StatefulWidget {
  final String teamId;

  const TeamGradesCalendar({super.key, required this.teamId});

  @override
  _TeamGradesCalendarState createState() => _TeamGradesCalendarState();
}

class _TeamGradesCalendarState extends State<TeamGradesCalendar> {
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
    final snapshot = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('team_games')
        .get();

    // 再読み込み時に重複しないように一度クリア
    kEvents.clear();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final ts = data['game_date'];
      if (ts is! Timestamp) {
        // game_date が無い/形式が違う場合はスキップ
        continue;
      }

      final gameDateUTC = ts.toDate();
      final gameDateJST = gameDateUTC.toLocal();

      final opponent = (data['opponent'] as String?) ?? '不明';
      final location = (data['location'] as String?) ?? '不明';
      final gameType = (data['game_type'] as String?) ?? '不明';

      // Firestore は int / double が混在するので num で受ける
      final score = (data['score'] as num?)?.toInt() ?? 0;
      final runsAllowed = (data['runs_allowed'] as num?)?.toInt() ?? 0;

      final result = (data['result'] as String?) ?? '不明';

      final events = [
        Event(doc.id, opponent, location, gameType, score, runsAllowed, result),
      ];

      if (kEvents.containsKey(gameDateJST)) {
        kEvents[gameDateJST]!.addAll(events);
      } else {
        kEvents[gameDateJST] = events;
      }
    }

    if (!mounted) return;

    setState(() {
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameTeamInputPage(
                teamId: widget.teamId,
                selectedDate: _selectedDay ?? _focusedDay,
              ),
            ),
          );

          if (result == true) {
            await _loadTeamData();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TableCalendar<Event>(
            firstDay: kFirstDay,
            lastDay: kLastDay,
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
                  return const Center(child: Text("イベントなし"));
                }
                return ListView.builder(
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    final event = value[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        border: Border.all(),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: ListTile(
                        title: Text(event.toString()),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16.0)),
                            ),
                            builder: (_) => GameDetailPage(event: event),
                          );
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
}

class GameDetailPage extends StatelessWidget {
  final Event event;

  const GameDetailPage({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4,
      width: double.infinity,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.gameType, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),
                  Text('対戦相手: ${event.opponent}',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),
                  Text('場所: ${event.location}',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),
                  Text('${event.score} - ${event.runsAllowed}',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),
                  Text('試合結果: ${event.result}',
                      style: const TextStyle(fontSize: 18)),
                  const Spacer(),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('とじる'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
