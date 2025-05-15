import 'dart:convert';
import 'package:flutter/services.dart';

class MLService {
  Future<Map<String, dynamic>> getSpendingAnalysis() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/ML/spending_analysis_results.json');
      return jsonDecode(jsonString);
    } catch (e) {
      return {'error': 'Error loading spending analysis: $e'};
    }
  }

  Future<Map<String, dynamic>> getSavingsSuggestions() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/ML/savings_suggestions_results.json');
      return jsonDecode(jsonString);
    } catch (e) {
      return {'error': 'Error loading savings suggestions: $e'};
    }
  }

  Future<Map<String, dynamic>> getPersonalizedTips() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/ML/personalized_tips_results.json');
      return jsonDecode(jsonString);
    } catch (e) {
      return {'error': 'Error loading personalized tips: $e'};
    }
  }

  Future<Map<String, dynamic>> getExpenseForecast() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/ML/expense_forecast_results.json');
      return jsonDecode(jsonString);
    } catch (e) {
      return {'error': 'Error loading expense forecast: $e'};
    }
  }
} 