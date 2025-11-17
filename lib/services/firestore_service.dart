// lib/services/firestore_service.dart
import 'dart:io' show File;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

class FirestoreService {
  static final _col = FirebaseFirestore.instance.collection('weddingGuests');

  // Stream all guests as List<Map<String,dynamic>>
  static Stream<List<Map<String, dynamic>>> streamWeddingGuests() {
    return _col.snapshots().map((snap) {
      return snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = d.id;
        return m;
      }).toList();
    });
  }

  static Future<void> addWeddingGuest(Map<String, dynamic> data) async {
    await _col.add(data);
  }

  static Future<void> updateWeddingGuest(
      String id, Map<String, dynamic> data) async {
    if (id.isEmpty) throw ArgumentError('id empty');
    await _col.doc(id).update(data);
  }

  static Future<void> deleteWeddingGuest(String id) async {
    if (id.isEmpty) throw ArgumentError('id empty');
    await _col.doc(id).delete();
  }

  /// Export CSV:
  /// - on web returns CSV text
  /// - on mobile/desktop writes temp file and returns file path
  static Future<String> exportWeddingGuestsToCSV() async {
    final snap = await _col.get();
    final headers = [
      'id',
      'name',
      'place',
      'phone',
      'relation',
      'invited',
      'invitedAt',
      'hasAmount',
      'amount',
      'receivedAt',
      'heads',
      'createdAt'
    ];

    String escape(dynamic v) {
      if (v == null) return '';
      final s = v.toString();
      if (s.contains(',') || s.contains('"') || s.contains('\n')) {
        return '"${s.replaceAll('"', '""')}"';
      }
      return s;
    }

    final sb = StringBuffer();
    sb.writeln(headers.join(','));

    for (final d in snap.docs) {
      final map = d.data();
      final row = [
        escape(d.id),
        escape(map['name']),
        escape(map['place']),
        escape(map['phone']),
        escape(map['relation']),
        escape(map['invited']),
        escape(map['invitedAt']),
        escape(map['hasAmount']),
        escape(map['amount']),
        escape(map['receivedAt']),
        escape(map['heads']),
        escape(map['createdAt']),
      ];
      sb.writeln(row.join(','));
    }

    final csv = sb.toString();

    if (kIsWeb) {
      return csv;
    } else {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/wedding_guests_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv, flush: true);
      return file.path;
    }
  }
}
