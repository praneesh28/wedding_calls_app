// lib/screens/expense_dashboard.dart
// Expense Dashboard: typed Transaction model, safe date parsing, Firestore ledger,
// period-aware totals, compact category list + right-shifted pie, and navigation.
//
// - List "Name" shows:  Cr → Dr  (from Firestore accountCr/accountDr)
// - Amount sign normalized from `type` (INCOME +, EXPENSE -)
// - Period selector drives totals AND pie
// - Bottom bar: Home | Reports | Transactions | Settings
// - Info card font sizes reduced

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'accounts_categories_page.dart';
import '../models/budget_plan.dart';
import 'advanced_budget_page.dart';
import 'report_page.dart';
import 'settings_page.dart';
import 'transaction_manager.dart';
import 'wedding_calls_page.dart';
import 'wedding_theme.dart';

/// Typed transaction mapped from Firestore
class Transaction {
  final String dateString;
  final DateTime? date;
  final double amount; // signed: INCOME +, EXPENSE -
  final String category;
  final String accountDr;
  final String accountCr;
  final String type; // 'INCOME' | 'EXPENSE'

  const Transaction({
    required this.dateString,
    required this.date,
    required this.amount,
    required this.category,
    required this.accountDr,
    required this.accountCr,
    required this.type,
  });

  factory Transaction.fromMap(Map<String, dynamic> m) {
    // Parse date string dd/MM/yyyy or fallback to dateTs
    final ds = (m['date'] as String?) ?? '';
    DateTime? parsed;
    if (ds.isNotEmpty) {
      try {
        final p = ds.split('/');
        if (p.length == 3) {
          parsed = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
        }
      } catch (_) {
        parsed = null;
      }
    }
    if (parsed == null && m['dateTs'] is Timestamp) {
      try {
        parsed = (m['dateTs'] as Timestamp).toDate();
      } catch (_) {
        parsed = null;
      }
    }

    // Raw amount (num or numeric string)
    double raw = 0.0;
    final amtRaw = m['amount'];
    if (amtRaw is num) {
      raw = amtRaw.toDouble();
    } else if (amtRaw is String) {
      raw = double.tryParse(amtRaw.replaceAll(',', '')) ?? 0.0;
    }

    final type = (m['type'] as String?)?.toUpperCase() ?? 'EXPENSE';
    double signed = raw;
    if (type == 'INCOME') {
      if (signed < 0) signed = signed.abs();
    } else {
      // treat unknown as EXPENSE
      if (signed > 0) signed = -signed;
    }

    final accountDr = (m['accountDr'] as String?) ?? '';
    final accountCr = (m['accountCr'] as String?) ?? '';
    final category = (m['category'] as String?) ?? 'Uncategorized';

    final dateStringFallback = ds.isNotEmpty
        ? ds
        : (parsed != null ? DateFormat('dd/MM/yyyy').format(parsed) : '');

    return Transaction(
      dateString: dateStringFallback,
      date: parsed,
      amount: signed,
      category: category,
      accountDr: accountDr,
      accountCr: accountCr,
      type: type,
    );
  }

  factory Transaction.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
      Transaction.fromMap(d.data());
}

class ExpenseDashboardPage extends StatefulWidget {
  const ExpenseDashboardPage({super.key});
  @override
  State<ExpenseDashboardPage> createState() => _ExpenseDashboardPageState();
}

