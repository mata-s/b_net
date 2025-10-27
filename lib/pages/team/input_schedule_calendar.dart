import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InputScheduleCalendar extends StatefulWidget {
  final String teamId;
  final DateTime? selectedDate;
  final String? existingId;
  final String? initialTitle;
  final String? initialLocation;
  final String? initialOpponent;
  final String? initialDetails;
  final String? initialTime;
  const InputScheduleCalendar({
    Key? key,
    required this.teamId,
    this.selectedDate,
    this.existingId,
    this.initialTitle,
    this.initialLocation,
    this.initialOpponent,
    this.initialDetails,
    this.initialTime,
  }) : super(key: key);

  @override
  State<InputScheduleCalendar> createState() => _InputScheduleCalendarState();
}

class _InputScheduleCalendarState extends State<InputScheduleCalendar> {
  final _formKey = GlobalKey<FormState>();
  String title = '';
  String location = '';
  String opponent = '';
  String details = '';
  String? time;
  late DateTime selectedDay;

  @override
  void initState() {
    super.initState();
    selectedDay = widget.selectedDate ?? DateTime.now();
    title = widget.initialTitle ?? '';
    location = widget.initialLocation ?? '';
    opponent = widget.initialOpponent ?? '';
    details = widget.initialDetails ?? '';
    time = widget.initialTime;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('予定を追加する'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('必須項目はありませんので柔軟にお使いください',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: title,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => title = value),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: time,
                decoration: const InputDecoration(
                  labelText: '時間',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => time = value),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: location,
                decoration: const InputDecoration(
                  labelText: '場所',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => location = value),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: opponent,
                decoration: const InputDecoration(
                  labelText: '対戦相手',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => opponent = value),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: details,
                decoration: const InputDecoration(
                  labelText: '詳細',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                onChanged: (value) => setState(() => details = value),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(
                    '日付: ${selectedDay.year}/${selectedDay.month}/${selectedDay.day}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDay,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 90)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDay = picked;
                    });
                    FocusScope.of(context).requestFocus(FocusNode());
                    Future.delayed(Duration(milliseconds: 100), () {
                      FocusScope.of(context).requestFocus(FocusNode());
                      FocusScope.of(context).requestFocus(FocusNode());
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, {'success': false});
                    },
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (title.isNotEmpty ||
                          location.isNotEmpty ||
                          opponent.isNotEmpty ||
                          details.isNotEmpty) {
                        String userId = FirebaseAuth.instance.currentUser!.uid;
                        DocumentSnapshot userDoc = await FirebaseFirestore
                            .instance
                            .collection('users')
                            .doc(userId)
                            .get();
                        String userName = userDoc['name'] ?? '未設定';

                        final scheduleRef = FirebaseFirestore.instance
                            .collection('teams')
                            .doc(widget.teamId)
                            .collection('schedule');

                        if (widget.existingId != null) {
                          await scheduleRef.doc(widget.existingId).update({
                            'game_date': selectedDay,
                            'title': title,
                            'location': location,
                            'opponent': opponent,
                            'details': details,
                            'time': time,
                          });
                        } else {
                          await scheduleRef.add({
                            'game_date': selectedDay,
                            'title': title,
                            'location': location,
                            'opponent': opponent,
                            'details': details,
                            'time': time,
                            'createdBy': userId,
                            'createdName': userName,
                            'stamps': [],
                            'comments': [],
                          });
                        }
                        Navigator.pop(context, {
                          'success': true,
                          'newDate': selectedDay,
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('フィールドを入力してください')),
                        );
                      }
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0
          ? Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: 44,
                color: Colors.grey[100],
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: const Text(
                        '完了',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
