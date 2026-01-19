import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

class NoticeDetailPage extends StatelessWidget {
  final String title;
  final String content;
  final String date;
  final bool isImportant;
  final List<String> prefectures; // 選択した都道府県

  const NoticeDetailPage({
    super.key,
    required this.title,
    required this.content,
    required this.date,
    this.isImportant = false,
    this.prefectures = const [],
  });

  Widget _buildContentWithLinks(String content, BuildContext context) {
    // ignore: unused_local_variable
    final textSubtle = Colors.grey.shade800;
    final urlRegExp = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );

    final matches = urlRegExp.allMatches(content);

    if (matches.isEmpty) {
      return Text(
        content,
        style: const TextStyle(
          fontSize: 16,
          height: 1.7,
        ),
      );
    }

    final List<TextSpan> spans = [];
    int start = 0;

    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: content.substring(start, match.start),
          style: const TextStyle(
            fontSize: 16,
            height: 1.7,
            color: Colors.black,
          ),
        ));
      }

      final url = match.group(0)!;

      spans.add(TextSpan(
        text: url,
        style: const TextStyle(
          fontSize: 16,
          height: 1.7,
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not launch $url')),
              );
            }
          },
      ));

      start = match.end;
    }

    if (start < content.length) {
      spans.add(TextSpan(
        text: content.substring(start),
        style: const TextStyle(
          fontSize: 16,
          height: 1.7,
          color: Colors.black,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = Colors.grey.shade50;
    final textSubtle = Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('お知らせの詳細'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== Header card =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.blueGrey.shade50,
                  ],
                ),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // date + badges
                  Row(
                    children: [
                      Text(
                        date,
                        style: TextStyle(fontSize: 13, color: textSubtle),
                      ),
                      const Spacer(),
                      if (isImportant)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '重要',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),

                  if (prefectures.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: prefectures
                          .map(
                            (p) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border:
                                    Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                p,
                                style:
                                    TextStyle(fontSize: 12, color: textSubtle),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ===== Content card =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _buildContentWithLinks(content, context),
            ),
          ],
        ),
      ),
    );
  }
}