class _ExpenseDashboardPageState extends State<ExpenseDashboardPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final CollectionReference<Map<String, dynamic>> _txCol =
      FirebaseFirestore.instance.collection('transactions');
  final CollectionReference<Map<String, dynamic>> _budgetCol =
      FirebaseFirestore.instance.collection('budget_plans');

  late final AnimationController _iconController;
  bool _drawerOpen = false;

  int _touchedIndexIncome = -1;
  int _touchedIndexExpense = -1;

  static const double _appBarHeight = 56.0;
  static const double _bottomNavHeight = 56.0;
  static const double _pagePadding = 12.0;

  int _selectedIndex = 0;
  int _selectedPeriod = 0; // 0=this month,1=last month,2=this year,3=last year

  final NumberFormat _inr0 =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  void _toggleDrawer() {
    if (!_drawerOpen) {
      _scaffoldKey.currentState?.openDrawer();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _handleDrawerChanged(bool isOpened) {
    if (isOpened && !_drawerOpen) {
      _iconController.forward();
      setState(() => _drawerOpen = true);
    } else if (!isOpened && _drawerOpen) {
      _iconController.reverse();
      setState(() => _drawerOpen = false);
    }
  }

  Future<void> _deleteBudgetPlan(BudgetPlan plan) async {
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

  // ---------- helpers ----------
  List<Transaction> _transactionsFromDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    try {
      return docs.map((d) => Transaction.fromDoc(d)).toList();
    } catch (_) {
      return <Transaction>[];
    }
  }

  List<Transaction> _lastNTransactionsFrom(List<Transaction> all, int n) {
    final copy = List<Transaction>.from(all);
    copy.sort((a, b) {
      final da = a.date;
      final db = b.date;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return copy.take(n).toList();
  }

  List<Transaction> _filterBySelectedPeriod(List<Transaction> all) {
    final now = DateTime.now();
    bool inMonth(Transaction r, DateTime base) =>
        r.date != null &&
        r.date!.month == base.month &&
        r.date!.year == base.year;
    bool inYear(Transaction r, int year) =>
        r.date != null && r.date!.year == year;

    switch (_selectedPeriod) {
      case 0: // this month
        return all.where((r) => inMonth(r, now)).toList();
      case 1: // last month
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        return all.where((r) => inMonth(r, lastMonth)).toList();
      case 2: // this year
        return all.where((r) => inYear(r, now.year)).toList();
      case 3: // last year
        return all.where((r) => inYear(r, now.year - 1)).toList();
      default:
        return all;
    }
  }

  double _sumForMonthFrom(List<Transaction> all, DateTime target,
      {required bool incomeOnly}) {
    var s = 0.0;
    for (final r in all) {
      final dt = r.date;
      if (dt == null) continue;
      if (dt.month == target.month && dt.year == target.year) {
        final amt = r.amount;
        if (incomeOnly && amt > 0) s += amt;
        if (!incomeOnly && amt < 0) s += amt;
      }
    }
    return s;
  }

  double _sumForYearFrom(List<Transaction> all, int year,
      {required bool incomeOnly}) {
    var s = 0.0;
    for (final r in all) {
      final dt = r.date;
      if (dt == null) continue;
      if (dt.year == year) {
        final amt = r.amount;
        if (incomeOnly && amt > 0) s += amt;
        if (!incomeOnly && amt < 0) s += amt;
      }
    }
    return s;
  }

  String _fmt(num v) => _inr0.format(v);

  // ---------- UI ----------

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long, size: 48, color: weddingOnSurfaceMuted),
          const SizedBox(height: 12),
          const Text(
            'No transactions yet',
            style: TextStyle(
              color: weddingOnSurface,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start by recording your first expense or income.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: weddingOnSurfaceMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: weddingAccent,
              foregroundColor: weddingSurface,
            ),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TransactionManager()));
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Transaction'),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingMenu(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final showLabel = constraints.maxWidth > 80;
      return Padding(
        padding: const EdgeInsets.only(left: 12.0),
        child: Semantics(
          button: true,
          label: 'Open navigation menu',
          child: Tooltip(
            message: _drawerOpen ? 'Close menu' : 'Open menu',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _toggleDrawer,
                child: Ink(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: AnimatedIcon(
                          icon: AnimatedIcons.menu_close,
                          progress: _iconController,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    if (showLabel) const SizedBox(width: 8),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: weddingBg,
      onDrawerChanged: _handleDrawerChanged,
      drawer: Drawer(
        backgroundColor: weddingSurface,
        child: SafeArea(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DrawerHeader(
              decoration: BoxDecoration(color: weddingAccent.withOpacity(0.06)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: weddingAccent,
                      child: Text('WP',
                          style: TextStyle(
                              color: weddingSurface,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Wedding Planner',
                              style: TextStyle(
                                  color: weddingOnSurface,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('Plan your big day',
                              style: TextStyle(
                                  color: weddingOnSurfaceMuted, fontSize: 12)),
                        ])
                  ],
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.phone, color: weddingAccent),
              title: const Text('Wedding Calls',
                  style: TextStyle(color: weddingOnSurface)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const WeddingCallsPage()));
              },
            ),
            const Divider(color: weddingOnSurfaceMuted, height: 1),
            ListTile(
              leading: Icon(Icons.dashboard, color: weddingAccent),
              title: const Text('Expense Dashboard',
                  style: TextStyle(color: weddingOnSurface)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.receipt_long, color: weddingAccent),
              title: const Text('Accounts & Categories',
                  style: TextStyle(color: weddingOnSurface)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AccountsCategoriesPage()));
              },
            ),
            ListTile(
              leading: Icon(Icons.pie_chart, color: weddingAccent),
              title: const Text('Report',
                  style: TextStyle(color: weddingOnSurface)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ReportPages()));
              },
            ),
            ListTile(
              leading: Icon(Icons.settings, color: weddingAccent),
              title: const Text('Settings',
                  style: TextStyle(color: weddingOnSurface)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text('© 2025 Wedding Planner',
                  style: TextStyle(color: weddingOnSurfaceMuted)),
            )
          ]),
        ),
      ),
      appBar: AppBar(
        toolbarHeight: _appBarHeight,
        backgroundColor: weddingSurface,
        elevation: 2,
        centerTitle: true,
        title: const Text('Expense Dashboard',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        leadingWidth: 120,
        leading: _buildLeadingMenu(context),
        actions: [
          PopupMenuButton<int>(
            color: weddingSurface,
            icon: const Icon(Icons.more_vert,
                size: 20, color: weddingOnSurfaceMuted),
            onSelected: (v) => setState(() {
              _touchedIndexIncome = -1;
              _touchedIndexExpense = -1;
              _selectedPeriod = v;
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('This Month')),
              PopupMenuItem(value: 1, child: Text('Last Month')),
              PopupMenuItem(value: 2, child: Text('This Year')),
              PopupMenuItem(value: 3, child: Text('Last Year')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SizedBox(
        height: _bottomNavHeight,
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          backgroundColor: weddingSurface,
          selectedItemColor: weddingAccent,
          unselectedItemColor: weddingOnSurfaceMuted,
          iconSize: 20,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          type: BottomNavigationBarType.fixed,
          onTap: (i) {
            if (i == 1) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReportPages()));
              return;
            }
            if (i == 2) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TransactionManager()));
              return;
            }
            if (i == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
              return;
            }
            setState(() => _selectedIndex = i);
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.pie_chart), label: 'Reports'),
            BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long), label: 'Transactions'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          // Using createdAt for recency; you can switch to dateTs if preferred.
          stream: _txCol.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: weddingAccent),
              );
            }

            final docs = snap.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final all = _transactionsFromDocs(docs);
            final periodLedger = _filterBySelectedPeriod(all);

            // Totals by selected period (using signed amounts)
            final now = DateTime.now();
            final thisMonthIncome =
                _sumForMonthFrom(all, now, incomeOnly: true);
            final thisMonthExpense =
                _sumForMonthFrom(all, now, incomeOnly: false);
            final lastMonth = DateTime(now.year, now.month - 1, 1);
            final lastMonthIncome =
                _sumForMonthFrom(all, lastMonth, incomeOnly: true);
            final lastMonthExpense =
                _sumForMonthFrom(all, lastMonth, incomeOnly: false);
            final thisYearIncome =
                _sumForYearFrom(all, now.year, incomeOnly: true);
            final thisYearExpense =
                _sumForYearFrom(all, now.year, incomeOnly: false);
            final lastYearIncome =
                _sumForYearFrom(all, now.year - 1, incomeOnly: true);
            final lastYearExpense =
                _sumForYearFrom(all, now.year - 1, incomeOnly: false);

            double selIncome = 0.0, selExpense = 0.0;
            switch (_selectedPeriod) {
              case 0:
                selIncome = thisMonthIncome;
                selExpense = thisMonthExpense;
                break;
              case 1:
                selIncome = lastMonthIncome;
                selExpense = lastMonthExpense;
                break;
              case 2:
                selIncome = thisYearIncome;
                selExpense = thisYearExpense;
                break;
              case 3:
                selIncome = lastYearIncome;
                selExpense = lastYearExpense;
                break;
            }
            final selBalance = selIncome + selExpense; // expense negative

            final last5 = _lastNTransactionsFrom(periodLedger, 5);

            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(_pagePadding),
                child: _buildEmptyState(context),
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _budgetCol.orderBy('category').snapshots(),
              builder: (context, budgetSnap) {
                final budgetDocs = budgetSnap.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final plans = budgetDocs.map(BudgetPlan.fromDoc).toList();
                final isLoadingBudgets =
                    budgetSnap.connectionState == ConnectionState.waiting &&
                        !budgetSnap.hasData;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                      _pagePadding, 6, _pagePadding, _pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InsightSummaryRow(
                        expense: selExpense,
                        income: selIncome,
                        balance: selBalance,
                        onPeriodSelected: (v) {
                          setState(() {
                            _touchedIndexIncome = -1;
                            _touchedIndexExpense = -1;
                            _selectedPeriod = v;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _RecentTransactionsCard(
                        items: last5,
                        currencyFormatter: _fmt,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 140,
                        child: Row(children: [
                          Expanded(
                            child: _PieBreakdownCard(
                              title: 'Income Mix',
                              ledger: periodLedger,
                              isIncome: true,
                              touchedIndex: _touchedIndexIncome,
                              onSectionTap: (idx) =>
                                  setState(() => _touchedIndexIncome = idx),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _PieBreakdownCard(
                              title: 'Expense Mix',
                              ledger: periodLedger,
                              isIncome: false,
                              touchedIndex: _touchedIndexExpense,
                              onSectionTap: (idx) =>
                                  setState(() => _touchedIndexExpense = idx),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      _BudgetPlanSection(
                        plans: plans,
                        ledger: periodLedger,
                        currencyFormatter: _fmt,
                        isLoading: isLoadingBudgets,
                        onAdd: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const AdvancedBudgetPage(autoCreate: true)),
                          );
                        },
                        onEdit: (plan) => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AdvancedBudgetPage(existingPlan: plan),
                          ),
                        ),
                        onDelete: _deleteBudgetPlan,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ---------------- Widgets ----------------

class _PieBreakdownCard extends StatelessWidget {
  final String title;
  final bool isIncome;
  final Function(int) onSectionTap;
  final int touchedIndex;
  final List<Transaction> ledger;

  const _PieBreakdownCard({
    required this.title,
    required this.isIncome,
    required this.onSectionTap,
    required this.touchedIndex,
    required this.ledger,
  });

  Map<String, double> _groupLedgerByCategory() {
    final Map<String, double> grouped = {};
    for (final r in ledger) {
      final amt = r.amount;
      final cat = r.category;
      final qualifies = isIncome ? amt > 0 : amt < 0;
      if (!qualifies) continue;
      grouped[cat] = (grouped[cat] ?? 0) + amt.abs();
    }
    if (grouped.isEmpty) grouped['None'] = 1.0;
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupLedgerByCategory();
    final entries = grouped.entries.toList();
    final total = grouped.values.fold<double>(0, (a, b) => a + b);

    final colors = [
      weddingPos,
      const Color(0xFF36CFC9),
      const Color(0xFF9777FF),
      const Color(0xFFFFA940),
      const Color(0xFFFF7875),
      const Color(0xFF40A9FF),
      const Color(0xFF73D13D),
    ];

    final List<PieChartSectionData> sections = [];
    for (var i = 0; i < entries.length; i++) {
      final val = entries[i].value;
      final isTouched = i == touchedIndex;
      final color = colors[i % colors.length];
      final percent = total > 0 ? (val / total * 100).round() : 0;

      sections.add(PieChartSectionData(
        color: color,
        value: val,
        title: '${percent}%',
        radius: isTouched ? 33 : 24,
        titleStyle: TextStyle(
          fontSize: isTouched ? 11 : 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        borderSide: BorderSide(
          color: Colors.black.withOpacity(0.2),
          width: isTouched ? 2 : 1,
        ),
      ));
    }

    final bool hasTouch = touchedIndex >= 0 && touchedIndex < entries.length;
    final String centerLabel = hasTouch
        ? entries[touchedIndex].key
        : (isIncome ? 'Total Income' : 'Total Expense');
    final double centerValue = hasTouch ? entries[touchedIndex].value : total;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1F2B), Color(0xFF151822)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: weddingOnSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _compactCurrency(centerValue),
                    style: const TextStyle(
                      color: weddingOnSurfaceMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sections: sections,
                            centerSpaceRadius: 14,
                            sectionsSpace: 1,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                if (response?.touchedSection == null) {
                                  onSectionTap(-1);
                                } else {
                                  onSectionTap(response!
                                      .touchedSection!.touchedSectionIndex);
                                }
                              },
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                centerLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _compactCurrency(centerValue),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 6,
                    child: _LegendList(
                      entries: entries,
                      colors: colors,
                      total: total,
                      touchedIndex: touchedIndex,
                      onTap: onSectionTap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compactCurrency(double value) {
    if (value >= 10000000 || value <= -10000000) {
      return '${(value / 10000000).toStringAsFixed(1)} Cr';
    }
    if (value >= 100000 || value <= -100000) {
      return '${(value / 100000).toStringAsFixed(1)} L';
    }
    if (value >= 1000 || value <= -1000) {
      return '${(value / 1000).toStringAsFixed(1)} K';
    }
    return value.toInt().toString();
  }
}

class _BudgetPlanSection extends StatelessWidget {
  final List<BudgetPlan> plans;
  final List<Transaction> ledger;
  final String Function(num) currencyFormatter;
  final bool isLoading;
  final VoidCallback onAdd;
  final ValueChanged<BudgetPlan> onEdit;
  final ValueChanged<BudgetPlan> onDelete;

  const _BudgetPlanSection({
    required this.plans,
    required this.ledger,
    required this.currencyFormatter,
    required this.isLoading,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  Map<String, double> _expenseByCategory() {
    final Map<String, double> totals = {};
    for (final tx in ledger) {
      if (tx.amount >= 0) continue;
      final key = tx.category.toLowerCase().trim();
      final positive = tx.amount.abs();
      totals[key] = (totals[key] ?? 0) + positive;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final expenseTotals = _expenseByCategory();

    return Container(
      decoration: BoxDecoration(
        color: weddingSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: weddingDivider),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Budget Planner',
                style: TextStyle(
                    color: weddingOnSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16, color: weddingAccent),
                label: const Text(
                  'Add Plan',
                  style: TextStyle(color: weddingAccent, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  foregroundColor: weddingAccent,
                  backgroundColor: weddingAccent.withOpacity(0.08),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const SizedBox(
              height: 64,
              child: Center(
                child: CircularProgressIndicator(
                    color: weddingAccent, strokeWidth: 2),
              ),
            )
          else if (plans.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: weddingBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'No budget plans yet',
                    style: TextStyle(
                        color: weddingOnSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Create limits for categories to track spending against your goals.',
                    style:
                        TextStyle(color: weddingOnSurfaceMuted, fontSize: 11),
                  ),
                ],
              ),
            )
          else
            Column(
              children: plans
                  .map((plan) {
                    final key = plan.category.toLowerCase().trim();
                    final spent = expenseTotals[key] ?? 0.0;
                    final remaining = (plan.limit - spent)
                        .clamp(-double.infinity, double.infinity);
                    final progress = plan.limit > 0
                        ? (spent / plan.limit).clamp(0.0, 2.0)
                        : 0.0;
                    final overLimit = spent > plan.limit && plan.limit > 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: weddingBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: overLimit ? weddingAccent : weddingDivider,
                        ),
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
                                          fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Limit · ${currencyFormatter(plan.limit)}',
                                      style: const TextStyle(
                                          color: weddingOnSurfaceMuted,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    size: 16, color: weddingOnSurfaceMuted),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    onEdit(plan);
                                  } else if (value == 'delete') {
                                    onDelete(plan);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: plan.limit <= 0
                                        ? 0
                                        : progress.clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor:
                                        weddingDivider.withOpacity(0.6),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      overLimit ? weddingAccent : weddingPos,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(progress * 100).clamp(0, 999).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: overLimit
                                      ? weddingAccent
                                      : weddingOnSurfaceMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Spent · ${currencyFormatter(spent)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: weddingOnSurface,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  remaining >= 0
                                      ? 'Remaining · ${currencyFormatter(remaining)}'
                                      : 'Over by · ${currencyFormatter(remaining.abs())}',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: remaining >= 0
                                        ? weddingOnSurfaceMuted
                                        : weddingAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  })
                  .toList()
                  .cast<Widget>(),
            ),
        ],
      ),
    );
  }
}

class _LegendList extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final List<Color> colors;
  final double total;
  final int touchedIndex;
  final ValueChanged<int> onTap;

  const _LegendList({
    required this.entries,
    required this.colors,
    required this.total,
    required this.touchedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: entries.length,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final color = colors[index % colors.length];
        final percent = total > 0 ? (entry.value / total * 100) : 0;
        final isActive = index == touchedIndex;

        return GestureDetector(
          onTap: () => onTap(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? color.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive ? color.withOpacity(0.7) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 12,
                  width: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: weddingOnSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.value.toInt()} · ${percent.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: weddingOnSurfaceMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 16, color: weddingOnSurfaceMuted.withOpacity(0.7)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InsightSummaryRow extends StatelessWidget {
  final double expense;
  final double income;
  final double balance;
  final ValueChanged<int> onPeriodSelected;

  const _InsightSummaryRow({
    required this.expense,
    required this.income,
    required this.balance,
    required this.onPeriodSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: weddingSurface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, .5))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _metric(
              label: 'Total Expenses',
              value: _balanceCurrency(expense),
              subtitle: 'Spent this period',
              color: Colors.redAccent,
              icon: Icons.trending_down,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _metric(
              label: 'Total Income',
              value: _balanceCurrency(income),
              subtitle: 'Earned this period',
              color: weddingPos,
              icon: Icons.trending_up,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    weddingAccent.withOpacity(0.16),
                    weddingAccent.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: weddingAccent.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet_outlined,
                            size: 15, color: weddingAccent),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Current Balance',
                        style: TextStyle(
                          color: weddingAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _balanceCurrency(balance),
                    style: TextStyle(
                      color: balance >= 0 ? weddingPos : Colors.redAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _balanceCurrency(double v) {
    final NumberFormat fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return fmt.format(v.abs()).replaceAll('₹', '₹ ');
  }

  Widget _metric({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.18),
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: weddingOnSurfaceMuted,
                fontSize: 9,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  final List<Transaction> items;
  final String Function(num) currencyFormatter;

  const _RecentTransactionsCard({
    required this.items,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: weddingSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    color: weddingOnSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const TransactionManager()));
                  },
                  icon: const Icon(Icons.open_in_new,
                      size: 16, color: weddingAccent),
                  label: const Text(
                    'View All',
                    style: TextStyle(
                      color: weddingAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No transactions match this period yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: weddingOnSurfaceMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              ListView.separated(
                itemCount: items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: weddingOnSurfaceMuted.withOpacity(0.3),
                ),
                itemBuilder: (context, index) {
                  final tx = items[index];
                  final isIncome = tx.amount > 0;
                  final amountText =
                      '${isIncome ? '+' : '-'}${currencyFormatter(tx.amount.abs())}';
                  final name = '${tx.accountCr} → ${tx.accountDr}';

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isIncome ? weddingPos : Colors.redAccent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: weddingOnSurface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    tx.dateString,
                                    style: const TextStyle(
                                      color: weddingOnSurfaceMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('•',
                                      style: TextStyle(
                                          color: weddingOnSurfaceMuted,
                                          fontSize: 9)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      tx.category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: weddingOnSurfaceMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          amountText,
                          style: TextStyle(
                            color: isIncome ? weddingPos : Colors.redAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
