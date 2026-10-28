import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CategoryUtils {
  static IconData iconFor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
      case 'restaurant':
        return Icons.ramen_dining_rounded;
      case 'groceries':
        return Icons.local_grocery_store_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'transport':
      case 'travel':
      case 'taxi':
      case 'petrol':
        return Icons.directions_transit_rounded;
      case 'entertainment':
      case 'movies':
      case 'fun':
        return Icons.local_activity_rounded;
      case 'bills':
      case 'utilities':
      case 'rent':
        return Icons.receipt_long_rounded;
      case 'health':
      case 'medical':
      case 'pharmacy':
        return Icons.medical_services_rounded;
      case 'education':
      case 'books':
        return Icons.school_rounded;
      case 'gifts':
      case 'family':
        return Icons.redeem_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  /// One enamel colour per category, used identically in tiers, rows and
  /// charts. Unknown categories get a stable colour from their name.
  static Color colorFor(BuildContext context, String category) {
    final e = context.enamel;
    switch (category.toLowerCase()) {
      case 'food':
        return e.tangerine;
      case 'groceries':
        return e.leaf;
      case 'transport':
        return e.cobalt;
      case 'shopping':
        return e.coral;
      case 'bills':
        return e.plum;
      case 'entertainment':
        return e.teal;
      case 'health':
        return e.rose;
      case 'education':
        return e.ochre;
      case 'other':
        return e.slate;
    }
    final cycle = e.categoryCycle;
    final hash = category.toLowerCase().codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
    return cycle[hash % cycle.length];
  }

  static IconData iconForMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.payments_rounded;
      case 'paynow':
        return Icons.qr_code_2_rounded;
      case 'credit card':
      case 'debit card':
        return Icons.credit_card_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }
}
