// lib/widgets/transaction_list.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TransactionList extends StatelessWidget {
  final FirebaseFirestore db;
  final int streamVersion;
  final Future<void> Function(DocumentSnapshot doc) onEdit;
  final Future<void> Function(String id) onDelete;
  final Future<bool?> Function(BuildContext) confirmDelete;
  final double openingBalance;
  final List<String> categoryList;

  // Colors & theming (passed from the parent)
  final Color primaryColor;
  final Color cardBg;
  final Color darkCard;
  final Color chipBg;
  final Color darkOnCard;
  final Color textPrimary;
  final Color accentColor;
  final Color incomeColor;
  final Color expenseColor;

  TransactionList({
    Key? key,
    required this.db,
    required this.streamVersion,
    required this.onEdit,
    required this.onDelete,
    required this.confirmDelete,
    required this.openingBalance,
    required this.categoryList,
    required this.primaryColor,
    required this.cardBg,
    required this.darkCard,
    required this.chipBg,
    required this.darkOnCard,
    required this.textPrimary,
    required this.accentColor,
    required this.incomeColor,
    required this.expenseColor,
  }) : super(key: key);

  // NumberFormat is NOT const — initialize normally.
  final NumberFormat _moneyFmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  Future<void> _showActionsForDoc(
      BuildContext context, DocumentSnapshot doc) async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: darkCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (c) {
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: Icon(Icons.edit, color: accentColor),
              title: Text('Edit', style: TextStyle(color: darkOnCard)),
              onTap: () => Navigator.of(c).pop('edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete, color: expenseColor),
              title: Text('Delete', style: TextStyle(color: darkOnCard)),
              onTap: () => Navigator.of(c).pop('delete'),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.close, color: Colors.white70),
              title: Text('Cancel', style: TextStyle(color: Colors.white70)),
              onTap: () => Navigator.of(c).pop(null),
            ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );

    if (result == 'edit') {
      await onEdit(doc);
    } else if (result == 'delete') {
      final confirmed = await confirmDelete(context);
      if (confirmed == true) {
        await onDelete(doc.id);
      }
    }
  }

  Widget _buildFooter(
      double incomeToday, double expenseToday, double balanceToday) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rowSmallText = TextStyle(fontSize: 10, color: textPrimary);
    final headingTextStyle = TextStyle(
        fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary);

    return StreamBuilder<QuerySnapshot>(
      key: ValueKey(streamVersion),
      stream: db
          .collection('transactions')
          .orderBy('dateTs', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final err = snapshot.error.toString();
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, color: expenseColor, size: 36),
              const SizedBox(height: 8),
              Text('Error loading data', style: TextStyle(color: darkOnCard)),
              const SizedBox(height: 6),
              Text(err,
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => (context as Element).markNeedsBuild(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              ),
            ]),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('No transactions found.', style: TextStyle(color: darkOnCard)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => (context as Element).markNeedsBuild(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            ),
          ]));
        }

        final docs = snapshot.data!.docs;

        // calculate today's totals
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = todayStart.add(const Duration(days: 1));
        double totalExpToday = 0, totalIncToday = 0;
        double? lastBalanceToday;
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>? ?? {};
          final amt =
              (d['amount'] is num) ? (d['amount'] as num).toDouble() : 0.0;
          final type = (d['type'] ?? 'EXPENSE').toString();
          final ts = d['dateTs'] is Timestamp
              ? (d['dateTs'] as Timestamp).toDate()
              : null;
          if (ts != null && !ts.isBefore(todayStart) && ts.isBefore(todayEnd)) {
            if (type == 'INCOME')
              totalIncToday += amt;
            else
              totalExpToday += amt;
            final bal =
                (d['balance'] is num) ? (d['balance'] as num).toDouble() : null;
            if (bal != null) lastBalanceToday = bal;
          }
        }
        final displayIncome = totalIncToday;
        final displayExpense = totalExpToday;
        final displayBalance = lastBalanceToday ?? openingBalance;

        return LayoutBuilder(builder: (context, constraints) {
          final avail = constraints.maxWidth;
          final isSmall = avail < 480;

          if (isSmall) {
            // compact list for phones (tap row to open actions)
            return Column(children: [
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemBuilder: (context, idx) {
                    final doc = docs[idx];
                    final d = doc.data() as Map<String, dynamic>? ?? {};
                    final ts = d['dateTs'] is Timestamp
                        ? (d['dateTs'] as Timestamp).toDate()
                        : null;
                    final dateStr = ts != null
                        ? DateFormat('dd/MM').format(ts)
                        : (d['date'] ?? '').toString();
                    final acc =
                        "${d['accountDr'] ?? ''} → ${d['accountCr'] ?? ''}";
                    final category = (d['category'] ?? '').toString();
                    final amtNum = (d['amount'] is num)
                        ? (d['amount'] as num).toDouble()
                        : 0.0;
                    final amt = _moneyFmt.format(amtNum);
                    final balNum = (d['balance'] is num)
                        ? (d['balance'] as num).toDouble()
                        : 0.0;
                    final bal = _moneyFmt.format(balNum);
                    final type = (d['type'] ?? 'EXPENSE').toString();

                    return Card(
                      color: cardBg,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(dateStr,
                                  style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ]),
                        title: Text(acc,
                            style: TextStyle(color: textPrimary, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                        subtitle: Row(children: [
                          Expanded(
                              child: Text(category,
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                  overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Text(amt,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: type == 'INCOME'
                                      ? incomeColor
                                      : expenseColor)),
                        ]),
                        // reduced width for balance, smaller font
                        trailing: SizedBox(
                          width: 64,
                          child: Text(bal,
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis),
                        ),
                        onTap: () async =>
                            await _showActionsForDoc(context, doc),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              _buildFooter(displayIncome, displayExpense, displayBalance),
            ]);
          }

          // larger screens: compact DataTable (no checkbox column)
          final minWidth = avail;

          return Column(children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minWidth),
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowColor:
                        WidgetStateProperty.all(const Color(0xFF0F1A26)),
                    dataRowColor: WidgetStateProperty.all(cardBg),
                    dataRowMinHeight: 22, // smaller rows
                    dataRowMaxHeight: 28,
                    headingRowHeight: 24,
                    border: TableBorder.all(color: const Color(0xFF1B2A37)),
                    columnSpacing: 6, // 👈 reduced spacing between columns
                    headingTextStyle: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textPrimary),
                    columns: const <DataColumn>[
                      DataColumn(label: Text("DT")),
                      DataColumn(label: Text("AC")),
                      DataColumn(label: Text("CAT")),
                      DataColumn(label: Text("AMT")),
                      DataColumn(label: Text("BAL")),
                    ],
                    rows: docs.map((doc) {
                      final d = doc.data() as Map<String, dynamic>? ?? {};
                      String shortDate;
                      if (d['dateTs'] is Timestamp) {
                        final dt = (d['dateTs'] as Timestamp).toDate();
                        shortDate = DateFormat('dd/MM').format(dt);
                      } else if (d['date'] != null) {
                        final s = d['date'].toString();
                        final parts = s.split('/');
                        shortDate =
                            parts.length >= 2 ? '${parts[0]}/${parts[1]}' : s;
                      } else {
                        shortDate = '';
                      }

                      final acc =
                          "${d['accountDr'] ?? ''}→${d['accountCr'] ?? ''}";
                      final category = (d['category'] ?? '').toString();
                      final amtNum = (d['amount'] is num)
                          ? (d['amount'] as num).toDouble()
                          : 0.0;
                      final amt = _moneyFmt.format(amtNum);
                      final balNum = (d['balance'] is num)
                          ? (d['balance'] as num).toDouble()
                          : 0.0;
                      final bal = _moneyFmt.format(balNum);
                      final type = (d['type'] ?? 'EXPENSE').toString();

                      return DataRow(
                        onSelectChanged: (sel) {
                          if (sel == true) _showActionsForDoc(context, doc);
                        },
                        cells: <DataCell>[
                          DataCell(SizedBox(
                              width: 32,
                              child: Text(shortDate,
                                  style: TextStyle(
                                      fontSize: 10, color: textPrimary),
                                  overflow: TextOverflow.ellipsis))),
                          DataCell(SizedBox(
                              width: 90,
                              child: Text(acc,
                                  style: TextStyle(
                                      fontSize: 10, color: textPrimary),
                                  overflow: TextOverflow.ellipsis))),
                          DataCell(SizedBox(
                              width: 80,
                              child: Text(category,
                                  style: TextStyle(
                                      fontSize: 10, color: textPrimary),
                                  overflow: TextOverflow.ellipsis))),
                          DataCell(SizedBox(
                              width: 60,
                              child: Text(amt,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: type == 'INCOME'
                                          ? incomeColor
                                          : expenseColor,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis))),
                          DataCell(SizedBox(
                              width: 55,
                              child: Text(bal,
                                  style: TextStyle(
                                      fontSize: 10, color: accentColor),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildFooter(displayIncome, displayExpense, displayBalance),
          ]);
        });
      },
    );
  }
}
