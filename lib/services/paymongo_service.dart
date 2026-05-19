import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

/// PayMongo payment integration using the Links API.
///
/// The Links API is the correct choice for Flutter Web + Firebase Hosting
/// because it does not require a backend server. The secret key creates a
/// hosted checkout URL; the customer pays on PayMongo's own page.
///
/// Supported channels: GCash, Maya (PayMaya), Credit/Debit Card.
///
/// SETUP — add these to your .env (local) and GitHub Secrets (CI):
///   PAYMONGO_SECRET_KEY=sk_test_xxxx    ← test key during development
///   PAYMONGO_SECRET_KEY=sk_live_xxxx    ← switch to live before going public
///
/// Get keys at: https://dashboard.paymongo.com/developers

class PayMongoService {
  static const String _baseUrl = 'https://api.paymongo.com/v1';

  static String get _secretKey => EnvConfig.paymongoSecretKey;

  static String get _basicAuth {
    final key = _secretKey;
    if (key.isEmpty) return '';
    // PayMongo uses HTTP Basic auth: base64(secretKey + ':')
    return 'Basic ${base64Encode(utf8.encode('$key:'))}';
  }

  static bool get isConfigured => EnvConfig.isPayMongoConfigured;

  // ── Create payment link ────────────────────────────────────────────────────

  /// Creates a PayMongo payment link.
  ///
  /// [amountInCentavos]  amount in centavos  (₱1 = 100 centavos)
  /// [description]       shown on the checkout page (e.g. "ClothNear Order")
  /// [remarks]           internal ref, not shown to customer (e.g. orderId)
  ///
  /// Returns [PayMongoLink] containing the checkout URL and link ID.
  /// Throws [PayMongoException] on API errors.
  static Future<PayMongoLink> createPaymentLink({
    required int amountInCentavos,
    required String description,
    String remarks = '',
  }) async {
    _assertConfigured();

    final body = jsonEncode({
      'data': {
        'attributes': {
          'amount': amountInCentavos,
          'description': description,
          if (remarks.isNotEmpty) 'remarks': remarks,
        },
      },
    });

    final response = await http
        .post(
          Uri.parse('$_baseUrl/links'),
          headers: {
            'Authorization': _basicAuth,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 20));

    _assertSuccess(response);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final attrs = (data['data'] as Map)['attributes'] as Map<String, dynamic>;

    return PayMongoLink(
      linkId: (data['data'] as Map)['id'] as String,
      checkoutUrl: attrs['checkout_url'] as String,
      referenceNumber: attrs['reference_number'] as String? ?? '',
      status: attrs['status'] as String? ?? 'unpaid',
      amountInCentavos: amountInCentavos,
    );
  }

  // ── Check payment status ───────────────────────────────────────────────────

  /// Returns the current status of a link: 'unpaid' | 'paid'.
  /// Safe to call repeatedly — used for polling after the customer returns.
  static Future<String> getLinkStatus(String linkId) async {
    if (!isConfigured) return 'not_configured';

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/links/$linkId'),
            headers: {
              'Authorization': _basicAuth,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['data'] as Map)['attributes']['status'] as String? ??
            'unknown';
      }
      return 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static void _assertConfigured() {
    if (!isConfigured) {
      throw PayMongoException(
        'PayMongo is not configured.\n'
        'Add PAYMONGO_SECRET_KEY to your .env file (local) '
        'or GitHub Secrets (CI).\n'
        'Get your keys at https://dashboard.paymongo.com/developers',
      );
    }
  }

  static void _assertSuccess(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) return;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final errors = body['errors'] as List?;
      if (errors != null && errors.isNotEmpty) {
        final detail =
            errors.first['detail'] as String? ??
            'PayMongo error (${response.statusCode})';
        throw PayMongoException(detail);
      }
    } catch (e) {
      if (e is PayMongoException) rethrow;
    }
    throw PayMongoException(
      'PayMongo returned ${response.statusCode}: ${response.body}',
    );
  }

  /// Converts Philippine Peso amount to centavos (PayMongo always uses centavos).
  static int pesosToCentavos(double pesos) => (pesos * 100).round();

  /// Converts centavos back to pesos.
  static double centavosTosPesos(int centavos) => centavos / 100;
}

// ── Data classes ──────────────────────────────────────────────────────────────

class PayMongoLink {
  final String linkId;
  final String checkoutUrl;
  final String referenceNumber;
  final String status; // 'unpaid' | 'paid'
  final int amountInCentavos;

  const PayMongoLink({
    required this.linkId,
    required this.checkoutUrl,
    required this.referenceNumber,
    required this.status,
    required this.amountInCentavos,
  });

  double get amountInPesos => amountInCentavos / 100.0;
  bool get isPaid => status == 'paid';
}

class PayMongoException implements Exception {
  final String message;
  const PayMongoException(this.message);

  @override
  String toString() => message;
}
