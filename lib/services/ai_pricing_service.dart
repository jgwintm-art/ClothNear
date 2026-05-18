import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../config/env_config.dart';

class AiPricingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch recent orders for this store to give AI sales history context
  Future<List<OrderModel>> _getRecentOrders(
    String storeId, {
    int limit = 50,
  }) async {
    final snap = await _firestore
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .limit(limit)
        .get();
    return snap.docs.map((d) => OrderModel.fromMap(d.data(), d.id)).toList();
  }

  /// Generate AI pricing suggestions for a single product.
  /// Returns a map of variant key → suggested price range string,
  /// plus a 'reasoning' key with a short explanation.
  Future<Map<String, String>> getSuggestionsForProduct({
    required ProductModel product,
    required String storeId,
  }) async {
    final apiKey = EnvConfig.geminiApiKey;
    if (apiKey.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY not found in .env. Please add it to enable AI suggestions.',
      );
    }

    final orders = await _getRecentOrders(storeId);

    // Build sales history for this product
    int totalUnitsSold = 0;
    final variantSales = <String, int>{};
    for (final order in orders) {
      for (final item in order.items) {
        if (item['productId'] == product.productId ||
            item['productName'] == product.name) {
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          totalUnitsSold += qty;
          final color = (item['color'] as String? ?? '').toLowerCase();
          final size = (item['size'] as String? ?? '').toLowerCase();
          final key = '${color}_$size';
          variantSales[key] = (variantSales[key] ?? 0) + qty;
        }
      }
    }

    // Build prompt
    final variantSummary = product.variants.entries
        .map((e) {
          final sold = variantSales[e.key] ?? 0;
          return '  ${e.key}: current price ₱${e.value.price.toStringAsFixed(0)}, '
              'stock ${e.value.stock}, units sold $sold';
        })
        .join('\n');

    final prompt =
        '''
You are a pricing consultant for a clothing print and screen printing business in the Philippines.

Product: ${product.name}
Type: ${product.type}
Base price: ₱${product.basePrice.toStringAsFixed(0)}
Total units sold (all time): $totalUnitsSold
Customizable: ${product.isCustomizable}

Current variant prices and stock:
$variantSummary

Based on:
1. The current prices and sales velocity per variant
2. Typical clothing print market in the Philippines (local SMEs)
3. High-demand variants (more units sold = may support higher price)
4. Low-stock variants (scarcity = can price slightly higher)
5. Slow-moving variants (low sales = consider price reduction to move stock)

Respond in this EXACT JSON format and nothing else — no markdown, no explanation outside JSON:
{
  "reasoning": "2-3 sentence overall pricing rationale",
  "suggestions": {
    "variant_key": "₱min - ₱max",
    ...
  }
}

Use the exact variant keys from the list above. Give realistic Philippine peso ranges.
''';

    final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text ?? '';

    // Parse JSON response
    try {
      // Strip any accidental markdown fences
      final clean = text.replaceAll('```json', '').replaceAll('```', '').trim();

      // Simple JSON parse
      final jsonStart = clean.indexOf('{');
      final jsonEnd = clean.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('No JSON in response');
      }
      final jsonStr = clean.substring(jsonStart, jsonEnd + 1);

      final result = <String, String>{};

      // Extract reasoning
      final reasoningMatch = RegExp(
        r'"reasoning"\s*:\s*"([^"]+)"',
      ).firstMatch(jsonStr);
      if (reasoningMatch != null) {
        result['reasoning'] = reasoningMatch.group(1) ?? '';
      }

      // Extract suggestions
      final suggestionsMatch = RegExp(
        r'"suggestions"\s*:\s*\{([^}]+)\}',
      ).firstMatch(jsonStr);
      if (suggestionsMatch != null) {
        final suggestionsStr = suggestionsMatch.group(1) ?? '';
        final pairPattern = RegExp(r'"([^"]+)"\s*:\s*"([^"]+)"');
        for (final match in pairPattern.allMatches(suggestionsStr)) {
          result[match.group(1)!] = match.group(2)!;
        }
      }

      return result;
    } catch (e) {
      throw Exception('Failed to parse AI response. Raw: $text');
    }
  }
}
