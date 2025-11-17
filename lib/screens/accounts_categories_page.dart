// lib/screens/accounts_categories_page.dart
// Material 3 Card-based CRUD UI for Accounts & Categories

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'wedding_theme.dart';

class AccountsCategoriesPage extends StatefulWidget {
  const AccountsCategoriesPage({super.key});
  @override
  State<AccountsCategoriesPage> createState() => _AccountsCategoriesPageState();
}

class _AccountsCategoriesPageState extends State<AccountsCategoriesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: weddingBg,
      appBar: AppBar(
        backgroundColor: weddingSurface,
        title: const Text('Accounts & Categories',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: weddingOnSurfaceMuted),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: weddingSurface,
            child: TabBar(
              controller: _tab,
              labelColor: weddingAccent,
              unselectedLabelColor: weddingOnSurfaceMuted,
              indicatorColor: weddingAccent,
              tabs: const [
                Tab(icon: Icon(Icons.account_balance_wallet), text: 'Accounts'),
                Tab(icon: Icon(Icons.category), text: 'Categories'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: const [
                FirestoreCrudTab(
                    collectionName: 'accounts', labelText: 'Account'),
                FirestoreCrudTab(
                    collectionName: 'categories', labelText: 'Category'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FirestoreCrudTab extends StatefulWidget {
  final String collectionName;
  final String labelText;

  const FirestoreCrudTab({
    super.key,
    required this.collectionName,
    required this.labelText,
  });

  @override
  State<FirestoreCrudTab> createState() => _FirestoreCrudTabState();
}

class _FirestoreCrudTabState extends State<FirestoreCrudTab> {
  final _db = FirebaseFirestore.instance;

  Future<void> _showAddOrEditDialog({String? id, String? currentName}) async {
    final controller = TextEditingController(text: currentName ?? '');
    final isEdit = id != null;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            isEdit ? 'Edit ${widget.labelText}' : 'Add ${widget.labelText}'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Enter ${widget.labelText} name',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: weddingAccent),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.pop(ctx, name);
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      if (isEdit) {
        await _db
            .collection(widget.collectionName)
            .doc(id)
            .update({'name': result});
      } else {
        await _db.collection(widget.collectionName).add({'name': result});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEdit
            ? '${widget.labelText} updated'
            : '${widget.labelText} added'),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _confirmDelete(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.collection(widget.collectionName).doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${widget.labelText} deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: weddingBg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: weddingAccent,
        icon: const Icon(Icons.add),
        label: Text('Add ${widget.labelText}'),
        onPressed: () => _showAddOrEditDialog(),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            _db.collection(widget.collectionName).orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: weddingAccent,
              ),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text('No ${widget.labelText.toLowerCase()}s yet',
                  style: const TextStyle(color: weddingOnSurfaceMuted)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final name = (doc['name'] ?? '') as String;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                child: Card(
                  elevation: 2,
                  color: weddingSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: weddingOnSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: weddingOnSurfaceMuted),
                      onSelected: (value) {
                        if (value == 'edit')
                          _showAddOrEditDialog(id: doc.id, currentName: name);
                        if (value == 'delete') _confirmDelete(doc.id, name);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18, color: weddingAccent),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete,
                                  size: 18, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
