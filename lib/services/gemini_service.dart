import 'dart:io';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GeminiService {
  static const String _apiKey = 'AIzaSyCtXLiTzNvafYxIghDXvABZQ_2o71TWcVM';
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
        print('Gemini returned empty response');
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
        print('Invalid response format: missing required fields');
        return null;
      }

      // Set defaults for missing optional fields
      data['category'] ??= 'Other';
      data['place'] ??= '';
      data['date'] ??= DateTime.now().toIso8601String().split('T')[0];

      print('Extracted data: $data');
      return data;
    } catch (e) {
      print('Error analyzing receipt: $e');
      return null;
    }
  }
}
