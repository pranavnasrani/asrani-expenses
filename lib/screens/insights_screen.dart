import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/expense_repository.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';
import '../utils/category_utils.dart';
import '../utils/money.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';

enum _Breakdown { category, place, method }

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  MonthKey _month = MonthKey.of(DateTime.now());
  _Breakdown _by = _Breakdown.category;
  Stream<List<Expense>>? _stream;

  MonthKey get _firstMonth => MonthKey.of(DateTime(_month.year, _month.month - 5, 1));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= _load();
  }

  Stream<List<Expense>> _load() =>
      context.repo.watchExpenses(from: _firstMonth.start, to: _month.end);

  void _setMonth(MonthKey m) => setState(() {
    _month = m;
    _stream = _load();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [MonthSwitcher(month: _month, onChanged: _setMonth)],
      ),
      body: StreamBuilder<List<Expense>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(icon: Icons.cloud_off_rounded, title: "Couldn't load", message: '${snap.error}');
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          final month = all.where((e) => _month.contains(e.date)).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
            children: [
              const _AssistantCard(),
              const SizedBox(height: 24),
              Text('Where it went', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              SegmentedButton<_Breakdown>(
                segments: const [
                  ButtonSegment(value: _Breakdown.category, label: Text('Category')),
                  ButtonSegment(value: _Breakdown.place, label: Text('Place')),
                  ButtonSegment(value: _Breakdown.method, label: Text('Method')),
                ],
                selected: {_by},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _by = v.first),
              ),
              const SizedBox(height: 16),
              if (month.isEmpty)
                EmptyState(
                  icon: Icons.donut_large_rounded,
                  title: 'No spending in ${DateFormat('MMMM').format(_month.start)}',
                  message: 'Pick another month, or log an expense.',
                )
              else
                _BreakdownCard(expenses: month, by: _by),
              const SizedBox(height: 24),
              Text('Last six months', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _TrendCard(expenses: all, lastMonth: _month),
            ],
          );
        },
      ),
    );
  }
}

class _AssistantCard extends StatefulWidget {
  const _AssistantCard();

  @override
  State<_AssistantCard> createState() => _AssistantCardState();
}

class _AssistantCardState extends State<_AssistantCard> {
  Future<String>? _insight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_insight == null && GeminiService.isConfigured) _insight = _loadInsight();
  }

  Future<String> _loadInsight() async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final week = await context.repo.fetchExpenses(from: since);
    if (week.isEmpty) return 'No spending logged in the last 7 days.';
    final byCategory = <String, double>{};
    for (final e in week) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    return GeminiService().weeklyInsight(
      totalSpent: week.fold(0, (s, e) => s + e.amount),
      transactionCount: week.length,
      categoryBreakdown: byCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enamel = context.enamel;
    return Material(
      color: enamel.field,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: enamel.onField, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('This week', style: theme.textTheme.titleMedium?.copyWith(color: enamel.onField)),
                ),
                if (_insight != null)
                  IconButton(
                    tooltip: 'Refresh',
                    icon: Icon(Icons.refresh_rounded, color: enamel.onField),
                    onPressed: () => setState(() => _insight = _loadInsight()),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (_insight == null)
              Text(
                'AI notes and questions need a Gemini API key in this build.',
                style: theme.textTheme.bodyMedium?.copyWith(color: enamel.onFieldMuted),
              )
            else
              FutureBuilder<String>(
                future: _insight,
                builder: (context, snap) {
                  final text = snap.hasError
                      ? "Couldn't get this week's note right now."
                      : snap.data;
                  if (text == null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(color: enamel.onField, backgroundColor: enamel.onField.withValues(alpha: 0.2)),
                    );
                  }
                  return Text(text, style: theme.textTheme.bodyLarge?.copyWith(color: enamel.onField, height: 1.45));
                },
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: enamel.onField,
                foregroundColor: enamel.field,
              ),
              onPressed: GeminiService.isConfigured
                  ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen()))
                  : null,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Ask about your spending'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatefulWidget {
  final List<Expense> expenses;
  final _Breakdown by;

  const _BreakdownCard({required this.expenses, required this.by});

  @override
  State<_BreakdownCard> createState() => _BreakdownCardState();
}

