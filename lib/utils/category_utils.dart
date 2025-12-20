import 'package:flutter/material.dart';

class CategoryUtils {
  static IconData getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
      case 'restaurant':
        return Icons.restaurant;
      case 'shopping':
      case 'groceries':
        return Icons.shopping_bag;
      case 'transport':
      case 'travel':
      case 'taxi':
      case 'petrol':
        return Icons.directions_car;
      case 'entertainment':
      case 'movies':
      case 'fun':
        return Icons.movie;
      case 'bills':
      case 'utilities':
      case 'rent':
        return Icons.receipt_long;
      case 'health':
      case 'medical':
      case 'pharmacy':
        return Icons.medical_services;
      case 'education':
      case 'books':
        return Icons.school;
      case 'salary':
      case 'income':
        return Icons.payments;
      case 'investment':
      case 'stocks':
        return Icons.trending_up;
      case 'other':
      default:
        return Icons.category;
    }
  }

  static Color getColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Colors.orange;
      case 'shopping':
        return Colors.pink;
      case 'transport':
        return Colors.blue;
      case 'entertainment':
        return Colors.purple;
      case 'bills':
        return Colors.red;
      case 'health':
        return Colors.green;
      case 'education':
        return Colors.teal;
      case 'salary':
        return Colors.lightGreen;
      case 'investment':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}
