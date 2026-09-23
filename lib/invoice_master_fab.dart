import 'package:flutter/material.dart';
import 'package:form_app/invoiceMasterManagement.dart';
import 'package:get/get.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  InvoiceMasterFAB — drop this into any Scaffold as a floatingActionButton
//  or inside a Stack → Positioned to place it wherever you want.
//
//  Usage (floatingActionButton slot):
//    floatingActionButton: const InvoiceMasterFAB(),
//    floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
//
//  Usage (inside Stack):
//    Positioned(bottom: 16, left: 16, child: const InvoiceMasterFAB()),
// ─────────────────────────────────────────────────────────────────────────────
class InvoiceMasterFAB extends StatefulWidget {
  const InvoiceMasterFAB({super.key});

  @override
  State<InvoiceMasterFAB> createState() => _InvoiceMasterFABState();
}

class _InvoiceMasterFABState extends State<InvoiceMasterFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _scale = Tween<double>(begin: 1.0, end: 0.91).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    Get.to(
      () => const InvoiceMasterManagement(),
      transition: Transition.leftToRight,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        _open();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1C2340), Color(0xFF2D3A6B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1C2340).withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.manage_search_rounded, color: Colors.white, size: 17),
              SizedBox(width: 7),
              Text(
                'Invoice\nMaster',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
