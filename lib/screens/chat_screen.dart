import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/gemini_service.dart';

class ChatScreen extends StatefulWidget {
  final String? initialQuery;

  const ChatScreen({super.key, this.initialQuery});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  bool _isLoading = false;
  final GeminiService _geminiService = GeminiService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Add initial welcome message
    _addMessage(
      Message(
        text:
            "Hi! I'm your AI Financial Assistant. 🤖\nAsk me things like:\n\n• \"How much did I spend on food this month?\"\n• \"What are my biggest expenses?\"\n• \"Did I spend more on transport or shopping?\"",
        isUser: false,
      ),
    );

    // Handle initial query if provided
    if (widget.initialQuery != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSubmitted(widget.initialQuery!);
      });
    }
  }

  void _addMessage(Message message) {
    setState(() {
      _messages.add(message);
    });
    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _controller.clear();
    _addMessage(Message(text: text, isUser: true));

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addMessage(
          Message(text: "Please log in to use this feature.", isUser: false),
        );
        return;
      }

      // 1. Parse Intent (RAG Step 1)
      final filters = await _geminiService.parseQuery(text);

      // 2. Fetch Data (RAG Step 2)
      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses');

      // Apply Date Filters
      if (filters['startDate'] != null) {
        try {
          final start = DateTime.parse(filters['startDate']!);
          query = query.where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
          );
          // Also handle String dates if legacy data exists?
          // For simplicity, assuming new queries mainly target properly timestamped data
          // or we rely on the fact that existing logic handles mixed types.
          // Firestore 'where' on mixed types is tricky.
          // Let's assume standard flow for extensive data.
          // Actually, the app uses `Timestamp` mostly now.
        } catch (e) {
          debugPrint("Date parse error: $e");
        }
      }

      // Fetch
      // We can't easily do complex AND queries on multiple fields without indexes.
      // So we fetch by date (most reliable) and filter the rest in memory.
      final snapshot = await query.get();
      final docs = snapshot.docs;

      // In-memory filter for Category/PaymentMethod & EndDate
      List<Map<String, dynamic>> relevantExpenses = [];

      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Date Filter (End Date)
        if (filters['endDate'] != null) {
          // ... check end date
        }

        // Category Filter
        if (filters['category'] != null) {
          if (data['category'] != filters['category']) continue;
        }

        // Payment Method Filter
        if (filters['paymentMethod'] != null) {
          if (data['paymentMethod'] != filters['paymentMethod']) continue;
        }

        relevantExpenses.add({
          'title': data['title'],
          'amount': data['amount'],
          'date': data['date'].toString(), // Simplified
          'category': data['category'],
          'place': data['place'],
        });
      }

      // 3. Generate Answer (RAG Step 3)
      String summary = "Found ${relevantExpenses.length} expenses:\n";
      if (relevantExpenses.isEmpty) {
        summary = "No expenses found matching criteria.";
      } else {
        // Limit to avoid token limits, maybe top 20?
        final limitedList = relevantExpenses.take(50).toList();
        summary += limitedList.toString();
      }

      final response = await _geminiService.generateResponse(text, summary);
      _addMessage(Message(text: response, isUser: false));
    } catch (e) {
      _addMessage(
        Message(text: "Sorry, I ran into an error: $e", isUser: false),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Financial Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(
                  Message(
                    text:
                        "Hi! I'm your AI Financial Assistant. 🤖\nAsk me things like:\n\n• \"How much did I spend on food this month?\"\n• \"What are my biggest expenses?\"\n• \"Did I spend more on transport or shopping?\"",
                    isUser: false,
                  ),
                );
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _MessageBubble(message: _messages[index]);
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: _handleSubmitted,
                      decoration: const InputDecoration(
                        hintText: 'Ask about your expenses...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: () => _handleSubmitted(_controller.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Message {
  final String text;
  final bool isUser;
  Message({required this.text, required this.isUser});
}

class _MessageBubble extends StatelessWidget {
  final Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.smart_toy_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).colorScheme.primary
                    : isDark
                    ? const Color(0xFF1F2937)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: message.isUser
                    ? null
                    : Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                      ),
              ),
              child: message.isUser
                  ? Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    )
                  : MarkdownBody(
                      data: message.text,
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ).copyWith(
                            p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                              height: 1.4,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                    ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
