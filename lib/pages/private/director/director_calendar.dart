import 'package:b_net/pages/private/director/schedule_input_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class DirectoCalendar extends StatefulWidget {
  final String userUid;
  final String teamId;

  const DirectoCalendar({
    super.key,
    required this.userUid,
    required this.teamId,
  });

  @override
  State<DirectoCalendar> createState() => _DirectoCalendarState();
}

class _DirectoCalendarState extends State<DirectoCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {}; // 🔹 追加

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents(); // 🔹 イベント読み込み
  }

  Future<void> _loadEvents() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('schedules')
        .get();

    for (var doc in snapshot.docs) {
      try {
        final docId = doc.id;
        final parts = docId.split('-');
        if (parts.length == 3) {
          final dateOnly = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          _events[dateOnly] = [
            {
              'title': 'オーダー',
              'docId': doc.id,
            }
          ];
        }
      } catch (_) {
        // Invalid date format in document ID, skip
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('オーダーを考える'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedDay != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScheduleInputPage(
                  selectedDate: _selectedDay!,
                  userUid: widget.userUid,
                  teamId: widget.teamId,
                ),
              ),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TableCalendar(
            locale: 'ja_JP',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31), // ← 余裕をもたせた最大日付
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: const CalendarStyle(
              todayDecoration:
                  BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              selectedDecoration:
                  BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
            ),
            eventLoader: (day) =>
                _events[DateTime(day.year, day.month, day.day)] ?? [],
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedDay != null &&
              _events[DateTime(_selectedDay!.year, _selectedDay!.month,
                      _selectedDay!.day)] !=
                  null)
            Column(
              children: _events[DateTime(_selectedDay!.year,
                      _selectedDay!.month, _selectedDay!.day)]!
                  .map((event) => Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        elevation: 2,
                        child: ListTile(
                          title: Text(event['title']),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ScheduleInputPage(
                                  selectedDate: _selectedDay!,
                                  userUid: widget.userUid,
                                  teamId: widget.teamId,
                                  scheduleDocId: event['docId'],
                                ),
                              ),
                            );
                          },
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}
