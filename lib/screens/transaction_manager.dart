// lib/screens/transaction_manager.dart
// Responsive, Android-friendly Transaction Manager
// Modified: Category, Amount, Narration and Save are now in a single horizontal row.
// Small-screen list shows ACCOUNTS | CATEGORY | AMT | BAL in one line (tighter layout).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import 'wedding_theme.dart';

class TransactionManager extends StatefulWidget {
  const TransactionManager({Key? key}) : super(key: key);
  @override
  State<TransactionManager> createState() => _TransactionManagerState();
}

class _TransactionManagerState extends State<TransactionManager> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _narrationController = TextEditingController();

  String? _accountDr;
  String? _accountCr;
  String? _category;
  bool _firstIsDr = true;
  double _openingBalance = 0.0;
  bool _saving = false;
  DateTime _selectedDate = DateTime.now();

  List<String> accountList = [];
  List<String> categoryList = [];
  final NumberFormat _moneyFmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  // Shared wedding dark palette
  static const Color _scaffoldBg = weddingBg;
  static const Color _primaryColor = weddingAccent;
  static const Color _cardBg = weddingSurface;
  static const Color _darkCard = weddingSurface;
  static const Color _chipBg = weddingSurface;
  static const Color _darkOnCard = weddingOnSurface;
  static const Color _textPrimary = weddingOnSurface;
  static const Color _accentColor = weddingAccent;
  static const Color _incomeColor = weddingPos;
  static const Color _expenseColor = weddingAccent;

  int _streamVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadCategories();
    _loadOpeningBalanceForYesterday();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final snapshot = await _db.collection('accounts').get();
      setState(() {
        accountList = snapshot.docs
            .map((e) => e['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (accountList.isNotEmpty) {
          _accountDr ??= accountList.first;
          _accountCr ??=
              accountList.length > 1 ? accountList[1] : accountList.first;
          if (_accountDr == _accountCr) {
            final diff = _firstDifferentAccount(_accountDr!);
            if (diff != null) _accountCr = diff;
          }
        } else {
          _accountDr = null;
          _accountCr = null;
        }
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error loading accounts: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final snapshot = await _db.collection('categories').orderBy('name').get();
      final fetched = snapshot.docs
          .map((e) => e['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        categoryList = fetched;
        if (categoryList.isNotEmpty) {
          if (_category == null || _category!.isEmpty) {
            _category = categoryList.first;
          } else if (!categoryList.contains(_category)) {
            _category = categoryList.first;
          }
        } else {
          _category = null;
        }
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error loading categories: $e');
    }
  }

  Future<void> _loadOpeningBalanceForDate(DateTime date) async {
    try {
      final prevDayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);
      final ts = Timestamp.fromDate(prevDayEnd);

      final snap = await _db
          .collection('transactions')
          .where('dateTs', isLessThanOrEqualTo: ts)
          .orderBy('dateTs', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data() as Map<String, dynamic>? ?? {};
        setState(() {
          _openingBalance = (data['balance'] is num)
              ? (data['balance'] as num).toDouble()
              : 0.0;
        });
      } else {
        setState(() => _openingBalance = 0.0);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading opening balance for date: $e');
      setState(() => _openingBalance = 0.0);
    }
  }

  Future<void> _loadOpeningBalanceForYesterday() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    await _loadOpeningBalanceForDate(yesterday);
  }

  String? _firstDifferentAccount(String selected) {
    for (final a in accountList) {
      if (a != selected) return a;
    }
    return accountList.isNotEmpty ? accountList.first : null;
  }

  void _toggleFirstRole(bool firstDr) {
    if (firstDr == _firstIsDr) return;
    setState(() => _firstIsDr = firstDr);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) =>
          Theme(data: ThemeData.dark(), child: child ?? const SizedBox()),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _promptTypeBeforeSave() async {
    final choice = await showDialog<String?>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _darkCard,
        title: Text('Select Type', style: TextStyle(color: _darkOnCard)),
        content: Text('Save this transaction as Income or Expense?',
            style: TextStyle(color: _darkOnCard)),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(c).pop(null),
              child: Text('Cancel', style: TextStyle(color: _darkOnCard))),
          TextButton(
              onPressed: () => Navigator.of(c).pop('EXPENSE'),
              child: Text('Expense', style: TextStyle(color: _expenseColor))),
          TextButton(
              onPressed: () => Navigator.of(c).pop('INCOME'),
              child: Text('Income', style: TextStyle(color: _incomeColor))),
        ],
      ),
    );
    if (choice == 'EXPENSE' || choice == 'INCOME') {
      await _saveTransactionWithType(choice!);
    }
  }

  Future<void> _saveTransactionWithType(String type) async {
    if (_saving) return;
    if (_accountDr == null || _accountCr == null || accountList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select both Dr and Cr accounts.')));
      return;
    }
    if (_accountDr == _accountCr) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Dr and Cr cannot be the same account.')));
      return;
    }
    final amtText = _amountController.text.trim();
    if (amtText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter an amount.')));
      return;
    }
    final amount = double.tryParse(amtText.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a valid amount greater than 0.')));
      return;
    }

    setState(() => _saving = true);
    try {
      double currentBalance = _openingBalance;
      final lastSnap = await _db
          .collection('transactions')
          .orderBy('dateTs', descending: true)
          .limit(1)
          .get();
      if (lastSnap.docs.isNotEmpty) {
        final lastData =
            lastSnap.docs.first.data() as Map<String, dynamic>? ?? {};
        currentBalance = (lastData['balance'] is num)
            ? (lastData['balance'] as num).toDouble()
            : currentBalance;
      }
      final double newBalance = (type == 'INCOME')
          ? (currentBalance + amount)
          : (currentBalance - amount);

      final data = {
        'date': DateFormat('dd/MM/yyyy').format(_selectedDate),
        'dateTs': Timestamp.fromDate(_selectedDate),
        'accountDr': _accountDr,
        'accountCr': _accountCr,
        'category': _category ?? '',
        'amount': amount,
        'narration': _narrationController.text.trim(),
        'type': type,
        'balance': newBalance,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('transactions').add(data);
      await _recalculateBalances();

      _amountController.clear();
      _narrationController.clear();
      setState(() {
        _accountDr = accountList.isNotEmpty ? accountList.first : null;
        _accountCr = accountList.length > 1 ? accountList[1] : _accountDr;
        _category = null;
        _selectedDate = DateTime.now();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Transaction saved.')));
      setState(() => _streamVersion++);
    } catch (e) {
      // ignore: avoid_print
      print('Error saving transaction: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      setState(() => _saving = false);
      await _loadOpeningBalanceForYesterday();
    }
  }

  Future<void> _deleteTransaction(String id) async {
    try {
      await _db.collection('transactions').doc(id).delete();
      await _recalculateBalances();
      await _loadOpeningBalanceForYesterday();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Transaction deleted.')));
      setState(() => _streamVersion++);
    } catch (e) {
      // ignore: avoid_print
      print('Error deleting: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    }
  }

  Future<void> _editTransaction(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final initialDr = data['accountDr']?.toString();
    final initialCr = data['accountCr']?.toString();
    final initialCategory = data['category']?.toString();
    final initialAmt = (data['amount'] is num)
        ? (data['amount'] as num).toString()
        : (data['amount'] ?? '').toString();
    final initialNarration = data['narration']?.toString() ?? '';
    final initialType = (data['type']?.toString() ?? 'EXPENSE');
    DateTime selectedDate = (data['dateTs'] is Timestamp)
        ? (data['dateTs'] as Timestamp).toDate()
        : DateTime.now();

    final TextEditingController amtCtrl =
        TextEditingController(text: initialAmt);
    final TextEditingController narrCtrl =
        TextEditingController(text: initialNarration);

    String? selDr = initialDr;
    String? selCr = initialCr;
    String? selCat = initialCategory;
    String selType = initialType;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: _darkCard,
            title:
                Text('Edit Transaction', style: TextStyle(color: _darkOnCard)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: selDr,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: 'Dr', border: OutlineInputBorder()),
                  dropdownColor: _darkCard,
                  items: accountList
                      .map((e) => DropdownMenuItem<String>(
                            value: e,
                            child:
                                Text(e, style: TextStyle(color: _darkOnCard)),
                          ))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => selDr = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selCr,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: 'Cr', border: OutlineInputBorder()),
                  dropdownColor: _darkCard,
                  items: accountList
                      .map((e) => DropdownMenuItem<String>(
                            value: e,
                            child:
                                Text(e, style: TextStyle(color: _darkOnCard)),
                          ))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => selCr = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selCat,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: 'Category', border: OutlineInputBorder()),
                  dropdownColor: _darkCard,
                  items: (() {
                    final options = [...categoryList];
                    if (selCat != null &&
                        selCat!.isNotEmpty &&
                        !options.contains(selCat)) {
                      options.add(selCat!);
                    }
                    return options
                        .map((e) => DropdownMenuItem<String>(
                              value: e,
                              child:
                                  Text(e, style: TextStyle(color: _darkOnCard)),
                            ))
                        .toList();
                  })(),
                  onChanged: (v) => setStateDialog(() => selCat = v),
                ),
                const SizedBox(height: 8),
                Row(children: <Widget>[
                  Text('Type:', style: TextStyle(color: _darkOnCard)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                      label: const Text('Expense'),
                      selected: selType == 'EXPENSE',
                      selectedColor: _expenseColor.withOpacity(0.2),
                      backgroundColor: _chipBg,
                      labelStyle: TextStyle(
                          color: selType == 'EXPENSE'
                              ? _expenseColor
                              : _darkOnCard),
                      onSelected: (_) =>
                          setStateDialog(() => selType = 'EXPENSE')),
                  const SizedBox(width: 8),
                  ChoiceChip(
                      label: const Text('Income'),
                      selected: selType == 'INCOME',
                      selectedColor: _incomeColor.withOpacity(0.2),
                      backgroundColor: _chipBg,
                      labelStyle: TextStyle(
                          color:
                              selType == 'INCOME' ? _incomeColor : _darkOnCard),
                      onSelected: (_) =>
                          setStateDialog(() => selType = 'INCOME')),
                ]),
                const SizedBox(height: 8),
                TextField(
                    controller: amtCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'))
                    ],
                    style: TextStyle(color: _darkOnCard)),
                const SizedBox(height: 8),
                TextField(
                    controller: narrCtrl, style: TextStyle(color: _darkOnCard)),
                const SizedBox(height: 8),
                Row(children: <Widget>[
                  Text('Date:', style: TextStyle(color: _darkOnCard)),
                  const SizedBox(width: 8),
                  TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) => Theme(
                                data: ThemeData.dark(),
                                child: child ?? const SizedBox()));
                        if (d != null) setStateDialog(() => selectedDate = d);
                      },
                      child: Text(DateFormat('dd/MM/yyyy').format(selectedDate),
                          style: TextStyle(color: _accentColor))),
                ]),
              ]),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    amtCtrl.dispose();
                    narrCtrl.dispose();
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel', style: TextStyle(color: _darkOnCard))),
              ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                  onPressed: () async {
                    final amtText = amtCtrl.text.trim();
                    final amount = double.tryParse(amtText.replaceAll(',', ''));
                    if (selDr == null || selCr == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Please select both accounts.')));
                      return;
                    }
                    if (selDr == selCr) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Dr and Cr cannot be same.')));
                      return;
                    }
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Enter a valid amount > 0.')));
                      return;
                    }
                    try {
                      await doc.reference.update({
                        'accountDr': selDr,
                        'accountCr': selCr,
                        'category': selCat ?? '',
                        'amount': amount,
                        'narration': narrCtrl.text.trim(),
                        'type': selType,
                        'date': DateFormat('dd/MM/yyyy').format(selectedDate),
                        'dateTs': Timestamp.fromDate(selectedDate),
                      });
                      amtCtrl.dispose();
                      narrCtrl.dispose();
                      Navigator.of(context).pop();
                      await _recalculateBalances();
                      await _loadOpeningBalanceForYesterday();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Transaction updated.')));
                      setState(() => _streamVersion++);
                    } catch (e) {
                      // ignore: avoid_print
                      print('Error updating: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating: $e')));
                    }
                  },
                  child: const Text('Save')),
            ],
          );
        });
      },
    );
  }

  Future<void> _recalculateBalances() async {
    try {
      final col = _db.collection('transactions');
      final snap = await col.orderBy('dateTs', descending: false).get();
      if (snap.docs.isEmpty) {
        _openingBalance = 0.0;
        setState(() {});
        return;
      }
      final WriteBatch batch = _db.batch();
      double running = 0.0;
      for (final doc in snap.docs) {
        final d = doc.data() as Map<String, dynamic>? ?? {};
        final amt =
            (d['amount'] is num) ? (d['amount'] as num).toDouble() : 0.0;
        final type = (d['type'] ?? 'EXPENSE').toString();
        running = (type == 'INCOME') ? (running + amt) : (running - amt);
        batch.update(doc.reference, {'balance': running});
      }
      await batch.commit();
      _openingBalance = snap.docs.first.data()['balance'] is num
          ? (snap.docs.first.data()['balance'] as num).toDouble()
          : 0.0;
      setState(() {});
    } catch (e) {
      // ignore: avoid_print
      print('Error recalculating balances: $e');
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _darkCard,
        title: Text('Confirm delete', style: TextStyle(color: _darkOnCard)),
        content: Text('Are you sure you want to delete this transaction?',
            style: TextStyle(color: _darkOnCard)),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: Text('Cancel', style: TextStyle(color: _darkOnCard))),
          ElevatedButton(
              onPressed: () => Navigator.of(c).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
              child: const Text('Delete')),
        ],
      ),
    );
  }

  Future<void> _showActionsForDoc(DocumentSnapshot doc) async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: _darkCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (c) {
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: Icon(Icons.edit, color: _accentColor),
              title: Text('Edit', style: TextStyle(color: _darkOnCard)),
              onTap: () => Navigator.of(c).pop('edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete, color: _expenseColor),
              title: Text('Delete', style: TextStyle(color: _darkOnCard)),
              onTap: () => Navigator.of(c).pop('delete'),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.close, color: weddingOnSurfaceMuted),
              title: const Text('Cancel',
                  style: TextStyle(color: weddingOnSurfaceMuted)),
              onTap: () => Navigator.of(c).pop(null),
            ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );

    if (result == 'edit') {
      await _editTransaction(doc);
    } else if (result == 'delete') {
      final confirmed = await _confirmDelete(context);
      if (confirmed == true) {
        await _deleteTransaction(doc.id);
      }
    }
  }

  Widget _transactionCard({
    required double scale,
    required String dateLabel,
    required String dayLabel,
    required String accounts,
    required String category,
    required String narration,
    required String amount,
    required String balance,
    required String type,
    required Color amountColor,
    required VoidCallback onTap,
  }) {
    final hasNarration = narration.trim().isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12 * scale),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(color: weddingDivider),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding:
            EdgeInsets.fromLTRB(12 * scale, 10 * scale, 12 * scale, 10 * scale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _transactionDateBadge(scale, dateLabel, dayLabel),
            SizedBox(width: 10 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.isEmpty ? 'Uncategorised' : category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: weddingOnSurface,
                            fontSize: 13 * scale,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8 * scale, vertical: 3 * scale),
                        decoration: BoxDecoration(
                          color: amountColor.withOpacity(0.18),
                          border:
                              Border.all(color: amountColor.withOpacity(0.4)),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            color: amountColor,
                            fontSize: 10 * scale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    accounts,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: weddingOnSurfaceMuted,
                      fontSize: 11 * scale,
                    ),
                  ),
                  if (hasNarration) ...[
                    SizedBox(height: 3 * scale),
                    Text(
                      narration,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: weddingOnSurfaceMuted.withOpacity(0.8),
                        fontSize: 10 * scale,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 10 * scale),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    color: amountColor,
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6 * scale),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 12 * scale, color: weddingOnSurfaceMuted),
                    SizedBox(width: 4 * scale),
                    Text(
                      balance,
                      style: TextStyle(
                        color: weddingOnSurfaceMuted,
                        fontSize: 11 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionDateBadge(
      double scale, String dateLabel, String dayLabel) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 6 * scale),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: weddingDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: TextStyle(
              color: weddingOnSurface,
              fontSize: 11 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (dayLabel.isNotEmpty) ...[
            SizedBox(height: 3 * scale),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 6 * scale, vertical: 2 * scale),
              decoration: BoxDecoration(
                color: weddingOnSurface.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8 * scale),
              ),
              child: Text(
                dayLabel,
                style: TextStyle(
                  color: weddingOnSurfaceMuted,
                  fontSize: 9 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(
      double incomeToday, double expenseToday, double balanceToday,
      {required double scale, required TextStyle boldStyle}) {
    return Container(
      padding:
          EdgeInsets.symmetric(vertical: 10 * scale, horizontal: 12 * scale),
      decoration: BoxDecoration(
          color: _darkCard,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
                color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))
          ]),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text("Income: ${_moneyFmt.format(incomeToday)}",
                  style: boldStyle, overflow: TextOverflow.ellipsis),
            ),
            SizedBox(width: 8 * scale),
            Expanded(
              child: Text("Expense: ${_moneyFmt.format(expenseToday)}",
                  style: boldStyle, overflow: TextOverflow.ellipsis),
            ),
            SizedBox(width: 8 * scale),
            Expanded(
              child: Text("Balance: ${_moneyFmt.format(balanceToday)}",
                  style: boldStyle, overflow: TextOverflow.ellipsis),
            ),
          ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isAndroid = platform == TargetPlatform.android;

    final mq = MediaQuery.of(context);
    final double clampedTextScale = mq.textScaleFactor.clamp(1.0, 1.15);
    final mediaOverride =
        mq.copyWith(textScaler: TextScaler.linear(clampedTextScale));

    final double baseWidth = isAndroid ? 400 : 430;
    final double platformCompactFactor = isAndroid ? 0.92 : 1.0;

    return MediaQuery(
      data: mediaOverride,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: _scaffoldBg,
          appBar: AppBar(
            backgroundColor: weddingSurface,
            foregroundColor: weddingOnSurface,
            title: const Text(
              "Transaction Manager",
              style: TextStyle(
                  fontSize: 16,
                  color: weddingOnSurface,
                  fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            elevation: 1.5,
          ),
          body: LayoutBuilder(builder: (context, constraints) {
            double scale =
                (constraints.maxWidth / baseWidth) * platformCompactFactor;
            scale = scale.clamp(0.65, 1.0);

            final smallText =
                TextStyle(fontSize: 11 * scale, color: _textPrimary);
            final boldText = TextStyle(
                fontSize: 12 * scale,
                fontWeight: FontWeight.bold,
                color: _textPrimary);
            final labelStyle =
                TextStyle(color: _darkOnCard, fontSize: 11 * scale);
            final inputTextStyle =
                TextStyle(color: _darkOnCard, fontSize: 13 * scale);

            Widget glanceBar(
                double s, double income, double expense, double balance) {
              Widget metric(String label, double value, Color color) {
                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              color: weddingOnSurfaceMuted,
                              fontSize: 10 * s,
                              letterSpacing: 0.3)),
                      const SizedBox(height: 2),
                      Text(_moneyFmt.format(value),
                          style: TextStyle(
                              color: color,
                              fontSize: 12 * s,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }

              return Container(
                margin: EdgeInsets.only(bottom: 8 * s),
                padding:
                    EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
                decoration: BoxDecoration(
                  color: _darkCard,
                  borderRadius: BorderRadius.circular(8 * s),
                  border: Border.all(color: weddingDivider),
                ),
                child: Row(
                  children: [
                    metric('Income', income, _incomeColor),
                    SizedBox(width: 12 * s),
                    metric('Expense', expense, _expenseColor),
                    SizedBox(width: 12 * s),
                    metric('Balance', balance, _accentColor),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.all(10 * scale),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Text('First is:', style: smallText),
                            SizedBox(width: 8 * scale),
                            ChoiceChip(
                                label: Text('Dr',
                                    style: TextStyle(fontSize: 11 * scale)),
                                selected: _firstIsDr,
                                selectedColor: _primaryColor.withOpacity(0.18),
                                backgroundColor: _chipBg,
                                labelStyle: TextStyle(
                                    color: _firstIsDr
                                        ? _primaryColor
                                        : _textPrimary,
                                    fontSize: 11 * scale),
                                onSelected: (s) => _toggleFirstRole(true)),
                            SizedBox(width: 6 * scale),
                            ChoiceChip(
                                label: Text('Cr',
                                    style: TextStyle(fontSize: 11 * scale)),
                                selected: !_firstIsDr,
                                selectedColor: _primaryColor.withOpacity(0.18),
                                backgroundColor: _chipBg,
                                labelStyle: TextStyle(
                                    color: !_firstIsDr
                                        ? _primaryColor
                                        : _textPrimary,
                                    fontSize: 11 * scale),
                                onSelected: (s) => _toggleFirstRole(false)),
                          ]),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Opening: ", style: boldText),
                              Text(
                                _moneyFmt.format(_openingBalance),
                                style: TextStyle(
                                  color: _accentColor,
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ]),
                    SizedBox(height: 10 * scale),

                    // single row: Account Dr | Account Cr | Date picker
                    Row(children: [
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          isDense: true,
                          isExpanded: true,
                          initialValue: _firstIsDr ? _accountDr : _accountCr,
                          hint: accountList.isEmpty
                              ? Text('No accounts', style: labelStyle)
                              : null,
                          decoration: InputDecoration(
                              labelText: _firstIsDr ? 'Dr' : 'Cr',
                              labelStyle: labelStyle,
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              floatingLabelStyle: labelStyle,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 8 * scale, horizontal: 10 * scale),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6))),
                          dropdownColor: _darkCard,
                          items: accountList
                              .map((e) => DropdownMenuItem<String>(
                                    value: e,
                                    child: Text(e, style: inputTextStyle),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              if (_firstIsDr) {
                                _accountDr = val;
                                if (_accountCr == _accountDr) {
                                  _accountCr = _firstDifferentAccount(val);
                                }
                              } else {
                                _accountCr = val;
                                if (_accountDr == _accountCr) {
                                  _accountDr = _firstDifferentAccount(val);
                                }
                              }
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          isDense: true,
                          isExpanded: true,
                          initialValue: _firstIsDr ? _accountCr : _accountDr,
                          hint: accountList.isEmpty
                              ? Text('No accounts', style: labelStyle)
                              : null,
                          decoration: InputDecoration(
                              labelText: _firstIsDr ? 'Cr' : 'Dr',
                              labelStyle: labelStyle,
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              floatingLabelStyle: labelStyle,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 8 * scale, horizontal: 10 * scale),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6))),
                          dropdownColor: _darkCard,
                          items: accountList
                              .map((e) => DropdownMenuItem<String>(
                                    value: e,
                                    child: Text(e, style: inputTextStyle),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              if (_firstIsDr) {
                                _accountCr = val;
                                if (_accountDr == _accountCr) {
                                  _accountDr = _firstDifferentAccount(val);
                                }
                              } else {
                                _accountDr = val;
                                if (_accountDr == _accountCr) {
                                  _accountCr = _firstDifferentAccount(val);
                                }
                              }
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      Expanded(
                        flex: 2,
                        child: TextButton.icon(
                          onPressed: _pickDate,
                          icon: Icon(Icons.calendar_today,
                              size: 16 * scale, color: weddingOnSurfaceMuted),
                          label: Text(
                              DateFormat('dd/MM/yyyy').format(_selectedDate),
                              style: TextStyle(
                                  color: _accentColor, fontSize: 13 * scale)),
                          style: TextButton.styleFrom(
                              backgroundColor: _chipBg,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10 * scale, vertical: 10 * scale),
                              visualDensity: VisualDensity.compact),
                        ),
                      ),
                    ]),

                    SizedBox(height: 8 * scale),

                    // ===== Single horizontal row for Category | Amount | Narration | Save =====
                    Container(
                      padding: EdgeInsets.all(8 * scale),
                      decoration: BoxDecoration(
                        color: _darkCard,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black54,
                              offset: Offset(0, 1),
                              blurRadius: 6)
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Row 1: Category | Amount
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Category (flexible)
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  isDense: true,
                                  isExpanded: true,
                                  initialValue: categoryList.contains(_category)
                                      ? _category
                                      : null,
                                  decoration: InputDecoration(
                                    labelText: 'Category',
                                    labelStyle: TextStyle(
                                        color: _darkOnCard,
                                        fontSize: 11 * scale),
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.always,
                                    floatingLabelStyle: TextStyle(
                                        color: _darkOnCard,
                                        fontSize: 11 * scale),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 8 * scale,
                                        horizontal: 10 * scale),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6)),
                                  ),
                                  dropdownColor: _darkCard,
                                  hint: categoryList.isEmpty
                                      ? Text('No categories',
                                          style: TextStyle(
                                              color: _darkOnCard,
                                              fontSize: 11 * scale))
                                      : null,
                                  items: categoryList
                                      .map((e) => DropdownMenuItem<String>(
                                            value: e,
                                            child: Text(e,
                                                style: TextStyle(
                                                    color: _darkOnCard,
                                                    fontSize: 13 * scale)),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _category = v),
                                ),
                              ),

                              SizedBox(width: 8 * scale),

                              // Amount (compact)
                              Flexible(
                                flex: 2,
                                child: ConstrainedBox(
                                  constraints:
                                      BoxConstraints(maxWidth: 120 * scale),
                                  child: TextField(
                                    controller: _amountController,
                                    style: TextStyle(
                                        color: _darkOnCard,
                                        fontSize: 13 * scale),
                                    decoration: InputDecoration(
                                      labelText: 'Amount',
                                      labelStyle: TextStyle(
                                          color: _darkOnCard,
                                          fontSize: 11 * scale),
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.always,
                                      floatingLabelStyle: TextStyle(
                                          color: _darkOnCard,
                                          fontSize: 11 * scale),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          vertical: 8 * scale,
                                          horizontal: 10 * scale),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d*\.?\d{0,2}')),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 8 * scale),

                          // Row 2: Narration | Save
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Narration (flexible)
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _narrationController,
                                  style: TextStyle(
                                      color: _darkOnCard, fontSize: 13 * scale),
                                  decoration: InputDecoration(
                                    labelText: 'Narration',
                                    labelStyle: TextStyle(
                                        color: _darkOnCard,
                                        fontSize: 11 * scale),
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.always,
                                    floatingLabelStyle: TextStyle(
                                        color: _darkOnCard,
                                        fontSize: 11 * scale),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 8 * scale,
                                        horizontal: 10 * scale),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),

                              SizedBox(width: 8 * scale),

                              // Save (fixed width)
                              SizedBox(
                                height: 40 * scale,
                                child: ElevatedButton.icon(
                                  onPressed: (_saving || accountList.isEmpty)
                                      ? null
                                      : _promptTypeBeforeSave,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12 * scale,
                                        vertical: 8 * scale),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: _saving
                                      ? SizedBox(
                                          width: 14 * scale,
                                          height: 14 * scale,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2 * scale,
                                            color: weddingOnSurface,
                                          ),
                                        )
                                      : Icon(Icons.save,
                                          size: 16 * scale,
                                          color: weddingOnSurface),
                                  label: Text(_saving ? '...' : 'Save',
                                      style: TextStyle(
                                          color: weddingOnSurface,
                                          fontSize: 13 * scale)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 10 * scale),

                    // transactions list area
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        key: ValueKey(_streamVersion),
                        stream: _db
                            .collection('transactions')
                            .orderBy('dateTs', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          // ignore: avoid_print
                          print(
                              'StreamBuilder debug -> state=${snapshot.connectionState}, hasData=${snapshot.hasData}, docs=${snapshot.data?.docs.length}');

                          if (snapshot.hasError) {
                            final err = snapshot.error.toString();
                            return Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: _expenseColor, size: 36 * scale),
                                    SizedBox(height: 8 * scale),
                                    Text('Error loading data',
                                        style: TextStyle(
                                            color: _darkOnCard,
                                            fontSize: 14 * scale)),
                                    SizedBox(height: 6 * scale),
                                    Text(err,
                                        style: TextStyle(
                                            color: weddingOnSurfaceMuted,
                                            fontSize: 12 * scale),
                                        textAlign: TextAlign.center),
                                    SizedBox(height: 10 * scale),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          setState(() => _streamVersion++),
                                      icon:
                                          Icon(Icons.refresh, size: 16 * scale),
                                      label: Text('Retry',
                                          style:
                                              TextStyle(fontSize: 13 * scale)),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: _primaryColor),
                                    ),
                                  ]),
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final docs = snapshot.data?.docs ?? [];

                          final now = DateTime.now();
                          final todayStart =
                              DateTime(now.year, now.month, now.day);
                          final todayEnd =
                              todayStart.add(const Duration(days: 1));
                          double totalExpToday = 0, totalIncToday = 0;
                          double? lastBalanceToday;
                          for (final doc in docs) {
                            final d = doc.data() as Map<String, dynamic>? ?? {};
                            final amt = (d['amount'] is num)
                                ? (d['amount'] as num).toDouble()
                                : 0.0;
                            final type = (d['type'] ?? 'EXPENSE').toString();
                            final ts = d['dateTs'] is Timestamp
                                ? (d['dateTs'] as Timestamp).toDate()
                                : null;
                            if (ts != null &&
                                !ts.isBefore(todayStart) &&
                                ts.isBefore(todayEnd)) {
                              if (type == 'INCOME') {
                                totalIncToday += amt;
                              } else {
                                totalExpToday += amt;
                              }
                              final bal = (d['balance'] is num)
                                  ? (d['balance'] as num).toDouble()
                                  : null;
                              if (bal != null) lastBalanceToday = bal;
                            }
                          }
                          final displayIncome = totalIncToday;
                          final displayExpense = totalExpToday;
                          final displayBalance =
                              lastBalanceToday ?? _openingBalance;

                          if (docs.isEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                glanceBar(scale, displayIncome, displayExpense,
                                    displayBalance),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'No transactions found.',
                                      style: TextStyle(
                                          color: _darkOnCard,
                                          fontSize: 14 * scale),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8 * scale),
                                _buildFooter(displayIncome, displayExpense,
                                    displayBalance,
                                    scale: scale, boldStyle: boldText),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              glanceBar(scale, displayIncome, displayExpense,
                                  displayBalance),
                              Expanded(
                                child: ListView.separated(
                                  padding: EdgeInsets.only(bottom: 12 * scale),
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) =>
                                      SizedBox(height: 8 * scale),
                                  itemBuilder: (context, idx) {
                                    final doc = docs[idx];
                                    final d =
                                        doc.data() as Map<String, dynamic>? ??
                                            {};
                                    final ts = d['dateTs'] is Timestamp
                                        ? (d['dateTs'] as Timestamp).toDate()
                                        : null;
                                    final dateLabel = ts != null
                                        ? DateFormat('dd MMM').format(ts)
                                        : (d['date'] ?? '').toString();
                                    final dayLabel = ts != null
                                        ? DateFormat('EEE')
                                            .format(ts)
                                            .toUpperCase()
                                        : '';
                                    final accounts =
                                        "${d['accountDr'] ?? ''} → ${d['accountCr'] ?? ''}";
                                    final category =
                                        (d['category'] ?? '').toString();
                                    final narration =
                                        (d['narration'] ?? '').toString();
                                    final amtNum = (d['amount'] is num)
                                        ? (d['amount'] as num).toDouble()
                                        : 0.0;
                                    final amount = _moneyFmt.format(amtNum);
                                    final balNum = (d['balance'] is num)
                                        ? (d['balance'] as num).toDouble()
                                        : 0.0;
                                    final balance = _moneyFmt.format(balNum);
                                    final type =
                                        (d['type'] ?? 'EXPENSE').toString();
                                    final amountColor = type == 'INCOME'
                                        ? _incomeColor
                                        : _expenseColor;

                                    return _transactionCard(
                                      scale: scale,
                                      dateLabel: dateLabel,
                                      dayLabel: dayLabel,
                                      accounts: accounts,
                                      category: category,
                                      narration: narration,
                                      amount: amount,
                                      balance: balance,
                                      type: type,
                                      amountColor: amountColor,
                                      onTap: () => _showActionsForDoc(doc),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(height: 8 * scale),
                              _buildFooter(
                                  displayIncome, displayExpense, displayBalance,
                                  scale: scale, boldStyle: boldText),
                            ],
                          );
                        },
                      ),
                    ),

                    SizedBox(height: 8 * scale),
                  ]),
            );
          }),
        ),
      ),
    );
  }
}