class _BreakdownCardState extends State<_BreakdownCard> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enamel = context.enamel;
    final totals = <String, double>{};
    for (final e in widget.expenses) {
      final key = switch (widget.by) {
        _Breakdown.category => e.category,
        _Breakdown.place => e.place.isEmpty ? 'No place' : e.place,
        _Breakdown.method => e.paymentMethod,
      };
      totals[key] = (totals[key] ?? 0) + e.amount;
    }
    var entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    // Fold the long tail so the chart stays readable.
    if (entries.length > 7) {
      final rest = entries.skip(6).fold<double>(0, (s, e) => s + e.value);
      entries = [...entries.take(6), MapEntry('Everything else', rest)];
    }
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    Color colorAt(int i, String key) {
      if (widget.by == _Breakdown.category && key != 'Everything else') {
        return CategoryUtils.colorFor(context, key);
      }
      if (key == 'Everything else') return enamel.slate;
      return enamel.categoryCycle[i % enamel.categoryCycle.length];
    }

    final touched = _touched != null && _touched! < entries.length ? entries[_touched!] : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 64,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (!event.isInterestedForInteractions) return;
                          setState(() => _touched = response?.touchedSection?.touchedSectionIndex);
                        },
                      ),
                      sections: [
                        for (var i = 0; i < entries.length; i++)
                          PieChartSectionData(
                            value: entries[i].value,
                            color: colorAt(i, entries[i].key),
                            radius: _touched == i ? 34 : 28,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        touched?.key ?? 'Total',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        Money.format(touched?.value ?? total),
                        style: theme.textTheme.titleMedium?.copyWith(fontFeatures: tabular),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: colorAt(i, entries[i].key), borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(entries[i].key, style: theme.textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${(entries[i].value / total * 100).round()}%',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontFeatures: tabular),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 96,
                      child: Text(
                        Money.format(entries[i].value),
                        textAlign: TextAlign.right,
                        style: theme.textTheme.titleSmall?.copyWith(fontFeatures: tabular),
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

class _TrendCard extends StatelessWidget {
  final List<Expense> expenses;
  final MonthKey lastMonth;

  const _TrendCard({required this.expenses, required this.lastMonth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final months = <MonthKey>[];
    for (var m = lastMonth, i = 0; i < 6; m = m.previous, i++) {
      months.insert(0, m);
    }
    final totals = {for (final m in months) m: 0.0};
    for (final e in expenses) {
      final m = MonthKey.of(e.date);
      if (totals.containsKey(m)) totals[m] = totals[m]! + e.amount;
    }
    final values = months.map((m) => totals[m]!).toList();
    final maxY = values.fold<double>(0, (a, b) => a > b ? a : b);
    final nonZero = values.where((v) => v > 0).toList();
    final avg = nonZero.isEmpty ? 0.0 : nonZero.reduce((a, b) => a + b) / nonZero.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Average ${Money.format(avg)} a month',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: tabular),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: maxY == 0
                  ? Center(child: Text('No spending in these months', style: theme.textTheme.bodyMedium))
                  : BarChart(
                      BarChartData(
                        maxY: maxY * 1.15,
                        alignment: BarChartAlignment.spaceAround,
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: maxY / 3,
                          getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        extraLinesData: ExtraLinesData(horizontalLines: [
                          HorizontalLine(y: avg, color: scheme.primary, strokeWidth: 1.5, dashArray: [6, 4]),
                        ]),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => scheme.inverseSurface,
                            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                              Money.format(rod.toY),
                              TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              interval: maxY / 3,
                              getTitlesWidget: (v, meta) => v == 0 || v > maxY * 1.05
                                  ? const SizedBox.shrink()
                                  : Text(
                                      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
                                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                    ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, meta) => Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  DateFormat('MMM').format(months[v.toInt()].start),
                                  style: theme.textTheme.labelMedium,
                                ),
                              ),
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < months.length; i++)
                            BarChartGroupData(x: i, barRods: [
                              BarChartRodData(
                                toY: values[i],
                                width: 22,
                                color: i == months.length - 1 ? scheme.primary : scheme.primary.withValues(alpha: 0.35),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ]),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
