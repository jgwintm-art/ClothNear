import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

/// PayMongo payment integration using the Links API.
///
/// Flutter Web cannot call api.paymongo.com directly because the browser
/// blocks cross-origin requests (CORS). All PayMongo calls are routed through
/// Firebase Cloud Functions which run server-side and are not subject to CORS.
///
/// Function endpoints (same Firebase project, same origin on web):
///   POST /paymongo_create_link  — creates a hosted checkout link
///   GET  /paymongo_get_link     — polls link payment status
///
/// The secret key lives in Firebase Secret Manager (set via
/// `firebase functions:secrets:set PAYMONGO_SECRET_KEY`).
/// It is never embedded in the Flutter bundle.
///
/// Supported channels: GCash, Maya (PayMaya), Credit/Debit Card.

class PayMongoService {
  /// Base URL for the Firebase Cloud Function proxy.
  ///
  /// During local development (flutter run -d chrome) this points to the
  /// Functions emulator. In production it points to the deployed functions.
  ///
  /// Override via PAYMONGO_FUNCTIONS_BASE in .env for custom regions/projects.
  static String get _functionsBase {
    // Allow override from env (useful for non-default regions)
    final override = EnvConfig.paymongoFunctionsBase;
    if (override.isNotEmpty) return override;
    // Default: Cloudflare Worker proxy for PayMongo
    return 'https://clothnear-paymongo.jg-wintm.workers.dev';
  }

  static bool get isConfigured => EnvConfig.isPayMongoConfigured;

  // ── Create payment link ────────────────────────────────────────────────────

  /// Creates a PayMongo payment link via the server-side Firebase Function.
  ///
  /// [amountInCentavos]  amount in centavos  (₱1 = 100 centavos)
  /// [description]       shown on the checkout page
  /// [remarks]           internal ref (e.g. orderId), not shown to customer
  ///
  /// Returns [PayMongoLink] containing the checkout URL and link ID.
  /// Throws [PayMongoException] on API or network errors.
  static Future<PayMongoLink> createPaymentLink({
    required int amountInCentavos,
    required String description,
    String remarks = '',
  }) async {
    _assertConfigured();

    final body = jsonEncode({
      'amountInCentavos': amountInCentavos,
      'description': description,
      if (remarks.isNotEmpty) 'remarks': remarks,
    });

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_functionsBase/paymongo_create_link'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw PayMongoException(
        'Network error reaching payment service. '
        'Check your internet connection and try again.\n(Detail: $e)',
      );
    }

    _assertSuccess(response);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return PayMongoLink(
      linkId: data['linkId'] as String,
      checkoutUrl: data['checkoutUrl'] as String,
      referenceNumber: data['referenceNumber'] as String? ?? '',
      status: data['status'] as String? ?? 'unpaid',
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
            Uri.parse('$_functionsBase/paymongo_get_link?linkId=$linkId'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['status'] as String? ?? 'unknown';
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
        'Add PAYMONGO_SECRET_KEY to Firebase Secret Manager:\n'
        '  firebase functions:secrets:set PAYMONGO_SECRET_KEY\n'
        'Get your keys at https://dashboard.paymongo.com/developers',
      );
    }
  }

  static void _assertSuccess(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) return;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'] as String?;
      if (error != null && error.isNotEmpty) {
        throw PayMongoException(error);
      }
    } catch (e) {
      if (e is PayMongoException) rethrow;
    }
    throw PayMongoException(
      'Payment service returned ${response.statusCode}: ${response.body}',
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
