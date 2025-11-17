import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'transaction_manager.dart';
import 'wedding_theme.dart';

class ReportPages extends StatefulWidget {
  const ReportPages({Key? key}) : super(key: key);

  @override
  State<ReportPages> createState() => _ReportPagesState();
}

class _ReportPagesState extends State<ReportPages> {
  final _col = FirebaseFirestore.instance.collection('transactions');

  String? _accountCr;
  String? _accountDr;
  String? _category;
  String _type = 'ALL';
  int _period = -1;
  String _sort = 'date_desc';
  final TextEditingController _searchCtrl = TextEditingController();

  final DateFormat _df = DateFormat('dd/MM/yyyy');
  final NumberFormat _currencyFormat = NumberFormat('#,##0');

  bool _inSelectedPeriod(DateTime dt) {
    final now = DateTime.now();
    switch (_period) {
      case -1:
        return true;
      case 0:
        return dt.year == now.year && dt.month == now.month;
      case 1:
        final lm = DateTime(now.year, now.month - 1, 1);
        return dt.year == lm.year && dt.month == lm.month;
      case 2:
        return dt.year == now.year;
      case 3:
        return dt.year == now.year - 1;
      default:
        return true;
    }
  }

  List<Map<String, dynamic>> _mapDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs.map((d) {
      final m = d.data();

      DateTime? dt;
      final dynamic dateField = m['dateTs'];
      if (dateField is Timestamp) {
        dt = dateField.toDate();
      } else if (m['date'] is String) {
        final s = (m['date'] as String).trim();
        try {
          final parts = s.split('/');
          if (parts.length == 3) {
            dt = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } catch (_) {
          dt = null;
        }
        dt ??= DateTime.tryParse(s);
      }
      dt ??= DateTime.fromMillisecondsSinceEpoch(0);

      final cr = (m['accountCr'] as String?) ?? '';
      final dr = (m['accountDr'] as String?) ?? '';
      final category = (m['category'] as String?) ?? '';
      final type = ((m['type'] as String?) ?? 'EXPENSE').toUpperCase();
      final narration = (m['narration'] as String?) ?? '';

      double amount = 0.0;
      final rawAmt = m['amount'];
      if (rawAmt is num) {
        amount = rawAmt.toDouble();
      } else if (rawAmt is String) {
        amount = double.tryParse(rawAmt.replaceAll(',', '')) ?? 0.0;
      }

      double? balance;
      final rawBal = m['balance'];
      if (rawBal is num) {
        balance = rawBal.toDouble();
      } else if (rawBal is String) {
        balance = double.tryParse(rawBal.replaceAll(',', ''));
      }

      return {
        'id': d.id,
        'date': dt,
        'dateS': _df.format(dt),
        'accountCr': cr,
        'accountDr': dr,
        'name': [cr, dr].where((e) => e.isNotEmpty).join(' → '),
        'category': category,
        'type': type,
        'amount': amount,
        'balance': balance,
        'narration': narration,
        'createdAt': m['createdAt'],
      };
    }).toList();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> rows) {
    final q = _searchCtrl.text.trim().toLowerCase();

    final filtered = rows.where((r) {
      final dt = r['date'] as DateTime;
      if (!_inSelectedPeriod(dt)) return false;

      if (_type != 'ALL' && r['type'] != _type) return false;

      if (_accountCr != null && _accountCr!.isNotEmpty) {
        if ((r['accountCr'] as String) != _accountCr) return false;
      }
      if (_accountDr != null && _accountDr!.isNotEmpty) {
        if ((r['accountDr'] as String) != _accountDr) return false;
      }
      if (_category != null && _category!.isNotEmpty) {
        if ((r['category'] as String) != _category) return false;
      }

      if (q.isNotEmpty) {
        final hay = [
          r['name'] as String,
          r['category'] as String,
          r['accountCr'] as String,
          r['accountDr'] as String,
          r['narration'] as String,
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case 'date_asc':
          return (a['date'] as DateTime).compareTo(b['date'] as DateTime);
        case 'amount_desc':
          return (b['amount'] as double).compareTo(a['amount'] as double);
        case 'amount_asc':
          return (a['amount'] as double).compareTo(b['amount'] as double);
        case 'date_desc':
        default:
          return (b['date'] as DateTime).compareTo(a['date'] as DateTime);
      }
    });

    return filtered;
  }

  List<Map<String, dynamic>> _withComputedBalance(
      List<Map<String, dynamic>> rows) {
    double running = 0.0;
    final asc = List<Map<String, dynamic>>.from(rows);
    asc.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    for (final r in asc) {
      if (r['balance'] == null) {
        if (r['type'] == 'INCOME') {
          running += (r['amount'] as double).abs();
        } else {
          running -= (r['amount'] as double).abs();
        }
        r['balance'] = running;
      } else {
        final existing = r['balance'];
        running = existing is num ? existing.toDouble() : running;
      }
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F121A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A24),
        elevation: 0,
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Expense Report',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Track credits, debits and running balances',
              style: TextStyle(
                color: Color(0xFF9AA2B2),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Transaction Manager',
            icon:
                const Icon(Icons.receipt_long, size: 20, color: weddingAccent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TransactionManager()),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF121621),
              Color(0xFF0B0E15),
            ],
          ),
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _col.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: weddingAccent),
              );
            }

            final docs = snap.data!.docs;
            final mapped = _mapDocs(docs);
            final filtered = _applyFilters(mapped);
            final rows = _withComputedBalance(filtered);
            final rowCount = rows.length;

            final accountSet = {
              ...mapped.map((e) => e['accountCr'] as String),
              ...mapped.map((e) => e['accountDr'] as String),
            }..removeWhere((e) => e.isEmpty);
            final accountList = accountSet.toList()..sort();

            final categorySet = mapped
                .map((e) => e['category'] as String)
                .where((e) => e.isNotEmpty)
                .toSet();
            final categoryList = categorySet.toList()..sort();

            final totalIncome = rows
                .where((r) => r['type'] == 'INCOME')
                .fold<double>(
                    0, (sum, r) => sum + (r['amount'] as double).abs());
            final totalExpense = rows
                .where((r) => r['type'] == 'EXPENSE')
                .fold<double>(
                    0, (sum, r) => sum + (r['amount'] as double).abs());
            final lastBalanceRaw = rows.isEmpty ? null : rows.first['balance'];
            final lastBalance =
                lastBalanceRaw is num ? lastBalanceRaw.toDouble() : 0.0;
            final net = totalIncome - totalExpense;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  child: _FilterToolbar(
                    accountList: accountList,
                    categoryList: categoryList,
                    accountCr: _accountCr,
                    accountDr: _accountDr,
                    category: _category,
                    type: _type,
                    period: _period,
                    sort: _sort,
                    searchCtrl: _searchCtrl,
                    resultCount: rowCount,
                    onCr: (v) => setState(
                        () => _accountCr = (v ?? '').isEmpty ? null : v),
                    onDr: (v) => setState(
                        () => _accountDr = (v ?? '').isEmpty ? null : v),
                    onCategory: (v) => setState(
                        () => _category = (v ?? '').isEmpty ? null : v),
                    onType: (v) => setState(() => _type = (v ?? 'ALL')),
                    onPeriod: (v) => setState(() => _period = v ?? -1),
                    onSort: (v) => setState(() => _sort = (v ?? 'date_desc')),
                    onSearchChanged: (_) => setState(() {}),
                    onClear: () {
                      setState(() {
                        _accountCr = null;
                        _accountDr = null;
                        _category = null;
                        _type = 'ALL';
                        _period = -1;
                        _sort = 'date_desc';
                        _searchCtrl.clear();
                      });
                    },
                  ),
                ),
                if (rows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: _LedgerSummaryStrip(
                      income: totalIncome,
                      expense: totalExpense,
                      net: net,
                      balance: lastBalance,
                      currency: _currencyFormat,
                      recordCount: rowCount,
                    ),
                  ),
                Expanded(
                  child: rows.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                          itemCount: rows.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            if (index == rows.length) {
                              return _TotalsBar(
                                income: totalIncome,
                                expense: totalExpense,
                                balance: lastBalance,
                              );
                            }
                            final r = rows[index];
                            return _TransactionTile(
                              data: r,
                              currencyFormat: _currencyFormat,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

class _FilterToolbar extends StatelessWidget {
  final List<String> accountList;
  final List<String> categoryList;
  final String? accountCr;
  final String? accountDr;
  final String? category;
  final String type;
  final int period;
  final String sort;
  final TextEditingController searchCtrl;
  final void Function(String?) onCr;
  final void Function(String?) onDr;
  final void Function(String?) onCategory;
  final void Function(String?) onType;
  final void Function(int?) onPeriod;
  final void Function(String?) onSort;
  final void Function(String) onSearchChanged;
  final VoidCallback onClear;
  final int resultCount;

  const _FilterToolbar({
    Key? key,
    required this.accountList,
    required this.categoryList,
    required this.accountCr,
    required this.accountDr,
    required this.category,
    required this.type,
    required this.period,
    required this.sort,
    required this.searchCtrl,
    required this.onCr,
    required this.onDr,
    required this.onCategory,
    required this.onType,
    required this.onPeriod,
    required this.onSort,
    required this.onSearchChanged,
    required this.onClear,
    required this.resultCount,
  }) : super(key: key);

  DropdownMenuItem<T> _item<T>(T v, String label) =>
      DropdownMenuItem<T>(value: v, child: Text(label));

  @override
  Widget build(BuildContext context) {
    const pillColor = Color(0xFF151926);
    const infoText = TextStyle(
      color: Color(0xFFBFC6DA),
      fontSize: 8.5,
      fontWeight: FontWeight.w600,
    );

    Widget filterAt(int index) {
      switch (index) {
        case 0:
          return _DropdownPill<String>(
            label: 'Accounts',
            icon: Icons.account_balance_wallet_outlined,
            value: (accountCr == null || accountCr!.isEmpty) ? null : accountCr,
            items: [
              _item<String>('', 'All accounts'),
              ...accountList.map((a) => _item<String>(a, a)),
            ],
            onChanged: onCr,
            highlighted: true,
          );
        case 1:
          return _DropdownPill<String>(
            label: 'Dr',
            icon: Icons.trending_down,
            value: (accountDr == null || accountDr!.isEmpty) ? null : accountDr,
            items: [
              _item<String>('', 'All Dr'),
              ...accountList.map((a) => _item<String>(a, a)),
            ],
            onChanged: onDr,
          );
        case 2:
          return _DropdownPill<String>(
            label: 'Category',
            icon: Icons.category_outlined,
            value: (category == null || category!.isEmpty) ? null : category,
            items: [
              _item<String>('', 'All Categories'),
              ...categoryList.map((c) => _item<String>(c, c)),
            ],
            onChanged: onCategory,
          );
        case 3:
          return _DropdownPill<int>(
            label: 'Period',
            icon: Icons.calendar_month_outlined,
            value: period,
            items: const [
              DropdownMenuItem(value: -1, child: Text('All time')),
              DropdownMenuItem(value: 0, child: Text('This Month')),
              DropdownMenuItem(value: 1, child: Text('Last Month')),
              DropdownMenuItem(value: 2, child: Text('This Year')),
              DropdownMenuItem(value: 3, child: Text('Last Year')),
            ],
            onChanged: onPeriod,
          );
        case 4:
          return _DropdownPill<String>(
            label: 'Type',
            icon: Icons.swap_vert_circle_outlined,
            value: type,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All')),
              DropdownMenuItem(value: 'INCOME', child: Text('Income')),
              DropdownMenuItem(value: 'EXPENSE', child: Text('Expense')),
            ],
            onChanged: onType,
          );
        default:
          return _DropdownPill<String>(
            label: 'Sort',
            icon: Icons.sort,
            value: sort,
            items: const [
              DropdownMenuItem(value: 'date_desc', child: Text('Date ↓')),
              DropdownMenuItem(value: 'date_asc', child: Text('Date ↑')),
              DropdownMenuItem(value: 'amount_desc', child: Text('Amount ↓')),
              DropdownMenuItem(value: 'amount_asc', child: Text('Amount ↑')),
            ],
            onChanged: onSort,
          );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 46,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 2),
            itemBuilder: (context, index) => filterAt(index),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF202538)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.search,
                        size: 13, color: Color(0xFF6E7895)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 9),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 5),
                          hintText: 'Search…',
                          hintStyle: const TextStyle(
                            color: Color(0xFF6E7895),
                            fontSize: 9,
                          ),
                          border: InputBorder.none,
                          suffixIconConstraints:
                              const BoxConstraints(maxHeight: 16, maxWidth: 16),
                          suffixIcon: searchCtrl.text.isEmpty
                              ? null
                              : InkWell(
                                  onTap: () {
                                    searchCtrl.clear();
                                    onSearchChanged('');
                                  },
                                  child: const Icon(Icons.close,
                                      size: 12, color: Color(0xFF6E7895)),
                                ),
                        ),
                        onChanged: onSearchChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 3),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: weddingAccent,
                backgroundColor: const Color(0xFF1F2636),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                minimumSize: const Size(0, 22),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onClear,
              icon: const Icon(Icons.refresh, size: 11),
              label: const Text('Reset', style: TextStyle(fontSize: 8.5)),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          '$resultCount records',
          style: infoText,
        ),
      ],
    );
  }
}

