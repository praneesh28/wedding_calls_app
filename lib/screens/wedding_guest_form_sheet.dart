// lib/screens/wedding_guest_form_sheet.dart
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'wedding_theme.dart';

class GuestFormSheet extends StatefulWidget {
  final List<String> places;
  final Set<String> existingKeys;
  const GuestFormSheet(
      {super.key, required this.places, required this.existingKeys});

  @override
  State<GuestFormSheet> createState() => _GuestFormSheetState();
}

class _GuestFormSheetState extends State<GuestFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _place = TextEditingController();
  final _phone = TextEditingController();
  final _relationOtherCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _placeFocus = FocusNode();

  final List<String> _relations = [
    'Family',
    'Friend',
    'Colleague',
    'Neighbor',
    'Other'
  ];
  String _relation = 'Family';
  late Set<String> _localKeys;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _localKeys = {...widget.existingKeys};
  }

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    _phone.dispose();
    _relationOtherCtrl.dispose();
    _nameFocus.dispose();
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

  String _dedupeKey(String name, String phone, String place) {
    final n = _toTitleCase(name);
    final p = _digitsOnly(phone);
    final pl = _toTitleCase(place);
    return '${n.trim()}|${p.trim()}|${pl.trim()}';
  }

  Iterable<String> _placeOptions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const Iterable<String>.empty();
    return widget.places.where((p) => p.toLowerCase().contains(q));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final nameT = _toTitleCase(_name.text);
    final placeT = _toTitleCase(_place.text);
    final phoneN = _digitsOnly(_phone.text);
    final key = _dedupeKey(nameT, phoneN, placeT);

    if (_localKeys.contains(key)) {
      await showDialog(
          context: context,
          builder: (_) => AlertDialog(
                backgroundColor: weddingSurface,
                title: const Text('Duplicate Found',
                    style: TextStyle(color: weddingOnSurface)),
                content: const Text('Same Name / Phone / Place already exists.',
                    style: TextStyle(color: weddingOnSurfaceMuted)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'))
                ],
              ));
      return;
    }

    setState(() => _saving = true);
    try {
      await FirestoreService.addWeddingGuest({
        'name': nameT,
        'place': placeT,
        'phone': phoneN,
        'relation':
            _relation == 'Other' ? _relationOtherCtrl.text.trim() : _relation,
        'invited': false,
        'invitedAt': null,
        'hasAmount': false,
        'amount': 0.0,
        'createdAt': DateTime.now().toIso8601String(),
      });

      _localKeys.add(key);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Added', style: TextStyle(fontSize: 12))));
      _name.clear();
      _place.clear();
      _phone.clear();
      if (_relation == 'Other') _relationOtherCtrl.clear();
      setState(() => _relation = 'Family');
      _nameFocus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e', style: const TextStyle(fontSize: 12))));
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
              child: ListView(shrinkWrap: true, children: [
                Row(children: [
                  const Text('Add Person',
                      style: TextStyle(
                          color: weddingOnSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close,
                          color: weddingOnSurface, size: 18),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero),
                ]),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _name,
                  focusNode: _nameFocus,
                  textCapitalization: TextCapitalization.words,
                  style: txtStyle,
                  decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      labelText: 'Name',
                      labelStyle: labelStyle,
                      filled: true,
                      fillColor: Color(0xFF1E2024),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: weddingDivider)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: weddingAccent))),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                ),
                const SizedBox(height: 8),
                RawAutocomplete<String>(
                  textEditingController: _place,
                  focusNode: _placeFocus,
                  optionsBuilder: (TextEditingValue tev) =>
                      _placeOptions(tev.text),
                  displayStringForOption: (o) => o,
                  fieldViewBuilder: (context, controller, focusNode, onSub) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.words,
                      style: txtStyle,
                      decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 15),
                          labelText: 'Place',
                          labelStyle: labelStyle,
                          filled: true,
                          fillColor: Color(0xFF1E2024),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: weddingDivider)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: weddingAccent))),
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
                                constraints:
                                    const BoxConstraints(maxHeight: 180),
                                child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: opts.length,
                                    itemBuilder: (ctx, i) {
                                      final opt = opts[i];
                                      return ListTile(
                                          dense: true,
                                          visualDensity: const VisualDensity(
                                              horizontal: -2, vertical: -2),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10),
                                          title: Text(opt,
                                              style: const TextStyle(
                                                  color: weddingOnSurface,
                                                  fontSize: 13)),
                                          onTap: () => onSelected(opt));
                                    }))));
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    style: txtStyle,
                    decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                        labelText: 'Phone (optional)',
                        labelStyle: labelStyle,
                        filled: true,
                        fillColor: Color(0xFF1E2024),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: weddingDivider)),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: weddingAccent)))),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _relation,
                  items: _relations
                      .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _relation = v ?? 'Family'),
                  decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      labelText: 'Relation',
                      labelStyle: labelStyle,
                      filled: true,
                      fillColor: Color(0xFF1E2024),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: weddingDivider)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: weddingAccent))),
                  dropdownColor: weddingSurface,
                  style: const TextStyle(color: weddingOnSurface, fontSize: 13),
                ),
                if (_relation == 'Other') ...[
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _relationOtherCtrl,
                      style: txtStyle,
                      decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 15),
                          labelText: 'Relation (Other)',
                          labelStyle: labelStyle,
                          filled: true,
                          fillColor: Color(0xFF1E2024),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: weddingDivider)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: weddingAccent))),
                      validator: (v) {
                        if (_relation == 'Other' &&
                            (v == null || v.trim().isEmpty))
                          return 'Specify relation';
                        return null;
                      }),
                ],
                const SizedBox(height: 8),
                SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: weddingAccent,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12)),
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('Save & Add Next',
                            style: TextStyle(fontSize: 12)))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
