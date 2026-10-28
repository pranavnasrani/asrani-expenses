import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../data/expense_repository.dart';
import '../services/gemini_service.dart';
import '../utils/money.dart';

class ChatScreen extends StatefulWidget {
  final String? initialQuery;

  const ChatScreen({super.key, this.initialQuery});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _Message {
  final String text;
  final bool fromUser;
  const _Message(this.text, this.fromUser);
}

class _ChatScreenState extends State<ChatScreen> {
  static const _suggestions = [
    'How much did I spend on food this month?',
    'What were my biggest expenses last month?',
    'Cash or card: which did I use more this month?',
  ];

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Message>[];
  final _gemini = GeminiService();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask(widget.initialQuery!));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _ask(String text) async {
    final question = text.trim();
    if (question.isEmpty || _busy) return;
    final repo = context.repo;
    _input.clear();
    setState(() {
      _messages.add(_Message(question, true));
      _busy = true;
    });
    _scrollToEnd();

    String reply;
    try {
      final categories = await repo.watchCategories().first;
      final q = await _gemini.parseQuery(question, categories: categories);
      final now = DateTime.now();
      final start = q.start ?? now.subtract(const Duration(days: 90));
      final end = q.end ?? now;
      final rows = (await repo.fetchExpenses(
        from: DateTime(start.year, start.month, start.day),
        to: DateTime(end.year, end.month, end.day + 1),
      )).where((e) {
        if (q.category != null && e.category != q.category) return false;
        if (q.paymentMethod != null && e.paymentMethod != q.paymentMethod) return false;
        return true;
      }).toList();

      final total = rows.fold<double>(0, (s, e) => s + e.amount);
      final fmt = DateFormat('yyyy-MM-dd');
      final summary = StringBuffer(
        'Period ${fmt.format(start)} to ${fmt.format(end)}'
        '${q.category != null ? ', category ${q.category}' : ''}'
        '${q.paymentMethod != null ? ', paid by ${q.paymentMethod}' : ''}.\n'
        '${rows.length} expenses, total ${Money.format(total)}.\n',
      );
      // Largest first, so the most relevant rows survive the cap.
      rows.sort((a, b) => b.amount.compareTo(a.amount));
      for (final e in rows.take(80)) {
        summary.writeln(
          '${fmt.format(e.date)} | ${e.title} | ${Money.format(e.amount)} | ${e.category} | ${e.paymentMethod} | ${e.place}',
        );
      }
      reply = await _gemini.answer(question, rows.isEmpty ? 'No matching expenses.' : summary.toString());
    } catch (e) {
      reply = e is GeminiNotConfigured
          ? e.toString()
          : "Sorry, I couldn't answer that right now. ($e)";
    }
    if (!mounted) return;
    setState(() {
      _messages.add(_Message(reply, false));
      _busy = false;
    });
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask about spending'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Start over',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _busy ? null : () => setState(_messages.clear),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('Ask in your own words.', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        'Answers come only from expenses you have logged.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      for (final s in _suggestions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ActionChip(
                            label: Text(s),
                            onPressed: () => _ask(s),
                          ),
                        ),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _messages.length + (_busy ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
                          ),
                        );
                      }
                      final m = _messages[i];
                      return Align(
                        alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: m.fromUser ? scheme.primary : scheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: m.fromUser ? const Radius.circular(4) : null,
                              bottomLeft: m.fromUser ? null : const Radius.circular(4),
                            ),
                          ),
                          child: m.fromUser
                              ? Text(m.text, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onPrimary))
                              : MarkdownBody(
                                  data: m.text,
                                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                                    p: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_busy,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _ask,
                      decoration: const InputDecoration(hintText: 'e.g. Groceries in September'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _busy ? null : () => _ask(_input.text),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
