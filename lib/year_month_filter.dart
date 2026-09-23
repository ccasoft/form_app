import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class YearMonthFilter extends StatelessWidget {
  final int selectedYear;
  final int? selectedMonth; // null = all months
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int?> onMonthChanged;
  final Color color;

  /// Nested count map: { year: { month: count } }
  /// Used only to show dot indicator (has data vs empty) — no number displayed.
  final Map<int, Map<int, int>> countMap;

  const YearMonthFilter({
    super.key,
    required this.selectedYear,
    required this.selectedMonth,
    required this.onYearChanged,
    required this.onMonthChanged,
    this.color = AppTheme.primary,
    this.countMap = const {},
  });

  bool _yearHasData(int year) {
    final months = countMap[year];
    if (months == null) return false;
    return months.values.any((c) => c > 0);
  }

  bool _monthHasData(int year, int month) {
    return (countMap[year]?[month] ?? 0) > 0;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Data only goes back to 2025 — don't offer earlier, empty years.
    const dataStartYear = 2025;
    final years = List.generate(
      (now.year - dataStartYear + 1).clamp(1, 100),
      (i) => now.year - i,
    );

    return Container(
      color: color,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Year row ──────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: years.map((y) {
                final active   = y == selectedYear;
                final hasData  = _yearHasData(y);
                return GestureDetector(
                  onTap: () => onYearChanged(y),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6, top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: active ? Colors.white : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$y',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: active ? color : Colors.white,
                          ),
                        ),
                        if (hasData) ...[
                          const SizedBox(width: 5),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active ? color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          // ── Month row ─────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _monthChip(
                  label: 'All',
                  hasDot: countMap.isNotEmpty,
                  active: selectedMonth == null,
                  onTap: () => onMonthChanged(null),
                  color: color,
                ),
                ...List.generate(12, (i) {
                  final m      = i + 1;
                  final active = selectedMonth == m;
                  final hasDot = _monthHasData(selectedYear, m);
                  return _monthChip(
                    label: _monthNames[i],
                    hasDot: hasDot,
                    active: active,
                    onTap: () => onMonthChanged(m),
                    color: color,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthChip({
    required String label,
    required bool hasDot,
    required bool active,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? color : Colors.white,
              ),
            ),
            if (hasDot) ...[
              const SizedBox(width: 4),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
