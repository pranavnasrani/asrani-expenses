import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/feedback_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _signIn() async {
    FeedbackService().lightTap();
    setState(() => _loading = true);
    try {
      await AuthService().signInWithGoogle();
    } catch (e) {
      FeedbackService().error();
      if (mounted) showMessage(context, 'Sign-in failed. Check your connection and try again.\n$e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enamel = context.enamel;
    return Scaffold(
      backgroundColor: enamel.field,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    const TingkatMark(size: 96),
                    const SizedBox(height: 32),
                    Text(
                      'Asrani\nExpenses',
                      style: theme.textTheme.displayMedium?.copyWith(color: enamel.onField, height: 1.0),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Log spending in seconds. Keep what you don\'t spend: it rolls into next month.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: enamel.onFieldMuted,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: constraints.maxHeight * 0.18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: enamel.onField,
                          foregroundColor: const Color(0xFF16201E),
                        ),
                        onPressed: _loading ? null : _signIn,
                        icon: _loading
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : const Icon(Icons.login_rounded),
                        label: const Text('Continue with Google'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Each family member signs in with their own account. Your expenses are private to you.',
                      style: theme.textTheme.bodySmall?.copyWith(color: enamel.onFieldMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app mark: three stacked enamel tiers with a handle, drawn as plain
/// geometry.
class TingkatMark extends StatelessWidget {
  final double size;
  const TingkatMark({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final e = Enamel.light;
    final tier = size * 0.26;
    Widget band(Color c) => Container(
      height: tier,
      margin: EdgeInsets.only(top: size * 0.04),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(tier * 0.35)),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        children: [
          Container(
            width: size * 0.4,
            height: size * 0.12,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFF2C14E), width: size * 0.04),
              borderRadius: BorderRadius.vertical(top: Radius.circular(size * 0.2)),
            ),
          ),
          band(const Color(0xFFF2C14E)),
          band(e.coral),
          band(const Color(0xFFFFFFFF)),
        ],
      ),
    );
  }
}
