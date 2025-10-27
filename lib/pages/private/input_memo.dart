import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InputMemoPage extends StatefulWidget {
  final String userUid;
  final List<String> userPosition;
  const InputMemoPage({
    required this.userUid,
    required this.userPosition,
    super.key,
  });

  @override
  State<InputMemoPage> createState() => _InputMemoPageState();
}

class _InputMemoPageState extends State<InputMemoPage> {
  bool isImportant = false;
  bool shouldReread = false;
  DateTime? selectedDate;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _opponentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _scoreController = TextEditingController();
  final TextEditingController _resultController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  @override
  void dispose() {
    _dateController.dispose();
    _opponentController.dispose();
    _locationController.dispose();
    _scoreController.dispose();
    _resultController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メモを追加'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: '日付',
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = picked;
                      _dateController.text =
                          "${picked.year}/${picked.month}/${picked.day}";
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: '場所',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _opponentController,
                decoration: const InputDecoration(
                  labelText: '対戦相手',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _scoreController,
                decoration: const InputDecoration(
                  labelText: '点数',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _resultController,
                decoration: const InputDecoration(
                  labelText: '勝敗',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _memoController,
                  maxLines: null,
                  minLines: 8,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'メモ',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('重要'),
                value: isImportant,
                onChanged: (value) {
                  setState(() {
                    isImportant = value ?? false;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('読み直したい'),
                value: shouldReread,
                onChanged: (value) {
                  setState(() {
                    shouldReread = value ?? false;
                  });
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final memoData = {
                      'date': selectedDate,
                      'opponent': _opponentController.text,
                      'location': _locationController.text,
                      'score': _scoreController.text,
                      'result': _resultController.text,
                      'memo': _memoController.text,
                      'isImportant': isImportant,
                      'shouldReread': shouldReread,
                      'createdAt': Timestamp.now(),
                    };

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.userUid)
                        .collection('memos')
                        .add(memoData);

                    Navigator.pop(context);
                  },
                  child: const Text('保存'),
                ),
              ),
              const SizedBox(height: 50),
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
