import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../services/feedback_service.dart';
import '../utils/category_utils.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;
  bool _isScanning = false;

  // Fields
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  List<String> _categories = [];
  final List<String> _paymentMethods = [
    'Cash',
    'Credit Card',
    'Debit Card',
    'PayNow',
    'Other',
  ];

  final GeminiService _geminiService = GeminiService();
  final StorageService _storageService = StorageService();
  final FeedbackService _feedback = FeedbackService();
  List<String> _locationHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchLocationHistory();
    _selectedPaymentMethod = _paymentMethods.first;
  }

  Future<void> _fetchLocationHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('locationHistory')
          .get();

      if (doc.exists && doc.data() != null) {
        if (mounted) {
          setState(() {
            _locationHistory = List<String>.from(doc.data()!['places'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching location history: $e');
    }
  }

  Future<void> _saveLocationToHistory(String place) async {
    if (place.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (!_locationHistory.contains(place)) {
        _locationHistory.insert(0, place);
        if (_locationHistory.length > 20) {
          _locationHistory = _locationHistory.take(20).toList();
        }
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('locationHistory')
            .set({'places': _locationHistory});
      }
    } catch (e) {
      debugPrint('Error saving location history: $e');
    }
  }

  Future<void> _fetchCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('categories')
          .get();

      if (doc.exists && doc.data() != null && doc.data()!.containsKey('list')) {
        if (mounted) {
          setState(() {
            _categories = List<String>.from(doc.data()!['list']);
            if (_categories.isNotEmpty) _selectedCategory = _categories.first;
          });
        }
      } else {
        final defaultCategories = [
          'Food',
          'Transport',
          'Shopping',
          'Entertainment',
          'Bills',
          'Other',
        ];
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('categories')
            .set({'list': defaultCategories});

        if (mounted) {
          setState(() {
            _categories = defaultCategories;
            _selectedCategory = _categories.first;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> _pickImageAndScan(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _isScanning = true;
      });

      try {
        // Load image
        dynamic imageSource;
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          imageSource = bytes;
          _selectedImageBytes = bytes;
        } else {
          final bytes = await pickedFile.readAsBytes();
          _selectedImage = File(pickedFile.path);
          _selectedImageBytes = bytes;
          imageSource = _selectedImage;
        }

        // Analyze with Gemini
        final extractedData = await _geminiService.analyzeReceipt(imageSource);

        if (extractedData != null && mounted) {
          // Autofill form
          setState(() {
            _titleController.text = extractedData['title'] ?? '';
            _amountController.text = extractedData['amount']?.toString() ?? '';
            _placeController.text = extractedData['place'] ?? '';

            final category = extractedData['category'] ?? 'Other';
            if (_categories.contains(category)) {
              _selectedCategory = category;
            }
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✨ Receipt scanned successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not extract data from receipt'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error scanning receipt: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        if (!kIsWeb) {
          _selectedImage = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _showScanOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, size: 30),
              title: const Text('Take Photo'),
              subtitle: const Text('Scan receipt with camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImageAndScan(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, size: 30),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select existing photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImageAndScan(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final place = _placeController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || amount == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl;
      if (_selectedImageBytes != null) {
        imageUrl = await _storageService.uploadReceipt(
          userId: user.uid,
          file: _selectedImage,
          bytes: _selectedImageBytes,
        );
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .add({
            'title': title,
            'amount': amount,
            'date': DateTime.now(),
            if (imageUrl != null) 'imageUrl': imageUrl,
            'place': place,
            'category': _selectedCategory ?? 'Other',
            'paymentMethod': _selectedPaymentMethod ?? 'Cash',
          });

      if (mounted) {
        // Capture messenger before async gap
        final messenger = ScaffoldMessenger.of(context);

        // Save place to history
        await _saveLocationToHistory(place);

        // Success feedback (haptic + sound)
        await _feedback.successFeedback();

        messenger.showSnackBar(
          const SnackBar(
            content: Text('Expense added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding expense: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearForm() {
    _titleController.clear();
    _amountController.clear();
    _placeController.clear();
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedCategory = _categories.isNotEmpty ? _categories.first : null;
      _selectedPaymentMethod = _paymentMethods.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isScanning
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Analyzing receipt with AI...',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // AI Scan Button
                    _buildScanCard(),
                    const SizedBox(height: 24),

                    // Title Field
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Amount Field
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        if (double.tryParse(value!) == null) {
                          return 'Invalid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Place Field with Autocomplete from history
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _locationHistory.take(5);
                        }
                        return _locationHistory.where((String option) {
                          return option.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          );
                        });
                      },
                      onSelected: (String selection) {
                        _placeController.text = selection;
                        _feedback.lightTap();
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmitted) {
                            // Sync the controller text
                            if (controller.text != _placeController.text) {
                              controller.text = _placeController.text;
                            }
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'Place',
                                prefixIcon: Icon(Icons.location_on),
                                hintText: 'Type or select from history...',
                              ),
                              onChanged: (value) {
                                _placeController.text = value;
                              },
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 200,
                                maxWidth: 300,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.history,
                                      size: 20,
                                    ),
                                    title: Text(option),
                                    dense: true,
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _categories.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Row(
                            children: [
                              Icon(
                                CategoryUtils.getIconForCategory(value),
                                color: CategoryUtils.getColorForCategory(value),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(value),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
                      },
                      validator: (val) =>
                          val == null ? 'Please select a category' : null,
                    ),
                    const SizedBox(height: 16),

                    // Payment Method Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: _paymentMethods
                          .map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child: Text(method),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Image Attachment
                    _buildImageSection(),
                    const SizedBox(height: 24),

                    // Save Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveExpense,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Expense'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildScanCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: InkWell(
        onTap: _showScanOptions,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.document_scanner,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan Receipt with AI',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Automatically extract expense details',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Receipt Image (Optional)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (_selectedImageBytes != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _selectedImageBytes!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _selectedImageBytes = null;
                      _selectedImage = null;
                    });
                  },
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
            ],
          )
        else
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Add Receipt Photo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _placeController.dispose();
    super.dispose();
  }
}
