import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../models/subscription_limits.dart' show LimitType;
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/paywall_sheet.dart';
import 'create_expense_screen.dart';
import 'cash_book_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/employee.dart';
import '../widgets/feature_guide_sheet.dart';

enum _Period { today, week, month, year, all }

String _l10nPeriod(BuildContext context, _Period p) {
  final l = AppLocalizations.of(context)!;
  switch (p) {
    case _Period.today:  return l.today;
    case _Period.week:   return l.thisWeek;
    case _Period.month:  return l.thisMonth;
    case _Period.year:   return l.thisYear;
    case _Period.all:    return l.allTime;
  }
}


class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  _Period _period = _Period.month;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showFeatureGuide(context, AppGuides.expenses);
    });
  }
  DateTimeRange? _customRange;
  String _categoryFilter = 'All';

  DateTimeRange _rangeFor(_Period p) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd =
        DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    switch (p) {
      case _Period.today:
        return DateTimeRange(start: todayStart, end: todayEnd);
      case _Period.week:
        return DateTimeRange(
            start: todayStart.subtract(const Duration(days: 6)),
            end: todayEnd);
      case _Period.month:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1), end: todayEnd);
      case _Period.year:
        return DateTimeRange(
            start: DateTime(now.year, 1, 1), end: todayEnd);
      case _Period.all:
        return DateTimeRange(start: DateTime(2020), end: todayEnd);
    }
  }

  List<Expense> _filtered(List<Expense> all) {
    final range = _rangeFor(_period);
    return all.where((e) {
      final inRange =
          !e.date.isBefore(range.start) && !e.date.isAfter(range.end);
      final inCat =
          _categoryFilter == 'All' || e.category == _categoryFilter;
      return inRange && inCat;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRange ??
          DateTimeRange(
              start: DateTime(now.year, now.month, 1), end: now),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _customRange = DateTimeRange(
          start: picked.start,
          end: DateTime(picked.end.year, picked.end.month,
              picked.end.day, 23, 59, 59, 999),
        );
        _period = _Period.all; // reuse "all" slot for custom
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<AppProvider>();
    // Expenses are managed by owners and managers (manageItems permission).
    final canManage = provider.canDo(AppPermission.manageItems);
    final currency = provider.profile.currency;
    final symbol = Fmt.currencySymbol(currency);
    final allExpenses = provider.expenses;
    final filtered = _filtered(allExpenses);

    final totalAmount =
        filtered.fold(0.0, (sum, e) => sum + e.amount);

    // Category breakdown for the current period
    final categoryTotals = <String, double>{};
    for (final e in filtered) {
      categoryTotals[e.category] =
          (categoryTotals[e.category] ?? 0) + e.amount;
    }
    final sortedCats = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // All unique categories in this period (for filter chips)
    final availableCategories = ['All', ...sortedCats.map((e) => e.key)];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expenses),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Cash Book',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CashBookScreen()),
            ),
          ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.addExpense,
              onPressed: () => _navigateToCreate(context),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── Summary banner ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _SummaryBanner(
                totalAmount: totalAmount,
                symbol: symbol,
                currency: currency,
                sortedCats: sortedCats,
                period: _period,
              ),
            ),
          ),

          // ── Period selector ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _PeriodSelector(
                selected: _period,
                customRange: _customRange,
                onPeriodChanged: (p) => setState(() => _period = p),
                onCustomTap: _pickCustomRange,
              ),
            ),
          ),

          // ── Category filter row ─────────────────────────────────────
          if (sortedCats.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: availableCategories.map((cat) {
                      final isSelected = cat == _categoryFilter;
                      final color = cat == 'All'
                          ? AppTheme.primary
                          : expenseCategoryColor(cat);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat == 'All' ? l10n.all : cat),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _categoryFilter = cat),
                          selectedColor:
                              color.withValues(alpha: 0.15),
                          checkmarkColor: color,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? color
                                : AppTheme.subtext(context),
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                          side: BorderSide(
                            color:
                                isSelected ? color : AppTheme.outline(context),
                          ),
                          backgroundColor: AppTheme.card(context),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

          // ── Expense list or empty state ─────────────────────────────
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(onAdd: () => _navigateToCreate(context)),
            )
          else ...[
            SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _ExpenseTile(
                    expense: filtered[i],
                    symbol: symbol,
                    canDelete: canManage,
                    onEdit: () => _navigateToEdit(context, filtered[i]),
                    onDelete: () => _confirmDelete(context, filtered[i]),
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
            const SliverPadding(
                padding: EdgeInsets.only(bottom: 80)),
          ],
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToCreate(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.addExpense),
              elevation: 2,
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Future<void> _navigateToCreate(BuildContext context) async {
    final info = context.read<AppProvider>().checkFeature(LimitType.expenses);
    if (info != null) {
      final up = await showPaywallSheet(context, info); // ignore: use_build_context_synchronously
      if (up && context.mounted) Navigator.pushNamed(context, '/plans');
      return;
    }
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateExpenseScreen()));
    }
  }

  void _navigateToEdit(BuildContext context, Expense expense) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CreateExpenseScreen(expense: expense)),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete "${expense.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await context.read<AppProvider>().deleteExpense(expense.id);
      } on PermissionDeniedException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(e.toString()),
                backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }
}

