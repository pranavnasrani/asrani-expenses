import 'package:flutter/material.dart';

import 'screens/budget_screen.dart';
import 'screens/expense_form_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'services/feedback_service.dart';

/// App shell: Material navigation bar with four destinations and one Add
/// FAB for the primary action.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  void _go(int index) {
    if (index == _index) return;
    FeedbackService().selectionClick();
    setState(() => _index = index);
  }

  Future<void> _add({bool scan = false}) => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ExpenseFormScreen(startWithScan: scan),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onAdd: () => _add(),
        onScan: () => _add(scan: true),
        onSeeAllExpenses: () => _go(1),
        onOpenBudget: () => _go(2),
      ),
      const ExpensesScreen(),
      const BudgetScreen(),
      const InsightsScreen(),
    ];
    return PopScope(
      // System Back returns to Home before leaving the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'add-expense',
          onPressed: _add,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add'),
          tooltip: 'Add expense',
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Expenses',
            ),
            NavigationDestination(
              icon: Icon(Icons.layers_outlined),
              selectedIcon: Icon(Icons.layers_rounded),
              label: 'Budget',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Insights',
            ),
          ],
        ),
      ),
    );
  }
}
