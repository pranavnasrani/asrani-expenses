import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'screens/add_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/budgeting_screen.dart';
import 'screens/charts_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';

class MainScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const MainScreen({super.key, required this.onThemeToggle});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = [
      HomeScreen(
        onNavigateToAdd: () => _onItemTapped(1),
        onNavigateToExpenses: () => _onItemTapped(2),
      ),
      const AddScreen(),
      const ExpensesScreen(),
      const SpendingBreakdownScreen(),
      const ChartsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitleForIndex(_selectedIndex)),
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: widget.onThemeToggle,
            tooltip: 'Toggle theme',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        },
        tooltip: 'Ask AI',
        child: const Icon(Icons.auto_awesome),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Expenses'),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Breakdown',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Charts'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  String _getTitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Asrani Expenses';
      case 1:
        return 'Add Expense';
      case 2:
        return 'Expenses';
      case 3:
        return 'Spending Breakdown';
      case 4:
        return 'Charts';
      default:
        return 'Asrani Expenses';
    }
  }
}
