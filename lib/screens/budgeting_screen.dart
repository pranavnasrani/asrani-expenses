import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SpendingBreakdownScreen extends StatefulWidget {
  const SpendingBreakdownScreen({super.key});

  @override
  State<SpendingBreakdownScreen> createState() =>
      _SpendingBreakdownScreenState();
}

class _SpendingBreakdownScreenState extends State<SpendingBreakdownScreen> {
  final user = FirebaseAuth.instance.currentUser;
  DateTime _selectedDate = DateTime.now();
  String _budgetType = 'method'; // 'overall', 'method', 'category'
  bool _enableRollover = false;
  bool _hasInitializedRollover = false;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(child: Text('Please log in'));
    }

    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final endOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
      23,
      59,
      59,
    );

    // Calculate Previous Month Range for Rollover
    final prevMonthDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
    final prevStart = DateTime(prevMonthDate.year, prevMonthDate.month, 1);
    final prevEnd = DateTime(
      prevMonthDate.year,
      prevMonthDate.month + 1,
      0,
      23,
      59,
      59,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgeting & Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditBudgetDialog(_budgetType),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                });
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('settings')
            .doc('budgets_${DateFormat('yyyy_MM').format(_selectedDate)}')
            .snapshots(),
        builder: (context, budgetSnapshot) {
          if (budgetSnapshot.hasError) {
            return Center(child: Text('Error loading budgets'));
          }

          if (!budgetSnapshot.hasData &&
              budgetSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Parse Budget Data
          final budgetData = budgetSnapshot.data?.exists == true
              ? budgetSnapshot.data!.data() as Map<String, dynamic>
              : <String, dynamic>{};

          if (!_hasInitializedRollover) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
               if (mounted) {
                 setState(() {
                   _enableRollover = budgetData['enableRollover'] == true;
                   _hasInitializedRollover = true;
                 });
               }
            });
          }

          // Read Budgets based on Type
          double overallBudget =
              (budgetData['overallLimit'] as num?)?.toDouble() ?? 0.0;
          double cashBudget = (budgetData['cash'] as num?)?.toDouble() ?? 0.0;
          double cardBudget = (budgetData['card'] as num?)?.toDouble() ?? 0.0;
          Map<String, double> categoryBudgets = {};
          if (budgetData['categories'] != null) {
            (budgetData['categories'] as Map<String, dynamic>).forEach((k, v) {
              categoryBudgets[k] = (v as num).toDouble();
            });
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .collection('expenses')
                .where('date', isGreaterThanOrEqualTo: startOfMonth)
                .where('date', isLessThanOrEqualTo: endOfMonth)
                .snapshots(),
            builder: (context, expenseSnapshot) {
              // Retrieve Previous Month Expenses ONLY if Rollover is ON
              return FutureBuilder<List<dynamic>?>(
                future: _enableRollover
                    ? Future.wait([
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(user!.uid)
                            .collection('expenses')
                            .where('date', isGreaterThanOrEqualTo: prevStart)
                            .where('date', isLessThanOrEqualTo: prevEnd)
                            .get(),
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(user!.uid)
                            .collection('settings')
                            .doc('budgets_${DateFormat('yyyy_MM').format(prevMonthDate)}')
                            .get()
                      ])
                    : Future.value(null),
                builder: (context, prevDataSnapshot) {
                  if (expenseSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = expenseSnapshot.data?.docs ?? [];
                  final prevDocs = prevDataSnapshot.data != null 
                      ? (prevDataSnapshot.data![0] as QuerySnapshot).docs 
                      : [];
                  final prevBudgetDoc = prevDataSnapshot.data != null
                      ? (prevDataSnapshot.data![1] as DocumentSnapshot).data() as Map<String, dynamic>? ?? {}
                      : <String, dynamic>{};

                  // --- Calculate Current Spending ---
                  double currentTotalSpent = 0.0;
                  double currentCashSpent = 0.0;
                  double currentCardSpent = 0.0;
                  Map<String, double> currentCategorySpent = {};

                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                    final method = data['paymentMethod'] as String? ?? 'Other';
                    final category = data['category'] as String? ?? 'Other';

                    currentTotalSpent += amount;
                    if (method.toLowerCase() == 'cash') {
                      currentCashSpent += amount;
                    } else {
                      currentCardSpent += amount;
                    }
                    currentCategorySpent[category] =
                        (currentCategorySpent[category] ?? 0.0) + amount;
                  }

                  // --- Calculate Rollover (Optional) ---
                  double rolloverAmount = 0.0;
                  double cashRollover = 0.0;
                  double cardRollover = 0.0;
                  Map<String, double> categoryRollover = {};

                  if (_enableRollover && prevDocs.isNotEmpty) {
                    // Only calculate rollover if there's actual previous month data
                    double prevTotalSpent = 0.0;
                    double prevCashSpent = 0.0;
                    double prevCardSpent = 0.0;
                    Map<String, double> prevCategorySpent = {};

                    for (var doc in prevDocs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final amount =
                          (data['amount'] as num?)?.toDouble() ?? 0.0;
                      final method =
                          data['paymentMethod'] as String? ?? 'Other';
                      final category = data['category'] as String? ?? 'Other';

                      prevTotalSpent += amount;
                      if (method.toLowerCase() == 'cash') {
                        prevCashSpent += amount;
                      } else {
                        prevCardSpent += amount;
                      }
                      prevCategorySpent[category] =
                          (prevCategorySpent[category] ?? 0.0) + amount;
                    }

                    double prevOverallBudget = (prevBudgetDoc['overallLimit'] as num?)?.toDouble() ?? 0.0;
                    double prevCashBudget = (prevBudgetDoc['cash'] as num?)?.toDouble() ?? 0.0;
                    double prevCardBudget = (prevBudgetDoc['card'] as num?)?.toDouble() ?? 0.0;
                    Map<String, double> prevCategoryBudgets = {};
                    if (prevBudgetDoc['categories'] != null) {
                      (prevBudgetDoc['categories'] as Map<String, dynamic>).forEach((k, v) {
                        prevCategoryBudgets[k] = (v as num).toDouble();
                      });
                    }

                    // Rollover = Previous Budget - Previous Spent (surplus or deficit)
                    rolloverAmount = prevOverallBudget - prevTotalSpent;
                    cashRollover = prevCashBudget - prevCashSpent;
                    cardRollover = prevCardBudget - prevCardSpent;
                    prevCategoryBudgets.forEach((key, val) {
                      categoryRollover[key] = val - (prevCategorySpent[key] ?? 0.0);
                    });
                  }
                  // If rollover is enabled but no previous month data, rollover stays 0

                  // --- Apply Rollover to Budgets ---
                  final finalOverallBudget = overallBudget + rolloverAmount;
                  final finalCashBudget = cashBudget + cashRollover;
                  final finalCardBudget = cardBudget + cardRollover;
                  // For categories, we need a list of all relevant categories (merged from budget and expenses)
                  final allCategories = {
                    ...categoryBudgets.keys,
                    ...currentCategorySpent.keys,
                  }.toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month Header and Controls
                        Center(
                          child: Column(
                            children: [
                              Text(
                                DateFormat('MMMM yyyy').format(_selectedDate),
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              _buildControls(context),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- Dynamic Body based on Budget Type ---
                        if (_budgetType == 'overall')
                          _buildBudgetCard(
                            'Overall Budget',
                            currentTotalSpent,
                            finalOverallBudget,
                            Theme.of(context).colorScheme.primary,
                            rollover: _enableRollover ? rolloverAmount : null,
                          )
                        else if (_budgetType == 'method') ...[
                          _buildBudgetCard(
                            'Cash Budget',
                            currentCashSpent,
                            finalCashBudget,
                            Colors.green,
                            rollover: _enableRollover ? cashRollover : null,
                          ),
                          const SizedBox(height: 16),
                          _buildBudgetCard(
                            'Card / Digital Budget',
                            currentCardSpent,
                            finalCardBudget,
                            Colors.blue,
                            rollover: _enableRollover ? cardRollover : null,
                          ),
                        ] else if (_budgetType == 'category') ...[
                          if (allCategories.isEmpty)
                            const Center(
                              child: Text('No categories or expenses found.'),
                            )
                          else
                            ...allCategories.map((cat) {
                              final budget = categoryBudgets[cat] ?? 0.0;
                              final rollover = _enableRollover
                                  ? (categoryRollover[cat] ?? 0.0)
                                  : null;
                              final finalBudget = budget + (rollover ?? 0.0);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: _buildBudgetCard(
                                  cat,
                                  currentCategorySpent[cat] ?? 0.0,
                                  finalBudget,
                                  Colors.orange, // Or dynamic color
                                  rollover: rollover,
                                ),
                              );
                            }),
                        ],

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Pie Chart (Always reflects breakdown of reported type?)
                        // Actually Pie Chart usually shows CATEGORY breakdown or METHOD breakdown.
                        // Let's stick to simple Method breakdown for now unless Category mode is on?
                        // Let's keep it simple: Break down by what is being budgetted if possible,
                        // or just default to Method like before?
                        // "Spending Analysis" usually implies Category or Method breakdown.
                        // Let's do a switch for the chart too.
                        if (currentTotalSpent > 0)
                          SizedBox(
                            height: 250,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: _buildChartSections(
                                  _budgetType,
                                  currentTotalSpent,
                                  currentCashSpent,
                                  currentCardSpent,
                                  currentCategorySpent,
                                ),
                              ),
                            ),
                          )
                        else
                          const Center(
                            child: Text('No expenses recorded this month.'),
                          ),
                      ],
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

  Widget _buildControls(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<String>(
          value: _budgetType,
          items: const [
            DropdownMenuItem(value: 'overall', child: Text('Overall Budget')),
            DropdownMenuItem(value: 'method', child: Text('Cash vs Card')),
            DropdownMenuItem(value: 'category', child: Text('By Category')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _budgetType = val);
          },
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Rollover'),
            Switch(
              value: _enableRollover,
              onChanged: (val) async {
                setState(() => _enableRollover = val);
                // Persist to Firestore
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .collection('settings')
                      .doc('budgets_${DateFormat('yyyy_MM').format(_selectedDate)}')
                      .set({'enableRollover': val}, SetOptions(merge: true));
                } catch (e) {
                  debugPrint('Failed to save rollover preference: $e');
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildChartSections(
    String type,
    double total,
    double cash,
    double card,
    Map<String, double> categories,
  ) {
    if (type == 'category') {
      // Generate colors for categories
      final List<Color> colors = [
        Colors.blue,
        Colors.red,
        Colors.green,
        Colors.orange,
        Colors.purple,
        Colors.teal,
      ];
      int i = 0;
      return categories.entries.map((e) {
        final color = colors[i % colors.length];
        i++;
        return PieChartSectionData(
          radius: 50,
          value: e.value,
          title: '${((e.value / total) * 100).toStringAsFixed(0)}%',
          color: color,
          titleStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      }).toList();
    } else {
      // Default to Method (Cash vs Card)
      return [
        if (cash > 0)
          PieChartSectionData(
            radius: 50,
            value: cash,
            title: '${((cash / total) * 100).toStringAsFixed(0)}%',
            color: Colors.green,
            titleStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        if (card > 0)
          PieChartSectionData(
            radius: 50,
            value: card,
            title: '${((card / total) * 100).toStringAsFixed(0)}%',
            color: Colors.blue,
            titleStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
      ];
    }
  }

  Widget _buildBudgetCard(
    String title,
    double spent,
    double budget,
    Color color, {
    double? rollover,
  }) {
    // Calculate balance
    final double balance = budget - spent;
    final bool isOverBudget = balance < 0 && budget > 0;
    final Color progressColor = isOverBudget ? Colors.red : color;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOverBudget ? Icons.warning_rounded : Icons.check_circle_rounded,
                  color: progressColor,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0,
              backgroundColor: color.withOpacity(0.1),
              color: progressColor,
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 20),
          // Balance prominently displayed
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: (balance >= 0 ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  balance >= 0 ? Icons.savings_rounded : Icons.trending_down_rounded,
                  color: balance >= 0 ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Balance: \$${balance.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: balance >= 0 ? Colors.green : Colors.red,
                    letterSpacing: -0.5,
                  ),
                ),
                if (balance < 0)
                  const Text(
                    ' over',
                    style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spent', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('\$${spent.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Budget', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '\$${budget.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (rollover != null && rollover != 0)
                    Text(
                      '(${rollover > 0 ? '+' : ''}${rollover.toStringAsFixed(2)} rollover)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: rollover > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditBudgetDialog(String type) async {
    // Fetch current settings first to pre-fill
    // We will use a Map to hold temporary values
    Map<String, double> tempValues = {};
    List<String> categories = [];

    // Fetch categories first if needed
    if (type == 'category') {
      try {
        final catDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('settings')
            .doc('categories')
            .get();
        if (catDoc.exists) {
          categories = List<String>.from(catDoc.data()!['list'] ?? []);
        }
      } catch (e) {
        // ignore
      }
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('settings')
          .doc('budgets_${DateFormat('yyyy_MM').format(_selectedDate)}')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        tempValues['overall'] =
            (data['overallLimit'] as num?)?.toDouble() ?? 0.0;
        tempValues['cash'] = (data['cash'] as num?)?.toDouble() ?? 0.0;
        tempValues['card'] = (data['card'] as num?)?.toDouble() ?? 0.0;

        if (data['categories'] != null) {
          (data['categories'] as Map<String, dynamic>).forEach((k, v) {
            tempValues['cat_$k'] = (v as num).toDouble();
          });
        }
      }
    } catch (e) {
      // ignore
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        // Use a StatefulBuilder to manage dialog state if needed, though controllers usually suffice
        return AlertDialog(
          title: Text(
            'Set ${type[0].toUpperCase()}${type.substring(1)} Budget',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (type == 'overall') ...[
                    _buildNumberField('Overall Limit', 'overall', tempValues),
                  ] else if (type == 'method') ...[
                    _buildNumberField('Cash Budget', 'cash', tempValues),
                    const SizedBox(height: 16),
                    _buildNumberField('Card Budget', 'card', tempValues),
                  ] else if (type == 'category') ...[
                    if (categories.isEmpty) const Text('No categories found.'),
                    ...categories.map(
                      (cat) => Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildNumberField(cat, 'cat_$cat', tempValues),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Save back to Firestore
                final docRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('settings')
                    .doc('budgets_${DateFormat('yyyy_MM').format(_selectedDate)}');

                Map<String, dynamic> updates = {};

                if (type == 'overall') {
                  updates['overallLimit'] = tempValues['overall'];
                } else if (type == 'method') {
                  updates['cash'] = tempValues['cash'];
                  updates['card'] = tempValues['card'];
                } else if (type == 'category') {
                  Map<String, double> catMap = {};
                  for (var cat in categories) {
                    catMap[cat] = tempValues['cat_$cat'] ?? 0.0;
                  }
                  updates['categories'] = catMap;
                }

                await docRef.set(updates, SetOptions(merge: true));

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNumberField(
    String label,
    String key,
    Map<String, double> values,
  ) {
    return TextFormField(
      initialValue: (values[key] ?? 0.0) == 0.0 ? '' : values[key].toString(),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '\$',
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (val) {
        values[key] = double.tryParse(val) ?? 0.0;
      },
    );
  }
}
