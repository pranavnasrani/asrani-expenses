import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BudgetingScreen extends StatefulWidget {
  const BudgetingScreen({super.key});

  @override
  State<BudgetingScreen> createState() => _BudgetingScreenState();
}

class _BudgetingScreenState extends State<BudgetingScreen> {
  final TextEditingController _budgetController = TextEditingController();
  bool _includeRollover = false;
  double _calculatedRollover = 0.0;

  // Advanced Budgeting State
  bool _isCategoryBudget = false;
  Map<String, double> _categoryBudgets = {};
  List<String> _availableCategories = [];

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('settings')
          .doc('categories')
          .get();
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('list')) {
        if (mounted) {
          setState(() {
            _availableCategories = List<String>.from(doc.data()!['list']);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _availableCategories = [
              'Food',
              'Transport',
              'Shopping',
              'Entertainment',
              'Bills',
              'Other',
            ];
          });
        }
      }
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  String _getDocId(DateTime date) {
    return DateFormat('yyyy_MM').format(date);
  }

  Future<double> _calculateRolloverForMonth(DateTime date) async {
    if (user == null) return 0.0;
    final prevDate = DateTime(date.year, date.month - 1);
    final prevDocId = _getDocId(prevDate);

    final budgetDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('budgets')
        .doc(prevDocId)
        .get();

    if (!budgetDoc.exists) return 0.0;

    final budgetData = budgetDoc.data() as Map<String, dynamic>;
    final bool includedRollover = budgetData['isRolloverIncluded'] ?? false;
    final double prevRollover =
        (budgetData['rolloverAmount'] as num?)?.toDouble() ?? 0.0;

    double totalBudget = 0.0;
    if (budgetData['budgetType'] == 'category') {
      final catBudgets = Map<String, dynamic>.from(
        budgetData['categoryBudgets'] ?? {},
      );
      double sum = 0.0;
      catBudgets.forEach((key, value) {
        sum += (value as num).toDouble();
      });
      totalBudget = sum;
    } else {
      totalBudget = (budgetData['amount'] as num?)?.toDouble() ?? 0.0;
    }

    totalBudget += (includedRollover ? prevRollover : 0.0);

    final startOfMonth = DateTime(prevDate.year, prevDate.month, 1);
    final endOfMonth = DateTime(
      prevDate.year,
      prevDate.month + 1,
      0,
      23,
      59,
      59,
    );

    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: startOfMonth)
        .where('date', isLessThanOrEqualTo: endOfMonth)
        .get();

    double totalSpent = 0.0;
    for (var doc in expensesSnapshot.docs) {
      totalSpent += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
    }

    final remainder = totalBudget - totalSpent;
    return remainder > 0 ? remainder : 0.0;
  }

  Future<void> _showBudgetDialog(
    double currentBaseBudget,
    bool currentIncludeRollover,
    Map<String, dynamic> currentCategoryBudgets,
  ) async {
    _budgetController.text = currentBaseBudget.toString();
    _includeRollover = currentIncludeRollover;
    _categoryBudgets = Map<String, double>.from(
      currentCategoryBudgets.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );

    _calculatedRollover = await _calculateRolloverForMonth(DateTime.now());

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Set Budget for ${DateFormat('MMMM').format(DateTime.now())}',
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Aggregate'),
                        Switch(
                          value: _isCategoryBudget,
                          onChanged: (value) {
                            setState(() {
                              _isCategoryBudget = value;
                            });
                          },
                        ),
                        const Text('Per-Category'),
                      ],
                    ),
                    const Divider(height: 30),
                    if (!_isCategoryBudget)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: TextField(
                          controller: _budgetController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Base Budget Amount',
                            border: OutlineInputBorder(),
                            prefixText: '\$',
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _availableCategories.map((category) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    category,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    initialValue:
                                        _categoryBudgets[category]
                                            ?.toString() ??
                                        '',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      prefixText: '\$',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      final val = double.tryParse(value);
                                      if (val != null) {
                                        _categoryBudgets[category] = val;
                                      } else {
                                        _categoryBudgets.remove(category);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 20),
                    if (_calculatedRollover > 0)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: CheckboxListTile(
                          title: const Text('Include Rollover'),
                          subtitle: Text(
                            'From last month: \$${_calculatedRollover.toStringAsFixed(2)}',
                          ),
                          value: _includeRollover,
                          onChanged: (bool? value) {
                            setState(() {
                              _includeRollover = value ?? false;
                            });
                          },
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No rollover available from last month.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
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
                  if (user == null) return;
                  final newBudget =
                      double.tryParse(_budgetController.text.trim()) ?? 0.0;

                  final docId = _getDocId(DateTime.now());
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .collection('budgets')
                      .doc(docId)
                      .set({
                        'budgetType': _isCategoryBudget
                            ? 'category'
                            : 'aggregate',
                        'amount': newBudget,
                        'categoryBudgets': _categoryBudgets,
                        'rolloverAmount': _calculatedRollover,
                        'isRolloverIncluded': _includeRollover,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text('Please log in'));

    final now = DateTime.now();
    final currentDocId = _getDocId(now);
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(title: const Text('Budgeting')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('budgets')
            .doc(currentDocId)
            .snapshots(),
        builder: (context, budgetSnapshot) {
          if (budgetSnapshot.hasError) {
            return Center(child: Text('Error: ${budgetSnapshot.error}'));
          }

          double baseBudget = 0.0;
          double rolloverAmount = 0.0;
          bool isRolloverIncluded = false;
          String budgetType = 'aggregate';
          Map<String, double> categoryBudgets = {};

          if (budgetSnapshot.hasData && budgetSnapshot.data!.exists) {
            final data = budgetSnapshot.data!.data() as Map<String, dynamic>;
            baseBudget = (data['amount'] as num?)?.toDouble() ?? 0.0;
            rolloverAmount =
                (data['rolloverAmount'] as num?)?.toDouble() ?? 0.0;
            isRolloverIncluded = data['isRolloverIncluded'] ?? false;
            budgetType = data['budgetType'] ?? 'aggregate';
            if (data['categoryBudgets'] != null) {
              final catMap = Map<String, dynamic>.from(data['categoryBudgets']);
              categoryBudgets = catMap.map(
                (key, value) => MapEntry(key, (value as num).toDouble()),
              );
            }
            // Sync local state for dialog
            _isCategoryBudget = budgetType == 'category';
          }

          double totalBudgetLimit = 0.0;
          if (budgetType == 'category') {
            categoryBudgets.forEach((key, value) => totalBudgetLimit += value);
          } else {
            totalBudgetLimit = baseBudget;
          }
          totalBudgetLimit += (isRolloverIncluded ? rolloverAmount : 0.0);

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .collection('expenses')
                .where('date', isGreaterThanOrEqualTo: startOfMonth)
                .where('date', isLessThanOrEqualTo: endOfMonth)
                .snapshots(),
            builder: (context, expenseSnapshot) {
              if (expenseSnapshot.hasError) {
                return Center(child: Text('Error: ${expenseSnapshot.error}'));
              }

              if (expenseSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              double totalSpent = 0.0;
              Map<String, double> categorySpent = {};

              if (expenseSnapshot.hasData) {
                for (var doc in expenseSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                  final category = data['category'] ?? 'Other';

                  totalSpent += amount;
                  categorySpent[category] =
                      (categorySpent[category] ?? 0.0) + amount;
                }
              }

              final double progress = totalBudgetLimit > 0
                  ? (totalSpent / totalBudgetLimit)
                  : 0.0;
              final bool isOverBudget =
                  totalSpent > totalBudgetLimit && totalBudgetLimit > 0;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              const Text(
                                'Total Spent (This Month)',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${totalSpent.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: isOverBudget
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                              const SizedBox(height: 20),
                              LinearProgressIndicator(
                                value: progress > 1.0 ? 1.0 : progress,
                                backgroundColor: Colors.grey[300],
                                color: isOverBudget ? Colors.red : Colors.blue,
                                minHeight: 10,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(progress * 100).toStringAsFixed(1)}% of total budget used',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              title: const Text('Monthly Budget'),
                              subtitle: Text(
                                budgetType == 'category'
                                    ? 'Per-Category Mode'
                                    : 'Aggregate Mode',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showBudgetDialog(
                                  baseBudget,
                                  isRolloverIncluded,
                                  categoryBudgets,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Limit: \$${totalBudgetLimit.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isRolloverIncluded)
                                    Text(
                                      '(Incl. Rollover: \$${rolloverAmount.toStringAsFixed(2)})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOverBudget)
                        const Padding(
                          padding: EdgeInsets.only(top: 20.0),
                          child: Card(
                            color: Colors.redAccent,
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                '⚠️ You have exceeded your total budget!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),

                      if (budgetType == 'category') ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Category Breakdown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...categoryBudgets.entries.map((entry) {
                          final catName = entry.key;
                          final catLimit = entry.value;
                          final catSpent = categorySpent[catName] ?? 0.0;
                          final catProgress = catLimit > 0
                              ? (catSpent / catLimit)
                              : 0.0;
                          final catOver = catSpent > catLimit;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        catName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '\$${catSpent.toStringAsFixed(2)} / \$${catLimit.toStringAsFixed(2)}',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: catProgress > 1.0
                                        ? 1.0
                                        : catProgress,
                                    backgroundColor: Colors.grey[200],
                                    color: catOver
                                        ? Colors.red
                                        : Colors.blueAccent,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
