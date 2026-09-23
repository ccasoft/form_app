// ─────────────────────────────────────────────────────────────────────────────
//  Invoice Series Configuration
//  Stored in Firestore: collection 'invoiceSeries'
//  Doc ID: {companyId}_{financialYear}_{seriesName_slug}
//  e.g. "abc123_2025_INV" or "abc123_2025_CG"
//  Legacy docs (format: companyId_fy) are still readable via fromMap.
// ─────────────────────────────────────────────────────────────────────────────
class InvoiceSeriesConfig {
  final String id; // Firestore doc id
  final String companyId;
  final String companyName;
  final int financialYear; // 2025 means Apr 2025 – Mar 2026
  final String seriesName; // Human label, e.g. "INV", "CG", "Main"
  final String prefix; // e.g. "INV-", "CG/", "" (empty = pure numeric)
  final int startNumber; // first invoice number of the series
  final bool isSequential; // true = validate sequence; false = manual entry
  final bool isAlphanumeric; // true = prefix+number e.g. "INV-001"
  final int padLength; // zero-pad digits, 0 = no padding

  InvoiceSeriesConfig({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.financialYear,
    this.seriesName = 'Default',
    this.prefix = '',
    required this.startNumber,
    this.isSequential = true,
    this.isAlphanumeric = false,
    this.padLength = 0,
  });

  factory InvoiceSeriesConfig.fromMap(String id, Map<String, dynamic> m) {
    return InvoiceSeriesConfig(
      id: id,
      companyId: m['companyId'] as String? ?? '',
      companyName: m['companyName'] as String? ?? '',
      financialYear: m['financialYear'] as int? ?? _currentFY(),
      seriesName: m['seriesName'] as String? ?? 'Default',
      prefix: m['prefix'] as String? ?? '',
      startNumber: m['startNumber'] as int? ?? 1,
      isSequential: m['isSequential'] as bool? ?? true,
      isAlphanumeric: m['isAlphanumeric'] as bool? ?? false,
      padLength: m['padLength'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'companyId': companyId,
        'companyName': companyName,
        'financialYear': financialYear,
        'seriesName': seriesName,
        'prefix': prefix,
        'startNumber': startNumber,
        'isSequential': isSequential,
        'isAlphanumeric': isAlphanumeric,
        'padLength': padLength,
      };

  // ── Helpers ────────────────────────────────────────────────────────────────

  static int _currentFY() {
    final now = DateTime.now();
    return now.month >= 4 ? now.year : now.year - 1;
  }

  static int financialYearOf(DateTime date) =>
      date.month >= 4 ? date.year : date.year - 1;

  String formatNumber(int n) {
    final numStr =
        padLength > 0 ? n.toString().padLeft(padLength, '0') : n.toString();
    return '$prefix$numStr';
  }

  int? parseNumber(String invoiceNo) {
    final cleaned = invoiceNo.trim();
    if (prefix.isNotEmpty && !cleaned.startsWith(prefix)) return null;
    final numPart = cleaned.substring(prefix.length);
    return int.tryParse(numPart);
  }

  String? validateFormat(String invoiceNo) {
    final cleaned = invoiceNo.trim();
    if (cleaned.isEmpty) return 'Invoice number is required';
    if (!isSequential) return null;
    if (prefix.isNotEmpty && !cleaned.startsWith(prefix)) {
      return 'Invoice must start with prefix "$prefix"';
    }
    final numPart = cleaned.substring(prefix.length);
    final num = int.tryParse(numPart);
    if (num == null)
      return 'Invoice number part must be numeric after prefix "$prefix"';
    if (num < startNumber) {
      return 'Invoice number $num is below series start ($startNumber)';
    }
    return null;
  }

  String? validateSequence(String invoiceNo, int existingMax) {
    if (!isSequential) return null;
    final num = parseNumber(invoiceNo);
    if (num == null) return null;
    if (existingMax > 0 && num < existingMax) {
      return 'Warning: Invoice #$num is lower than the latest entered (#$existingMax). Possible duplicate or out-of-order entry.';
    }
    return null;
  }

  String get fyLabel {
    final next = (financialYear + 1).toString().substring(2);
    return 'FY $financialYear–$next';
  }

  /// Slug for use in doc IDs (safe characters only)
  static String _slug(String name) =>
      name.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toUpperCase();

  /// New multi-series doc ID: {companyId}_{fy}_{seriesNameSlug}
  static String docId(String companyId, int fy, String seriesName) =>
      '${companyId}_${fy}_${_slug(seriesName)}';

  /// Legacy doc ID (single series per company per FY)
  static String legacyDocId(String companyId, int fy) => '${companyId}_$fy';
}
