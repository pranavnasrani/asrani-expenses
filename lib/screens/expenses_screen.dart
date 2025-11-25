import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final user = FirebaseAuth.instance.currentUser;

  Future<void> _deleteExpense(String id) async {
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('expenses')
        .doc(id)
        .delete();
  }

  Future<void> _showEditDialog(DocumentSnapshot doc) async {
    if (user == null) return;
    final data = doc.data() as Map<String, dynamic>;

    // Add null safety for all fields
    final titleController = TextEditingController(
      text: data['title']?.toString() ?? '',
    );
    final amountController = TextEditingController(
      text: (data['amount'] as num?)?.toString() ?? '0',
    );
    final placeController = TextEditingController(
      text: data['place']?.toString() ?? '',
    );

    String selectedCategory = data['category']?.toString() ?? 'Other';
    String selectedPaymentMethod = data['paymentMethod'] ?? 'Cash';
    List<String> categories = [
      'Food',
      'Transport',
      'Shopping',
      'Entertainment',
      'Bills',
      'Other',
    ];
    final List<String> paymentMethods = [
      'Cash',
      'Credit Card',
      'Debit Card',
      'PayNow',
      'Other',
    ];

    // Fetch user categories
    try {
      final catDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('settings')
          .doc('categories')
          .get();
      if (catDoc.exists &&
          catDoc.data() != null &&
          catDoc.data()!.containsKey('list')) {
        categories = List<String>.from(catDoc.data()!['list']);
      }
    } catch (e) {
      print('Error fetching categories: $e');
    }

    if (!categories.contains(selectedCategory)) {
      categories.add(selectedCategory);
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Expense'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: placeController,
                    decoration: const InputDecoration(labelText: 'Place'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedPaymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                    ),
                    items: paymentMethods
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedPaymentMethod = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newTitle = titleController.text.trim();
                  final newAmount = double.tryParse(
                    amountController.text.trim(),
                  );
                  final newPlace = placeController.text.trim();

                  if (newTitle.isNotEmpty && newAmount != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .collection('expenses')
                        .doc(doc.id)
                        .update({
                          'title': newTitle,
                          'amount': newAmount,
                          'place': newPlace,
                          'category': selectedCategory,
                          'paymentMethod': selectedPaymentMethod,
                        });
                    if (context.mounted) Navigator.pop(context);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('expenses')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No expenses found'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              // Handle both Timestamp and String date formats
              String date;
              try {
                if (data['date'] is Timestamp) {
                  date = DateFormat(
                    'MMM d, yyyy',
                  ).format((data['date'] as Timestamp).toDate());
                } else if (data['date'] is String) {
                  // Parse string date and format it
                  final parsedDate = DateTime.parse(data['date'] as String);
                  date = DateFormat('MMM d, yyyy').format(parsedDate);
                } else {
                  date = 'Unknown date';
                }
              } catch (e) {
                date = 'Invalid date';
                print('Error parsing date: $e');
              }
              final category = data['category'] ?? 'Other';
              final place = data['place'] ?? '';

              // Add null safety for all fields
              final title = data['title']?.toString() ?? 'Untitled';
              final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
              final imageUrl = data['imageUrl']?.toString();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image, size: 50),
                            );
                          },
                        ),
                      ),
                    ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          title.isNotEmpty ? title[0].toUpperCase() : '?',
                        ),
                      ),
                      title: Text(title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$date • $category'),
                          if (place.isNotEmpty)
                            Text(
                              '📍 $place',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\$${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showEditDialog(doc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteExpense(doc.id),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
