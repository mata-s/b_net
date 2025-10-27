import 'package:b_net/pages/private/director/schedule_input_page.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class ManagerCalendar extends StatefulWidget {
  final String userUid;
  final String teamId;

  const ManagerCalendar({
    super.key,
    required this.userUid,
    required this.teamId,
  });

  @override
  State<ManagerCalendar> createState() => _ManagerCalendarState();
}

class _ManagerCalendarState extends State<ManagerCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedDay != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScheduleInputPage(
                    selectedDate: _selectedDay!,
                    userUid: widget.userUid,
                    teamId: widget.teamId),
              ),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
      body: TableCalendar(
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
      ),
    );
  }
}
