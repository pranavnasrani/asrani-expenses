import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/gemini_service.dart';

class InsightsWidget extends StatefulWidget {
  const InsightsWidget({super.key});

  @override
  State<InsightsWidget> createState() => _InsightsWidgetState();
}

class _InsightsWidgetState extends State<InsightsWidget>
    with SingleTickerProviderStateMixin {
  String? _insight;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get expenses from last 7 days
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: sevenDaysAgo)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _insight = "Start tracking expenses to get AI insights! 📊";
            _isLoading = false;
          });
          _animationController.forward();
        }
        return;
      }

      // Prepare expense summary for AI
      double totalSpent = 0;
      Map<String, double> categorySpending = {};
      Map<String, double> dailySpending = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        final category = data['category'] ?? 'Other';
        final date = (data['date'] as Timestamp?)?.toDate();

        totalSpent += amount;
        categorySpending[category] = (categorySpending[category] ?? 0) + amount;

        if (date != null) {
          final dayKey = '${date.month}/${date.day}';
          dailySpending[dayKey] = (dailySpending[dayKey] ?? 0) + amount;
        }
      }

      // Get top category
      String topCategory = 'Unknown';
      double topAmount = 0;
      categorySpending.forEach((cat, amt) {
        if (amt > topAmount) {
          topCategory = cat;
          topAmount = amt;
        }
      });

      // Generate insight using Gemini
      final gemini = GeminiService();
      final insight = await gemini.generateWeeklyInsight(
        totalSpent: totalSpent,
        transactionCount: snapshot.docs.length,
        topCategory: topCategory,
        topCategoryAmount: topAmount,
        categoryBreakdown: categorySpending,
      );

      if (mounted) {
        setState(() {
          _insight = insight;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _insight = "Your weekly spending looks healthy! Keep it up! 💪";
          _isLoading = false;
        });
        _animationController.forward();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A5F), const Color(0xFF2D1B4E)]
              : [const Color(0xFFE8F4FD), const Color(0xFFF3E8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Insights',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (!_isLoading)
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                    });
                    _animationController.reset();
                    _loadInsights();
                  },
                  tooltip: 'Refresh insights',
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                _insight ?? '',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