class _DropdownPill<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool highlighted;

  const _DropdownPill({
    Key? key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.highlighted = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color baseColor =
        highlighted ? const Color(0xFF1F2636) : const Color(0xFF151926);
    final Color borderColor =
        highlighted ? weddingAccent : const Color(0xFF2A3147);
    final List<BoxShadow> shadows = highlighted
        ? [
            BoxShadow(
              color: weddingAccent.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ]
        : const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            )
          ];

    return Container(
      constraints: const BoxConstraints(minWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          dropdownColor: const Color(0xFF1B2132),
          borderRadius: BorderRadius.circular(10),
          icon: Icon(Icons.expand_more,
              color: highlighted ? weddingAccent : const Color(0xFF6E7895),
              size: 10),
          value: value,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 10,
                  color: highlighted ? weddingAccent : const Color(0xFF6E7895)),
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                    color:
                        highlighted ? weddingAccent : const Color(0xFF6E7895),
                    fontSize: 8.5),
              ),
            ],
          ),
          items: items,
          onChanged: onChanged,
          selectedItemBuilder: (context) => items.map((item) {
            final displayText =
                item.child is Text ? (item.child as Text).data ?? '' : label;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 11,
                    color:
                        highlighted ? weddingAccent : const Color(0xFF8C95AA)),
                const SizedBox(width: 2),
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    displayText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _LedgerSummaryStrip extends StatelessWidget {
  final double income;
  final double expense;
  final double net;
  final double balance;
  final NumberFormat currency;
  final int recordCount;

  const _LedgerSummaryStrip({
    Key? key,
    required this.income,
    required this.expense,
    required this.net,
    required this.balance,
    required this.currency,
    required this.recordCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final netPositive = net >= 0;
    final netColor = netPositive ? weddingPos : const Color(0xFFFF7070);

    Widget metricTile(String label, double value, Color color) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8C95AA),
                fontSize: 9,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '₹${currency.format(value.abs())}',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141A26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2636)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                    const Text(
                      'Current balance',
                      style: TextStyle(
                        color: Color(0xFF7D859D),
                        fontSize: 10,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '₹${currency.format(balance)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$recordCount records',
                    style: const TextStyle(
                      color: Color(0xFF7D859D),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: netColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: netColor.withOpacity(0.35)),
                    ),
                    child: Text(
                      net == 0
                          ? 'Net balanced'
                          : '${netPositive ? 'Net gain' : 'Net loss'} ₹${currency.format(net.abs())}',
                      style: TextStyle(
                        color: netColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              metricTile('Income', income, weddingPos),
              const SizedBox(width: 12),
              metricTile('Expense', expense, const Color(0xFFFF7070)),
              const SizedBox(width: 12),
              metricTile('Net', net, netColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat currencyFormat;

  const _TransactionTile({
    Key? key,
    required this.data,
    required this.currencyFormat,
  }) : super(key: key);

  Color _amountColor(bool isIncome) =>
      isIncome ? weddingPos : const Color(0xFFFF7070);

  Widget _metaBadge({
    required IconData icon,
    required String label,
    Color background = const Color(0xFF1F2535),
    Color? textColor,
    Color? iconColor,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  }) {
    final Color resolvedText = textColor ?? const Color(0xFFE2E7F5);
    final Color resolvedIcon = iconColor ?? const Color(0xFF8C95AA);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: background.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: resolvedIcon),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: resolvedText,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = data['date'] as DateTime;
    final type = data['type'] as String;
    final isIncome = type == 'INCOME';
    final amount = (data['amount'] as double).abs();
    final rawBalance = data['balance'];
    final balance = rawBalance is num ? rawBalance.toDouble() : 0.0;
    final cr = (data['accountCr'] as String?) ?? '';
    final dr = (data['accountDr'] as String?) ?? '';
    final category = (data['category'] as String?) ?? '';
    final narration = (data['narration'] as String?)?.trim() ?? '';

    final accountLine = () {
      if (cr.isEmpty && dr.isEmpty) return '—';
      if (cr.isEmpty) return dr;
      if (dr.isEmpty) return cr;
      return '$cr → $dr';
    }();

    final dateLabel = DateFormat('dd/MM/yyyy').format(date);
    final dayLabel = DateFormat('EEE').format(date).toUpperCase();
    final typeLabel = isIncome ? 'Income' : 'Expense';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C2235), Color(0xFF151A27)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x332B3244)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DatePill(
                dateLabel: dateLabel,
                dayLabel: dayLabel,
                isIncome: isIncome,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            accountLine,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${currencyFormat.format(amount)}',
                              style: TextStyle(
                                color: _amountColor(isIncome),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Balance • ₹${currencyFormat.format(balance)}',
                              style: const TextStyle(
                                color: Color(0xFF9AA2B2),
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('hh:mm a').format(date),
                              style: const TextStyle(
                                color: Color(0xFF8C95AA),
                                fontSize: 8.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _amountColor(isIncome).withOpacity(0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _amountColor(isIncome).withOpacity(0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isIncome
                                    ? Icons.arrow_outward
                                    : Icons.arrow_downward,
                                size: 10,
                                color: _amountColor(isIncome),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                typeLabel,
                                style: TextStyle(
                                  color: _amountColor(isIncome),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _metaBadge(
                          icon: Icons.swap_horiz,
                          label: type == 'INCOME'
                              ? (cr.isEmpty ? '—' : cr)
                              : (dr.isEmpty ? '—' : dr),
                          background: const Color(0xFF1E2434),
                          textColor: const Color(0xFFE2E7F5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  final String dateLabel;
  final String dayLabel;
  final bool isIncome;

  const _DatePill({
    Key? key,
    required this.dateLabel,
    required this.dayLabel,
    required this.isIncome,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B3450), Color(0xFF1B2132)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF394058)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF3E4761),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  dayLabel,
                  style: const TextStyle(
                    color: Color(0xFFD9E0F5),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isIncome ? weddingPos : const Color(0xFFFF7070))
                    .withOpacity(0.2),
                border: Border.all(
                    color: isIncome ? weddingPos : const Color(0xFFFF7070)),
              ),
              child: Icon(
                isIncome ? Icons.north_east : Icons.south_west,
                size: 10,
                color: isIncome ? weddingPos : const Color(0xFFFF7070),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  final double income;
  final double expense;
  final double balance;

  const _TotalsBar({
    Key? key,
    required this.income,
    required this.expense,
    required this.balance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0');
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF191E2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2B3244)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Summary',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Net totals based on filters applied',
                  style: TextStyle(
                    color: Color(0xFF8C95AA),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Income  ₹${currency.format(income)}',
                style: const TextStyle(
                  color: weddingPos,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Expense  ₹${currency.format(expense)}',
                style: const TextStyle(
                  color: Color(0xFFFF7070),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Balance  ₹${currency.format(balance)}',
                style: const TextStyle(
                  color: Color(0xFF9AA2B2),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.inbox_outlined, size: 46, color: Color(0xFF3F465B)),
            SizedBox(height: 12),
            Text(
              'No records for the selected filters',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Adjust accounts, categories, or time range to load more entries.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8C95AA),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
