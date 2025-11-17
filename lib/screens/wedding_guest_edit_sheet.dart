// lib/screens/wedding_guest_edit_sheet.dart
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'wedding_theme.dart';

class GuestEditSheet extends StatefulWidget {
  final Map<String, dynamic> initial;
  final List<String> places;
  const GuestEditSheet(
      {super.key, required this.initial, required this.places});

  @override
  State<GuestEditSheet> createState() => _GuestEditSheetState();
}

class _GuestEditSheetState extends State<GuestEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _place;
  late final TextEditingController _phone;
  final _placeFocus = FocusNode();

  final _relations = ['Family', 'Friend', 'Colleague', 'Neighbor', 'Other'];
  late final TextEditingController _relationOtherCtrl;
  String _relation = 'Family';

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name =
        TextEditingController(text: (widget.initial['name'] ?? '').toString());
    _place =
        TextEditingController(text: (widget.initial['place'] ?? '').toString());
    _phone =
        TextEditingController(text: (widget.initial['phone'] ?? '').toString());
    _relationOtherCtrl = TextEditingController();

    _relation = (widget.initial['relation'] ?? 'Family').toString();
    if (!_relations.contains(_relation) && _relation.trim().isNotEmpty) {
      _relationOtherCtrl.text = _relation;
      _relation = 'Other';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    _phone.dispose();
    _relationOtherCtrl.dispose();
    _placeFocus.dispose();
    super.dispose();
  }

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

  Iterable<String> _placeOptions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const Iterable<String>.empty();
    return widget.places.where((p) => p.toLowerCase().contains(q));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final id = (widget.initial['id'] ?? '').toString();

    try {
      await FirestoreService.updateWeddingGuest(id, {
        'name': _toTitleCase(_name.text),
        'place': _toTitleCase(_place.text),
        'phone': _digitsOnly(_phone.text),
        'relation':
            _relation == 'Other' ? _relationOtherCtrl.text.trim() : _relation,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Updated', style: TextStyle(fontSize: 12))),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(color: weddingOnSurfaceMuted, fontSize: 11);
    const txtStyle = TextStyle(color: weddingOnSurface, fontSize: 13);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Material(
          color: weddingSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Edit Guest',
                        style: TextStyle(
                          color: weddingOnSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: weddingOnSurface, size: 18),
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    style: txtStyle,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      labelText: 'Name',
                      labelStyle: labelStyle,
                      filled: true,
                      fillColor: Color(0xFF1E2024),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: weddingDivider)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: weddingAccent)),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 6),

                  // Place autocomplete
                  RawAutocomplete<String>(
                    textEditingController: _place,
                    focusNode: _placeFocus,
                    optionsBuilder: (TextEditingValue tev) =>
                        _placeOptions(tev.text),
                    displayStringForOption: (o) => o,
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        textCapitalization: TextCapitalization.words,
                        style: txtStyle,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          labelText: 'Place',
                          labelStyle: labelStyle,
                          filled: true,
                          fillColor: Color(0xFF1E2024),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: weddingDivider)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: weddingAccent)),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      final opts = options.toList();
                      if (opts.isEmpty) return const SizedBox.shrink();
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: weddingSurface,
                          elevation: 4,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 180),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: opts.length,
                              itemBuilder: (ctx, i) {
                                final opt = opts[i];
                                return ListTile(
                                  dense: true,
                                  visualDensity: const VisualDensity(
                                      horizontal: -2, vertical: -2),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  title: Text(opt,
                                      style: const TextStyle(
                                          color: weddingOnSurface,
                                          fontSize: 13)),
                                  onTap: () => onSelected(opt),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    style: txtStyle,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      labelText: 'Phone',
                      labelStyle: labelStyle,
                      filled: true,
                      fillColor: Color(0xFF1E2024),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: weddingDivider)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: weddingAccent)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _relation,
                    items: _relations
                        .map((r) => DropdownMenuItem(
                            value: r,
                            child:
                                Text(r, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _relation = v ?? 'Family'),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      labelText: 'Relation',
                      labelStyle: labelStyle,
                      filled: true,
                      fillColor: Color(0xFF1E2024),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: weddingDivider)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: weddingAccent)),
                    ),
                    dropdownColor: weddingSurface,
                    style:
                        const TextStyle(color: weddingOnSurface, fontSize: 13),
                  ),
                  if (_relation == 'Other') ...[
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _relationOtherCtrl,
                      style: txtStyle,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        labelText: 'Relation (Other)',
                        labelStyle: labelStyle,
                        filled: true,
                        fillColor: Color(0xFF1E2024),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: weddingDivider)),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: weddingAccent)),
                      ),
                      validator: (v) {
                        if (_relation == 'Other' &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Specify relation';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: weddingAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Save', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
