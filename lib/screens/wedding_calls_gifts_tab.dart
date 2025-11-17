// lib/screens/wedding_calls_gifts_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import 'wedding_theme.dart';

class GiftsTab extends StatefulWidget {
  final List<Map<String, dynamic>> invited;
  const GiftsTab({super.key, required this.invited});

  @override
  State<GiftsTab> createState() => _GiftsTabState();
}

class _GiftsTabState extends State<GiftsTab> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, TextEditingController> _headCtrls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final g in widget.invited) {
      final id = (g['id'] ?? '').toString();
      final amt =
          (g['amount'] is num) ? (g['amount'] as num).toStringAsFixed(0) : '';
      _controllers[id] = TextEditingController(text: amt);
      final hasHeads = g['heads'] is num;
      _headCtrls[id] = TextEditingController(
          text: hasHeads ? (g['heads'] as num).toString() : '');
    }
  }

  @override
  void didUpdateWidget(covariant GiftsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final g in widget.invited) {
      final id = (g['id'] ?? '').toString();
      final amtNow =
          (g['amount'] is num) ? (g['amount'] as num).toStringAsFixed(0) : '';
      if (!_controllers.containsKey(id)) {
        _controllers[id] = TextEditingController(text: amtNow);
      } else if (_controllers[id]!.text.trim() != amtNow) {
        _controllers[id]!.text = amtNow;
      }

      final hasHeadsNow = g['heads'] is num;
      final headsNow = hasHeadsNow ? (g['heads'] as num).toInt() : null;
      if (!_headCtrls.containsKey(id)) {
        _headCtrls[id] = TextEditingController(
            text: hasHeadsNow ? headsNow!.toString() : '');
      } else {
        final currentTxt = _headCtrls[id]!.text.trim();
        final currentParsed = int.tryParse(currentTxt);
        if (hasHeadsNow) {
          if (currentParsed != headsNow)
            _headCtrls[id]!.text = headsNow!.toString();
        } else {
          if (currentTxt.isNotEmpty) _headCtrls[id]!.text = '';
        }
      }
    }

    final current =
        widget.invited.map((g) => (g['id'] ?? '').toString()).toSet();
    for (final k
        in _controllers.keys.where((k) => !current.contains(k)).toList()) {
      _controllers[k]?.dispose();
      _controllers.remove(k);
    }
    for (final k
        in _headCtrls.keys.where((k) => !current.contains(k)).toList()) {
      _headCtrls[k]?.dispose();
      _headCtrls.remove(k);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    for (final c in _headCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _saveOne(Map<String, dynamic> g) async {
    final id = (g['id'] ?? '').toString();
    final amtCtrl = _controllers[id];
    final headCtrl = _headCtrls[id];
    if (amtCtrl == null || headCtrl == null) return;

    final amount = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
    final headsTxt = headCtrl.text.trim();
    final headsVal = headsTxt.isEmpty ? null : int.tryParse(headsTxt);

    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'hasAmount': amount > 0,
        'amount': amount,
        'receivedAt': amount > 0 ? DateTime.now().toIso8601String() : null,
        'heads': headsVal,
      };
      await FirestoreService.updateWeddingGuest(id, data);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.compactCurrency(
      symbol: '₹',
      decimalDigits: 0,
    );

    final giftEntries = <Map<String, dynamic>>[];
    double totalGiftValue = 0;
    int totalHeads = 0;
    final now = DateTime.now();
    int recentGiftCount = 0;

    for (final g in widget.invited) {
      final hasGift = g['hasAmount'] == true;
      final heads = (g['heads'] is num) ? (g['heads'] as num).toInt() : 0;
      totalHeads += heads;

      if (hasGift) {
        final amount =
            (g['amount'] is num) ? (g['amount'] as num).toDouble() : 0.0;
        totalGiftValue += amount;
        giftEntries.add(g);

        final receivedRaw = g['receivedAt']?.toString();
        if (receivedRaw != null && receivedRaw.isNotEmpty) {
          final received = DateTime.tryParse(receivedRaw);
          if (received != null && now.difference(received).inDays <= 7) {
            recentGiftCount += 1;
          }
        }
      }
    }

    giftEntries.sort((a, b) {
      final av = (a['amount'] is num) ? (a['amount'] as num).toDouble() : 0.0;
      final bv = (b['amount'] is num) ? (b['amount'] as num).toDouble() : 0.0;
      return bv.compareTo(av);
    });

    final averageGift = giftEntries.isEmpty
        ? 0.0
        : totalGiftValue / giftEntries.length.toDouble();
    final topContributor = giftEntries.isNotEmpty ? giftEntries.first : null;
    final pendingGifts = widget.invited.length - giftEntries.length;

    final insights = _generateGiftInsights(
      totalGuests: widget.invited.length,
      totalHeads: totalHeads,
      giftContributors: giftEntries.length,
      averageGift: averageGift,
      totalGiftValue: totalGiftValue,
      recentGiftCount: recentGiftCount,
      pendingGifts: pendingGifts,
      topContributor: topContributor,
    );

    return ListView(
      key: const PageStorageKey('gifts_list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _buildHeroSummary(
          currency: currency,
          totalGuests: widget.invited.length,
          giftContributors: giftEntries.length,
          totalGiftValue: totalGiftValue,
          averageGift: averageGift,
          recentGiftCount: recentGiftCount,
          topContributor: topContributor,
        ),
        const SizedBox(height: 16),
        _buildInsightsCard(insights),
        const SizedBox(height: 16),
        _buildGiftManagementHeader(pendingGifts),
        const SizedBox(height: 12),
        for (final g in widget.invited) _buildGiftCard(g, currency),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHeroSummary({
    required NumberFormat currency,
    required int totalGuests,
    required int giftContributors,
    required double totalGiftValue,
    required double averageGift,
    required int recentGiftCount,
    required Map<String, dynamic>? topContributor,
  }) {
    final topName = (topContributor?['name'] ?? '').toString();
    final topAmount = topContributor == null
        ? 0.0
        : (topContributor['amount'] is num)
            ? (topContributor['amount'] as num).toDouble()
            : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A202B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gift performance snapshot',
            style: TextStyle(
              color: weddingOnSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _heroMetric(
                label: 'Total gifts logged',
                value: currency.format(totalGiftValue),
                helper:
                    '$giftContributors of $totalGuests guests have contributed',
                icon: Icons.card_giftcard_outlined,
                color: Colors.pinkAccent,
              ),
              _heroMetric(
                label: 'Average gift value',
                value: currency.format(averageGift),
                helper: giftContributors == 0
                    ? 'No gift amounts yet'
                    : 'Across $giftContributors recorded gifts',
                icon: Icons.insights_outlined,
                color: weddingAccent,
              ),
              _heroMetric(
                label: 'Gifts this week',
                value: '$recentGiftCount',
                helper: recentGiftCount == 0
                    ? 'No recent gift updates'
                    : 'Logged in the last 7 days',
                icon: Icons.bolt_outlined,
                color: Colors.orangeAccent,
              ),
              _heroMetric(
                label: 'Top contributor',
                value: topName.isEmpty ? '—' : topName,
                helper: topAmount == 0
                    ? 'Awaiting your first gift entry'
                    : currency.format(topAmount),
                icon: Icons.emoji_events_outlined,
                color: Colors.amberAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric({
    required String label,
    required String value,
    required String helper,
    required IconData icon,
    required Color color,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180, minWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF212734),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25), width: 0.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: weddingOnSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              helper,
              style: const TextStyle(
                color: weddingOnSurfaceMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsCard(List<String> insights) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D2330),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI gift playbook',
            style: TextStyle(
              color: weddingOnSurface,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (insights.isEmpty)
            const Text(
              'Keep logging contributions to unlock personalised suggestions.',
              style: TextStyle(color: weddingOnSurfaceMuted, fontSize: 12),
            )
          else
            Column(
              children: insights
                  .map(
                    (insight) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Icon(Icons.auto_awesome_outlined,
                                size: 15, color: weddingAccent),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              insight,
                              style: const TextStyle(
                                color: weddingOnSurface,
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildGiftManagementHeader(int pendingGifts) {
    return Row(
      children: [
        const Icon(Icons.manage_accounts_outlined,
            size: 18, color: weddingAccent),
        const SizedBox(width: 8),
        const Text(
          'Manage guest gifts',
          style: TextStyle(
            color: weddingOnSurface,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        if (pendingGifts > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$pendingGifts pending',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGiftCard(Map<String, dynamic> g, NumberFormat currency) {
    final id = (g['id'] ?? '').toString();
    final name = (g['name'] ?? '').toString();
    final place = (g['place'] ?? '').toString();
    final relation = (g['relation'] ?? '').toString();
    final amount =
        (g['amount'] is num) ? (g['amount'] as num).toDouble() : 0.0;
    final hasGift = g['hasAmount'] == true;
    final receivedAt = g['receivedAt']?.toString();
    final receivedDate = receivedAt == null || receivedAt.isEmpty
        ? null
        : DateTime.tryParse(receivedAt);

    final amtCtrl = _controllers[id]!;
    final headCtrl = _headCtrls[id]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181E29),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.22)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? 'Unnamed guest' : name,
                  style: const TextStyle(
                    color: weddingOnSurface,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasGift)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Logged',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Awaiting gift',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (place.isNotEmpty)
                _infoChip(Icons.location_pin, place, weddingOnSurfaceMuted),
              if (relation.isNotEmpty)
                _infoChip(Icons.groups_outlined, relation,
                    weddingOnSurfaceMuted),
              if (hasGift)
                _infoChip(Icons.currency_rupee_outlined,
                    currency.format(amount), Colors.pinkAccent),
              if (receivedDate != null)
                _infoChip(Icons.today_outlined,
                    DateFormat('dd MMM').format(receivedDate),
                    weddingOnSurfaceMuted),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: amtCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Gift amount',
                    prefixText: '₹ ',
                  ),
                  style: const TextStyle(
                    color: weddingOnSurface,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: headCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'No. of heads',
                  ),
                  style: const TextStyle(
                    color: weddingOnSurface,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _saving ? null : () => _saveOne(g),
                style: ElevatedButton.styleFrom(
                  backgroundColor: weddingAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(_saving ? 'Saving...' : 'Save gift'),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () {
                  amtCtrl.clear();
                  headCtrl.clear();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Input cleared – remember to save changes'),
                    ),
                  );
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF242B39),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }

  List<String> _generateGiftInsights({
    required int totalGuests,
    required int totalHeads,
    required int giftContributors,
    required double averageGift,
    required double totalGiftValue,
    required int recentGiftCount,
    required int pendingGifts,
    required Map<String, dynamic>? topContributor,
  }) {
    final insights = <String>[];

    if (giftContributors == 0) {
      insights.add(
        'No gift amounts recorded yet. Capture the first contribution to unlock deeper insights.',
      );
    } else {
      insights.add(
        'Average gift value is ₹${averageGift.toStringAsFixed(0)} across $giftContributors contributors. Consider sending personalised thanks.',
      );
    }

    if (pendingGifts > 0) {
      final pct = totalGuests == 0
          ? 0
          : (pendingGifts / totalGuests * 100).round();
      insights.add(
        '$pendingGifts guests (${pct.toString()}%) are yet to be logged. Prioritise follow-up calls to confirm their gifts.',
      );
    }

    if (recentGiftCount > 0) {
      insights.add(
        '$recentGiftCount gifts logged this week. Keep momentum by acknowledging them promptly.',
      );
    }

    final topName = (topContributor?['name'] ?? '').toString();
    if (topName.isNotEmpty) {
      final topAmount = (topContributor?['amount'] is num)
          ? (topContributor?['amount'] as num).toDouble()
          : 0.0;
      if (topAmount > 0) {
        insights.add(
          '$topName leads with a gift of ₹${topAmount.toStringAsFixed(0)}. Send a personalised gratitude message.',
        );
      }
    }

    if (totalHeads > totalGuests) {
      insights.add(
        'You have $totalHeads heads logged across $totalGuests guests. Double-check large group entries for completeness.',
      );
    }

    if (totalGiftValue == 0 && pendingGifts == 0 && giftContributors > 0) {
      insights.add(
        'Gift data captured, but values are zero. Update gift amounts to unlock budget planning insights.',
      );
    }

    return insights.take(5).toList();
  }
}
