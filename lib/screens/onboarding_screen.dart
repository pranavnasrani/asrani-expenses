import 'package:flutter/material.dart';

import '../services/feedback_service.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Page {
  final IconData icon;
  final String title;
  final String body;
  final Color Function(Enamel) color;
  const _Page(this.icon, this.title, this.body, this.color);
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static final _pages = [
    _Page(
      Icons.bolt_rounded,
      'Log it in seconds',
      'Tap Add after you pay, or scan the receipt and let the details fill in.',
      (e) => e.tangerine,
    ),
    _Page(
      Icons.layers_rounded,
      'Budgets stack like a tingkat',
      'Set a budget once, overall, by cash and card, or by category. It repeats every month until you change it.',
      (e) => e.cobalt,
    ),
    _Page(
      Icons.savings_rounded,
      'Keep what you don\'t spend',
      'Turn on rollover and unspent money settles in the Saved tier, adding up month after month. Overspending is never carried.',
      (e) => e.saved,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    FeedbackService().lightTap();
    if (_page < _pages.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enamel = context.enamel;
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(onPressed: widget.onComplete, child: const Text('Skip')),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  final color = p.color(enamel);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(28)),
                          child: Icon(p.icon, color: theme.colorScheme.surface, size: 44),
                        ),
                        const SizedBox(height: 32),
                        Text(p.title, style: theme.textTheme.displaySmall?.copyWith(height: 1.1)),
                        const SizedBox(height: 16),
                        Text(
                          p.body,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              child: Row(
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(last ? 'Get started' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
