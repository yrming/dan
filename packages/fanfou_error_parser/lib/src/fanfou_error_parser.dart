import 'dart:convert';

/// Extracts the API's error field from a JSON response body.
///
/// Returns null when the response is not structured JSON or has no usable
/// error field.
String? parseFanfouApiError(String body) {
  final normalizedBody = body.trim();
  if (normalizedBody.isEmpty) return null;

  try {
    final decoded = jsonDecode(normalizedBody);
    if (decoded is Map<String, dynamic>) {
      final error = decoded['error'];
      if (error is String && error.trim().isNotEmpty) return error.trim();
    }
  } on FormatException {
    // Ignore malformed or non-JSON error bodies.
  }

  return null;
}
