import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InputScheduleCalendar extends StatefulWidget {
  const InputScheduleCalendar({
    super.key,
    required this.teamId,
    this.selectedDate,
    this.existingId,
    this.initialTitle,
    this.initialLocation,
    this.initialOpponent,
    this.initialDetails,
    this.initialTime,
    this.initialEventType,
  });

  final String teamId;
  final DateTime? selectedDate;
  final String? existingId;
  final String? initialTitle;
  final String? initialLocation;
  final String? initialOpponent;
  final String? initialDetails;
  final String? initialTime;
  final String? initialEventType;

  @override
  State<InputScheduleCalendar> createState() => _InputScheduleCalendarState();
}

class _InputScheduleCalendarState extends State<InputScheduleCalendar> {
  final _formKey = GlobalKey<FormState>();
  static const _eventTypes = ['試合', '練習', 'ミーティング', 'その他'];

  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _opponentController;
  late final TextEditingController _detailsController;
  late DateTime _selectedDay;
  TimeOfDay? _selectedTime;
  late String _eventType;
  bool _isSaving = false;

  bool get _isEditing => widget.existingId != null;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDate ?? DateTime.now();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _locationController =
        TextEditingController(text: widget.initialLocation ?? '');
    _opponentController =
        TextEditingController(text: widget.initialOpponent ?? '');
    _detailsController =
        TextEditingController(text: widget.initialDetails ?? '');
    _selectedTime = _parseTime(widget.initialTime);
    final initialType = widget.initialEventType?.trim();
    _eventType = initialType != null && _eventTypes.contains(initialType)
        ? initialType
        : (_opponentController.text.trim().isNotEmpty ? '試合' : 'その他');
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String? get _timeValue {
    final value = _selectedTime;
    if (value == null) return null;
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _opponentController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null && mounted) setState(() => _selectedDay = picked);
  }

  Future<void> _pickTime() async {
    FocusScope.of(context).unfocus();
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: '開始時刻を選択',
    );
    if (picked != null && mounted) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('ログインが必要です');
      final scheduleRef = FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('schedule');
      final values = <String, dynamic>{
        'game_date': Timestamp.fromDate(_selectedDay),
        'eventType': _eventType,
        'title': _titleController.text.trim(),
        'location': _locationController.text.trim(),
        'opponent': _eventType == '試合' ? _opponentController.text.trim() : '',
        'details': _detailsController.text.trim(),
        'time': _timeValue,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await scheduleRef.doc(widget.existingId).update(values);
      } else {
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        await scheduleRef.add({
          ...values,
          'createdBy': user.uid,
          'createdName': userSnapshot.data()?['name'] ?? '未設定',
          'createdAt': FieldValue.serverTimestamp(),
          'stamps': <Map<String, dynamic>>[],
          'comments': <Map<String, dynamic>>[],
        });
      }

      if (!mounted) return;
      Navigator.pop(context, {
        'saved': true,
        'selectedDate': _selectedDay,
        'success': true,
        'newDate': _selectedDay,
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('予定を保存できませんでした。もう一度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText =
        '${_selectedDay.year}/${_selectedDay.month}/${_selectedDay.day}';
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '予定を編集' : '予定を追加')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              _sectionLabel('種類'),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _eventTypes.map((type) {
                  return ChoiceChip(
                    label: Text(type),
                    selected: _eventType == type,
                    onSelected: _isSaving
                        ? null
                        : (_) => setState(() => _eventType = type),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              _sectionLabel('日付・時間'),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(dateText),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _pickTime,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(_timeValue ?? '時刻未設定'),
                    ),
                  ),
                ],
              ),
              if (_selectedTime != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => setState(() => _selectedTime = null),
                    child: const Text('時刻を削除'),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                enabled: !_isSaving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'タイトル（必須）',
                  hintText: '例：秋季大会 2回戦',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'タイトルを入力してください'
                    : null,
              ),
              if (_eventType == '試合') ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _opponentController,
                  enabled: !_isSaving,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '対戦相手',
                    hintText: '例：大阪クラブ',
                    prefixIcon: Icon(Icons.groups_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _locationController,
                enabled: !_isSaving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '場所',
                  hintText: '例：○○球場',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _detailsController,
                enabled: !_isSaving,
                minLines: 4,
                maxLines: 7,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: '詳細・連絡事項',
                  hintText: '集合時間、持ち物など',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_isSaving ? '保存中...' : '予定を保存'),
          ),
        ),
      ),
    );
  }
}
