// lib/screens/wedding_filters_sheet.dart
import 'package:flutter/material.dart';
import 'wedding_theme.dart';
import 'wedding_calls_page.dart'; // for ListFilter type

class FiltersSheet extends StatefulWidget {
  final ListFilter current;
  final ValueChanged<ListFilter> onApply;
  const FiltersSheet({super.key, required this.current, required this.onApply});

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  late ListFilter f;
  final relations = const [
    '',
    'Family',
    'Friend',
    'Colleague',
    'Neighbor',
    'Other'
  ];

  final placeCtrl = TextEditingController();
  final minAmtCtrl = TextEditingController();
  final maxAmtCtrl = TextEditingController();
  final minHeadsCtrl = TextEditingController();
  final maxHeadsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    f = widget.current.copy();
    placeCtrl.text = f.place;
    minAmtCtrl.text = f.minAmount.toStringAsFixed(0);
    maxAmtCtrl.text =
        f.maxAmount == 1000000 ? '' : f.maxAmount.toStringAsFixed(0);
    minHeadsCtrl.text = f.minHeads.toString();
    maxHeadsCtrl.text = f.maxHeads == 1000 ? '' : f.maxHeads.toString();
  }

  @override
  void dispose() {
    placeCtrl.dispose();
    minAmtCtrl.dispose();
    maxAmtCtrl.dispose();
    minHeadsCtrl.dispose();
    maxHeadsCtrl.dispose();
    super.dispose();
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
            child: ListView(shrinkWrap: true, children: [
              Row(children: [
                const Text('Filters',
                    style: TextStyle(
                        color: weddingOnSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close,
                        color: weddingOnSurface, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero)
              ]),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: f.relation,
                items: relations
                    .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.isEmpty ? 'Any' : r,
                            style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => f.relation = v ?? ''),
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
                        borderSide: BorderSide(color: weddingAccent))),
                dropdownColor: weddingSurface,
                style: txtStyle,
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: placeCtrl,
                  onChanged: (v) => f.place = v,
                  style: txtStyle,
                  decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      labelText: 'Place contains',
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
                initialValue:
                    f.hasAmount == null ? 'any' : (f.hasAmount! ? 'yes' : 'no'),
                items: const [
                  DropdownMenuItem(
                      value: 'any',
                      child: Text('Gift: Any', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(
                      value: 'yes',
                      child: Text('Has gift', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(
                      value: 'no',
                      child: Text('No gift', style: TextStyle(fontSize: 13)))
                ],
                onChanged: (v) {
                  setState(() {
                    if (v == 'any')
                      f.hasAmount = null;
                    else
                      f.hasAmount = (v == 'yes');
                  });
                },
                decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    labelText: 'Gift',
                    labelStyle: labelStyle,
                    filled: true,
                    fillColor: Color(0xFF1E2024),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: weddingDivider)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: weddingAccent))),
                dropdownColor: weddingSurface,
                style: txtStyle,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: f.sortAsc ? 'az' : 'za',
                items: const [
                  DropdownMenuItem(
                      value: 'az',
                      child: Text('Sort: Name (A → Z)',
                          style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(
                      value: 'za',
                      child: Text('Sort: Name (Z → A)',
                          style: TextStyle(fontSize: 13)))
                ],
                onChanged: (v) =>
                    setState(() => f.sortAsc = (v ?? 'az') == 'az'),
                decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    labelText: 'Sort',
                    labelStyle: labelStyle,
                    filled: true,
                    fillColor: Color(0xFF1E2024),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: weddingDivider)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: weddingAccent))),
                dropdownColor: weddingSurface,
                style: txtStyle,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: minAmtCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: txtStyle,
                        decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            labelText: 'Min ₹',
                            labelStyle: labelStyle,
                            filled: true,
                            fillColor: Color(0xFF1E2024),
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: weddingDivider)),
                            focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: weddingAccent))))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: maxAmtCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: txtStyle,
                        decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            labelText: 'Max ₹',
                            labelStyle: labelStyle,
                            filled: true,
                            fillColor: Color(0xFF1E2024),
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: weddingDivider)),
                            focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: weddingAccent))))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: minHeadsCtrl,
                        keyboardType: TextInputType.number,
                        style: txtStyle,
                        decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            labelText: 'Min heads',
                            labelStyle: labelStyle,
                            filled: true,
                            fillColor: Color(0xFF1E2024),
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: weddingDivider)),
                            focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: weddingAccent))))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: maxHeadsCtrl,
                        keyboardType: TextInputType.number,
                        style: txtStyle,
                        decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            labelText: 'Max heads',
                            labelStyle: labelStyle,
                            filled: true,
                            fillColor: Color(0xFF1E2024),
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: weddingDivider)),
                            focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: weddingAccent))))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            f = ListFilter();
                            placeCtrl.text = '';
                            minAmtCtrl.text = '0';
                            maxAmtCtrl.text = '';
                            minHeadsCtrl.text = '0';
                            maxHeadsCtrl.text = '';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8)),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reset',
                            style: TextStyle(fontSize: 12)))),
                const SizedBox(width: 10),
                Expanded(
                    child: ElevatedButton.icon(
                        onPressed: () {
                          f.minAmount =
                              double.tryParse(minAmtCtrl.text.trim()) ?? 0;
                          f.maxAmount = maxAmtCtrl.text.trim().isEmpty
                              ? 1000000
                              : (double.tryParse(maxAmtCtrl.text.trim()) ??
                                  1000000);
                          f.minHeads =
                              int.tryParse(minHeadsCtrl.text.trim()) ?? 0;
                          f.maxHeads = maxHeadsCtrl.text.trim().isEmpty
                              ? 1000
                              : (int.tryParse(maxHeadsCtrl.text.trim()) ??
                                  1000);
                          widget.onApply(f);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: weddingAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8)),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Apply',
                            style: TextStyle(fontSize: 12))))
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
