import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';


class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Global navigator key — register this in MaterialApp to enable 401 auto-redirect.
  static final navigatorKey = GlobalKey<NavigatorState>();

  final http.Client _client = http.Client();

  final _storage = const FlutterSecureStorage();
  String? _token;
  bool _redirectingToLogin = false;

  // -------------------------------------------------------
  // TOKEN MANAGEMENT
  // -------------------------------------------------------

  Future<String?> getToken() async {
    _token ??= await _storage.read(key: AppConfig.tokenKey);
    return _token;
  }

  Future<void> setToken(String token) async {
    _token = token;
    _redirectingToLogin = false;
    await _storage.write(key: AppConfig.tokenKey, value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: AppConfig.tokenKey);
  }

  // -------------------------------------------------------
  // HEADERS
  // -------------------------------------------------------

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<String> _baseUrl() => AppConfig.getBaseUrl();

  // -------------------------------------------------------
  // AUTH
  // -------------------------------------------------------

  Future<Map<String, dynamic>> login(
      String username, String password, String deviceName) async {
    final base = await _baseUrl();
    final res = await http
        .post(
          Uri.parse('$base/auth/login'),
          headers: await _headers(auth: false),
          body: jsonEncode({
            'username':    username,
            'password':    password,
            'device_name': deviceName,
          }),
        )
        .timeout(const Duration(seconds: 15));
    // Decode directly — do NOT go through _decode() so a server-side 401
    // never triggers the "Session expired" redirect on the login screen.
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      // Normalise: if server still returns 401 for bad creds, surface the message
      if (res.statusCode == 401 && body['message'] == null) {
        return {'success': false, 'message': 'Invalid credentials'};
      }
      return body;
    } catch (_) {
      return {'success': false, 'message': 'Invalid server response (status ${res.statusCode})'};
    }
  }

  Future<void> logout() async {
    try {
      final base = await _baseUrl();
      await http
          .post(
            Uri.parse('$base/auth/logout'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
    await clearToken();
  }

  Future<Map<String, dynamic>> getMe() async {
    final base = await _baseUrl();
    final res = await http
        .get(Uri.parse('$base/auth/me'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    return _decode(res);
  }

  // -------------------------------------------------------
  // BENEFICIARIES
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getBeneficiaries({
    String? barangay,
    String? search,
    String? status,
    String? source,
    int page = 1,
    int perPage = 30,
    String? updatedSince,
    bool validatedOnly = false,
  }) async {
    final base = await _baseUrl();
    final params = <String, String>{
      'page':     page.toString(),
      'per_page': perPage.toString(),
    };
    if (barangay != null)     params['barangay']      = barangay;
    if (search != null)       params['search']        = search;
    if (status != null)       params['status']        = status;
    if (source != null)       params['source']        = source;
    if (updatedSince != null) params['updated_since'] = updatedSince;
    if (validatedOnly)        params['validated_only'] = '1';

    final uri = Uri.parse('$base/beneficiaries').replace(queryParameters: params);
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getBeneficiary(int id) async {
    final base = await _baseUrl();
    final res = await http
        .get(Uri.parse('$base/beneficiaries/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    return _decode(res);
  }

  Future<Map<String, dynamic>> createBeneficiary(
      Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await http
        .post(
          Uri.parse('$base/beneficiaries'),
          headers: await _headers(),
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> updateBeneficiary(
      int id, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await http
        .put(
          Uri.parse('$base/beneficiaries/$id'),
          headers: await _headers(),
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> submitBeneficiary(int id) async {
    final base = await _baseUrl();
    final res = await http
        .post(
          Uri.parse('$base/beneficiaries/$id/submit'),
          headers: await _headers(),
          body: jsonEncode({}),
        )
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getReadyToSubmit() async {
    final base = await _baseUrl();
    final res = await _client
        .get(Uri.parse('$base/beneficiaries/ready-to-submit'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> batchSubmitToAdmin(List<int> ids) async {
    final base = await _baseUrl();
    final res = await _client
        .post(
          Uri.parse('$base/beneficiaries/batch-submit'),
          headers: await _headers(),
          body: jsonEncode({'ids': ids}),
        )
        .timeout(const Duration(seconds: 30));
    return _decode(res);
  }

  // -------------------------------------------------------
  // ASSESSMENTS
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getAssessments({
    int? beneficiaryId,
    String? barangay,
    int? year,
    String? period,
    int page = 1,
    int perPage = 30,
  }) async {
    final base = await _baseUrl();
    final params = <String, String>{
      'page':     page.toString(),
      'per_page': perPage.toString(),
    };
    if (beneficiaryId != null) params['beneficiary_id'] = beneficiaryId.toString();
    if (barangay != null)      params['barangay']       = barangay;
    if (year != null)          params['year']           = year.toString();
    if (period != null)        params['period']         = period;

    final uri = Uri.parse('$base/assessments').replace(queryParameters: params);
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> createAssessment(
      Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await http
        .post(
          Uri.parse('$base/assessments'),
          headers: await _headers(),
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  // -------------------------------------------------------
  // SYNC
  // -------------------------------------------------------

  Future<Map<String, dynamic>> syncPull({
    String? since,
    String? barangay,
  }) async {
    final base = await _baseUrl();
    final params = <String, String>{};
    if (since != null)    params['since']    = since;
    if (barangay != null) params['barangay'] = barangay;

    final uri = Uri.parse('$base/sync/pull').replace(queryParameters: params);
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 60));
    return _decode(res);
  }

  Future<Map<String, dynamic>> syncPush({
    List<Map<String, dynamic>> beneficiaries = const [],
    List<Map<String, dynamic>> assessments   = const [],
  }) async {
    final base = await _baseUrl();
    final res = await http
        .post(
          Uri.parse('$base/sync/push'),
          headers: await _headers(),
          body: jsonEncode({
            'beneficiaries': beneficiaries,
            'assessments':   assessments,
          }),
        )
        .timeout(const Duration(seconds: 60));
    return _decode(res);
  }

  // -------------------------------------------------------
  // BARANGAYS
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getBarangays() async {
    final base = await _baseUrl();
    final res = await http
        .get(Uri.parse('$base/barangays'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    return _decode(res);
  }

  // -------------------------------------------------------
  // STATS
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getDashboardStats({String? barangay}) async {
    final base = await _baseUrl();
    final params = <String, String>{};
    if (barangay != null) params['barangay'] = barangay;
    final uri = Uri.parse('$base/stats/dashboard').replace(queryParameters: params);
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  // -------------------------------------------------------
  // PROGRAMS
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getPrograms({
    required String type,
    int? year,
    String? period,
    String? barangay,
    String? tab,
  }) async {
    final base = await _baseUrl();
    final params = <String, String>{};
    if (year != null)     params['year']     = year.toString();
    if (period != null)   params['period']   = period;
    if (barangay != null) params['barangay'] = barangay;
    if (tab != null)      params['tab']      = tab;
    if (type == 'mns')    params['round']    = period ?? 'February';

    final uri = Uri.parse('$base/programs/$type').replace(queryParameters: params);
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  // -------------------------------------------------------
  // DISPENSING
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getDispensingRecords({
    int? year,
    String? barangay,
  }) async {
    final base = await _baseUrl();
    final params = <String, String>{};
    if (year != null)     params['year']     = year.toString();
    if (barangay != null) params['barangay'] = barangay;

    final uri = Uri.parse('$base/dispensing').replace(queryParameters: params);
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> createDispensingRecord(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/dispensing'), headers: await _headers(), body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  // -------------------------------------------------------
  // REPORTS
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getReportSummary({
    int? year,
    String? period,
    String? barangay,
  }) async {
    final base = await _baseUrl();
    final params = <String, String>{};
    if (year != null)     params['year']     = year.toString();
    if (period != null)   params['period']   = period;
    if (barangay != null) params['barangay'] = barangay;

    final uri = Uri.parse('$base/reports/summary').replace(queryParameters: params);
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  // -------------------------------------------------------
  // ACTIVITY
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getActivity({int page = 1}) async {
    final base = await _baseUrl();
    final uri = Uri.parse('$base/activity').replace(queryParameters: {'page': page.toString()});
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  // -------------------------------------------------------
  // BENEFICIARY EXTRA
  // -------------------------------------------------------

  Future<Map<String, dynamic>> deleteBeneficiary(int id) async {
    final base = await _baseUrl();
    final res = await _client.delete(Uri.parse('$base/beneficiaries/$id'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> restoreBeneficiary(int id) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/beneficiaries/$id/restore'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getTrashedBeneficiaries() async {
    final base = await _baseUrl();
    final res = await _client.get(Uri.parse('$base/beneficiaries/trash'), headers: await _headers()).timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getFollowupBeneficiaries({int? year, String? barangay}) async {
    final base = await _baseUrl();
    final params = <String, String>{};
    if (year != null)     params['year']     = year.toString();
    if (barangay != null) params['barangay'] = barangay;
    final uri = Uri.parse('$base/beneficiaries/followup').replace(queryParameters: params);
    final res = await _client.get(uri, headers: await _headers()).timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> checkDuplicate({required String firstName, required String lastName, required String dob}) async {
    final base = await _baseUrl();
    final uri = Uri.parse('$base/beneficiaries/check-duplicate').replace(queryParameters: {'first_name': firstName, 'last_name': lastName, 'date_of_birth': dob});
    final res = await _client.get(uri, headers: await _headers()).timeout(const Duration(seconds: 10));
    return _decode(res);
  }

  // -------------------------------------------------------
  // ASSESSMENT EXTRA
  // -------------------------------------------------------

  Future<Map<String, dynamic>> deleteAssessment(int id) async {
    final base = await _baseUrl();
    final res = await _client.delete(Uri.parse('$base/assessments/$id'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> batchAssessments(List<Map<String, dynamic>> assessments) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/assessments/batch'), headers: await _headers(), body: jsonEncode({'assessments': assessments})).timeout(const Duration(seconds: 30));
    return _decode(res);
  }

  // -------------------------------------------------------
  // DSP PROGRAM
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getDsp({int? year, String? status, String? barangay}) async {
    final base = await _baseUrl();
    final params = <String, String>{};
    if (year != null)     params['year']     = year.toString();
    if (status != null)   params['status']   = status;
    if (barangay != null) params['barangay'] = barangay;
    final res = await _client.get(Uri.parse('$base/programs/dsp').replace(queryParameters: params), headers: await _headers()).timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> dspEnroll(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/programs/dsp/enroll'), headers: await _headers(), body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> dspUpdate(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/programs/dsp/update'), headers: await _headers(), body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> dspDischarge(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/programs/dsp/discharge'), headers: await _headers(), body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  // -------------------------------------------------------
  // MNS ACTIONS
  // -------------------------------------------------------

  Future<Map<String, dynamic>> recordVitaminA(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/programs/mns/vitamina'), headers: await _headers(), body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> recordMnp(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/programs/mns/mnp'), headers: await _headers(), body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> recordLnsSq(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/programs/mns/lnssq'), headers: await _headers(), body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> deleteVitaminA(int id) async {
    final base = await _baseUrl();
    final res = await _client.delete(Uri.parse('$base/programs/mns/vitamina/$id'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> mnpComplete(int id) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/programs/mns/mnp/$id/complete'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> lnsSqComplete(int id) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/programs/mns/lnssq/$id/complete'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getGenericProgram(String code, {int? year, String? status, String? barangay}) async {
    final base = await _baseUrl();
    final params = <String, String>{};
    if (year != null)     params['year']     = year.toString();
    if (status != null)   params['status']   = status;
    if (barangay != null) params['barangay'] = barangay;
    final res = await _client.get(Uri.parse('$base/programs/${code.toLowerCase()}').replace(queryParameters: params), headers: await _headers()).timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> genericEnroll(String code, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/programs/${code.toLowerCase()}/enroll'), headers: await _headers(), body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> genericDischarge(String code, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/programs/${code.toLowerCase()}/discharge'), headers: await _headers(), body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  // -------------------------------------------------------
  // MORE REPORTS
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getReportOpt({int? year, String? period, String? barangay}) async {
    final base = await _baseUrl();
    final params = <String, String>{};
    if (year != null)     params['year']     = year.toString();
    if (period != null)   params['period']   = period;
    if (barangay != null) params['barangay'] = barangay;
    final res = await _client.get(Uri.parse('$base/reports/opt').replace(queryParameters: params), headers: await _headers()).timeout(const Duration(seconds: 30));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getReportDsp({int? year, String? barangay}) async {
    final base = await _baseUrl();
    final params = <String, String>{};
    if (year != null)     params['year']     = year.toString();
    if (barangay != null) params['barangay'] = barangay;
    final res = await _client.get(Uri.parse('$base/reports/dsp').replace(queryParameters: params), headers: await _headers()).timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getReportMns({int? year, String? barangay}) async {
    final base = await _baseUrl();
    final params = <String, String>{};
    if (year != null)     params['year']     = year.toString();
    if (barangay != null) params['barangay'] = barangay;
    final res = await _client.get(Uri.parse('$base/reports/mns').replace(queryParameters: params), headers: await _headers()).timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getReportOutcome({int? year, String? barangay}) async {
    final base = await _baseUrl();
    final params = <String, String>{};
    if (year != null)     params['year']     = year.toString();
    if (barangay != null) params['barangay'] = barangay;
    final res = await _client.get(Uri.parse('$base/reports/outcome').replace(queryParameters: params), headers: await _headers()).timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getReportComparison({int? year1, int? year2, String? barangay}) async {
    final base = await _baseUrl();
    final params = <String, String>{};
    if (year1 != null)    params['year1']    = year1.toString();
    if (year2 != null)    params['year2']    = year2.toString();
    if (barangay != null) params['barangay'] = barangay;
    final res = await _client.get(Uri.parse('$base/reports/comparison').replace(queryParameters: params), headers: await _headers()).timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getReportDistribution({int? year, String? period, String? barangay}) async {
    final base = await _baseUrl();
    final params = <String, String>{};
    if (year != null)     params['year']     = year.toString();
    if (period != null)   params['period']   = period;
    if (barangay != null) params['barangay'] = barangay;
    final res = await _client.get(Uri.parse('$base/reports/distribution').replace(queryParameters: params), headers: await _headers()).timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  // -------------------------------------------------------
  // USERS
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getUsers() async {
    final base = await _baseUrl();
    final res = await _client.get(Uri.parse('$base/users'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/users'), headers: await _headers(), body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> updateUser(int id, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await _client.put(Uri.parse('$base/users/$id'), headers: await _headers(), body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> deleteUser(int id) async {
    final base = await _baseUrl();
    final res = await _client.delete(Uri.parse('$base/users/$id'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> toggleUserActive(int id, bool isActive) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/users/$id/activate'), headers: await _headers(), body: jsonEncode({'is_active': isActive ? 1 : 0})).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  // -------------------------------------------------------
  // VALIDATION
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getValidationPending() async {
    final base = await _baseUrl();
    final res = await _client.get(Uri.parse('$base/validation/pending'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getMySubmissions({String? status}) async {
    final base = await _baseUrl();
    final q = status != null ? '?status=$status' : '';
    final res = await _client.get(Uri.parse('$base/validation/my-submissions$q'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getValidationCounts() async {
    final base = await _baseUrl();
    final res = await _client.get(Uri.parse('$base/validation/counts'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> batchValidate({
    required String type,
    required List<int> ids,
  }) async {
    final base = await _baseUrl();
    final res = await _client
        .post(
          Uri.parse('$base/validation/batch'),
          headers: await _headers(),
          body: jsonEncode({'type': type, 'ids': ids}),
        )
        .timeout(const Duration(seconds: 30));
    return _decode(res);
  }

  Future<Map<String, dynamic>> validateAssessment(int id) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/validation/$id/validate'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> rejectAssessment(int id, String note) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/validation/$id/reject'), headers: await _headers(), body: jsonEncode({'note': note})).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getBeneficiaryValidationPending() async {
    final base = await _baseUrl();
    final res = await _client.get(Uri.parse('$base/validation/beneficiaries/pending'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getMyBeneficiarySubmissions({String? status}) async {
    final base = await _baseUrl();
    final q = status != null ? '?status=$status' : '';
    final res = await _client.get(Uri.parse('$base/validation/beneficiaries/my-submissions$q'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> validateBeneficiaryRecord(int id) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/validation/beneficiaries/$id/validate'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> rejectBeneficiaryRecord(int id, String note) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/validation/beneficiaries/$id/reject'), headers: await _headers(), body: jsonEncode({'note': note})).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  // -------------------------------------------------------
  // PROGRAMS ADMIN
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getProgramsList() async {
    final base = await _baseUrl();
    final res = await _client.get(Uri.parse('$base/programs/list'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getProgramsAdmin() async {
    final base = await _baseUrl();
    final res = await _client.get(Uri.parse('$base/programs-admin'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> createProgram(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/programs-admin'), headers: await _headers(), body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> updateProgram(int id, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final res = await _client.put(Uri.parse('$base/programs-admin/$id'), headers: await _headers(), body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> toggleProgram(int id) async {
    final base = await _baseUrl();
    final res = await _client.post(Uri.parse('$base/programs-admin/$id/toggle'), headers: await _headers()).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  // -------------------------------------------------------
  // BACKUP
  // -------------------------------------------------------

  Future<List<dynamic>> listBackups() async {
    final base = await _baseUrl();
    final res  = await _client
        .get(Uri.parse('$base/backup/list'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final decoded = _decode(res);
    return List<dynamic>.from(decoded['data']?['backups'] ?? []);
  }

  Future<Uint8List?> downloadBackup(String filename) async {
    final base  = await _baseUrl();
    final hdrs  = await _headers();
    final resp  = await _client
        .get(Uri.parse('$base/backup/$filename'), headers: hdrs)
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode == 200) return resp.bodyBytes;
    return null;
  }

  // -------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------

  Map<String, dynamic> _decode(http.Response res) {
    // Any 401 means token missing or expired — clear and redirect to login
    if (res.statusCode == 401) {
      _storage.delete(key: AppConfig.tokenKey);
      _token = null;
      if (!_redirectingToLogin) {
        _redirectingToLogin = true;
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/login', (_) => false);
      }
      return {'success': false, 'message': 'Session expired. Please log in again.'};
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return {'success': true, 'data': decoded};
      return {'success': false, 'message': 'Unexpected response format'};
    } catch (_) {
      return {
        'success': false,
        'message': 'Invalid server response (status ${res.statusCode})',
      };
    }
  }
}
