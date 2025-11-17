// lib/screens/wedding_calls_calls_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <<-- required for FilteringTextInputFormatter
import '../services/firestore_service.dart';
import 'wedding_theme.dart';
import 'wedding_guest_form_sheet.dart';
import 'wedding_guest_edit_sheet.dart';
import '../widgets/section_header.dart';

class CallsTab extends StatelessWidget {
  final List<Map<String, dynamic>> invited;
  final List<Map<String, dynamic>> notInvited;
  final List<String> places;
  final Set<String> existingKeys;

  const CallsTab({
    super.key,
    required this.invited,
    required this.notInvited,
    required this.places,
    required this.existingKeys,
  });

  Future<void> _toggleInvited(
      BuildContext ctx, Map<String, dynamic> g, bool value) async {
    final id = (g['id'] ?? '').toString();
    await FirestoreService.updateWeddingGuest(id, {
      'invited': value,
      'invitedAt': value ? DateTime.now().toIso8601String() : null,
    });
    if (ctx.mounted)
      ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(value ? 'Marked invited' : 'Unmarked')));
  }

  Future<void> _editAmount(BuildContext ctx, Map<String, dynamic> g) async {
    final id = (g['id'] ?? '').toString();
    final TextEditingController c = TextEditingController(
      text: (g['amount'] is num) ? (g['amount'] as num).toStringAsFixed(0) : '',
    );

    await showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: weddingSurface,
        title: const Text(
          'Add / Update Amount',
          style: TextStyle(color: weddingOnSurface),
        ),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            // allow digits and optional decimal point (up to 2 decimals)
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            hintText: '₹',
            hintStyle: TextStyle(color: weddingOnSurfaceMuted, fontSize: 12),
            filled: true,
            fillColor: Color(0xFF1E2024),
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(color: weddingOnSurface, fontSize: 13),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(fontSize: 12))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: weddingAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            onPressed: () async {
              final amt = double.tryParse(c.text.trim()) ?? 0.0;
              await FirestoreService.updateWeddingGuest(id, {
                'hasAmount': amt > 0,
                'amount': amt,
                'receivedAt': amt > 0 ? DateTime.now().toIso8601String() : null,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (ctx.mounted)
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(const SnackBar(content: Text('Saved')));
            },
            child: const Text('Save', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _editGuest(BuildContext ctx, Map<String, dynamic> g) async {
    await showModalBottomSheet(
      context: ctx,
      backgroundColor: weddingSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => GuestEditSheet(initial: g, places: places),
    );
  }

  Future<void> _delete(BuildContext ctx, Map<String, dynamic> g) async {
    final id = (g['id'] ?? '').toString();
    final name = (g['name'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: weddingSurface,
        title: const Text('Delete guest?',
            style: TextStyle(color: weddingOnSurface)),
        content: Text('Remove $name?',
            style: const TextStyle(color: weddingOnSurfaceMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirestoreService.deleteWeddingGuest(id);
      if (ctx.mounted)
        ScaffoldMessenger.of(ctx)
            .showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (e) {
      if (ctx.mounted)
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Widget _row(BuildContext ctx, Map<String, dynamic> g) {
    const titleStyle = TextStyle(
        color: weddingOnSurface, fontSize: 13, fontWeight: FontWeight.w500);
    const subStyle = TextStyle(color: weddingOnSurfaceMuted, fontSize: 11);

    final name = (g['name'] ?? '').toString();
    final place = (g['place'] ?? '').toString();
    final phone = (g['phone'] ?? '').toString();
    final relation = (g['relation'] ?? '').toString();
    final invitedFlag = g['invited'] == true;
    final amount = (g['amount'] is num) ? (g['amount'] as num).toDouble() : 0.0;
    final createdAt = g['createdAt']?.toString();

    final subParts = <Widget>[];
    if (place.trim().isNotEmpty)
      subParts.add(Text(place,
          style: subStyle, maxLines: 1, overflow: TextOverflow.ellipsis));
    if (phone.trim().isNotEmpty)
      subParts.add(Text(phone,
          style: subStyle, maxLines: 1, overflow: TextOverflow.ellipsis));
    if (relation.trim().isNotEmpty)
      subParts.add(Text(relation,
          style: subStyle, maxLines: 1, overflow: TextOverflow.ellipsis));
    if ((createdAt ?? '').isNotEmpty)
      subParts
          .add(Text('Added: ${_formatDateIso(createdAt)}', style: subStyle));

    return ListTile(
      dense: true,
      title: Text(name, style: titleStyle, overflow: TextOverflow.ellipsis),
      subtitle: subParts.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: subParts),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (invitedFlag)
            const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check_circle, color: Colors.green, size: 16)),
          if (amount > 0) const SizedBox(width: 4),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon:
                const Icon(Icons.more_vert, color: weddingOnSurface, size: 18),
            constraints: const BoxConstraints(minWidth: 170),
            onSelected: (v) {
              if (v == 'toggle_invited') {
                _toggleInvited(ctx, g, !invitedFlag);
              } else if (v == 'edit_amount') {
                _editAmount(ctx, g);
              } else if (v == 'edit_guest') {
                _editGuest(ctx, g);
              } else if (v == 'delete') {
                _delete(ctx, g);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'toggle_invited',
                  height: 36,
                  child: Row(children: [
                    Icon(invitedFlag ? Icons.undo : Icons.check, size: 16),
                    const SizedBox(width: 6),
                    Text(invitedFlag ? 'Unmark Invited' : 'Mark Invited',
                        style: const TextStyle(fontSize: 12))
                  ])),
              PopupMenuItem(
                  value: 'edit_amount',
                  height: 36,
                  child: Row(children: const [
                    Icon(Icons.currency_rupee, size: 16),
                    SizedBox(width: 6),
                    Text('Add / Update Amount', style: TextStyle(fontSize: 12))
                  ])),
              PopupMenuItem(
                  value: 'edit_guest',
                  height: 36,
                  child: Row(children: const [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 6),
                    Text('Edit Guest', style: TextStyle(fontSize: 12))
                  ])),
              const PopupMenuDivider(),
              PopupMenuItem(
                  value: 'delete',
                  height: 36,
                  child: Row(children: const [
                    Icon(Icons.delete, size: 16, color: Colors.redAccent),
                    SizedBox(width: 6),
                    Text('Delete', style: TextStyle(fontSize: 12))
                  ])),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (invited.isEmpty && notInvited.isEmpty)
          const Center(
            child: Text(
              'No guests yet.\nTap the + button to add your first guest.',
              textAlign: TextAlign.center,
              style: TextStyle(color: weddingOnSurfaceMuted, fontSize: 12),
            ),
          )
        else
          ListView(
            key: const PageStorageKey('calls_list'),
            padding: const EdgeInsets.only(bottom: 70),
            children: [
              if (notInvited.isNotEmpty)
                const SectionHeader(title: 'Not Invited'),
              ...notInvited.map((g) => _row(context, g)),
              if (invited.isNotEmpty)
                const Divider(height: 1, color: weddingDivider),
              if (invited.isNotEmpty) const SectionHeader(title: 'Invited'),
              ...invited.map((g) => _row(context, g)),
            ],
          ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: weddingAccent,
            onPressed: () => _openAdd(context),
            child: const Icon(Icons.person_add, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  Future<void> _openAdd(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: weddingSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) =>
          GuestFormSheet(places: places, existingKeys: existingKeys),
    );
  }
}

String _formatDateIso(String? iso) {
  if (iso == null || iso.trim().isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ][dt.month - 1];
    final yy = dt.year;
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd $mm $yy, $hh:$min';
  } catch (_) {
    return iso;
  }
}
