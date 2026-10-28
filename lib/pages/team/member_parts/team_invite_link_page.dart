import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TeamInviteLinkPage extends StatefulWidget {
  const TeamInviteLinkPage({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  final String teamId;
  final String teamName;

  @override
  State<TeamInviteLinkPage> createState() => _TeamInviteLinkPageState();
}

class _TeamInviteLinkPageState extends State<TeamInviteLinkPage> {
  bool _isLoading = false;
  String? _inviteUrl;
  DateTime? _expiresAt;

  Future<void> _createLink() async {
    setState(() => _isLoading = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('createTeamInviteLink')
          .call(<String, dynamic>{'teamId': widget.teamId});
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      setState(() {
        _inviteUrl = data['inviteUrl']?.toString();
        final expiresAtMillis = data['expiresAtMillis'] as num?;
        _expiresAt = expiresAtMillis == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(expiresAtMillis.toInt());
      });
    } on FirebaseFunctionsException catch (error) {
      _showMessage(
        error.code == 'permission-denied'
            ? '招待リンクはチーム代表者だけが発行できます。'
            : '招待リンクを発行できませんでした。',
      );
    } catch (_) {
      _showMessage('招待リンクを発行できませんでした。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _copyLink() async {
    final inviteUrl = _inviteUrl;
    if (inviteUrl == null) return;
    await Clipboard.setData(ClipboardData(text: inviteUrl));
    _showMessage('招待URLをコピーしました。');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inviteUrl = _inviteUrl;
    return Scaffold(
      appBar: AppBar(title: const Text('招待URL・QRコード')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.teamName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'このURLやQRコードを送ると、相手はチーム検索や参加申請をせずに招待を受け取れます。',
            ),
            const SizedBox(height: 24),
            if (inviteUrl == null) ...[
              FilledButton.icon(
                onPressed: _isLoading ? null : _createLink,
                icon: _isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: const Text('招待URLを発行する'),
              ),
              const SizedBox(height: 12),
              const Text(
                '発行した招待は7日間有効です。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ] else ...[
              Center(
                child: Card(
                  color: Colors.white,
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: inviteUrl,
                      size: 220,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SelectableText(
                inviteUrl,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.blueGrey),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _copyLink,
                icon: const Icon(Icons.copy),
                label: const Text('招待URLをコピー'),
              ),
              TextButton.icon(
                onPressed: _isLoading ? null : _createLink,
                icon: const Icon(Icons.refresh),
                label: const Text('新しいURLを発行'),
              ),
              if (_expiresAt != null)
                Text(
                  '有効期限: ${_expiresAt!.year}/${_expiresAt!.month}/${_expiresAt!.day} '
                  '${_expiresAt!.hour.toString().padLeft(2, '0')}:'
                  '${_expiresAt!.minute.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
