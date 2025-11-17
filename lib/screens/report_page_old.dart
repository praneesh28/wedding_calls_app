// lib/screens/report_pages.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'wedding_theme.dart';

/// ReportPages: Account Head and Ledger reports with date range and running balance.
/// Paste as: lib/screens/report_pages.dart
class ReportPages extends StatefulWidget {
  const ReportPages({super.key});

  @override
  State<ReportPages> createState() => _ReportPagesState();
}

class _ReportPagesState extends State<ReportPages>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Data caches
  List<Map<String, dynamic>> _transactions = [];
  List<String> _names = [];
  List<String> _categories = [];

  // Common controls
  DateTime? _from;
  DateTime? _to;

  // Account Head tab
  String? _selectedAccount;

  // Ledger tab
  String? _selectedLedger;

  bool _loadingLists = true;
  bool _loadingTx = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _from = DateTime.now().subtract(const Duration(days: 30));
    _to = DateTime.now();
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Defensive parse of dd/MM/yyyy -> DateTime
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      final s = value.toString();
      final p = s.split('/');
      if (p.length != 3) return null;
      final d = int.parse(p[0]);
      final m = int.parse(p[1]);
      final y = int.parse(p[2]);
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _loadInitialData() async {
    setState(() {
      _loadingLists = true;
      _loadingTx = true;
      _error = null;
    });

    try {
      // Load transactions once (we'll also keep an active stream later if needed)
      final txSnap =
          await FirebaseFirestore.instance.collection('transactions').get();
      final List<Map<String, dynamic>> txs = [];
      for (final d in txSnap.docs) {
        final m = Map<String, dynamic>.from(d.data());
        // keep doc id if needed later
        m['_docId'] = d.id;
        txs.add(m);
      }

      // Try vendors / categories collections first (preferred)
      final names = <String>{};
      final cats = <String>{};
      try {
        final vSnap =
            await FirebaseFirestore.instance.collection('vendors').get();
        for (final d in vSnap.docs) {
          final n = (d.data()['name'] ?? d.id).toString().trim();
          if (n.isNotEmpty) names.add(n);
        }
      } catch (_) {
        // ignore vendor load
      }
      try {
        final cSnap =
            await FirebaseFirestore.instance.collection('categories').get();
        for (final d in cSnap.docs) {
          final c = (d.data()['name'] ?? d.id).toString().trim();
          if (c.isNotEmpty) cats.add(c);
        }
      } catch (_) {
        // ignore category load
      }

      // Fallback: derive from transactions
      for (final m in txs) {
        if (names.isEmpty) {
          final n = (m['name'] ?? '').toString().trim();
          if (n.isNotEmpty) names.add(n);
        }
        if (cats.isEmpty) {
          final c = (m['category'] ?? '').toString().trim();
          if (c.isNotEmpty) cats.add(c);
        }
      }

      // Defaults if still empty
      if (names.isEmpty) names.addAll({'Cash', 'Gift', 'Catering'});
      if (cats.isEmpty) cats.addAll({'Income', 'Food', 'Decor', 'Media'});

      setState(() {
        _transactions = txs;
        _names = names.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _categories = cats.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        if (_names.isNotEmpty && _selectedAccount == null)
          _selectedAccount = _names.first;
        if (_categories.isNotEmpty && _selectedLedger == null)
          _selectedLedger = _categories.first;
        _loadingLists = false;
        _loadingTx = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _loadingLists = false;
        _loadingTx = false;
      });
    }
  }

  // Filters transactions by date range and either account name or category.
  List<_RowItem> _buildRows({
    required bool byAccount,
    required String selected,
    required DateTime from,
    required DateTime to,
  }) {
    final rows = <_RowItem>[];

    for (final m in _transactions) {
      final dt = _parseDate(m['date']);
      if (dt == null) continue;
      // inclusive range
      if (dt.isBefore(from) || dt.isAfter(to)) continue;

      if (byAccount) {
        final name = (m['name'] ?? '').toString();
        if (name != selected) continue;
      } else {
        final cat = (m['category'] ?? '').toString();
        if (cat != selected) continue;
      }

      final amtRaw = m['amount'];
      final amt = (amtRaw is int) ? amtRaw : int.tryParse('$amtRaw') ?? 0;
      rows.add(_RowItem(
        date: dt,
        voucher: (m['type'] ?? '').toString().toUpperCase(),
        ledgerOrCategory: byAccount
            ? (m['category'] ?? '').toString()
            : (m['name'] ?? '').toString(),
        amount: amt,
      ));
    }

    // Sort ascending by date (older first) to compute running balance
    rows.sort((a, b) => a.date.compareTo(b.date));

    // Compute running balance
    var balance = 0;
    for (final r in rows) {
      balance += r.amount;
      r.balance = balance;
    }

    return rows;
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _to = d);
  }

  Widget _buildControls({
    required bool byAccount,
    required String? selected,
    required List<String> options,
    required void Function(String?) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: selected,
              items: options
                  .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(o, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: onSelect,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), labelText: ''),
            ),
          ),
          const SizedBox(width: 8),
          Column(children: [
            TextButton(
                onPressed: _pickFrom,
                style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 8)),
                child: Text('From\n${_from != null ? _fmtDate(_from!) : '-'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12))),
          ]),
          const SizedBox(width: 8),
          Column(children: [
            TextButton(
                onPressed: _pickTo,
                style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 8)),
                child: Text('To\n${_to != null ? _fmtDate(_to!) : '-'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12))),
          ]),
        ]),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTable(List<_RowItem> rows, {required bool showLedgerColumn}) {
    // Column widths approximated with Flex
    return Card(
      color: weddingSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header row
          Row(children: [
            Expanded(flex: 2, child: _tableHeader('DATE')),
            Expanded(flex: 2, child: _tableHeader('VOUCHER')),
            Expanded(
                flex: 4,
                child: _tableHeader(
                    showLedgerColumn ? 'ACCOUNT/LEDGER' : 'CATEGORY')),
            Expanded(flex: 2, child: _tableHeader('AMOUNT', alignRight: true)),
            Expanded(flex: 2, child: _tableHeader('BALANCE', alignRight: true)),
          ]),
          const Divider(height: 12, color: weddingDivider),
          // Rows
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Text('No records found',
                      style: TextStyle(
                          color: weddingOnSurfaceMuted, fontSize: 13))),
            )
          else
            ...rows.map((r) {
              final amtPos = r.amount > 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(
                      flex: 2,
                      child: Text(_fmtDate(r.date),
                          style: TextStyle(
                              color: weddingOnSurface, fontSize: 13))),
                  Expanded(
                      flex: 2,
                      child: Text(r.voucher,
                          style: TextStyle(
                              color: weddingOnSurface, fontSize: 13))),
                  Expanded(
                      flex: 4,
                      child: Text(r.ledgerOrCategory,
                          style: TextStyle(
                              color: weddingOnSurface, fontSize: 13))),
                  Expanded(
                      flex: 2,
                      child: Text('${amtPos ? '' : '-'}₹${r.amount.abs()}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: amtPos ? weddingPos : Colors.redAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 13))),
                  Expanded(
                      flex: 2,
                      child: Text('₹${r.balance.abs()}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: weddingOnSurface, fontSize: 13))),
                ]),
              );
            }).toList(),
          const SizedBox(height: 8),
          // Totals row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: weddingSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: [
              const Expanded(flex: 2, child: SizedBox()), // date
              const Expanded(flex: 2, child: SizedBox()), // voucher
              Expanded(
                  flex: 4,
                  child: Text('Total',
                      style: TextStyle(
                          color: weddingOnSurfaceMuted,
                          fontWeight: FontWeight.w800,
                          fontSize: 13))),
              Expanded(
                flex: 2,
                child: Text(
                  '₹${rows.fold<int>(0, (s, r) => s + r.amount.abs())}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: weddingOnSurfaceMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  rows.isEmpty ? '₹0' : '₹${rows.last.balance.abs()}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: weddingOnSurfaceMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                ),
              ),
            ]),
          )
        ]),
      ),
    );
  }

  Widget _tableHeader(String text, {bool alignRight = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: TextStyle(
                color: weddingOnSurfaceMuted,
                fontWeight: FontWeight.w800,
                fontSize: 12),
            textAlign: alignRight ? TextAlign.right : TextAlign.left),
      );

  @override
  Widget build(BuildContext context) {
    if (_loadingLists || _loadingTx) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Reports'),
            backgroundColor: weddingSurface,
            toolbarHeight: 48),
        body: const Center(child: CircularProgressIndicator()),
        backgroundColor: weddingBg,
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Reports'),
            backgroundColor: weddingSurface,
            toolbarHeight: 48),
        body: Center(
            child: Text(_error!, style: TextStyle(color: weddingOnSurface))),
        backgroundColor: weddingBg,
      );
    }

    // Ensure from/to defaults
    final from = _from ?? DateTime.now().subtract(const Duration(days: 30));
    final to = _to ?? DateTime.now();

    // Build current rows for each tab
    final accountRows = (_selectedAccount != null)
        ? _buildRows(
            byAccount: true, selected: _selectedAccount!, from: from, to: to)
        : <_RowItem>[];
    final ledgerRows = (_selectedLedger != null)
        ? _buildRows(
            byAccount: false, selected: _selectedLedger!, from: from, to: to)
        : <_RowItem>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: weddingSurface,
        toolbarHeight: 52,
        bottom: TabBar(
          controller: _tabController,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          indicatorWeight: 2,
          tabs: const [Tab(text: 'ACCOUNT HEAD'), Tab(text: 'LEDGER')],
        ),
      ),
      backgroundColor: weddingBg,
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: TabBarView(controller: _tabController, children: [
          // Account Head Tab
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('ACCOUNT HEAD (SELECTED)',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildControls(
                      byAccount: true,
                      selected: _selectedAccount,
                      options: _names,
                      onSelect: (v) => setState(() => _selectedAccount = v),
                    ),
                    Row(children: [
                      ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: weddingAccent,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12)),
                          child: const Text('Generate',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13))),
                      const SizedBox(width: 8),
                      TextButton(
                          onPressed: _loadInitialData,
                          style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12)),
                          child: const Text('Refresh',
                              style: TextStyle(fontSize: 13))),
                    ])
                  ]),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildTable(accountRows, showLedgerColumn: true)),
          ]),

          // Ledger Tab
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('LEDGER (SELECTED)',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildControls(
                      byAccount: false,
                      selected: _selectedLedger,
                      options: _categories,
                      onSelect: (v) => setState(() => _selectedLedger = v),
                    ),
                    Row(children: [
                      ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: weddingAccent,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12)),
                          child: const Text('Generate',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13))),
                      const SizedBox(width: 8),
                      TextButton(
                          onPressed: _loadInitialData,
                          style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12)),
                          child: const Text('Refresh',
                              style: TextStyle(fontSize: 13))),
                    ])
                  ]),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildTable(ledgerRows, showLedgerColumn: false)),
          ]),
        ]),
      ),
    );
  }
}

/// Simple row model used for rendering and running balance.
class _RowItem {
  final DateTime date;
  final String voucher;
  final String ledgerOrCategory;
  final int amount;
  int balance = 0;
  _RowItem({
    required this.date,
    required this.voucher,
    required this.ledgerOrCategory,
    required this.amount,
  });
}
