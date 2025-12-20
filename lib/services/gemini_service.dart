import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
  }

  /// Analyzes a receipt image and extracts expense details
  /// Returns a Map with extracted data: title, amount, category, place, date
  Future<Map<String, dynamic>?> analyzeReceipt(dynamic imageSource) async {
    try {
      // Prepare the image data
      Uint8List? imageBytes;

      if (kIsWeb) {
        // Web: imageSource should already be Uint8List
        imageBytes = imageSource as Uint8List;
      } else {
        // Mobile: imageSource should be File
        final File imageFile = imageSource as File;
        imageBytes = await imageFile.readAsBytes();
      }

      // Create the prompt for structured data extraction
      final prompt = '''
Analyze this receipt image and extract the following information in JSON format:
{
  "title": "Brief description of the expense (e.g., 'Grocery Shopping', 'Restaurant Dinner')",
  "amount": <numeric value only, no currency symbols>,
  "category": "One of: Food, Transport, Shopping, Entertainment, Bills, Other",
  "place": "Merchant/store name",
  "date": "Date in YYYY-MM-DD format if visible, otherwise use today's date"
}

Rules:
- Extract ONLY the total amount to pay
- Choose the most appropriate category from the list
- If any field cannot be determined, use reasonable defaults
- Return ONLY valid JSON, no extra text
''';

      // Create content parts
      final content = [
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ];

      // Get response from Gemini
      final response = await _model.generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        debugPrint('Gemini returned empty response');
        return null;
      }

      // Parse the JSON response
      String responseText = response.text!.trim();

      // Clean up the response (remove markdown code blocks if present)
      if (responseText.startsWith('```json')) {
        responseText = responseText.substring(7);
      }
      if (responseText.startsWith('```')) {
        responseText = responseText.substring(3);
      }
      if (responseText.endsWith('```')) {
        responseText = responseText.substring(0, responseText.length - 3);
      }
      responseText = responseText.trim();

      // Parse JSON
      final Map<String, dynamic> data = {};

      // Simple JSON parsing (you could use dart:convert for more robust parsing)
      final lines = responseText.split('\n');
      for (final line in lines) {
        if (line.contains(':')) {
          final parts = line.split(':');
          if (parts.length >= 2) {
            String key = parts[0]
                .trim()
                .replaceAll('"', '')
                .replaceAll('{', '')
                .replaceAll(',', '');
            String value = parts
                .sublist(1)
                .join(':')
                .trim()
                .replaceAll('"', '')
                .replaceAll(',', '')
                .replaceAll('}', '');

            if (key.isNotEmpty && value.isNotEmpty) {
              // Convert amount to double
              if (key == 'amount') {
                data[key] =
                    double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ??
                    0.0;
              } else {
                data[key] = value;
              }
            }
          }
        }
      }

      // Validate required fields
      if (!data.containsKey('title') || !data.containsKey('amount')) {
        debugPrint('Invalid response format: missing required fields');
        return null;
      }

      // Set defaults for missing optional fields
      data['category'] ??= 'Other';
      data['place'] ??= '';
      data['date'] ??= DateTime.now().toIso8601String().split('T')[0];

      return data;
    } catch (e) {
      debugPrint('Error analyzing receipt: $e');
      return null;
    }
  }

  /// Parses a user query to extract search filters
  /// Returns: { 'startDate': YYYY-MM-DD, 'endDate': YYYY-MM-DD, 'category': String?, 'paymentMethod': String? }
  Future<Map<String, String?>> parseQuery(String query) async {
    try {
      final now = DateTime.now();
      final prompt =
          '''
Current Date: ${now.toIso8601String().split('T')[0]}
User Query: "$query"

Extract the following search filters from the query in JSON format:
{
  "startDate": "YYYY-MM-DD" (start of range, e.g., for 'last month', 'this week'),
  "endDate": "YYYY-MM-DD" (end of range, usually today if not specified),
  "category": "Food, Transport, Shopping, Entertainment, Bills, Other" (or null if not specified),
  "paymentMethod": "Cash, Credit Card, Debit Card, PayNow, Other" (or null if not specified)
}
Rules:
- Calculate exact dates based on "Current Date".
- If no date is specified, default to the last 30 days.
- Return ONLY valid JSON.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      if (response.text == null) return {};

      String jsonStr = response.text!.trim();
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      }
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }

      // Simple manual JSON parsing to avoid heavy dependencies if possible,
      // but robust enough for the expected format.
      // (Using basic string manipulation for simplicity in this context)
      // Ideally usage of dart:convert jsonDecode is better.
      // LET'S USE dart:convert which is standard.
      // But since I cannot easily add imports at the top with this tool, I'll rely on string matching or assume dart:convert is available?
      // Wait, dart:convert is a core library, but I need to make sure it's imported.
      // I will assume it's NOT imported and use regex-based parsing to be safe/standalone,
      // OR I can use the existing manual parsing logic style.

      // Regex parsing for the specific keys
      final startDateMatch = RegExp(
        r'"startDate"\s*:\s*"([^"]+)"',
      ).firstMatch(jsonStr);
      final endDateMatch = RegExp(
        r'"endDate"\s*:\s*"([^"]+)"',
      ).firstMatch(jsonStr);
      final categoryMatch = RegExp(
        r'"category"\s*:\s*"([^"]+)"',
      ).firstMatch(jsonStr);
      final paymentMethodMatch = RegExp(
        r'"paymentMethod"\s*:\s*"([^"]+)"',
      ).firstMatch(jsonStr);

      return {
        'startDate': startDateMatch?.group(1),
        'endDate': endDateMatch?.group(1),
        'category': categoryMatch?.group(1) == 'null'
            ? null
            : categoryMatch?.group(1),
        'paymentMethod': paymentMethodMatch?.group(1) == 'null'
            ? null
            : paymentMethodMatch?.group(1),
      };
    } catch (e) {
      debugPrint('Error parsing query: $e');
      return {};
    }
  }

  /// Generates a natural language answer based on the provided expense data
  Future<String> generateResponse(String query, String dataSummary) async {
    try {
      final prompt =
          '''
User Question: "$query"
Expense Data Found:
$dataSummary

Answer the user's question naturally and concisely based *only* on the data provided.
- If data is empty, say "I couldn't find any expenses matching that."
- Highlight totals, trends, or specific largest expenses if relevant.
- Be friendly and helpful.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? 'I stayed silent... (Error)';
    } catch (e) {
      return 'I encountered an error analyzing the data.';
    }
  }
}
