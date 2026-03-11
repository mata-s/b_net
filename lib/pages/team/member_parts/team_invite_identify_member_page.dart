import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class TeamInviteIdentifyMemberPage extends StatefulWidget {
  final String currentUserUid;
  final String teamId;
  final String inviteDocId;
  final String teamName;

  const TeamInviteIdentifyMemberPage({
    super.key,
    required this.currentUserUid,
    required this.teamId,
    required this.inviteDocId,
    required this.teamName,
  });

  @override
  State<TeamInviteIdentifyMemberPage> createState() =>
      _TeamInviteIdentifyMemberPageState();
}

class _TeamInviteIdentifyMemberPageState
    extends State<TeamInviteIdentifyMemberPage> {
  bool _loading = true;
  String? _selectedUid;
  List<String> _memberUids = [];
  Map<String, Map<String, dynamic>> _memberUserData = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final teamSnap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .get();

      final teamData = teamSnap.data() ?? {};
      final rawMembers = teamData['members'];
      final List<String> memberUids = (rawMembers is List)
          ? rawMembers.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];

      // 自分自身は候補から外す（既に自分のUIDでデータを持っているため）
      memberUids.removeWhere((id) => id == widget.currentUserUid);

      // users をまとめて取得（10件制限を避けるため逐次）
      // ✅ 誤統合防止のため、仮メンバー（isTeamMemberOnly: true）のみ候補に出す
      final List<String> filteredMemberUids = [];
      final Map<String, Map<String, dynamic>> userDataMap = {};

      for (final uid in memberUids) {
        final u = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (!u.exists) {
          // users が無い（削除ユーザー等）は候補に出さない
          continue;
        }

        final data = u.data() ?? {};
        final isTeamMemberOnly = data['isTeamMemberOnly'] == true;

        // isTeamMemberOnly 以外（= 実ユーザー等）は候補から除外
        if (!isTeamMemberOnly) {
          continue;
        }

        filteredMemberUids.add(uid);
        userDataMap[uid] = data;
      }

      if (!mounted) return;
      setState(() {
        _memberUids = filteredMemberUids;
        _memberUserData = userDataMap;
        _loading = false;
      });
    } catch (e) {
      debugPrint('load members error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  String _displayNameFor(String uid) {
    final data = _memberUserData[uid] ?? {};
    final name = (data['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    final username = (data['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) return username;
    return uid;
  }

  Future<String?> _showConfirmDialog({required String? selectedUid}) async {
    final titleTeamName = widget.teamName.trim().isNotEmpty ? widget.teamName.trim() : 'チーム';

    // 選択が null の場合は「自分はいない」で新規参加
    if (selectedUid == null) {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('確認'),
            content: Text(
              '$titleTeamName に「新規メンバー」として参加します。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('戻る'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('参加する'),
              ),
            ],
          );
        },
      );
      return ok == true ? 'join_new' : null;
    }

    final name = _displayNameFor(selectedUid);
    final action = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('この選手の記録をどうしますか？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('選択：$name'),
              const SizedBox(height: 10),
              const Text(
                'この選手があなた本人なら、これまでこの選手に記録されている成績をあなたのアカウントにまとめます。\n'
                '今の記録をそのまま残したい場合は、そのまま参加してください。',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop('merge'),
                  child: const Text('この選手の記録を自分にまとめる'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop('skip_delete'),
                  child: const Text('記録はそのままで参加する'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('戻る'),
                ),
              ),
            ],
          ),
        );
      },
    );

    return action;
  }

  Future<void> _submitJoinOrMerge() async {
    if (_submitting) return;

    setState(() {
      _submitting = true;
    });

    try {
      final selectedUid = _selectedUid;

      // ④ 確認
      final action = await _showConfirmDialog(selectedUid: selectedUid);
      if (action == null) {
        if (!mounted) return;
        setState(() {
          _submitting = false;
        });
        return;
      }

      // ⑤ 統合（または新規参加）
      // 方針：
      // - selectedUid == null → そのまま currentUserUid を members に追加
      // - selectedUid != null → teams.members の selectedUid を currentUserUid に置換
      //   さらに selectedUid 側の users ドキュメントに "mergedToUid" 等のフラグを残して追跡できるようにする
      //
      // ⚠️ 成績のサブコレクション移行など、より深い統合が必要な場合はここに追加してください。

      final firestore = FirebaseFirestore.instance;
      final teamRef = firestore.collection('teams').doc(widget.teamId);

      // ✅ チーム側にも invites がある場合はここも更新（teams/{teamId}/invites/{inviteeUid}）
      final teamInviteRef = teamRef.collection('invites').doc(widget.currentUserUid);

      // ✅ 招待は users/{inviteeUid}/teamInvites/{inviteDocId} に保存されている（コンソール確認）
      final inviteRef = firestore
          .collection('users')
          .doc(widget.currentUserUid)
          .collection('teamInvites')
          .doc(widget.inviteDocId);

      final currentUserRef = firestore.collection('users').doc(widget.currentUserUid);

      final bool shouldMerge = action == 'merge';
final bool shouldDeleteTentativeAndJoin = action == 'skip_delete';

if (selectedUid != null && shouldMerge) {
  final callable = FirebaseFunctions.instance.httpsCallable(
    'mergeTentativeUserDataToRealUser',
  );
  await callable.call({
    'tentativeUid': selectedUid,
    'realUid': widget.currentUserUid,
  });
}

if (selectedUid != null && shouldDeleteTentativeAndJoin) {
  final callable = FirebaseFunctions.instance.httpsCallable(
    'removeTentativeUserFromTeam',
  );
  await callable.call({
    'tentativeUid': selectedUid,
    'teamId': widget.teamId,
  });
}

      await firestore.runTransaction((tx) async {
        final teamSnap = await tx.get(teamRef);
        final teamData = teamSnap.data() ?? {};
        final rawMembers = teamData['members'];
        final List<String> members = (rawMembers is List)
            ? rawMembers.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : <String>[];

        if (selectedUid == null) {
          // 新規参加
          if (!members.contains(widget.currentUserUid)) {
            members.add(widget.currentUserUid);
          }
          tx.update(teamRef, {
            'members': members,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          if (shouldMerge) {
            // 統合：ダミーUIDを自分のUIDに置換
            final idx = members.indexOf(selectedUid);
            if (idx >= 0) {
              members[idx] = widget.currentUserUid;
            } else {
              if (!members.contains(widget.currentUserUid)) {
                members.add(widget.currentUserUid);
              }
            }

            // 重複除去
            final uniq = <String>{};
            final mergedMembers = <String>[];
            for (final m in members) {
              if (uniq.add(m)) mergedMembers.add(m);
            }

            tx.update(teamRef, {
              'members': mergedMembers,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            // 引き継がず参加：仮ユーザーは Functions 側で削除済みなので、自分を追加するだけ
            if (!members.contains(widget.currentUserUid)) {
              members.add(widget.currentUserUid);
            }
            tx.update(teamRef, {
              'members': members,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        // currentUser に teamId を紐づける（teams 配列がある前提。無くても merge で追加するだけ）
        tx.set(
          currentUserRef,
          {
            'teams': FieldValue.arrayUnion([widget.teamId]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // 招待ドキュメントの更新（存在しなくても set(merge) で安全）
        tx.set(
          inviteRef,
          {
            'status': 'accepted',
            'respondedAt': FieldValue.serverTimestamp(),
            'acceptedByUid': widget.currentUserUid,
            'acceptedAt': FieldValue.serverTimestamp(),
            'identifiedMemberUid': selectedUid,
            // 念のため teamId も保持（既に入っていても merge なので安全）
            'teamId': widget.teamId,
          },
          SetOptions(merge: true),
        );

        // チーム側 invites も accepted に更新（UI/管理画面が参照している可能性があるため）
        tx.set(
          teamInviteRef,
          {
            'status': 'accepted',
            'respondedAt': FieldValue.serverTimestamp(),
            'acceptedByUid': widget.currentUserUid,
            'acceptedAt': FieldValue.serverTimestamp(),
            'identifiedMemberUid': selectedUid,
            'inviteeUid': widget.currentUserUid,
            'teamId': widget.teamId,
          },
          SetOptions(merge: true),
        );
      });

      if (!mounted) return;

      final successMessage = selectedUid == null
          ? 'チームに参加しました'
          : shouldMerge
              ? '成績を統合してチームに参加しました'
              : '仮ユーザーを削除してチームに参加しました';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
        ),
      );

      // 完了：選択した uid（または null = 新規参加）を返す（呼び出し元の戻り値型に合わせる）
      Navigator.of(context).pop(selectedUid);
    } catch (e) {
      debugPrint('submit join/merge error: $e');

      // まれに「招待ドキュメント更新だけ失敗」等で、members 追加は反映されているケースがあるため救済する
      try {
        final teamSnap = await FirebaseFirestore.instance
            .collection('teams')
            .doc(widget.teamId)
            .get();
        final teamData = teamSnap.data() ?? {};
        final rawMembers = teamData['members'];
        final List<String> members = (rawMembers is List)
            ? rawMembers.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : <String>[];

        final alreadyJoined = members.contains(widget.currentUserUid);

        if (!mounted) return;

        if (alreadyJoined) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('チーム参加は完了しました（招待情報の更新に失敗した可能性があります）')),
          );
          // 参加は完了しているので、選択した uid（または null）を返す
          Navigator.of(context).pop(_selectedUid);
          return;
        }
      } catch (e2) {
        debugPrint('post-check error: $e2');
        // ここは無視して通常のエラー表示へ
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('処理に失敗しました。通信状況をご確認ください。')),
      );
      setState(() {
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleTeamName = widget.teamName.trim().isNotEmpty ? widget.teamName.trim() : 'チーム';

    return Scaffold(
      appBar: AppBar(
        title: const Text('あなたはいますか？'),
        actions: [
          IconButton(
            tooltip: '閉じる',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(null),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$titleTeamName のメンバーの中に、あなたの名前はありますか？\n一致する選手を選択してください。',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: _memberUids.isEmpty
                        ? const Center(
                            child: Text('候補メンバーが見つかりませんでした'),
                          )
                        : ListView.separated(
                            itemCount: _memberUids.length + 1,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              // 最後に「自分はいない」オプション
                              if (index == _memberUids.length) {
                                final selected = _selectedUid == null;
                                return ListTile(
                                  leading: Icon(
                                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: selected ? const Color(0xFF1565C0) : Colors.grey,
                                  ),
                                  title: const Text(
                                    '見つからない / 自分はいない',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: const Text('新規メンバーとして登録する場合はこちら'),
                                  onTap: _submitting
                                      ? null
                                      : () {
                                          setState(() {
                                            _selectedUid = null;
                                          });
                                        },
                                );
                              }

                              final uid = _memberUids[index];
                              final name = _displayNameFor(uid);
                              final selected = _selectedUid == uid;
                              return ListTile(
                                leading: Icon(
                                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: selected ? const Color(0xFF1565C0) : Colors.grey,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                onTap: _submitting
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedUid = uid;
                                        });
                                      },
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submitJoinOrMerge,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('確定'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}