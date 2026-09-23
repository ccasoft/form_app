import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:form_app/data.dart';
import 'package:form_app/invoice_series_config.dart';

const String _BASE_URL =
    //'https://unabsorbed-noncongregative-truman.ngrok-free.dev';
    'https://win-dkfo938f104-1.tail25c88f.ts.net';

const Map<String, String> _HEADERS = {
  'Content-Type': 'application/json',
  'ngrok-skip-browser-warning': 'true',
};
const Map<String, String> _GET_HEADERS = {
  'ngrok-skip-browser-warning': 'true',
};

class ApiService {
  // Public baseUrl so other files can use ApiService.baseUrl
  static String get baseUrl => _BASE_URL;

  static Future<Map<String, dynamic>> _get(String path) async {
    try {
      final r =
          await http.get(Uri.parse('$_BASE_URL$path'), headers: _GET_HEADERS);
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('GET $path error: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    try {
      final r = await http.post(Uri.parse('$_BASE_URL$path'),
          headers: _HEADERS, body: jsonEncode(body));
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('POST $path error: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  static Future<Map<String, dynamic>> _put(
      String path, Map<String, dynamic> body) async {
    try {
      final r = await http.put(Uri.parse('$_BASE_URL$path'),
          headers: _HEADERS, body: jsonEncode(body));
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('PUT $path error: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  static Future<Map<String, dynamic>> _delete(String path) async {
    try {
      final r = await http.delete(Uri.parse('$_BASE_URL$path'),
          headers: _GET_HEADERS);
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('DELETE $path error: $e');
      return {'success': false, 'error': '$e'};
    }
  }

  static bool _ok(Map<String, dynamic> r) => r['success'] == true;

  // AUTH
  Future<String?> login(String userId, String password) async {
    final r =
        await _post('/auth/login', {'userId': userId, 'password': password});
    if (_ok(r)) return null;
    return r['error'] as String? ?? 'Login failed';
  }

  Future<Map<String, dynamic>?> loginData(
      String userId, String password) async {
    final r =
        await _post('/auth/login', {'userId': userId, 'password': password});
    if (_ok(r)) return r['data'] as Map<String, dynamic>?;
    return null;
  }

  // ── Face login ──────────────────────────────────────────────────
  /// Returns the full raw {success, data, error} response so callers
  /// can distinguish "no match" from a network/server error.
  Future<Map<String, dynamic>> loginWithFace(List<double> embedding) async {
    return _post('/auth/face/login', {'embedding': embedding});
  }

  Future<bool> enrollFace(String userId, List<double> embedding) async {
    final r = await _post(
        '/auth/face/enroll', {'userId': userId, 'embedding': embedding});
    return _ok(r);
  }

  Future<bool> removeFaceEnrollment(String userId) async {
    final r = await _delete('/auth/face/$userId');
    return _ok(r);
  }

  Future<bool> isFaceEnrolled(String userId) async {
    final r = await _get('/auth/face/$userId/status');
    if (!_ok(r)) return false;
    return (r['data'] as Map<String, dynamic>?)?['enrolled'] == true;
  }

  Future<Map<String, dynamic>?> fetchPermissions(String userId) async {
    final r = await _get('/auth/permissions/$userId');
    if (_ok(r)) return r['data'] as Map<String, dynamic>?;
    return null;
  }

  Future<bool> savePermissions(
      String userId, Map<String, dynamic> screens) async {
    final r = await _put('/auth/permissions/$userId', {'screens': screens});
    return _ok(r);
  }

  // ROUTES
  Future<List<RouteData>> getRoutes() async {
    final r = await _get('/routes');
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) => RouteData.fromMap(d['routeId'], d as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.routeName.compareTo(b.routeName));
  }

  Future<bool> createRoute(Map<String, dynamic> data) async =>
      _ok(await _post('/routes', data));
  Future<bool> updateRoute(String routeId, Map<String, dynamic> data) async =>
      _ok(await _post('/routes', {...data, 'routeId': routeId}));
  Future<bool> deleteRoute(String routeId) async =>
      _ok(await _delete('/routes/$routeId'));

  // PARTIES
  Future<bool> createParty(Map<String, dynamic> data, bool isEditing) async =>
      _ok(await _post('/parties', {...data, 'isEditing': isEditing}));

  Future<List<PartyData>> getParties() async {
    final r = await _get('/parties');
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) => PartyData.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<List<PartyData>> getPartiesNeedingCheque() async {
    final r = await _get('/parties/needs-cheque');
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) => PartyData.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<List<PartyData>> getPartiesByCompany(String companyId) async {
    final r = await _get('/parties/by-company/$companyId');
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) => PartyData.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  // COMPANIES
  Future<List<CompanyData>> getCompanies() async {
    final r = await _get('/companies');
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) =>
            CompanyData.fromMap(d['companyId'], d as Map<String, dynamic>))
        .toList();
  }

  Future<bool> createCompany(Map<String, dynamic> data) async =>
      _ok(await _post('/companies', data));
  Future<bool> updateCompany(String id, Map<String, dynamic> data) async =>
      _ok(await _put('/companies/$id', data));
  Future<bool> deleteCompany(String id) async =>
      _ok(await _delete('/companies/$id'));

  // TRANSPORT
  Future<List<String>> getTransport() async {
    final r = await _get('/transport');
    if (!_ok(r)) return [];
    return List<String>.from(r['data'] as List);
  }

  Future<bool> saveTransport(List<String> transportList) async =>
      _ok(await _post('/transport', {'transportList': transportList}));

  // INVOICE SERIES
  Future<List<InvoiceSeriesConfig>> getSeriesConfigs() async {
    final r = await _get('/invoice-series');
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) =>
            InvoiceSeriesConfig.fromMap(d['id'], d as Map<String, dynamic>))
        .toList();
  }

