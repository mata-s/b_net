import 'package:b_net/home_page.dart';
import 'package:b_net/login/login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const pendingTeamInviteTokenKey = 'pending_team_invite_token';

class TeamInviteLinkLandingPage extends StatefulWidget {
  const TeamInviteLinkLandingPage({super.key, required this.token});

  final String token;

  @override
  State<TeamInviteLinkLandingPage> createState() =>
      _TeamInviteLinkLandingPageState();
}

class _TeamInviteLinkLandingPageState extends State<TeamInviteLinkLandingPage> {
  bool _isLoading = true;
  bool _isJoining = false;
  String? _teamName;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  Future<void> _loadInvite() async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getTeamInviteLink')
          .call(<String, dynamic>{'token': widget.token});
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      setState(() => _teamName = data['teamName']?.toString() ?? 'チーム');
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'この招待URLは無効か、有効期限が切れています。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continue() async {
    if (FirebaseAuth.instance.currentUser == null) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(pendingTeamInviteTokenKey, widget.token);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('redeemTeamInviteLink')
          .call(<String, dynamic>{'token': widget.token});
      final data = Map<String, dynamic>.from(result.data as Map);
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(pendingTeamInviteTokenKey);
      if (!mounted) return;
      if (data['alreadyMember'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('すでにこのチームに参加しています。')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('招待を受け取りました。ホームで参加を完了してください。')),
        );
      }
      await _openHome();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.code == 'failed-precondition'
            ? 'この招待URLは無効か、有効期限が切れています。'
            : '招待を受け取れませんでした。もう一度お試しください。';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = '招待を受け取れませんでした。もう一度お試しください。');
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _openHome() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    final userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userSnapshot.data() ?? <String, dynamic>{};
    final positions = List<String>.from(data['positions'] ?? const []);
    final teams = List<String>.from(data['teams'] ?? const []);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomePage(
          userUid: user.uid,
          isTeamAccount: false,
          accountId: user.uid,
          accountName: data['username'] ?? data['name'] ?? '未設定',
          userPrefecture: data['prefecture'] ?? '未設定',
          userPosition: positions,
          userTeamId: teams.isNotEmpty ? teams.first : null,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('チーム招待')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _errorMessage == null
                              ? Icons.group_add_rounded
                              : Icons.link_off_rounded,
                          size: 72,
                          color: _errorMessage == null
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _errorMessage == null
                              ? '$_teamName から招待されています'
                              : _errorMessage!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (_errorMessage == null) ...[
                          const SizedBox(height: 12),
                          Text(
                            FirebaseAuth.instance.currentUser == null
                                ? 'ログイン後、そのまま招待を受け取れます。'
                                : '招待を受け取った後、自分が登録済み選手か確認できます。',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isJoining ? null : _continue,
                              child: _isJoining
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text(
                                      FirebaseAuth.instance.currentUser == null
                                          ? 'ログインして招待を受け取る'
                                          : '招待を受け取る',
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
