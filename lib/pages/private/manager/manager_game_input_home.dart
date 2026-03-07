import 'package:flutter/material.dart';
import 'manager_game_input_fielding.dart';
import 'manager_game_input_batting.dart';

class ManagerGameInputHomePage extends StatefulWidget {
  final int matchIndex;
  final String userUid;
  final String teamId;
  final List<Map<String, dynamic>> members;

  const ManagerGameInputHomePage({
    Key? key,
    required this.matchIndex,
    required this.userUid,
    required this.teamId,
    required this.members,
  }) : super(key: key);

  @override
  _ManagerGameInputHomePageState createState() =>
      _ManagerGameInputHomePageState();
}

class _ManagerGameInputHomePageState extends State<ManagerGameInputHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _inningController = TextEditingController(text: '1');
  final TextEditingController _ourScoreController = TextEditingController(text: '0');
  final TextEditingController _opponentScoreController = TextEditingController(text: '0');
  bool _isTopInning = true;

  final ManagerGameInputBattingController _battingSaveController =
      ManagerGameInputBattingController();
  final ManagerGameInputFieldingController _fieldingSaveController =
      ManagerGameInputFieldingController();
  bool _isSaving = false;

  Future<void> _saveAllInputs() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _battingSaveController.save(showSnackbar: false);
      await _fieldingSaveController.save(showSnackbar: false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('打撃・守備の成績をまとめて仮保存しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存に失敗しました')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _changeInning(int delta) {
    final current = int.tryParse(_inningController.text) ?? 1;
    final next = (current + delta).clamp(1, 99);
    setState(() {
      _inningController.text = next.toString();
    });
  }

  void _changeScore(TextEditingController controller, int delta) {
    final current = int.tryParse(controller.text) ?? 0;
    final next = (current + delta).clamp(0, 999);
    setState(() {
      controller.text = next.toString();
    });
  }

  Future<void> _showMatchStatusEditor() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '試合状況を編集',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('イニング'),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _changeInning(-1),
                    icon: const Icon(Icons.remove_circle_outline),
                    visualDensity: VisualDensity.compact,
                  ),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _inningController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeInning(1),
                    icon: const Icon(Icons.add_circle_outline),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(_isTopInning ? '表' : '裏'),
                    selected: _isTopInning,
                    onSelected: (_) {
                      setState(() {
                        _isTopInning = !_isTopInning;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ourScoreController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '自チーム',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _changeScore(_ourScoreController, 1),
                          icon: const Icon(Icons.exposure_plus_1),
                          tooltip: '自チーム +1',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '-',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _opponentScoreController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '相手',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _changeScore(_opponentScoreController, 1),
                          icon: const Icon(Icons.exposure_plus_1),
                          tooltip: '相手 +1',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _inningController.dispose();
    _ourScoreController.dispose();
    _opponentScoreController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('試合入力'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '打撃'),
            Tab(text: '守備'),
          ],
        ),
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 1,
            child: InkWell(
              onTap: _showMatchStatusEditor,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_inningController.text.isEmpty ? '1' : _inningController.text}回 ${_isTopInning ? '表' : '裏'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '自 ${_ourScoreController.text.isEmpty ? '0' : _ourScoreController.text} - ${_opponentScoreController.text.isEmpty ? '0' : _opponentScoreController.text} 相手',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _showMatchStatusEditor,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: '試合状況を編集',
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                        FilledButton.tonal(
                          onPressed: _isSaving ? null : _saveAllInputs,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('保存'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ManagerGameInputBatting(
                  matchIndex: widget.matchIndex,
                  userUid: widget.userUid,
                  teamId: widget.teamId,
                  members: widget.members,
                  controller: _battingSaveController,
                ),
                ManagerGameInputFielding(
                  matchIndex: widget.matchIndex,
                  userUid: widget.userUid,
                  teamId: widget.teamId,
                  members: widget.members,
                  controller: _fieldingSaveController,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