  // Combined call — returns configs + maxNum in one round trip
  Future<List<Map<String, dynamic>>> getSeriesConfigsWithMax(int fy) async {
    final r = await _get('/invoice-series-with-max/$fy');
    if (!_ok(r)) return [];
    return List<Map<String, dynamic>>.from(
        (r['data'] as List).map((m) => Map<String, dynamic>.from(m as Map)));
  }

  Future<List<InvoiceSeriesConfig>> getSeriesConfigsForCompany(
      String companyId, int fy) async {
    final r = await _get('/invoice-series/$companyId/$fy');
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) =>
            InvoiceSeriesConfig.fromMap(d['id'], d as Map<String, dynamic>))
        .toList();
  }

  Future<InvoiceSeriesConfig?> getSeriesConfig(String companyId, int fy) async {
    final all = await getSeriesConfigsForCompany(companyId, fy);
    return all.isNotEmpty ? all.first : null;
  }

  Future<bool> saveSeriesConfig(InvoiceSeriesConfig cfg) async =>
      _ok(await _post('/invoice-series', cfg.toMap()));
  Future<bool> deleteSeriesConfig(String id) async =>
      _ok(await _delete('/invoice-series/$id'));

  // INVOICE
  Future<String> createInvoice(Map<String, dynamic> data) async {
    final r = await _post('/invoices', data);
    if (_ok(r)) return r['data'] as String? ?? 'true';
    return r['error'] as String? ?? 'Something went wrong';
  }

  Future<bool> invoiceNumberExists(
      String companyId, int fy, String invoiceNumber) async {
    final r = await _post('/invoices/check-exists',
        {'companyId': companyId, 'fy': fy, 'invoiceNumber': invoiceNumber});
    return _ok(r) ? r['data'] as bool : false;
  }

  Future<int> getMaxInvoiceNumber(String companyId, int fy, String prefix,
      {int? startNumber, int? upperBound}) async {
    final enc = Uri.encodeComponent(prefix.isEmpty ? '_NONE_' : prefix);
    String q = '/invoices/max-number/$companyId/$fy/$enc';
    final params = <String>[];
    if (startNumber != null) params.add('start=$startNumber');
    if (upperBound != null) params.add('upper=$upperBound');
    if (params.isNotEmpty) q += '?${params.join('&')}';
    final r = await _get(q);
    if (!_ok(r)) return 0;
    return (r['data'] as num?)?.toInt() ?? 0;
  }

  // Batch version — one HTTP call returns max numbers for ALL series at once.
  // series: list of {id, companyId, prefix, startNumber, upperBound}
  Future<Map<String, int>> getMaxInvoiceNumbersBatch(
      int fy, List<Map<String, dynamic>> series) async {
    final r = await _post('/invoices/max-numbers-batch', {
      'fy': fy,
      'series': series,
    });
    if (!_ok(r)) return {};
    return Map<String, int>.from((r['data'] as Map)
        .map((k, v) => MapEntry(k as String, (v as num).toInt())));
  }

  Future<Set<int>> getInvoiceNumbersForSeriesCheck(
      String companyId, int fy, String prefix) async {
    final enc = Uri.encodeComponent(prefix.isEmpty ? '_NONE_' : prefix);
    final r = await _get('/invoices/numbers-for-series/$companyId/$fy/$enc');
    if (!_ok(r)) return {};
    return Set<int>.from((r['data'] as List).map((n) => (n as num).toInt()));
  }

  // Server-side gap detection — fast, no Flutter loop needed.
  Future<Map<String, dynamic>> getMissingInvoiceNumbers(
      String companyId, int fy, String prefix,
      {int startNumber = 1, int? upperBound, int cap = 500}) async {
    final enc = Uri.encodeComponent(prefix.isEmpty ? '_NONE_' : prefix);
    String q =
        '/invoices/missing-numbers/$companyId/$fy/$enc?start=$startNumber&cap=$cap';
    if (upperBound != null) q += '&upper=$upperBound';
    final r = await _get(q);
    if (!_ok(r))
      return {'missing': <int>[], 'total': 0, 'entered': 0, 'maxNum': 0};
    final d = r['data'] as Map<String, dynamic>;
    return {
      'missing':
          List<int>.from((d['missing'] as List).map((n) => (n as num).toInt())),
      'total': (d['total'] as num).toInt(),
      'entered': (d['entered'] as num).toInt(),
      'maxNum': (d['maxNum'] as num).toInt(),
      'minNum': (d['minNum'] as num?)?.toInt(),
      'warning': d['warning'] as String?,
    };
  }

  Future<Map<int, Map<int, int>>> getInvoiceCountMap(int stage) async {
    final r = await _get('/invoices/count-map/$stage');
    if (!_ok(r)) return {};
    final raw = r['data'] as Map<String, dynamic>;
    return raw.map((y, months) => MapEntry(
          int.parse(y),
          (months as Map<String, dynamic>)
              .map((m, c) => MapEntry(int.parse(m), (c as num).toInt())),
        ));
  }

  Future<List<InvoiceData>> getInvoices(int stage,
      {int? year, int? month}) async {
    String q = '/invoices?stage=$stage';
    if (year != null) q += '&year=$year';
    if (month != null) q += '&month=$month';
    final r = await _get(q);
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) => _mapToInvoiceData(d as Map<String, dynamic>))
        .toList();
  }

  Future<List<InvoiceData>> getInvoicesUpToDate(DateTime cutoff,
      {int? year, int? month}) async {
    final invoices = await getInvoices(2, year: year, month: month);
    return invoices.where((inv) {
      if (inv.invoiceDate.isEmpty) return true;
      try {
        final parts = inv.invoiceDate.split('/');
        if (parts.length != 3) return true;
        final d = DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        return !d.isAfter(cutoff);
      } catch (_) {
        return true;
      }
    }).toList();
  }

  // TELECALLING (Cold Chain / Cool Chain / Special — delivery follow-up)
  // Invoices at stage >= 3 (Dispatched) whose orderType needs a delivery
  // confirmation call. Backend filters by stage + orderType server-side.
  Future<List<InvoiceData>> getTelecallingInvoices() async {
    final r = await _get('/invoices/telecalling');
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) => _mapToInvoiceData(d as Map<String, dynamic>))
        .toList();
  }

  // Records one call attempt (kept in telecalling_logs on the backend for
  // a full history) and updates the invoice's current telecall_* summary.
  // Throws with the SERVER's actual error text on failure (instead of just
  // returning false) so the UI can show what really went wrong — a DB
  // error (e.g. missing column/table) looks very different from the
  // request never reaching the server at all, and silently returning
  // false made both look identical ("could not reach the server").
  Future<bool> submitTelecallResult(
    String invoiceId, {
    required bool delivered,
    required String calledBy,
    String? contactPerson,
    String? temperature,
    int? deliveryTime,
    String? transportNumberUsed,
    String? remarks,
  }) async {
    final r = await _put('/invoices/$invoiceId/telecall', {
      'delivered': delivered,
      'calledBy': calledBy,
      if (contactPerson != null) 'contactPerson': contactPerson,
      if (temperature != null) 'temperature': temperature,
      if (deliveryTime != null) 'deliveryTime': deliveryTime,
      if (transportNumberUsed != null)
        'transportNumberUsed': transportNumberUsed,
      if (remarks != null) 'remarks': remarks,
    });
    if (!_ok(r)) {
      throw Exception(r['error']?.toString() ?? 'Save failed on the server.');
    }
    return true;
  }

  Future<List<Map<String, dynamic>>> getTelecallLogs(String invoiceId) async {
    final r = await _get('/invoices/$invoiceId/telecall-logs');
    if (!_ok(r)) return [];
    return (r['data'] as List).cast<Map<String, dynamic>>();
  }

  // Looks up a phone number from an Office category+entries directory
  // (prefix 'address-book' for parties, 'transport' for transport
  // contacts) by matching an entry's name/firmName against [name].
  // Used so telecalling can call the numbers already saved in Office
  // Hub rather than duplicating contact data on the invoice itself.
  Future<String?> findOfficeContactPhone(String prefix, String name) async {
    final target = name.trim().toLowerCase();
    if (target.isEmpty) return null;
    try {
      final categories = await getOfficeCategories(prefix);
      for (final cat in categories) {
        final catName = cat['name']?.toString() ?? '';
        if (catName.isEmpty) continue;
        final entries = await getOfficeCategoryEntries(prefix, catName);
        for (final e in entries) {
          final n = (e['name']?.toString() ?? '').trim().toLowerCase();
          final firm = (e['firmName']?.toString() ?? '').trim().toLowerCase();
          if (n == target || firm == target) {
            final phone = e['phone']?.toString();
            if (phone != null && phone.isNotEmpty) return phone;
          }
        }
      }
    } catch (e) {
      debugPrint('findOfficeContactPhone error: $e');
    }
    return null;
  }

  // Same lookup as [findOfficeContactPhone] but returns every matching entry
  // (not just the first phone found), so a stockist with both a shop number
  // and a staff number — or any other name that has more than one number
  // saved — shows all of them. Each map carries: id, categoryName, name,
  // phone, notes (used as a free-text label like "Stockist"/"Staff").
  Future<List<Map<String, dynamic>>> findOfficeContacts(
      String prefix, String name) async {
    final target = name.trim().toLowerCase();
    if (target.isEmpty) return [];
    final matches = <Map<String, dynamic>>[];
    try {
      final categories = await getOfficeCategories(prefix);
      for (final cat in categories) {
        final catName = cat['name']?.toString() ?? '';
        if (catName.isEmpty) continue;
        final entries = await getOfficeCategoryEntries(prefix, catName);
        for (final e in entries) {
          final n = (e['name']?.toString() ?? '').trim().toLowerCase();
          final firm = (e['firmName']?.toString() ?? '').trim().toLowerCase();
          if (n == target || firm == target) {
            final phone = e['phone']?.toString() ?? '';
            if (phone.isNotEmpty) {
              matches.add({
                'id': e['id'],
                'categoryName': catName,
                'name': e['name'],
                'phone': phone,
                'notes': e['notes']?.toString() ?? '',
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('findOfficeContacts error: $e');
    }
    return matches;
  }

  Future<bool> createPackaging(Map<String, dynamic> data) async {
    final ids = List<String>.from(data['selectedInvoicesIdList'] ?? []);
    final body = {
      ...data,
      'stage': 2,
      'packagingTimestamp': DateTime.now().millisecondsSinceEpoch
    };
    return _ok(
        await _post('/invoices/batch-update', {'ids': ids, 'data': body}));
  }

  Future<bool> createDispatch(Map<String, dynamic> data) async {
    final ids = List<String>.from(data['selectedInvoicesIdList'] ?? []);
    final body = {
      ...data,
      'stage': 3,
      'dispatchTimestamp': DateTime.now().millisecondsSinceEpoch,
      'ackDone': false
    };
    return _ok(
        await _post('/invoices/batch-update', {'ids': ids, 'data': body}));
  }

  Future<bool> deleteDispatch(List<String> invoiceIds) async {
    return _ok(await _post('/invoices/batch-update', {
      'ids': invoiceIds,
      'data': {
        'stage': 2,
        'tripNumber': null,
        'openingKm': null,
        'dispatchTimestamp': null,
        'dispatchDate': null,
        'vehicleNumber': null
      },
    }));
  }

  Future<bool> updateDispatch(
          List<String> invoiceIds, Map<String, dynamic> data) async =>
      _ok(await _post(
          '/invoices/batch-update', {'ids': invoiceIds, 'data': data}));

  Future<String> getNextTripNumber() async {
    final r = await _get('/invoices/next-trip-number');
    return _ok(r) ? r['data'] as String : '';
  }

  Future<List<InvoiceData>> getInvoicesForAck({int? year, int? month}) async {
    String q = '/invoices/ack';
    final params = <String>[];
    if (year != null) params.add('year=$year');
    if (month != null) params.add('month=$month');
    if (params.isNotEmpty) q += '?${params.join('&')}';
    final r = await _get(q);
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) => _mapToInvoiceData(d as Map<String, dynamic>))
        .toList();
  }

  Future<List<InvoiceData>> getInvoicesForCheque(
      {int? year, int? month}) async {
    String q = '/invoices/cheque';
    final params = <String>[];
    if (year != null) params.add('year=$year');
    if (month != null) params.add('month=$month');
    if (params.isNotEmpty) q += '?${params.join('&')}';
    final r = await _get(q);
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) => _mapToInvoiceData(d as Map<String, dynamic>))
        .toList();
  }

  Future<List<InvoiceData>> getInvoicesForChequeAllStages(
          {int? year, int? month}) =>
      getInvoicesForCheque(year: year, month: month);

  Future<bool> createAcknowledgement(Map<String, dynamic> data) async {
    final ids = List<String>.from(data['selectedInvoicesIdList'] ?? []);
    final body = {
      ...data,
      'stage': 4,
      'ackDone': true,
      'ackTimestamp': DateTime.now().millisecondsSinceEpoch
    };
    body.remove('selectedInvoicesIdList');
    return _ok(
        await _post('/invoices/batch-update', {'ids': ids, 'data': body}));
  }

  Future<bool> createChequeCollection(Map<String, dynamic> data) async {
    final ids = List<String>.from(data['selectedInvoicesIdList'] ?? []);
    final body = {
      'chequeDone': true,
      'chequeNumber': data['chequeNumber'] ?? '',
      'chequeDate': data['chequeDate'] ?? '',
      'chequeAmount': data['chequeAmount'] ?? '',
      'bankName': data['bankName'] ?? '',
      'chequeTimestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return _ok(
        await _post('/invoices/batch-update', {'ids': ids, 'data': body}));
  }

  Future<List<AcknowledgementData>> getAcknowledgements() async {
    final r = await _get('/invoices?stage=3');
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) => AcknowledgementData.fromJson(d as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<Map<String, dynamic>> getChequeStats() async {
    final r = await _get('/invoices/cheque-stats');
    return _ok(r)
        ? r['data'] as Map<String, dynamic>
        : {'pending': 0, 'collected': 0, 'pendingByStage': {}};
  }

  Future<Map<int, int>> getStageCounts() async {
    final r = await _get('/invoices/stage-counts');
    if (!_ok(r)) return {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    return (r['data'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
  }

  Future<List<Map<String, dynamic>>> getPackagingGroupsByLR() async {
    final r = await _get('/invoices/packaging-groups-lr');
    if (!_ok(r)) return [];
    return (r['data'] as List).map((group) {
      final g = Map<String, dynamic>.from(group as Map);
      g['invoices'] = (g['invoices'] as List)
          .map((inv) => _mapToInvoiceData(inv as Map<String, dynamic>))
          .toList();
      return g;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getGarageSlipPending() async {
    final r = await _get('/invoices/garage-slip-pending');
    if (!_ok(r)) return [];
    return (r['data'] as List).map((group) {
      final g = Map<String, dynamic>.from(group as Map);
      g['invoices'] = (g['invoices'] as List)
          .map((inv) => _mapToInvoiceData(inv as Map<String, dynamic>))
          .toList();
      return g;
    }).toList();
  }

  Future<bool> updateLRByGarageSlip(
          {required String garageSlip,
          required String lrNumber,
          required String lrDate}) async =>
      _ok(await _post('/invoices/update-lr-by-garage',
          {'garageSlip': garageSlip, 'lrNumber': lrNumber, 'lrDate': lrDate}));

  Future<bool> addInvoiceToExistingPackaging(
      {required String newInvoiceId,
      required String ewayBillNumber,
      required Map<String, dynamic> packagingData,
      required List<String> siblingInvoiceIds}) async {
    final allIds = [...siblingInvoiceIds, newInvoiceId];
    // Build per-invoice eway bill map: only set for the new invoice
    final ewayBillNumbers = <String, String>{
      newInvoiceId: ewayBillNumber,
    };
    final body = {
      'stage': 2,
      'lrNumber': packagingData['lrNumber'] ?? '',
      'lrDate': packagingData['lrDate'] ?? '',
      'packCase': packagingData['packCase'] ?? '',
      'looseCase': packagingData['looseCase'] ?? '',
      'totalCase': packagingData['totalCase'] ?? '',
      'packagingTimestamp': packagingData['packagingTimestamp'] ??
          DateTime.now().millisecondsSinceEpoch,
      'ewayBillNumbers': ewayBillNumbers,
      'selectedInvoicesIdList': allIds,
    };
    return _ok(
        await _post('/invoices/batch-update', {'ids': allIds, 'data': body}));
  }

  Future<List<InvoiceAcknowledgementData>> getAllMasterInvoices(
      {int? year, int? month}) async {
    String q = '/invoices/master';
    final params = <String>[];
    if (year != null) params.add('year=$year');
    if (month != null) params.add('month=$month');
    if (params.isNotEmpty) q += '?${params.join('&')}';
    final r = await _get(q);
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) => _mapToInvoiceAck(d as Map<String, dynamic>))
        .toList();
  }

  Future<List<InvoiceAcknowledgementData>> getMasterInvoicesByDateRange(
      DateTime from, DateTime to) async {
    final q =
        '/invoices/master?from=${from.millisecondsSinceEpoch}&to=${to.millisecondsSinceEpoch}';
    final r = await _get(q);
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) => _mapToInvoiceAck(d as Map<String, dynamic>))
        .toList();
  }

  Future<List<InvoiceAcknowledgementData>> getAllMasterInvoicesWithDebounce(
      String searchQuery) async {
    final q = '/invoices/master?search=${Uri.encodeComponent(searchQuery)}';
    final r = await _get(q);
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) => _mapToInvoiceAck(d as Map<String, dynamic>))
        .toList();
  }

  Future<List<InvoiceAcknowledgementData>> getInvoicesForRegister(
      String companyId, int fy) async {
    final r = await _get('/invoices/register/$companyId/$fy');
    if (!_ok(r)) return [];
    return (r['data'] as List)
        .map((d) => _mapToInvoiceAck(d as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>?> rawInvoiceByNumber(String invoiceNumber) async {
    final r = await _get(
        '/invoices/raw-by-number/${Uri.encodeComponent(invoiceNumber)}');
    return _ok(r) ? r['data'] as Map<String, dynamic>? : null;
  }

  Future<bool> updateInvoiceMaster(
          String docId, Map<String, dynamic> data) async =>
      _ok(await _put('/invoices/$docId', data));

  Future<bool> deleteAckPhoto(String docId) async =>
      _ok(await _delete('/invoices/$docId/ack-photo'));
  Future<bool> deleteInvoiceMaster(String docId) async =>
      _ok(await _delete('/invoices/$docId'));
  Future<bool> voidInvoice(String invoiceId) async =>
      _ok(await _post('/invoices/$invoiceId/void', {}));
  Future<bool> voidInvoiceWithRemarks(String invoiceId,
          {String remarks = ''}) async =>
      _ok(await _post('/invoices/$invoiceId/void', {'remarks': remarks}));
  Future<bool> thirdPartyVoidInvoice(String invoiceId,
          {required String remarks}) async =>
      _ok(await _post(
          '/invoices/$invoiceId/third-party', {'remarks': remarks}));

  // IMAGE UPLOAD
  Future<bool> uploadAckPhotoBytes({
    required List<String> invoiceIds,
    required String invoiceNumbers,
    required List<int> imageBytes,
    String fileName = 'photo.jpg',
  }) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final r = await http.post(
        Uri.parse('$_BASE_URL/upload/ack-photo-base64'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'imageBase64': base64Image,
          'invoiceIds': invoiceIds,
          'invoiceNumbers': invoiceNumbers,
        }),
      );
      debugPrint('uploadAckPhotoBytes status: ${r.statusCode}');
      debugPrint('uploadAckPhotoBytes body: ${r.body}');
      final body = jsonDecode(r.body);
      return body['success'] == true;
    } catch (e) {
      debugPrint('uploadAckPhotoBytes error: $e');
      return false;
    }
  }

  Future<bool> uploadImage(
      List<String> invoiceId, String fileName, Uint8List imageBytes) async {
    try {
      final uri = Uri.parse('$_BASE_URL/upload/invoice-image');
      final req = http.MultipartRequest('POST', uri);
      req.headers.addAll(_GET_HEADERS);
      req.files.add(http.MultipartFile.fromBytes('file', imageBytes,
          filename: fileName, contentType: MediaType('image', 'jpeg')));
      req.fields['invoiceIds'] = jsonEncode(invoiceId);
      final res = await req.send();
      final body = jsonDecode(await res.stream.bytesToString());
      return body['success'] == true;
    } catch (e) {
      debugPrint('uploadImage error: $e');
      return false;
    }
  }

  // HELPERS
  InvoiceData _mapToInvoiceData(Map<String, dynamic> d) {
    return InvoiceData(
      id: d['id'] ?? '',
      partyData: PartyData.fromJson({
        'partyId': d['partyId'] ?? '',
        'partyName': d['partyName'] ?? '',
        'address': d['address'] ?? '',
        'contactNumber1': d['contactNumber1'] ?? '',
        'contactNumber2': d['contactNumber2'] ?? '',
        'contactPerson': d['contactPerson'] ?? '',
        'transportName': d['transportName'] ?? '',
        'routeName': d['routeName'] ?? '',
        'needsCheque': d['needsCheque'] ?? false,
      }),
      companyName: d['companyName'] ?? '',
      invoiceNumber: d['invoiceNumber'] ?? '',
      selectedInvoicesIdList:
          List<String>.from(d['selectedInvoicesIdList'] ?? []),
      invoiceDate: d['invoiceDate'] ?? '',
      invoiceAmount: d['invoiceAmount'] ?? '',
      timestamp: (d['timestamp'] as num?)?.toInt() ?? 0,
      validityDate: d['validityDate'] ?? '',
      ewayBillNumber: d['ewayBillNumber'] ?? '',
      transportName: d['transportName'] ?? '',
      orderType: d['orderType'] ?? '',
      stage: (d['stage'] as num?)?.toInt() ?? 1,
      routeName: d['routeName'],
      vehicleNumber: d['vehicleNumber'],
      seriesId: d['seriesId'],
      seriesName: d['seriesName'],
      dispatchDate: d['dispatchDate'],
      tripNumber: d['tripNumber'],
      openingKm: d['openingKm'],
      lrNumber: d['lrNumber'],
      lrDate: d['lrDate'],
      packCase: d['packCase'],
      looseCase: d['looseCase'],
      totalCase: d['totalCase'],
      ackPhotoUrl: d['ackPhotoUrl'],
      telecallStatus: d['telecallStatus'],
      telecallAttempts: (d['telecallAttempts'] as num?)?.toInt(),
      telecallLastCalledAt: (d['telecallLastCalledAt'] as num?)?.toInt(),
      telecallContactPerson: d['telecallContactPerson'],
      telecallTemperature: d['telecallTemperature'],
      telecallDeliveryTime: (d['telecallDeliveryTime'] as num?)?.toInt(),
    );
  }

  InvoiceAcknowledgementData _mapToInvoiceAck(Map<String, dynamic> d) {
    return InvoiceAcknowledgementData(
      partyData: PartyData.fromJson({
        'partyId': d['partyId'] ?? '',
        'partyName': d['partyName'] ?? '',
        'address': d['address'] ?? '',
        'contactNumber1': d['contactNumber1'] ?? '',
        'contactNumber2': d['contactNumber2'] ?? '',
        'contactPerson': d['contactPerson'] ?? '',
        'transportName': d['transportName'] ?? '',
        'routeName': d['routeName'] ?? '',
      }),
      invoiceNumber: d['invoiceNumber'] ?? '',
      invoiceDate: d['invoiceDate'] ?? '',
      invoiceAmount: d['invoiceAmount'] ?? '',
      timestamp: (d['timestamp'] as num?)?.toInt() ?? 0,
      validityDate: d['validityDate'] ?? '',
      ewayBillNumber: d['ewayBillNumber'] ?? '',
      transportName: d['transportName'] ?? '',
      id: d['id'] ?? '',
      orderType: d['orderType'] ?? '',
      selectedInvoicesIdList:
          List<String>.from(d['selectedInvoicesIdList'] ?? []),
      companyName: d['companyName'] ?? '',
      looseCase: d['looseCase'] ?? '',
      lrDate: d['lrDate'] ?? '',
      lrNumber: d['lrNumber'] ?? '',
      openingKm: d['openingKm'] ?? '',
      packCase: d['packCase'] ?? '',
      partyId: d['partyId'] ?? '',
      partyName: d['partyName'] ?? '',
      totalCase: d['totalCase'] ?? '',
      tripNumber: d['tripNumber'] ?? '',
      stage: (d['stage'] as num?)?.toInt() ?? 1,
      routeName: d['routeName'],
      vehicleNumber: d['vehicleNumber'],
      chequeNumber: d['chequeNumber'],
      chequeDate: d['chequeDate'],
      chequeAmount: d['chequeAmount'],
      bankName: d['bankName'],
      dispatchDate: d['dispatchDate'],
      ackPhotoUrl: d['ackPhotoUrl'],
      isCancelled: d['isCancelled'] as bool? ?? false,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  OFFICE CONSOLE — merged from the separate CCA Admin Console
  //  app. Replaces that app's own api_client.dart entirely; every
  //  call here uses this same ApiService (same base URL, same
  //  headers, same login) instead of a second separate API wrapper.
  // ═══════════════════════════════════════════════════════════════

  // ── Licenses & AMC ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLicenseCategories() async {
    final r = await _get('/api/license-categories');
    if (!_ok(r)) return [];
    return (r['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<bool> addLicenseEntry(
      String categoryName, Map<String, dynamic> data) async {
    final r = await _post(
        '/api/license-categories/by-name/$categoryName/entries', data);
    return _ok(r);
  }

  Future<List<Map<String, dynamic>>> getAmcContracts() async {
    final r = await _get('/api/amc-contracts');
    if (!_ok(r)) return [];
    return (r['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<bool> addAmcContract(Map<String, dynamic> data) async {
    final r = await _post('/api/amc-contracts', data);
    return _ok(r);
  }

  // ── One-time licenses ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getOneTimeLicenses() async {
    final r = await _get('/api/one-time-licenses');
    if (!_ok(r)) return [];
    return (r['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<bool> addOneTimeLicense(Map<String, dynamic> data) async {
    final r = await _post('/api/one-time-licenses', data);
    return _ok(r);
  }

  Future<bool> deleteOneTimeLicense(String id) async {
    final r = await _delete('/api/one-time-licenses/$id');
    return _ok(r);
  }

  // ── Important numbers ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getImportantNumbers() async {
    final r = await _get('/api/important-numbers');
    if (!_ok(r)) return [];
    return (r['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<bool> addImportantNumber(Map<String, dynamic> data) async {
    final r = await _post('/api/important-numbers', data);
    return _ok(r);
  }

  // ── Persons & personal documents ──────────────────────────────
  Future<List<Map<String, dynamic>>> getPersons() async {
    final r = await _get('/api/persons');
    if (!_ok(r)) return [];
    return (r['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addPerson(Map<String, dynamic> data) async {
    return _post('/api/persons', data);
  }

  Future<List<Map<String, dynamic>>> getPersonalDocuments(
      {String? personId}) async {
    final path = personId != null
        ? '/api/personal-documents?personId=${Uri.encodeComponent(personId)}'
        : '/api/personal-documents';
    final r = await _get(path);
    if (!_ok(r)) return [];
    return (r['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<bool> addPersonalDocument(Map<String, dynamic> data) async {
    final r = await _post('/api/personal-documents', data);
    return _ok(r);
  }

  Future<bool> deletePersonalDocument(String id) async {
    final r = await _delete('/api/personal-documents/$id');
    return _ok(r);
  }

  // ── Generic category+entries-by-name helpers (Address Book /
  //    Passwords / Transport Contacts all share this exact shape) ──
  Future<List<Map<String, dynamic>>> getOfficeCategories(String prefix) async {
    final r = await _get('/api/$prefix/categories');
    if (!_ok(r)) return [];
    return (r['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addOfficeCategory(
      String prefix, Map<String, dynamic> data) async {
    return _post('/api/$prefix/categories', data);
  }

  Future<bool> deleteOfficeCategory(String prefix, String id) async {
    final r = await _delete('/api/$prefix/categories/$id');
    return _ok(r);
  }

  Future<List<Map<String, dynamic>>> getOfficeCategoryEntries(
      String prefix, String categoryName) async {
    final r = await _get(
        '/api/$prefix/categories/${Uri.encodeComponent(categoryName)}/entries');
    if (!_ok(r)) return [];
    return (r['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<bool> addOfficeCategoryEntry(
      String prefix, String categoryName, Map<String, dynamic> data) async {
    final r = await _post(
        '/api/$prefix/categories/${Uri.encodeComponent(categoryName)}/entries',
        data);
    return _ok(r);
  }

  Future<bool> updateOfficeEntry(
      String prefix, String entryId, Map<String, dynamic> data) async {
    final r = await _put('/api/$prefix/entries/$entryId', data);
    return _ok(r);
  }

  Future<bool> deleteOfficeEntry(String prefix, String entryId) async {
    final r = await _delete('/api/$prefix/entries/$entryId');
    return _ok(r);
  }

  // ── Registers (user-defined columns; entries stored as JSON) ──
  Future<List<Map<String, dynamic>>> getRegisters() async {
    final r = await _get('/api/registers');
    if (!_ok(r)) return [];
    return (r['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<bool> addRegister(Map<String, dynamic> data) async {
    final r = await _post('/api/registers', data);
    return _ok(r);
  }

  // ⚠ Not previously called anywhere in the app — added to support a
  // delete action on the Registers list. Mirrors the exact REST shape
  // every other resource here uses, but I have not seen the backend
  // source, so verify DELETE /api/registers/:id actually exists before
  // relying on it.
  Future<bool> deleteRegister(String id) async =>
      _ok(await _delete('/api/registers/$id'));

  Future<List<Map<String, dynamic>>> getRegisterEntries(
      String registerId) async {
    final r = await _get('/api/registers/$registerId/entries');
    if (!_ok(r)) return [];
    return (r['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<bool> addRegisterEntry(
      String registerId, Map<String, dynamic> data) async {
    final r = await _post('/api/registers/$registerId/entries', data);
    return _ok(r);
  }

  Future<bool> deleteRegisterEntry(String registerId, String entryId) async {
    final r = await _delete('/api/registers/$registerId/entries/$entryId');
    return _ok(r);
  }

  // ── Reminder mail templates ────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMailTemplates() async {
    final r = await _get('/api/mail-templates');
    if (!_ok(r)) return [];
    return (r['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<bool> addMailTemplate(Map<String, dynamic> data) async {
    final r = await _post('/api/mail-templates', data);
    return _ok(r);
  }

  Future<bool> updateMailTemplate(String id, Map<String, dynamic> data) async {
    final r = await _put('/api/mail-templates/$id', data);
    return _ok(r);
  }

  Future<bool> deleteMailTemplate(String id) async {
    final r = await _delete('/api/mail-templates/$id');
    return _ok(r);
  }

  // ── Notification settings ──────────────────────────────────────
  Future<Map<String, dynamic>> getNotificationSettings() async {
    final r = await _get('/api/settings/notifications');
    if (!_ok(r)) return {};
    return (r['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<bool> updateNotificationSettings(Map<String, dynamic> data) async {
    final r = await _put('/api/settings/notifications', data);
    return _ok(r);
  }

  // ── Telecalling report — admin-configurable mandatory columns ──
  // Returns the saved mandatory column keys, or null if nothing saved yet
  // (caller falls back to a sensible default list).
  Future<List<String>?> getTelecallReportMandatoryColumns() async {
    final r = await _get('/api/settings/telecalling-report');
    if (!_ok(r)) return null;
    final data = r['data'] as Map<String, dynamic>?;
    final keys = data?['mandatoryKeys'] as List<dynamic>?;
    if (keys == null) return null;
    return keys.map((e) => e.toString()).toList();
  }

  Future<bool> saveTelecallReportMandatoryColumns(List<String> keys) async {
    final r =
        await _put('/api/settings/telecalling-report', {'mandatoryKeys': keys});
    return _ok(r);
  }

  // ── Dashboard stats ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getOfficeDashboardStats() async {
    final r = await _get('/api/dashboard/stats');
    if (!_ok(r)) return {};
    return (r['data'] as Map<String, dynamic>?) ?? {};
  }

  // ── Audit log ────────────────────────────────────────────────────
  Future<bool> addAuditLog(Map<String, dynamic> data) async {
    final r = await _post('/api/audit-logs', data);
    return _ok(r);
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 100}) async {
    final r = await _get('/api/audit-logs?limit=$limit');
    if (!_ok(r)) return [];
    return (r['data'] as List).cast<Map<String, dynamic>>();
  }
}
