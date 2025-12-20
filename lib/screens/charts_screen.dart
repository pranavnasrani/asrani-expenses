import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  String _pieChartFilter = 'Category'; // Category, Place, Payment Method
  final List<String> _filterOptions = ['Category', 'Place', 'Payment Method'];

  // Colors for charts
  final List<Color> _colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text('Please log in'));

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPieChartSection(),
            const SizedBox(height: 20),
            _buildBarChartSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Spending Breakdown',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _pieChartFilter,
                  items: _filterOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() {
                        _pieChartFilter = newValue;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('expenses')
                    .where(
                      'date',
                      isGreaterThanOrEqualTo: DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        1,
                      ),
                    )
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading data'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No expenses this month'));
                  }

                  // Process data
                  Map<String, double> dataMap = {};
                  double total = 0.0;

                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                    String key = 'Unknown';

                    if (_pieChartFilter == 'Category') {
                      key = data['category'] ?? 'Other';
                    } else if (_pieChartFilter == 'Place') {
                      key = (data['place'] as String?)?.isNotEmpty == true
                          ? data['place']
                          : 'Unknown';
                    } else if (_pieChartFilter == 'Payment Method') {
                      key = data['paymentMethod'] ?? 'Other';
                    }

                    dataMap[key] = (dataMap[key] ?? 0.0) + amount;
                    total += amount;
                  }

                  if (total == 0) {
                    return const Center(child: Text('No spending to show'));
                  }

                  // Create Pie Sections
                  int colorIndex = 0;
                  List<PieChartSectionData> sections = [];

                  dataMap.forEach((key, value) {
                    final percentage = (value / total) * 100;
                    final isLarge = percentage > 10; // Highlight large sections
                    sections.add(
                      PieChartSectionData(
                        color: _colors[colorIndex % _colors.length],
                        value: value,
                        title: '${percentage.toStringAsFixed(1)}%',
                        radius: isLarge ? 60 : 50,
                        titleStyle: TextStyle(
                          fontSize: isLarge ? 16 : 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    );
                    colorIndex++;
                  });

                  return Column(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sections: sections,
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: dataMap.keys.toList().asMap().entries.map((
                          entry,
                        ) {
                          int idx = entry.key;
                          String name = entry.value;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                color: _colors[idx % _colors.length],
                              ),
                              const SizedBox(width: 4),
                              Text(name, style: const TextStyle(fontSize: 12)),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last 6 Months Spending',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: FutureBuilder<Map<int, double>>(
                future: _fetchMonthlySpending(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading history'));
                  }

                  final data = snapshot.data ?? {};
                  if (data.isEmpty) {
                    return const Center(child: Text('No history available'));
                  }

                  // Prepare Bar Groups
                  List<BarChartGroupData> barGroups = [];
                  double maxY = 0;

                  final now = DateTime.now();
                  for (int i = 5; i >= 0; i--) {
                    final monthDate = DateTime(now.year, now.month - i);
                    // Key format: YYYYMM
                    final key = monthDate.year * 100 + monthDate.month;
                    final amount = data[key] ?? 0.0;
                    if (amount > maxY) maxY = amount;

                    barGroups.add(
                      BarChartGroupData(
                        x:
                            5 -
                            i, // 0 to 5, where 0 is oldest (5 months ago), 5 is newest (current month)
                        barRods: [
                          BarChartRodData(
                            toY: amount,
                            color: Colors.blue,
                            width: 16,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY * 1.2, // Add some headroom
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => Colors.blueGrey,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '\$${rod.toY.toStringAsFixed(0)}',
                              const TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt(); // 0 to 5
                              // 0 is oldest (5 months ago), 5 is newest (current month)
                              if (index < 0 || index > 5) {
                                return const SizedBox.shrink();
                              }
                              final date = DateTime(
                                now.year,
                                now.month - (5 - index),
                              );
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat('MMM').format(date),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<int, double>> _fetchMonthlySpending() async {
    if (user == null) return {};
    final now = DateTime.now();
    final startOfSixMonthsAgo = DateTime(now.year, now.month - 5, 1);

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: startOfSixMonthsAgo)
        .get();

    Map<int, double> monthlyTotals = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();

      // Handle both Timestamp and String date formats
      DateTime date;
      try {
        if (data['date'] is Timestamp) {
          date = (data['date'] as Timestamp).toDate();
        } else if (data['date'] is String) {
          date = DateTime.parse(data['date'] as String);
        } else {
          continue; // Skip this entry if date format is unknown
        }
      } catch (e) {
        debugPrint('Error parsing date in charts: $e');
        continue; // Skip this entry if date parsing fails
      }

      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

      final key = date.year * 100 + date.month;
      monthlyTotals[key] = (monthlyTotals[key] ?? 0.0) + amount;
    }

    return monthlyTotals;
  }
}
