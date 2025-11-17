import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/budget_plan.dart';
import 'wedding_theme.dart';

class AdvancedBudgetPage extends StatefulWidget {
  const AdvancedBudgetPage({
    super.key,
    this.existingPlan,
    this.autoCreate = false,
  });

  final BudgetPlan? existingPlan;
  final bool autoCreate;

  @override
  State<AdvancedBudgetPage> createState() => _AdvancedBudgetPageState();
}

class _AdvancedBudgetPageState extends State<AdvancedBudgetPage> {
  final CollectionReference<Map<String, dynamic>> _budgetCol =
      FirebaseFirestore.instance.collection('budget_plans');
  final CollectionReference<Map<String, dynamic>> _txCol =
      FirebaseFirestore.instance.collection('transactions');
  final CollectionReference<Map<String, dynamic>> _categoriesCol =
      FirebaseFirestore.instance.collection('categories');

  bool _analysisLoading = false;
  DateTime? _analysisGeneratedAt;
  String? _narrative;
  List<_BudgetInsight> _insights = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.existingPlan != null) {
        _openBudgetForm(existing: widget.existingPlan);
      } else if (widget.autoCreate) {
        _openBudgetForm();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: weddingBg,
      appBar: AppBar(
        backgroundColor: weddingSurface,
        elevation: 1,
        centerTitle: true,
        title: const Text(
          'Advanced Budget Planner',
          style: TextStyle(
            color: weddingOnSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Analyze budgets',
            icon:
                const Icon(Icons.auto_awesome, color: weddingAccent, size: 20),
            onPressed: _analysisLoading
                ? null
                : () async {
                    final plans = await _loadCurrentPlans();
                    if (!mounted) return;
                    await _runAnalysis(plans);
                  },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: weddingAccent,
        foregroundColor: weddingOnSurface,
        icon: const Icon(Icons.add),
        label: const Text('New Budget'),
        onPressed: () => _openBudgetForm(),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _budgetCol.orderBy('category').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _CenteredMessage(
                icon: Icons.warning_amber_rounded,
                message: 'Could not load budgets: ${snapshot.error}',
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: weddingAccent),
              );
            }
            final plans = snapshot.data!.docs
                .map(BudgetPlan.fromDoc)
                .toList(growable: false);
            return _buildContent(context, plans);
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<BudgetPlan> plans) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final totalLimit = plans.fold<double>(0, (sum, p) => sum + p.limit);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        _HeroHeader(totalBudgets: plans.length, totalLimit: totalLimit),
        const SizedBox(height: 16),
        _analysisSection(plans, currency),
        const SizedBox(height: 20),
        if (plans.isEmpty)
          const _EmptyBudgetsState()
        else
          ...plans.map(
            (plan) => _BudgetPlanCard(
              plan: plan,
              currency: currency,
              onEdit: () => _openBudgetForm(existing: plan),
              onDelete: () => _deleteBudgetPlan(plan),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _analysisSection(List<BudgetPlan> plans, NumberFormat currency) {
    final generatedAt = _analysisGeneratedAt;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: weddingSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: weddingDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded,
                  color: weddingAccent, size: 20),
              const SizedBox(width: 10),
              const Text(
                'AI Budget Insights',
                style: TextStyle(
                  color: weddingOnSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (generatedAt != null)
                Text(
                  DateFormat('dd MMM, hh:mm a').format(generatedAt),
                  style: const TextStyle(
                    color: weddingOnSurfaceMuted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            plans.isEmpty
                ? 'Create a budget plan to unlock AI forecasting and risk alerts.'
                : 'Forecast future spend, spot risky categories, and get narrative guidance.',
            style: const TextStyle(
              color: weddingOnSurfaceMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: weddingAccent,
              foregroundColor: weddingOnSurface,
              minimumSize: const Size.fromHeight(42),
            ),
            icon: _analysisLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: weddingOnSurface,
                    ),
                  )
                : const Icon(Icons.manage_search_rounded, size: 18),
            label: Text(
              _analysisLoading
                  ? 'Analyzing...'
                  : plans.isEmpty
                      ? 'Add a budget to analyze'
                      : 'Analyze Budgets',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: _analysisLoading || plans.isEmpty
                ? null
                : () => _runAnalysis(plans),
          ),
          if (_narrative != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: weddingBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _narrative!,
                    style: const TextStyle(
                      color: weddingOnSurface,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  if (_insights.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(color: weddingDivider, height: 16),
                    ..._insights.map((insight) {
                      final riskColor =
                          insight.isAtRisk ? weddingAccent : weddingPos;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              insight.isAtRisk
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              size: 18,
                              color: riskColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    insight.plan.category,
                                    style: TextStyle(
                                      color: weddingOnSurface,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    insight.summaryDescription(currency),
                                    style: const TextStyle(
                                      color: weddingOnSurfaceMuted,
                                      fontSize: 11.5,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<List<BudgetPlan>> _loadCurrentPlans() async {
    final snapshot = await _budgetCol.orderBy('category').get();
    return snapshot.docs.map(BudgetPlan.fromDoc).toList(growable: false);
  }

  Future<void> _runAnalysis(List<BudgetPlan> plans) async {
    if (plans.isEmpty) return;
    setState(() {
      _analysisLoading = true;
    });
    try {
      final txSnap =
          await _txCol.orderBy('dateTs', descending: true).limit(400).get();
      final transactions = txSnap.docs
          .map(_BudgetTransaction.fromDoc)
          .where((tx) => tx.date != null)
          .toList();
      final insights = _buildInsights(plans, transactions);
      final narrative = _composeNarrative(insights);
      if (!mounted) return;
      setState(() {
        _insights = insights;
        _narrative = narrative;
        _analysisGeneratedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to analyze budgets: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _analysisLoading = false;
        });
      }
    }
  }

  List<_BudgetInsight> _buildInsights(
    List<BudgetPlan> plans,
    List<_BudgetTransaction> transactions,
  ) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final previousMonthStart = DateTime(
        now.year, now.month - 1, 1); // handles year change automatically
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sixtyDaysAgo = now.subtract(const Duration(days: 60));

    final byCategory = <String, _CategorySpend>{};

    for (final tx in transactions) {
      if (tx.category.isEmpty || tx.amount >= 0) continue;
      final catKey = tx.category.toLowerCase().trim();
      final spend = byCategory.putIfAbsent(catKey, () => _CategorySpend());
      final date = tx.date ?? now;

      if (date
          .isAfter(startOfMonth.subtract(const Duration(milliseconds: 1)))) {
        spend.currentMonth += tx.amount.abs();
      }
      if (date.isAfter(
              previousMonthStart.subtract(const Duration(milliseconds: 1))) &&
          date.isBefore(startOfMonth)) {
        spend.previousMonth += tx.amount.abs();
      }
      if (date.isAfter(thirtyDaysAgo)) {
        spend.lastThirtyDays += tx.amount.abs();
      } else if (date.isAfter(sixtyDaysAgo)) {
        spend.previousThirtyDays += tx.amount.abs();
      }
    }

    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final daysElapsed = now.day.clamp(1, daysInMonth);

    final insights = <_BudgetInsight>[];

    for (final plan in plans) {
      final catKey = plan.category.toLowerCase().trim();
      final spend = byCategory[catKey] ?? _CategorySpend();
      final spent = spend.currentMonth;
      final projected =
          daysElapsed == 0 ? spent : (spent / daysElapsed) * daysInMonth;
      final variance = plan.limit - projected;
      final isAtRisk = plan.limit > 0 && projected > plan.limit * 1.02;

      double recentAvg = 0;
      double previousAvg = 0;
      if (spend.lastThirtyDays > 0) {
        recentAvg = spend.lastThirtyDays / 30;
      }
      if (spend.previousThirtyDays > 0) {
        previousAvg = spend.previousThirtyDays / 30;
      }
      final hasSpike =
          previousAvg > 0 && recentAvg > previousAvg * 1.25 && recentAvg > 200;

      insights.add(
        _BudgetInsight(
          plan: plan,
          spent: spent,
          projected: projected,
          variance: variance,
          recentAverage: recentAvg,
          previousAverage: previousAvg,
          isAtRisk: isAtRisk,
          hasSpike: hasSpike,
        ),
      );
    }

    insights.sort((a, b) => (b.isAtRisk ? 1 : 0)
        .compareTo(a.isAtRisk ? 1 : 0)); // surface risks first
    return insights;
  }

  String _composeNarrative(List<_BudgetInsight> insights) {
    if (insights.isEmpty) {
      return 'No budgets found yet. Add a plan and run analysis to see AI insights.';
    }
    final risk = insights.where((i) => i.isAtRisk).toList();
    final spikes = insights.where((i) => i.hasSpike).toList();

    if (risk.isEmpty && spikes.isEmpty) {
      return 'All tracked categories are pacing comfortably within their limits this month. Keep monitoring regularly to stay ahead.';
    }

    final buffer = StringBuffer();
    if (risk.isNotEmpty) {
      buffer.write('Watch ');
      buffer.write(_humaniseCategories(risk.map((e) => e.plan.category)));
      buffer.write(
          ' — projected spend is set to cross the limit before month-end. Consider trimming discretionary expenses or increasing the budget ceiling.');
    }

    if (spikes.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(_humaniseCategories(spikes.map((e) => e.plan.category)));
      buffer.write(
          ' have seen a sharp jump versus last month. Double-check recent transactions to confirm they’re expected.');
    }

    return buffer.toString();
  }

  String _humaniseCategories(Iterable<String> categories) {
    final distinct = categories.toSet().toList();
    if (distinct.length == 1) return distinct.first;
    if (distinct.length == 2) return '${distinct[0]} and ${distinct[1]}';
    return '${distinct.take(distinct.length - 1).join(', ')} and ${distinct.last}';
  }

  Future<void> _openBudgetForm({BudgetPlan? existing}) async {
    final categorySnapshot = await _categoriesCol.orderBy('name').get();
    final categoryOptions = categorySnapshot.docs
        .map((e) => e['name']?.toString() ?? '')
        .where((name) => name.trim().isNotEmpty)
        .toList();

    final String customMarker = '__custom__';
    String? matchedExistingCategory;
    if (existing != null) {
      matchedExistingCategory = categoryOptions
          .firstWhere(
              (option) =>
                  option.toLowerCase() == existing.category.toLowerCase(),
              orElse: () => '')
          .trim();
      if (matchedExistingCategory.isEmpty) {
        matchedExistingCategory = null;
      }
    }

    final bool existingInOptions = matchedExistingCategory != null;

    bool useCustomCategory = categoryOptions.isEmpty || !existingInOptions;
    String? selectedCategory = existingInOptions
        ? matchedExistingCategory
        : (categoryOptions.isNotEmpty ? categoryOptions.first : null);

    final categoryCtrl = TextEditingController(
        text: useCustomCategory ? (existing?.category ?? '') : '');
    final limitCtrl = TextEditingController(
        text: existing != null && existing.limit > 0
            ? existing.limit.toStringAsFixed(0)
            : '');
    final formKey = GlobalKey<FormState>();

    Future<void> showError(String message) async {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: weddingSurface,
        title: Text(
          existing == null ? 'New Budget Plan' : 'Edit Budget Plan',
          style: const TextStyle(color: weddingOnSurface),
        ),
        content: StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (categoryOptions.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: useCustomCategory
                          ? customMarker
                          : (selectedCategory ?? categoryOptions.first),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(color: weddingOnSurfaceMuted),
                      ),
                      dropdownColor: weddingSurface,
                      items: [
                        ...categoryOptions.map(
                          (option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(option,
                                style:
                                    const TextStyle(color: weddingOnSurface)),
                          ),
                        ),
                        DropdownMenuItem<String>(
                          value: customMarker,
                          child: Text(
                            'Other (type manually)',
                            style: TextStyle(
                                color: weddingAccent.withOpacity(0.85)),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          if (value == customMarker) {
                            useCustomCategory = true;
                            selectedCategory = null;
                          } else {
                            useCustomCategory = false;
                            selectedCategory = value;
                            categoryCtrl.clear();
                          }
                        });
                      },
                      validator: (value) {
                        if (!useCustomCategory &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Select a category';
                        }
                        return null;
                      },
                    ),
                  if (useCustomCategory)
                    Padding(
                      padding: EdgeInsets.only(
                          top: categoryOptions.isEmpty ? 0 : 12),
                      child: TextFormField(
                        controller: categoryCtrl,
                        style: const TextStyle(color: weddingOnSurface),
                        decoration: InputDecoration(
                          labelText: categoryOptions.isEmpty
                              ? 'Category'
                              : 'Custom Category',
                          labelStyle:
                              const TextStyle(color: weddingOnSurfaceMuted),
                          focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: weddingAccent)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a category name';
                          }
                          return null;
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: limitCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: weddingOnSurface),
                    decoration: const InputDecoration(
                      labelText: 'Monthly Limit',
                      labelStyle: TextStyle(color: weddingOnSurfaceMuted),
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(color: weddingOnSurfaceMuted),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: weddingAccent)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a limit amount';
                      }
                      final parsed = double.tryParse(value.replaceAll(',', ''));
                      if (parsed == null || parsed <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: weddingAccent,
              foregroundColor: weddingOnSurface,
            ),
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              final category = useCustomCategory
                  ? categoryCtrl.text.trim()
                  : (selectedCategory ?? '');
              final limit =
                  double.tryParse(limitCtrl.text.replaceAll(',', '')) ?? 0.0;
              if (category.isEmpty) {
                await showError('Enter a category name');
                return;
              }
              try {
                if (existing == null) {
                  await _budgetCol.add({
                    'category': category,
                    'limit': limit,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  await _budgetCol.doc(existing.id).update({
                    'category': category,
                    'limit': limit,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(true);
              } catch (e) {
                await showError('Failed to save budget: $e');
              }
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );

    categoryCtrl.dispose();
    limitCtrl.dispose();

    if (result == true && mounted) {
      final message =
          existing == null ? 'Budget plan added' : 'Budget plan updated';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _deleteBudgetPlan(BudgetPlan plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: weddingSurface,
        title: const Text('Delete budget',
            style: TextStyle(color: weddingOnSurface)),
        content: Text(
          'Remove the "${plan.category}" budget?',
          style: const TextStyle(color: weddingOnSurfaceMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: weddingAccent,
              foregroundColor: weddingOnSurface,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _budgetCol.doc(plan.id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${plan.category} budget')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete budget: $e')),
      );
    }
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.totalBudgets,
    required this.totalLimit,
  });

  final int totalBudgets;
  final double totalLimit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF232731), Color(0xFF1C1F28)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: weddingDivider),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: weddingAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: weddingAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalBudgets budget${totalBudgets == 1 ? '' : 's'} tracked',
                  style: const TextStyle(
                    color: weddingOnSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monthly limit coverage ₹${NumberFormat('#,##0').format(totalLimit)}',
                  style: const TextStyle(
                    color: weddingOnSurfaceMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetPlanCard extends StatelessWidget {
  const _BudgetPlanCard({
    required this.plan,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  final BudgetPlan plan;
  final NumberFormat currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: weddingSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: weddingDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.category,
                      style: const TextStyle(
                        color: weddingOnSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Limit · ${currency.format(plan.limit)}',
                      style: const TextStyle(
                        color: weddingOnSurfaceMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 18, color: weddingOnSurfaceMuted),
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyBudgetsState extends StatelessWidget {
  const _EmptyBudgetsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: weddingSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: weddingDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'No budgets created yet',
            style: TextStyle(
              color: weddingOnSurface,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Set monthly limits for your key categories to track spending and unlock AI forecasting.',
            style: TextStyle(
              color: weddingOnSurfaceMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: weddingOnSurfaceMuted, size: 32),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: weddingOnSurfaceMuted, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetTransaction {
  final DateTime? date;
  final double amount;
  final String category;
  final String type;

  const _BudgetTransaction({
    required this.date,
    required this.amount,
    required this.category,
    required this.type,
  });

  factory _BudgetTransaction.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    DateTime? date;
    if (data['dateTs'] is Timestamp) {
      date = (data['dateTs'] as Timestamp).toDate();
    } else if (data['date'] is String) {
      final ds = (data['date'] as String).split('/');
      if (ds.length == 3) {
        try {
          date = DateTime(int.parse(ds[2]), int.parse(ds[1]), int.parse(ds[0]));
        } catch (_) {}
      }
    }
    final rawAmount = data['amount'];
    double amount = 0.0;
    if (rawAmount is num) {
      amount = rawAmount.toDouble();
    } else if (rawAmount is String) {
      amount = double.tryParse(rawAmount.replaceAll(',', '')) ?? 0.0;
    }
    return _BudgetTransaction(
      date: date,
      amount: amount,
      category: (data['category'] ?? '').toString(),
      type: (data['type'] ?? '').toString().toUpperCase(),
    );
  }
}

class _CategorySpend {
  double currentMonth = 0;
  double previousMonth = 0;
  double lastThirtyDays = 0;
  double previousThirtyDays = 0;
}

class _BudgetInsight {
  final BudgetPlan plan;
  final double spent;
  final double projected;
  final double variance;
  final double recentAverage;
  final double previousAverage;
  final bool isAtRisk;
  final bool hasSpike;

  const _BudgetInsight({
    required this.plan,
    required this.spent,
    required this.projected,
    required this.variance,
    required this.recentAverage,
    required this.previousAverage,
    required this.isAtRisk,
    required this.hasSpike,
  });

  String summaryDescription(NumberFormat currency) {
    final buffer = StringBuffer();
    buffer.write(
        'Spent ${currency.format(spent)} so far · Projected ${currency.format(projected)} (');
    buffer.write(variance >= 0
        ? '${currency.format(variance)} under'
        : '${currency.format(variance.abs())} over');
    buffer.write(' limit)');

    if (hasSpike) {
      buffer.write(
          ' · Recent daily spend ${recentAverage.toStringAsFixed(0)} vs ${previousAverage.toStringAsFixed(0)} last month');
    }
    return buffer.toString();
  }
}
