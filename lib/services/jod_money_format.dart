/// عرض مبالغ بالدينار الأردني (بدون اعتماد حزمة intl).
String formatJod(double amount) {
  if (!amount.isFinite) return '0.00';
  return amount.toStringAsFixed(2);
}

double? parseJodInput(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return 0;
  return double.tryParse(t);
}
