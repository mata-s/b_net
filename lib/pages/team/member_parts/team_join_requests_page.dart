import 'package:b_net/common/profile_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeamJoinRequestsPage extends StatefulWidget {
  const TeamJoinRequestsPage({super.key, required this.teamId});

  final String teamId;

  @override
  State<TeamJoinRequestsPage> createState() => _TeamJoinRequestsPageState();
}

class _TeamJoinRequestsPageState extends State<TeamJoinRequestsPage> {
  final Set<String> _processingUserIds = <String>{};

  Future<void> _respond(String userId, String action) async {
    if (_processingUserIds.contains(userId)) return;
    setState(() => _processingUserIds.add(userId));
    try {
      await FirebaseFunctions.instance
          .httpsCallable('respondToTeamJoinRequest')
          .call<void>({
        'teamId': widget.teamId,
        'applicantUid': userId,
        'action': action,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'approve'
                ? '参加申請を承認しました。相手が選手情報を確認すると参加が完了します。'
                : '申請を見送りました。',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = error.code == 'failed-precondition'
          ? 'この申請はすでに処理されています。'
          : '申請を処理できませんでした。';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _processingUserIds.remove(userId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('joinRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('参加申請')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('参加申請を読み込めませんでした。'));
          }

          final docs = [...?snapshot.data?.docs];
          docs.sort((a, b) {
            final aDate = a.data()['createdAt'];
            final bDate = b.data()['createdAt'];
            if (aDate is Timestamp && bDate is Timestamp) {
              return bDate.compareTo(aDate);
            }
            return 0;
          });
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mark_email_read_outlined,
                      size: 52, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('現在、確認待ちの参加申請はありません。'),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final name = (data['userName'] ?? '名前未設定').toString();
              final positions = data['positions'] is List
                  ? (data['positions'] as List).join(' / ')
                  : '';
              final message = (data['message'] ?? '').toString().trim();
              final isProcessing = _processingUserIds.contains(doc.id);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            child: Icon(Icons.person_outline_rounded),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (positions.isNotEmpty)
                                  Text(
                                    positions,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(message),
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () => showProfileDialog(
                                    context,
                                    doc.id,
                                    false,
                                    currentUserUid:
                                        FirebaseAuth.instance.currentUser?.uid,
                                  ),
                          icon: const Icon(Icons.account_circle_outlined),
                          label: const Text('プロフィールを見る'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isProcessing
                                  ? null
                                  : () => _respond(doc.id, 'decline'),
                              child: const Text('見送る'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: isProcessing
                                  ? null
                                  : () => _respond(doc.id, 'approve'),
                              child: isProcessing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('承認する'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
