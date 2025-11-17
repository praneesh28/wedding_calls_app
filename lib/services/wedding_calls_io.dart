// lib/services/wedding_calls_io.dart
// Placeholder helpers for wedding calls import/export flows.
//
// TODO: Wire these helpers to actual CSV/Sheets integrations and file pickers.

class WeddingCallsIO {
  /// Exports the provided guest data to an external destination (CSV/JSON).
  /// Currently unimplemented – replace with Drive/Sheets integration.
  Future<void> exportGuests(
      List<Map<String, dynamic>> guests, String format) async {
    throw UnimplementedError(
      'ExportGuests is not implemented. Hook this into Drive/Sheets.',
    );
  }

  /// Prompts the user to import guests and returns the parsed list.
  /// Currently returns an empty list – replace with real parsing logic.
  Future<List<Map<String, dynamic>>> importGuests(String format) async {
    throw UnimplementedError(
      'ImportGuests is not implemented. Provide CSV/JSON parsing here.',
    );
  }
}

