import 'package:b_net/pages/team/team_schedule_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({
    super.key,
    required this.event,
    required this.teamId,
    required this.onUpdate,
  });

  final Event event;
  final String teamId;
  final ValueChanged<Event> onUpdate;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late Event _event;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  Future<void> _stampEvent(String stampType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDocument = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userName = userDocument.data()?['name'] ?? '未設定';
    final updatedStamps = List<Map<String, dynamic>>.from(_event.stamps)
      ..removeWhere((stamp) => stamp['userId'] == user.uid)
      ..add({
        'userId': user.uid,
        'userName': userName,
        'stampType': stampType,
      });

    await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('schedule')
        .doc(_event.id)
        .update({'stamps': updatedStamps});
    if (!mounted) return;
    setState(() => _event = _event.copyWith(newStamps: updatedStamps));
    widget.onUpdate(_event);
  }

  Future<Map<String, dynamic>?> _addComment(String commentText) async {
    final text = commentText.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null) return null;
    final userDocument = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final newComment = <String, dynamic>{
      'userId': user.uid,
      'userName': userDocument.data()?['name'] ?? '未設定',
      'comment': text,
    };
    await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('schedule')
        .doc(_event.id)
        .update({
      'comments': FieldValue.arrayUnion([newComment]),
    });
    if (!mounted) return null;
    setState(() {
      _event = _event.copyWith(
        newComments: [..._event.comments, newComment],
      );
    });
    widget.onUpdate(_event);
    return newComment;
  }

  void _showCommentsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EventCommentsSheet(
        initialComments: _event.comments,
        onSubmit: _addComment,
      ),
    );
  }

  String _formattedDate(DateTime date) {
    final weekday = const ['月', '火', '水', '木', '金', '土', '日'][date.weekday - 1];
    return '${date.year}年${date.month}月${date.day}日（$weekday）';
  }

  Widget _informationRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: const Color(0xFF475569)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stampSummary = _getStampSummary(_event.stamps);
    final hasTime = _event.time != null &&
        _event.time!.trim().isNotEmpty &&
        _event.time != '未設定';
    return Scaffold(
      appBar: AppBar(title: const Text('予定の詳細')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _event.eventType,
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _event.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            if (_event.date != null)
              _informationRow(
                Icons.calendar_today_outlined,
                _formattedDate(_event.date!),
              ),
            if (hasTime) _informationRow(Icons.schedule_outlined, _event.time!),
            if (_event.location.trim().isNotEmpty && _event.location != '不明')
              _informationRow(Icons.location_on_outlined, _event.location),
            if (_event.eventType == '試合' &&
                _event.opponent.trim().isNotEmpty &&
                _event.opponent != '不明')
              _informationRow(
                Icons.groups_outlined,
                '対戦相手：${_event.opponent}',
              ),
            if (_event.details.trim().isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(height: 1),
              ),
              const Text(
                '詳細・連絡事項',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                _event.details,
                style: const TextStyle(fontSize: 15, height: 1.55),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'リアクション',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showStampSelectionDialog,
                  icon: const Icon(Icons.add_reaction_outlined),
                  label: const Text('追加'),
                ),
              ],
            ),
            if (stampSummary.isEmpty)
              const Text(
                'まだリアクションはありません。',
                style: TextStyle(color: Colors.black54),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stampSummary.entries.map((entry) {
                  return ActionChip(
                    label: Text('${entry.key} ${entry.value}'),
                    onPressed: () => _showStampDetailDialog(
                      entry.key,
                      _event.stamps,
                    ),
                  );
                }).toList(),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'コメント ${_event.comments.length}件',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _showCommentsSheet,
                  child: Text(
                    _event.comments.isEmpty ? 'コメントする' : 'すべて見る',
                  ),
                ),
              ],
            ),
            if (_event.comments.isEmpty)
              const Text(
                'まだコメントはありません。',
                style: TextStyle(color: Colors.black54),
              )
            else
              ..._event.comments.reversed.take(2).map((comment) {
                return InkWell(
                  onTap: _showCommentsSheet,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (comment['userName'] ?? '名前未設定').toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (comment['comment'] ?? '').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '作成者：${_event.createdName}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStampSelectionDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('リアクションを選択'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['🙆‍♂️', '🙅', '🤔'].map((emoji) {
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                Navigator.of(dialogContext).pop();
                await _stampEvent(emoji);
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(emoji, style: const TextStyle(fontSize: 38)),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  Map<String, int> _getStampSummary(List<Map<String, dynamic>> stamps) {
    final summary = <String, int>{};
    for (final stamp in stamps) {
      final type = (stamp['stampType'] ?? '').toString();
      if (type.isNotEmpty) summary[type] = (summary[type] ?? 0) + 1;
    }
    return summary;
  }

  void _showStampDetailDialog(
    String stampType,
    List<Map<String, dynamic>> stamps,
  ) {
    final users = stamps
        .where((stamp) => stamp['stampType'] == stampType)
        .map((stamp) => (stamp['userName'] ?? '名前未設定').toString())
        .toList();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$stampType を押した人'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: users.map((user) => ListTile(title: Text(user))).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

class _EventCommentsSheet extends StatefulWidget {
  const _EventCommentsSheet({
    required this.initialComments,
    required this.onSubmit,
  });

  final List<Map<String, dynamic>> initialComments;
  final Future<Map<String, dynamic>?> Function(String text) onSubmit;

  @override
  State<_EventCommentsSheet> createState() => _EventCommentsSheetState();
}

class _EventCommentsSheetState extends State<_EventCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final List<Map<String, dynamic>> _comments;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _comments = List<Map<String, dynamic>>.from(widget.initialComments);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      final comment = await widget.onSubmit(text);
      if (!mounted || comment == null) return;
      setState(() {
        _comments.add(comment);
        _controller.clear();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('コメントを送信できませんでした。')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'コメント ${_comments.length}件',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '閉じる',
                      onPressed: () {
                        _focusNode.unfocus();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'まだコメントはありません。',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 18),
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final userName =
                              (comment['userName'] ?? '名前未設定').toString();
                          final initial = userName.trim().isEmpty
                              ? '?'
                              : userName.trim().characters.first;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 17,
                                backgroundColor: const Color(0xFFE3F2FD),
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Color(0xFF1565C0),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      (comment['comment'] ?? '').toString(),
                                      style: const TextStyle(height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'コメントを入力…',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '送信',
                        onPressed: _isSending ? null : _send,
                        icon: _isSending
                            ? const SizedBox.square(
                                dimension: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        color: const Color(0xFF1565C0),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
