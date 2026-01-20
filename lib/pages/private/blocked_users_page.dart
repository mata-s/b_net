import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BlockedUsersPage extends StatefulWidget {
  final String? userUid;

  const BlockedUsersPage({super.key, required this.userUid});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => widget.userUid ?? _auth.currentUser?.uid ?? '';

  Future<void> _unblock(String blockedUid) async {
    if (_uid.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('blockedUsers')
        .doc(blockedUid)
        .delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ブロックを解除しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('ブロックしたユーザー')),
        body: const Center(child: Text('ログイン情報が取得できませんでした')),
      );
    }

    final blockedRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('blockedUsers')
        .orderBy('blockedAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ブロックしたユーザー'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: blockedRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ブロックしているユーザーはいません'));
          }

          final blockedDocs = snapshot.data!.docs;

          return ListView.separated(
            itemCount: blockedDocs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final blockedUid = blockedDocs[index].id;

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(blockedUid).get(),
                builder: (context, userSnap) {
                  String title = blockedUid;
                  String? subtitle;

                  if (userSnap.hasData && userSnap.data!.exists) {
                    final data =
                        userSnap.data!.data() as Map<String, dynamic>?;
                    final name =
                        (data?['name'] ?? data?['displayName'] ?? '').toString();
                    if (name.isNotEmpty) title = name;

                    final prefecture = (data?['prefecture'] ?? '').toString();
                    if (prefecture.isNotEmpty) subtitle = prefecture;
                  }

                  return ListTile(
                    title: Text(title),
                    subtitle: subtitle == null ? null : Text(subtitle),
                    trailing: TextButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('ブロック解除'),
                              content:
                                  const Text('このユーザーのブロックを解除しますか？'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('キャンセル'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('解除'),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirm == true) {
                          await _unblock(blockedUid);
                        }
                      },
                      child: const Text('解除'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}