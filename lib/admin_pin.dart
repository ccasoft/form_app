import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_app/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Admin PIN Gate — "2112"
//  Usage:
//    final ok = await AdminPin.verify(context);
//    if (!ok) return;
//    // proceed with edit / delete
// ─────────────────────────────────────────────────────────────────────────────

const _kAdminPin = '2112';

class AdminPin {
  AdminPin._();

  /// Shows a PIN entry bottom-sheet.
  /// Returns true if the correct PIN was entered, false otherwise.
  static Future<bool> verify(BuildContext context, {String action = 'continue'}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PinSheet(action: action),
    );
    return result == true;
  }
}

class _PinSheet extends StatefulWidget {
  final String action;
  const _PinSheet({required this.action});

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  String _entered = '';
  bool _wrong = false;
  bool _obscure = true;

  void _tap(String digit) {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _wrong = false;
    });
    if (_entered.length == 4) _submit();
  }

  void _delete() {
    if (_entered.isEmpty) return;
    setState(() { _entered = _entered.substring(0, _entered.length - 1); _wrong = false; });
  }

  void _submit() {
    if (_entered == _kAdminPin) {
      HapticFeedback.lightImpact();
      Navigator.pop(context, true);
    } else {
      HapticFeedback.vibrate();
      setState(() { _wrong = true; _entered = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF37474F); // blue-grey dark
    const errorColor = Colors.red;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Handle ────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 18),

          // ── Lock icon ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _wrong ? errorColor.withValues(alpha: 0.1) : color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _wrong ? Icons.lock_open_rounded : Icons.admin_panel_settings_rounded,
              color: _wrong ? errorColor : color,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),

          // ── Title ─────────────────────────────────────────────────────
          Text('Admin PIN Required',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _wrong ? errorColor : color,
              )),
          const SizedBox(height: 4),
          Text(
            _wrong ? 'Incorrect PIN. Try again.' : 'Enter PIN to ${widget.action}',
            style: TextStyle(
              fontSize: 12,
              color: _wrong ? errorColor : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // ── PIN dots ─────────────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) {
            final filled = i < _entered.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? (_wrong ? errorColor : color)
                    : Colors.transparent,
                border: Border.all(
                  color: _wrong ? errorColor : (filled ? color : Colors.grey.shade300),
                  width: 2,
                ),
              ),
            );
          })),
          const SizedBox(height: 24),

          // ── Number pad ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(children: [
              _Row(['1','2','3'], color),
              const SizedBox(height: 10),
              _Row(['4','5','6'], color),
              const SizedBox(height: 10),
              _Row(['7','8','9'], color),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                // empty / cancel
                GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    width: 72, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('Cancel',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600))),
                  ),
                ),
                _Digit('0', color, _tap),
                // backspace
                GestureDetector(
                  onTap: _delete,
                  child: Container(
                    width: 72, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Icon(Icons.backspace_outlined, size: 20, color: AppTheme.textSecondary)),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 28),
        ]),
      ),
    );
  }

  Widget _Row(List<String> digits, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _Digit(d, color, _tap)).toList(),
    );
  }
}

class _Digit extends StatelessWidget {
  final String digit;
  final Color color;
  final void Function(String) onTap;
  const _Digit(this.digit, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(digit),
      child: Container(
        width: 72, height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Center(
          child: Text(digit,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
      ),
    );
  }
}
