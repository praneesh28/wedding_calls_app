// lib/screens/wedding_calls_page.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'wedding_theme.dart';
import 'wedding_calls_calls_tab.dart';
import 'wedding_calls_gifts_tab.dart';
import 'wedding_filters_sheet.dart';
import 'wedding_report_page.dart';
import 'package:intl/intl.dart';

class WeddingCallsPage extends StatefulWidget {
  const WeddingCallsPage({super.key});
  @override
  State<WeddingCallsPage> createState() => _WeddingCallsPageState();
}

class _WeddingCallsPageState extends State<WeddingCallsPage> {
  int _tab = 0; // 0 = Calls, 1 = Gifts

  // Search + debounce
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _deb;

  // Filters (includes sort)
  ListFilter _filter = ListFilter();

  // Keep one stream instance to avoid flicker
  late final Stream<List<Map<String, dynamic>>> _guestsStream;

  @override
  void initState() {
    super.initState();
    _guestsStream = FirestoreService.streamWeddingGuests();
  }

  @override
  void dispose() {
    _deb?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = v.trim().toLowerCase());
    });
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: weddingSurface,
        title:
            const Text('Log out?', style: TextStyle(color: weddingOnSurface)),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: weddingOnSurfaceMuted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, log out')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Use kIsWeb to avoid dart:io import which fails on web builds.
      if (!kIsWeb) {
        // On mobile platforms this attempts to close the app.
        SystemNavigator.pop();
      } else {
        // Web or other platforms: return to root route.
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  bool _matchesQuery(Map<String, dynamic> g, String q) {
    if (q.isEmpty) return true;
    final query = q.toLowerCase().trim();
    String norm(String? s) => (s ?? '').toString().toLowerCase().trim();

    bool wordStart(String hay) {
      for (final t in hay.split(RegExp(r'\s+'))) {
        if (t.startsWith(query)) return true;
      }
      return hay.contains(query);
    }

    final name = norm(g['name']?.toString());
    final place = norm(g['place']?.toString());
    final phone = norm(g['phone']?.toString());
    final relation = norm(g['relation']?.toString());
    final amount = (g['amount'] is num) ? (g['amount'] as num).toString() : '';
    final heads = (g['heads'] is num) ? (g['heads'] as num).toString() : '';

    return wordStart(name) ||
        wordStart(place) ||
        phone.contains(query) ||
        relation.contains(query) ||
        amount.contains(query) ||
        heads.contains(query);
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> all) {
    final filtered = all.where((g) {
      if (!_matchesQuery(g, _query)) return false;

      if (_filter.invitedOnly != null) {
        final inv = g['invited'] == true;
        if (inv != _filter.invitedOnly) return false;
      }

      if (_filter.relation.isNotEmpty) {
        final r = (g['relation'] ?? '').toString();
        if (r != _filter.relation) return false;
      }

      if (_filter.place.trim().isNotEmpty) {
        final p = (g['place'] ?? '').toString().toLowerCase();
        if (!p.contains(_filter.place.toLowerCase().trim())) return false;
      }

      if (_filter.hasAmount != null) {
        final has = g['hasAmount'] == true;
        if (has != _filter.hasAmount) return false;
      }

      final amt = (g['amount'] is num) ? (g['amount'] as num).toDouble() : 0.0;
      if (amt < _filter.minAmount || amt > _filter.maxAmount) return false;

      final heads = (g['heads'] is num) ? (g['heads'] as num).toInt() : 0;
      if (heads < _filter.minHeads || heads > _filter.maxHeads) return false;

      return true;
    }).toList();

    filtered.sort((a, b) {
      final an = (a['name'] ?? '').toString().toLowerCase().trim();
      final bn = (b['name'] ?? '').toString().toLowerCase().trim();
      final cmp = an.compareTo(bn);
      return _filter.sortAsc ? cmp : -cmp;
    });

    return filtered;
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: weddingSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => FiltersSheet(
        current: _filter,
        onApply: (nf) => setState(() => _filter = nf),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: weddingBg,
      appBar: AppBar(
        backgroundColor: weddingBg,
        elevation: 0,
        toolbarHeight: 56,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Wedding Calls',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: weddingOnSurface,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Track invites, gifts, and reminders',
              style: TextStyle(
                fontSize: 11,
                color: weddingOnSurfaceMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'AI Wedding Report',
            icon: const Icon(Icons.auto_graph_outlined,
                size: 20, color: weddingAccent),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WeddingReportPage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () => _confirmLogout(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _guestsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: weddingAccent, strokeWidth: 2),
              ),
            );
          }
          if (snap.hasError) {
            return const Center(
              child: Text(
                'Error loading',
                style: TextStyle(
                  color: weddingOnSurfaceMuted,
                  fontSize: 12,
                ),
              ),
            );
          }
          final all = snap.data ?? [];

          final sorted = _applyFilters(all);
          final invited = sorted.where((g) => g['invited'] == true).toList();
          final notInvited = sorted.where((g) => g['invited'] != true).toList();

          final invitedCount = all.where((e) => e['invited'] == true).length;
          final notInvitedCount = all.length - invitedCount;
          final giftsAmount = all.fold<double>(0.0, (s, g) {
            final a =
                (g['amount'] is num) ? (g['amount'] as num).toDouble() : 0.0;
            return s + ((g['hasAmount'] == true) ? a : 0.0);
          });
          final giftsCount = all.where((g) => g['hasAmount'] == true).length;
          final headsTotal = all.fold<int>(0, (s, g) {
            final h = (g['heads'] is num) ? (g['heads'] as num).toInt() : 0;
            return s + h;
          });

          final uniquePlaces = <String>{
            for (final g in all)
              if ((g['place'] ?? '').toString().trim().isNotEmpty)
                (g['place'] ?? '').toString().trim(),
          }.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          final existingKeys = <String>{
            for (final g in all)
              _dedupeKey(
                (g['name'] ?? '').toString(),
                (g['phone'] ?? '').toString(),
                (g['place'] ?? '').toString(),
              ),
          };

          return Column(
            children: [
              _buildSummarySection(
                total: all.length,
                invitedCount: invitedCount,
                notInvitedCount: notInvitedCount,
                giftsAmount: giftsAmount,
                giftsCount: giftsCount,
                headsTotal: headsTotal,
              ),
              _buildSearchAndFilters(context),
              Expanded(
                child: _tab == 0
                    ? CallsTab(
                        invited: invited,
                        notInvited: notInvited,
                        places: uniquePlaces,
                        existingKeys: existingKeys,
                      )
                    : GiftsTab(invited: invited),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: weddingSurface,
        selectedItemColor: weddingAccent,
        unselectedItemColor: weddingOnSurfaceMuted,
        iconSize: 18,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
          BottomNavigationBarItem(
              icon: Icon(Icons.card_giftcard), label: 'Gifts'),
        ],
      ),
    );
  }

  Widget _buildSummarySection({
    required int total,
    required int invitedCount,
    required int notInvitedCount,
    required double giftsAmount,
    required int giftsCount,
    required int headsTotal,
  }) {
    final currency =
        NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 0);
    final invitedPct = total == 0 ? 0 : ((invitedCount / total) * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A202B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.35)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Guest overview',
              style: TextStyle(
                color: weddingOnSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _summaryMetric(
                    icon: Icons.people_outline,
                    label: 'Guests',
                    value: '$total',
                    accent: weddingAccent,
                    helper: '$headsTotal heads',
                  ),
                  _summaryMetric(
                    icon: Icons.verified_outlined,
                    label: 'Invited',
                    value: '$invitedCount',
                    accent: weddingPos,
                    helper: '$invitedPct% confirmed',
                  ),
                  _summaryMetric(
                    icon: Icons.pending_actions_outlined,
                    label: 'Pending',
                    value: '$notInvitedCount',
                    accent: Colors.orangeAccent,
                    helper: '$notInvitedCount pending',
                  ),
                  _summaryMetric(
                    icon: Icons.card_giftcard_outlined,
                    label: 'Gifts',
                    value: currency.format(giftsAmount),
                    accent: Colors.pinkAccent,
                    helper: '$giftsCount entries',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildTotalAmountChip(currency.format(giftsAmount)),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        width: 108,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF212734),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.25), width: 0.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, color: accent, size: 12),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: weddingOnSurfaceMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (helper != null) ...[
              const SizedBox(height: 2),
              Text(
                helper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: weddingOnSurfaceMuted,
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotalAmountChip(String formattedTotal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: weddingAccent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: weddingAccent.withOpacity(0.4), width: 0.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.summarize_outlined, size: 16, color: weddingAccent),
          const SizedBox(width: 6),
          const Text(
            'Total gifts',
            style: TextStyle(
              color: weddingAccent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            formattedTotal,
            style: const TextStyle(
              color: weddingOnSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    final filterActive = _filter.invitedOnly != null ||
        _filter.relation.isNotEmpty ||
        _filter.place.trim().isNotEmpty ||
        _filter.hasAmount != null ||
        _filter.minAmount > 0 ||
        _filter.maxAmount < 1000000 ||
        _filter.minHeads > 0 ||
        _filter.maxHeads < 1000;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141A24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withOpacity(0.4)),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              style: const TextStyle(
                  color: weddingOnSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText:
                    'Search guests by name, relation, phone, or contribution…',
                hintStyle: const TextStyle(
                  color: weddingOnSurfaceMuted,
                  fontSize: 12,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: weddingOnSurfaceMuted),
                suffixIcon: (_query.isEmpty)
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close,
                            color: weddingOnSurfaceMuted, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChoiceChip(
                  label: 'All',
                  selected: _filter.invitedOnly == null,
                  onTap: () => setState(() => _filter.invitedOnly = null),
                ),
                _buildChoiceChip(
                  label: 'Invited',
                  selected: _filter.invitedOnly == true,
                  onTap: () => setState(() => _filter.invitedOnly = true),
                ),
                _buildChoiceChip(
                  label: 'Not invited',
                  selected: _filter.invitedOnly == false,
                  onTap: () => setState(() => _filter.invitedOnly = false),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF1C2230),
                  labelStyle: const TextStyle(
                    color: weddingAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  avatar: const Icon(Icons.filter_list,
                      size: 16, color: weddingAccent),
                  label: const Text('More filters'),
                  onPressed: _openFilters,
                ),
                const SizedBox(width: 8),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF1C2230),
                  labelStyle: const TextStyle(
                    color: weddingAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  avatar: Icon(
                    _filter.sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: weddingAccent,
                  ),
                  label: Text(_filter.sortAsc ? 'Sort A → Z' : 'Sort Z → A'),
                  onPressed: () =>
                      setState(() => _filter.sortAsc = !_filter.sortAsc),
                ),
              ],
            ),
          ),
          if (filterActive || !_filter.sortAsc)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton.icon(
                onPressed: () => setState(() => _filter = ListFilter()),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset advanced filters'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: weddingAccent.withOpacity(0.18),
        backgroundColor: const Color(0xFF1C2230),
        labelStyle: TextStyle(
          color: selected ? weddingAccent : weddingOnSurfaceMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? weddingAccent : Colors.transparent,
          ),
        ),
      ),
    );
  }
}

