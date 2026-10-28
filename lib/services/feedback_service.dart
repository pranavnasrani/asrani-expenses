import 'package:flutter/services.dart';

/// Haptic feedback, kept in one place so it feels consistent.
class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  Future<void> lightTap() => HapticFeedback.lightImpact();

  Future<void> selectionClick() => HapticFeedback.selectionClick();

  Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  }

  Future<void> error() => HapticFeedback.heavyImpact();
}
