import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/app_config.dart';
import 'api_service.dart';
import 'local_db_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final _api   = ApiService();
  final _local = LocalDbService();

  // -------------------------------------------------------
  // CONNECTIVITY
  // -------------------------------------------------------

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  // -------------------------------------------------------
  // FULL SYNC
  // -------------------------------------------------------

  /// Full sync: push offline records, then pull from server.
  Future<SyncResult> sync({String? barangay}) async {
    if (!await isOnline()) {
      return SyncResult(success: false, message: 'No internet connection');
    }

    try {
      final prefs    = await SharedPreferences.getInstance();
      final lastSync = prefs.getString(AppConfig.lastSyncKey);

      // 1. Push offline records (native only)
      int offlinePushed = 0;
      if (!kIsWeb) {
        offlinePushed = await _pushOffline();
      }

      // 2. Pull from server
      final pullResult = await _api.syncPull(since: lastSync, barangay: barangay);

      if (pullResult['success'] == true) {
        final data = pullResult['data'] as Map<String, dynamic>;

        final beneficiaries = List<Map<String, dynamic>>.from(data['beneficiaries'] ?? []);
        final assessments   = List<Map<String, dynamic>>.from(data['assessments'] ?? []);
        final barangays     = List<String>.from(data['barangays'] ?? []);

        if (!kIsWeb) {
          await _local.upsertBeneficiaries(beneficiaries);
          await _local.upsertAssessments(assessments);
          await _local.upsertBarangays(barangays);
        }

        // 3. Save sync timestamp
        final syncedAt = data['synced_at'] as String? ?? DateTime.now().toIso8601String();
        await prefs.setString(AppConfig.lastSyncKey, syncedAt);

        return SyncResult(
          success:              true,
          message:              'Synced ${beneficiaries.length} beneficiaries, '
                                '${assessments.length} assessments',
          beneficiariesSynced:  beneficiaries.length,
          assessmentsSynced:    assessments.length,
          offlinePushed:        offlinePushed,
          syncedAt:             syncedAt,
        );
      } else {
        return SyncResult(
          success: false,
          message: pullResult['message'] as String? ?? 'Sync failed',
        );
      }
    } catch (e) {
      return SyncResult(success: false, message: 'Sync error: $e');
    }
  }

  // -------------------------------------------------------
  // FULL SYNC (no since — forces pull of all records)
  // -------------------------------------------------------

  /// Same as [sync] but ignores the last-sync timestamp so all records
  /// are re-pulled from the server. Useful to pick up validation status
  /// changes that incremental sync might have missed.
  Future<SyncResult> syncFull({String? barangay}) async {
    if (!await isOnline()) {
      return SyncResult(success: false, message: 'No internet connection');
    }

    try {
      int offlinePushed = 0;
      if (!kIsWeb) {
        offlinePushed = await _pushOffline();
      }

      final pullResult = await _api.syncPull(since: null, barangay: barangay);

      if (pullResult['success'] == true) {
        final data = pullResult['data'] as Map<String, dynamic>;

        final beneficiaries = List<Map<String, dynamic>>.from(data['beneficiaries'] ?? []);
        final assessments   = List<Map<String, dynamic>>.from(data['assessments'] ?? []);
        final barangays     = List<String>.from(data['barangays'] ?? []);

        if (!kIsWeb) {
          await _local.upsertBeneficiaries(beneficiaries);
          await _local.upsertAssessments(assessments);
          await _local.upsertBarangays(barangays);
        }

        final prefs    = await SharedPreferences.getInstance();
        final syncedAt = data['synced_at'] as String? ?? DateTime.now().toIso8601String();
        await prefs.setString(AppConfig.lastSyncKey, syncedAt);

        return SyncResult(
          success:             true,
          message:             'Full sync: ${beneficiaries.length} beneficiaries, '
                               '${assessments.length} assessments',
          beneficiariesSynced: beneficiaries.length,
          assessmentsSynced:   assessments.length,
          offlinePushed:       offlinePushed,
          syncedAt:            syncedAt,
        );
      } else {
        return SyncResult(
          success: false,
          message: pullResult['message'] as String? ?? 'Sync failed',
        );
      }
    } catch (e) {
      return SyncResult(success: false, message: 'Sync error: $e');
    }
  }

  // -------------------------------------------------------
  // PUSH OFFLINE RECORDS
  // -------------------------------------------------------

  Future<int> _pushOffline() async {
    final unsyncedBenes       = await _local.getUnsyncedBeneficiaries();
    final unsyncedAssessments = await _local.getUnsyncedAssessments();

    if (unsyncedBenes.isEmpty && unsyncedAssessments.isEmpty) return 0;

    final result = await _api.syncPush(
      beneficiaries: unsyncedBenes,
      assessments:   unsyncedAssessments,
    );

    if (result['success'] == true) {
      final data   = result['data'] as Map<String, dynamic>;
      final idMap  = Map<String, dynamic>.from(data['id_map'] ?? {});

      for (final entry in idMap.entries) {
        await _local.markBeneficiarySynced(entry.key, entry.value as int);
      }

      final created = List<Map<String, dynamic>>.from(
        data['results']?['created'] ?? [],
      );
      for (final item in created) {
        if (item['type'] == 'assessment' && item['local_id'] != null) {
          await _local.markAssessmentSynced(
            item['local_id'] as String,
            item['server_id'] as int,
          );
        }
      }

      return created.length + idMap.length;
    }
    return 0;
  }

  // -------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------

  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.lastSyncKey);
  }

  Future<int> getUnsyncedCount() async {
    if (kIsWeb) return 0;
    return _local.getUnsyncedCount();
  }
}

// -------------------------------------------------------
// RESULT MODEL
// -------------------------------------------------------

class SyncResult {
  final bool   success;
  final String message;
  final int    beneficiariesSynced;
  final int    assessmentsSynced;
  final int    offlinePushed;
  final String? syncedAt;

  const SyncResult({
    required this.success,
    required this.message,
    this.beneficiariesSynced = 0,
    this.assessmentsSynced   = 0,
    this.offlinePushed       = 0,
    this.syncedAt,
  });
}
