// ─────────────────────────────────────────────────────────────────────────────
//  Audit Log — minimal read-only viewer
//
//  ApiService already has getAuditLogs()/addAuditLog(), but nothing in
//  the app displayed them. This is my best guess at what the 3-dot
//  menu on the Admin Console reference screenshot was for — I don't
//  actually know what that menu does, so treat this as a placeholder
//  to replace once you tell me what it should really be.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:form_app/api_service.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D5C63),
        foregroundColor: Colors.white,
        title: const Text('Audit Log', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: api.getAuditLogs(limit: 100),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final logs = snapshot.data!;
          if (logs.isEmpty) {
            return const Center(child: Text('No audit log entries yet.', style: TextStyle(color: Colors.black45)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final log = logs[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log['action']?.toString() ?? log['event']?.toString() ?? 'Unknown action',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (log['user'] != null) 'By ${log['user']}',
                        if (log['timestamp'] != null) log['timestamp'].toString(),
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7C8A97)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
