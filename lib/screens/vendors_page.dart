// lib/screens/vendors_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'wedding_theme.dart';

/// VendorsPage: manage 'vendors' Firestore collection (live list, add, edit, delete).
class VendorsPage extends StatefulWidget {
  const VendorsPage({super.key});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  final _col = FirebaseFirestore.instance.collection('vendors');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: weddingBg,
      appBar: AppBar(
        title: const Text('Vendors'),
        backgroundColor: weddingSurface,
        centerTitle: true,
        elevation: 1,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: weddingAccent,
        icon: const Icon(Icons.add),
        label: const Text('Add vendor'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
                child: Text('Error: ${snap.error}',
                    style: TextStyle(color: weddingOnSurface)));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.storefront, size: 64, color: weddingOnSurfaceMuted),
                const SizedBox(height: 12),
                Text('No vendors yet',
                    style: TextStyle(color: weddingOnSurfaceMuted)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _openEditor(context),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: weddingAccent),
                  child: const Text('Add first vendor'),
                )
              ]),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final name = (data['name'] ?? '').toString();
              final phone = (data['phone'] ?? '').toString();
              final place = (data['place'] ?? '').toString();

              return Dismissible(
                key: ValueKey(d.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _deleteWithUndo(context, d),
                child: Card(
                  color: weddingSurface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: weddingAccent,
                      child: Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: TextStyle(
                            color: weddingSurface, fontWeight: FontWeight.w900),
                      ),
                    ),
                    title: Text(name.isEmpty ? '(no name)' : name,
                        style: TextStyle(
                            color: weddingOnSurface,
                            fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      [if (place.isNotEmpty) place, if (phone.isNotEmpty) phone]
                          .join(' • '),
                      style: TextStyle(color: weddingOnSurfaceMuted),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _openEditor(context, doc: d);
                        if (v == 'delete') _confirmDelete(context, d);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () => _openEditor(context, doc: d),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext ctx,
      {QueryDocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final existing = doc?.data() ?? <String, dynamic>{};
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.56,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: weddingSurface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16))),
          child: SingleChildScrollView(
            controller: ctrl,
            child: _VendorEditorForm(initial: existing),
          ),
        ),
      ),
    );

    if (result == null) return;

    try {
      if (doc != null) {
        await _col.doc(doc.id).update({
          'name': result['name'],
          'phone': result['phone'],
          'place': result['place'],
        });
      } else {
        await _col.add({
          'name': result['name'],
          'phone': result['phone'],
          'place': result['place'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted)
        ScaffoldMessenger.of(ctx)
            .showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _confirmDelete(
      BuildContext ctx, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: weddingSurface,
        title: const Text('Delete vendor?',
            style: TextStyle(color: weddingOnSurface)),
        content: const Text(
            'This will remove the vendor. You can undo the delete from the snackbar.',
            style: TextStyle(color: weddingOnSurfaceMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) _deleteWithUndo(ctx, doc);
  }

  Future<void> _deleteWithUndo(
      BuildContext ctx, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    // ignore: unused_local_variable
    final snapshotId = doc.id;
    try {
      await doc.reference.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).clearSnackBars();
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('Deleted "${(data['name'] ?? '').toString()}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await _col.add({
                'name': data['name'] ?? '',
                'phone': data['phone'] ?? '',
                'place': data['place'] ?? '',
                'createdAt': FieldValue.serverTimestamp(),
              });
            } catch (e) {
              if (mounted)
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(SnackBar(content: Text('Undo failed: $e')));
            }
          },
        ),
      ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }
}

/// Bottom sheet form used for Add/Edit vendor.
class _VendorEditorForm extends StatefulWidget {
  final Map<String, dynamic> initial;
  const _VendorEditorForm({this.initial = const {}});

  @override
  State<_VendorEditorForm> createState() => _VendorEditorFormState();
}

class _VendorEditorFormState extends State<_VendorEditorForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _phoneC;
  late final TextEditingController _placeC;

  @override
  void initState() {
    super.initState();
    _nameC =
        TextEditingController(text: widget.initial['name']?.toString() ?? '');
    _phoneC =
        TextEditingController(text: widget.initial['phone']?.toString() ?? '');
    _placeC =
        TextEditingController(text: widget.initial['place']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _placeC.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final out = {
      'name': _nameC.text.trim(),
      'phone': _phoneC.text.trim(),
      'place': _placeC.text.trim(),
    };
    Navigator.pop(context, out);
  }

  String? _phoneValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final digits = s.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.length < 6) return 'Enter a valid phone';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial.isNotEmpty;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(isEdit ? 'Edit Vendor' : 'New Vendor',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: weddingOnSurface))),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, color: weddingOnSurface))
        ]),
        const SizedBox(height: 8),
        Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _nameC,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder()),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter vendor name' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneC,
              decoration: const InputDecoration(
                  labelText: 'Phone (optional)', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
              validator: _phoneValidator,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _placeC,
              decoration: const InputDecoration(
                  labelText: 'Place (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: weddingAccent),
              child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Save',
                      style: TextStyle(fontWeight: FontWeight.w800))),
            ),
            const SizedBox(height: 12),
          ]),
        ),
      ]),
    );
  }
}