// ---------- Filters model ----------
class ListFilter {
  bool? invitedOnly;
  String relation;
  String place;
  bool? hasAmount;
  double minAmount;
  double maxAmount;
  int minHeads;
  int maxHeads;
  bool sortAsc;

  ListFilter({
    this.invitedOnly,
    this.relation = '',
    this.place = '',
    this.hasAmount,
    this.minAmount = 0,
    this.maxAmount = 1000000,
    this.minHeads = 0,
    this.maxHeads = 1000,
    this.sortAsc = true,
  });

  ListFilter copy() => ListFilter(
        invitedOnly: invitedOnly,
        relation: relation,
        place: place,
        hasAmount: hasAmount,
        minAmount: minAmount,
        maxAmount: maxAmount,
        minHeads: minHeads,
        maxHeads: maxHeads,
        sortAsc: sortAsc,
      );
}

// ---------- Helpers ----------
String _toTitleCase(String input) {
  final s = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (s.isEmpty) return s;
  return s
      .split(' ')
      .map((w) => w.isEmpty
          ? w
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}

String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

String _dedupeKey(String name, String phone, String place) {
  final n = _toTitleCase(name);
  final p = _digitsOnly(phone);
  final pl = _toTitleCase(place);
  return '${n.trim()}|${p.trim()}|${pl.trim()}';
}