// ── Summary banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final double totalAmount;
  final String symbol;
  final String currency;
  final List<MapEntry<String, double>> sortedCats;
  final _Period period;

  const _SummaryBanner({
    required this.totalAmount,
    required this.symbol,
    required this.currency,
    required this.sortedCats,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${AppLocalizations.of(context)!.expenses} · ${_l10nPeriod(context, period)}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                key: ValueKey(totalAmount),
                tween: Tween(begin: 0, end: totalAmount),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context2, v, child2) => Text(
                  Fmt.currencyAmount(v, currency),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
              if (sortedCats.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: sortedCats.take(4).map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${entry.key}: $symbol${Fmt.compact(entry.value)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Period selector ───────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final _Period selected;
  final DateTimeRange? customRange;
  final ValueChanged<_Period> onPeriodChanged;
  final VoidCallback onCustomTap;

  const _PeriodSelector({
    required this.selected,
    required this.customRange,
    required this.onPeriodChanged,
    required this.onCustomTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._Period.values.where((p) => p != _Period.all).map((p) {
            final isSelected = selected == p;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_l10nPeriod(context, p)),
                selected: isSelected,
                onSelected: (_) => onPeriodChanged(p),
                selectedColor: const Color(0xFFDC2626),
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : AppTheme.onCard(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFFDC2626)
                      : AppTheme.outline(context),
                ),
                backgroundColor: AppTheme.card(context),
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selected == _Period.all && customRange != null
                        ? '${Fmt.shortDate(customRange!.start)} – ${Fmt.shortDate(customRange!.end)}'
                        : AppLocalizations.of(context)!.custom,
                    style: TextStyle(
                        color: AppTheme.onCard(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.calendar_month_outlined,
                      size: 14, color: AppTheme.subtext(context)),
                ],
              ),
              onPressed: onCustomTap,
              side: BorderSide(color: AppTheme.outline(context)),
              backgroundColor: AppTheme.card(context),
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expense tile ──────────────────────────────────────────────────────────────

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final String symbol;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseTile({
    required this.expense,
    required this.symbol,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = expenseCategoryColor(expense.category);
    return Dismissible(
      key: Key(expense.id),
      direction: canDelete
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child:
            const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Expense'),
            content: Text('Delete "${expense.title}"?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: AppTheme.error)),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 13),
            child: Row(
              children: [
                // Category icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    expenseCategoryIcon(expense.category),
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Title + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              expense.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.onCard(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (expense.isRecurring)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Monthly',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${expense.category} · ${Fmt.date(expense.date)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtext(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Amount
                Text(
                  '$symbol${Fmt.compact(expense.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  size: 34, color: Color(0xFFDC2626)),
            ),
            const SizedBox(height: 18),
            Text(AppLocalizations.of(context)!.noExpensesYet,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onCard(context))),
            const SizedBox(height: 6),
            Text(AppLocalizations.of(context)!.noExpensesHint,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.subtext(context))),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(AppLocalizations.of(context)!.addExpense),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
