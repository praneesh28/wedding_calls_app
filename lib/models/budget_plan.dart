import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetPlan {
  final String id;
  final String category;
  final double limit;

  const BudgetPlan({
    required this.id,
    required this.category,
    required this.limit,
  });

  factory BudgetPlan.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawLimit = data['limit'];
    double parsedLimit = 0.0;
    if (rawLimit is num) {
      parsedLimit = rawLimit.toDouble();
    } else if (rawLimit is String) {
      parsedLimit = double.tryParse(rawLimit.replaceAll(',', '')) ?? 0.0;
    }
    return BudgetPlan(
      id: doc.id,
      category: (data['category'] as String?)?.trim().isNotEmpty == true
          ? (data['category'] as String).trim()
          : 'Unnamed',
      limit: parsedLimit,
    );
  }

  Map<String, dynamic> toMap() => {
        'category': category,
        'limit': limit,
      };
}

