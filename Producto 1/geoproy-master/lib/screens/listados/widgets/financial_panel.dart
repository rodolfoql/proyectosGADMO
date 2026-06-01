import 'package:flutter/material.dart';

class FinancialAuditPanel extends StatelessWidget {
  final Map<String, dynamic> proyecto;

  const FinancialAuditPanel({super.key, required this.proyecto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      color: const Color(0xFFF1F5F9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _metric("MONTO", "\$${proyecto['monto_total'].toStringAsFixed(0)}"),
          _metric("DEVENGADO", "\$${proyecto['presupuesto_devengado'].toStringAsFixed(0)}"),
          _metric("SALDO", "\$${proyecto['saldo'].toStringAsFixed(0)}"),
          _metric("PLAZO DIN.", "${proyecto['plazo_dinamico'] ?? proyecto['plazo']} d"),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
      ],
    );
  }
}
