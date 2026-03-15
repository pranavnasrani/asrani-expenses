import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../utils/category_utils.dart';
import '../widgets/insights_widget.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onNavigateToAdd;
  final VoidCallback onNavigateToExpenses;

  const HomeScreen({
    super.key,
    required this.onNavigateToAdd,
    required this.onNavigateToExpenses,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          _buildWelcomeSection(context, user),
          const SizedBox(height: 24),

          // Quick Action Cards
          _buildQuickActions(context),
          const SizedBox(height: 24),

          // AI Insights Widget
          const InsightsWidget(),
          const SizedBox(height: 24),

          // Monthly Summary & Dashboard
          _buildMonthlySummary(context, user),
          const SizedBox(height: 24),

          // Recent Expenses
          _buildRecentExpenses(context, user),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, User? user) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting,',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              user?.displayName ?? user?.email?.split('@')[0] ?? 'User',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        CircleAvatar(
          radius: 28,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Text(
            (user?.displayName ?? user?.email ?? 'U').toUpperCase().substring(0, 1),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildActionCard(
                  context,
                  icon: Icons.document_scanner_rounded,
                  title: 'Scan Receipt',
                  subtitle: 'AI-powered extract',
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  onTap: onNavigateToAdd,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  context,
                  icon: Icons.edit_note_rounded,
                  title: 'Add Manual',
                  subtitle: 'Quick entry',
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.secondary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  onTap: onNavigateToAdd,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySummary(BuildContext context, User? user) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final last7Days = List.generate(7, (index) {
          return DateTime.now().subtract(Duration(days: 6 - index));
        });

        double monthTotal = 0;
        double cashTotal = 0;
        double cardTotal = 0;
        Map<int, double> dailySpending = {for (var i = 0; i < 7; i++) i: 0.0};

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final date = data['date'] != null
              ? (data['date'] as Timestamp).toDate()
              : DateTime.now();
          final method = data['paymentMethod']?.toString().toLowerCase() ?? '';

            if (date.isAfter(startOfMonth)) {
              monthTotal += amount;
              if (method == 'cash') {
                cashTotal += amount;
              } else if (method.contains('card')) {
                cardTotal += amount;
              }
            }

            for (var i = 0; i < 7; i++) {
              if (date.year == last7Days[i].year &&
                  date.month == last7Days[i].month &&
                  date.day == last7Days[i].day) {
                dailySpending[i] = (dailySpending[i] ?? 0) + amount;
              }
            }
          }

          final isDark = Theme.of(context).brightness == Brightness.dark;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('settings')
                .doc('budgets_${DateFormat('yyyy_MM').format(now)}')
                .snapshots(),
            builder: (context, budgetSnapshot) {
              double cashBudget = 0.0;
              double cardBudget = 0.0;

              if (budgetSnapshot.hasData && budgetSnapshot.data!.exists) {
                final budgetData =
                    budgetSnapshot.data!.data() as Map<String, dynamic>;
                cashBudget = (budgetData['cash'] as num?)?.toDouble() ?? 0.0;
                cardBudget = (budgetData['card'] as num?)?.toDouble() ?? 0.0;
              }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spending Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isDark ? [] : [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Spent this month',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '\$${monthTotal.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.trending_up,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Simple Bar Chart
                  SizedBox(
                    height: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (index) {
                        final spending = dailySpending[index] ?? 0.0;
                        final maxSpending = dailySpending.values.isEmpty
                            ? 1.0
                            : dailySpending.values
                                  .reduce((a, b) => a > b ? a : b)
                                  .clamp(1.0, double.infinity);
                        final heightFactor = (spending / maxSpending).clamp(
                          0.05,
                          1.0,
                        );

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 32,
                              height: 80 * heightFactor,
                              decoration: BoxDecoration(
                                gradient: index == 6 ? LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.secondary,
                                  ],
                                ) : null,
                                color: index == 6
                                    ? null
                                    : Theme.of(context).colorScheme.primary
                                          .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('E').format(last7Days[index])[0],
                              style: TextStyle(
                                fontSize: 10,
                                color: index == 6
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[600],
                                fontWeight: index == 6
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                    if (cashBudget > 0 || cashTotal > 0)
                      _buildBudgetProgress(
                        context,
                        label: 'Cash Spending',
                        amount: cashTotal,
                        budget: cashBudget > 0 ? cashBudget : (cashTotal > 0 ? cashTotal : 1),
                        color: Colors.orange,
                      ),
                    if (cashBudget > 0 || cashTotal > 0)
                      const SizedBox(height: 12),
                    if (cardBudget > 0 || cardTotal > 0)
                      _buildBudgetProgress(
                        context,
                        label: 'Card Spending',
                        amount: cardTotal,
                        budget: cardBudget > 0 ? cardBudget : (cardTotal > 0 ? cardTotal : 1),
                        color: Colors.blue,
                      ),
                  ],
                ),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildRecentExpenses(BuildContext context, User? user) {
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Expenses',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: onNavigateToExpenses,
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('expenses')
              .orderBy('date', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.data!.docs.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No expenses yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first expense to get started',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.grey.withOpacity(0.1)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(color: Colors.grey.withOpacity(0.1), height: 1),
                ),
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final title = data['title']?.toString() ?? 'Untitled';
                  final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                  final category = data['category']?.toString() ?? 'Other';

                  // Handle date
                  String dateStr;
                  try {
                    if (data['date'] is Timestamp) {
                      dateStr = DateFormat(
                        'MMM d',
                      ).format((data['date'] as Timestamp).toDate());
                    } else if (data['date'] is String) {
                      dateStr = DateFormat(
                        'MMM d',
                      ).format(DateTime.parse(data['date'] as String));
                    } else {
                      dateStr = 'N/A';
                    }
                  } catch (e) {
                    dateStr = 'N/A';
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CategoryUtils.getColorForCategory(category).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        CategoryUtils.getIconForCategory(category),
                        color: CategoryUtils.getColorForCategory(category),
                        size: 24,
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('$category • $dateStr', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    trailing: Text(
                      '\$${amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBudgetProgress(
    BuildContext context, {
    required String label,
    required double amount,
    required double budget,
    required Color color,
  }) {
    final progress = (amount / budget).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              '\$${amount.toInt()} / \$${budget.toInt()}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
