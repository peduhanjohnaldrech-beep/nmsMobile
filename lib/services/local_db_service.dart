import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Local SQLite database for offline storage.
/// All methods are no-ops on web (kIsWeb).
class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  Database? _db;

  Future<Database> get db async {
    if (kIsWeb) throw UnsupportedError('SQLite not available on web');
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, 'nms_offline.db');

    return openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _createIndexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try { await db.execute('ALTER TABLE beneficiaries ADD COLUMN father_name TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE beneficiaries ADD COLUMN suffix TEXT'); } catch (_) {}
    }
    if (oldVersion < 4) {
      // Safety: add hfa_status / wflh_status if missed in earlier v3 migration
      try { await db.execute('ALTER TABLE assessments ADD COLUMN hfa_status TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE assessments ADD COLUMN wflh_status TEXT'); } catch (_) {}
    }
    if (oldVersion < 3) {
      // beneficiaries: extended fields + validation
      for (final col in [
        'ALTER TABLE beneficiaries ADD COLUMN household_no TEXT',
        'ALTER TABLE beneficiaries ADD COLUMN place_of_birth TEXT',
        'ALTER TABLE beneficiaries ADD COLUMN guardian_name TEXT',
        'ALTER TABLE beneficiaries ADD COLUMN guardian_relationship TEXT',
        'ALTER TABLE beneficiaries ADD COLUMN income_classification TEXT',
        'ALTER TABLE beneficiaries ADD COLUMN household_monthly_income REAL',
        'ALTER TABLE beneficiaries ADD COLUMN income_source TEXT',
        'ALTER TABLE beneficiaries ADD COLUMN nhts_pr_status TEXT',
        'ALTER TABLE beneficiaries ADD COLUMN is_pwd_household INTEGER DEFAULT 0',
        'ALTER TABLE beneficiaries ADD COLUMN is_indigenous_people INTEGER DEFAULT 0',
        'ALTER TABLE beneficiaries ADD COLUMN ip_group TEXT',
        "ALTER TABLE beneficiaries ADD COLUMN validation_status TEXT DEFAULT 'validated'",
        // assessments: zscore columns + validation
        'ALTER TABLE assessments ADD COLUMN height_for_age_zscore REAL',
        'ALTER TABLE assessments ADD COLUMN hfa_status TEXT',
        'ALTER TABLE assessments ADD COLUMN wflh_zscore REAL',
        'ALTER TABLE assessments ADD COLUMN wflh_status TEXT',
        "ALTER TABLE assessments ADD COLUMN validation_status TEXT DEFAULT 'validated'",
        'ALTER TABLE assessments ADD COLUMN validated_by INTEGER',
        'ALTER TABLE assessments ADD COLUMN validated_at TEXT',
        'ALTER TABLE assessments ADD COLUMN rejection_note TEXT',
      ]) {
        try { await db.execute(col); } catch (_) {}
      }
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS beneficiaries (
        id                       INTEGER PRIMARY KEY,
        local_id                 TEXT UNIQUE,
        last_name                TEXT NOT NULL,
        first_name               TEXT NOT NULL,
        middle_name              TEXT,
        suffix                   TEXT,
        date_of_birth            TEXT NOT NULL,
        sex                      TEXT NOT NULL,
        barangay                 TEXT NOT NULL,
        purok_zone               TEXT,
        household_no             TEXT,
        place_of_birth           TEXT,
        mother_name              TEXT,
        father_name              TEXT,
        guardian_name            TEXT,
        guardian_relationship    TEXT,
        contact_number           TEXT,
        income_classification    TEXT,
        household_monthly_income REAL,
        income_source            TEXT,
        philhealth_status        TEXT,
        is_4ps_member            INTEGER DEFAULT 0,
        nhts_pr_status           TEXT,
        is_pwd_household         INTEGER DEFAULT 0,
        is_indigenous_people     INTEGER DEFAULT 0,
        ip_group                 TEXT,
        source                   TEXT,
        validation_status        TEXT DEFAULT 'validated',
        created_at               TEXT,
        updated_at               TEXT,
        is_synced                INTEGER DEFAULT 1,
        is_deleted               INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS assessments (
        id                    INTEGER PRIMARY KEY,
        local_id              TEXT UNIQUE,
        local_beneficiary_id  TEXT,
        beneficiary_id        INTEGER,
        assessment_date       TEXT NOT NULL,
        age_in_months         INTEGER,
        weight_kg             REAL NOT NULL,
        height_cm             REAL,
        muac_cm               REAL,
        nutritional_status    TEXT DEFAULT 'Normal',
        weight_for_age_zscore REAL,
        height_for_age_zscore REAL,
        hfa_status            TEXT,
        wflh_zscore           REAL,
        wflh_status           TEXT,
        period                TEXT NOT NULL,
        assessment_year       INTEGER NOT NULL,
        assessed_by           TEXT,
        remarks               TEXT,
        validation_status     TEXT DEFAULT 'validated',
        validated_by          INTEGER,
        validated_at          TEXT,
        rejection_note        TEXT,
        created_at            TEXT,
        is_synced             INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS barangays (
        name TEXT PRIMARY KEY
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_bene_barangay  ON beneficiaries(barangay)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_bene_synced    ON beneficiaries(is_synced)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_assess_bene    ON assessments(beneficiary_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_assess_synced  ON assessments(is_synced)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_assess_year    ON assessments(assessment_year)');
  }

  // -------------------------------------------------------
  // BENEFICIARIES
  // -------------------------------------------------------

  static const _beneColumns = {
    'id', 'local_id', 'last_name', 'first_name', 'middle_name', 'suffix',
    'date_of_birth', 'sex', 'barangay', 'purok_zone', 'household_no',
    'place_of_birth', 'mother_name', 'father_name', 'guardian_name',
    'guardian_relationship', 'contact_number', 'income_classification',
    'household_monthly_income', 'income_source', 'philhealth_status',
    'is_4ps_member', 'nhts_pr_status', 'is_pwd_household',
    'is_indigenous_people', 'ip_group', 'source', 'validation_status',
    'created_at', 'updated_at', 'is_synced', 'is_deleted',
  };

  static const _assessColumns = {
    'id', 'local_id', 'local_beneficiary_id', 'beneficiary_id',
    'assessment_date', 'age_in_months', 'weight_kg', 'height_cm', 'muac_cm',
    'nutritional_status', 'weight_for_age_zscore', 'height_for_age_zscore',
    'hfa_status', 'wflh_zscore', 'wflh_status', 'period', 'assessment_year',
    'assessed_by', 'remarks', 'validation_status', 'validated_by',
    'validated_at', 'rejection_note', 'created_at', 'is_synced',
  };

  Future<void> upsertBeneficiaries(List<Map<String, dynamic>> rows) async {
    if (kIsWeb) return;
    final database = await db;
    final batch = database.batch();
    for (final row in rows) {
      final filtered = {
        for (final e in row.entries)
          if (_beneColumns.contains(e.key)) e.key: e.value,
        'is_synced': 1,
      };
      batch.insert(
        'beneficiaries',
        filtered,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getBeneficiaries({
    String? barangay,
    String? purok,
    String? search,
    String? statusFilter,
    String? sourceFilter,
    int page    = 1,
    int perPage = 30,
  }) async {
    if (kIsWeb) return [];
    final database = await db;
    final where = <String>['b.is_deleted = 0'];
    final args  = <dynamic>[];

    if (barangay != null) {
      where.add('b.barangay = ?');
      args.add(barangay);
    }
    if (purok != null && purok.isNotEmpty) {
      where.add('LOWER(b.purok_zone) = LOWER(?)');
      args.add(purok);
    }
    if (search != null && search.isNotEmpty) {
      where.add('(b.last_name LIKE ? OR b.first_name LIKE ?)');
      args.add('%$search%');
      args.add('%$search%');
    }
    if (sourceFilter != null && sourceFilter != 'All') {
      where.add('b.source = ?');
      args.add(sourceFilter);
    }

    // Build query with latest assessment status joined in
    final sql = '''
      SELECT
        b.*,
        a.nutritional_status  AS latest_status,
        a.assessment_date     AS latest_assessment_date,
        a.weight_kg           AS latest_weight_kg,
        a.weight_for_age_zscore AS latest_zscore
      FROM beneficiaries b
      LEFT JOIN assessments a ON a.id = (
        SELECT id FROM assessments
        WHERE beneficiary_id = b.id
        ORDER BY assessment_date DESC
        LIMIT 1
      )
      ${where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : ''}
      ${statusFilter != null && statusFilter != 'All' ? 'AND (a.nutritional_status = ? OR a.nutritional_status IS NULL)' : ''}
      ORDER BY b.last_name, b.first_name
      LIMIT ? OFFSET ?
    ''';

    if (statusFilter != null && statusFilter != 'All') args.add(statusFilter);
    args.add(perPage);
    args.add((page - 1) * perPage);
    return database.rawQuery(sql, args);
  }

  Future<int> countBeneficiaries({String? barangay}) async {
    if (kIsWeb) return 0;
    final database = await db;
    final where = <String>['is_deleted = 0'];
    final args  = <dynamic>[];
    if (barangay != null) {
      where.add('barangay = ?');
      args.add(barangay);
    }
    final result = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM beneficiaries WHERE ${where.join(' AND ')}',
      args,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countByStatus(String status, {String? barangay}) async {
    if (kIsWeb) return 0;
    final database = await db;
    final where = <String>['b.is_deleted = 0'];
    final args  = <dynamic>[];
    if (barangay != null) {
      where.add('b.barangay = ?');
      args.add(barangay);
    }
    args.add(status);
    final sql = '''
      SELECT COUNT(*) as cnt FROM beneficiaries b
      WHERE ${where.join(' AND ')}
      AND (
        SELECT nutritional_status FROM assessments
        WHERE beneficiary_id = b.id
        ORDER BY assessment_date DESC LIMIT 1
      ) = ?
    ''';
    final result = await database.rawQuery(sql, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, dynamic>?> getBeneficiaryById(int id) async {
    if (kIsWeb) return null;
    final database = await db;
    final rows = await database.rawQuery('''
      SELECT
        b.*,
        a.nutritional_status  AS latest_status,
        a.assessment_date     AS latest_assessment_date,
        a.weight_kg           AS latest_weight_kg,
        a.weight_for_age_zscore AS latest_zscore
      FROM beneficiaries b
      LEFT JOIN assessments a ON a.id = (
        SELECT id FROM assessments
        WHERE beneficiary_id = b.id
        ORDER BY assessment_date DESC
        LIMIT 1
      )
      WHERE b.id = ?
    ''', [id]);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> insertOfflineBeneficiary(Map<String, dynamic> data) async {
    if (kIsWeb) return 0;
    final database = await db;
    return database.insert('beneficiaries', {...data, 'is_synced': 0});
  }

  Future<int> updateBeneficiary(int id, Map<String, dynamic> data) async {
    if (kIsWeb) return 0;
    final database = await db;
    return database.update(
      'beneficiaries',
      {...data, 'is_synced': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<String>> getPuroksByBarangay({String? barangay}) async {
    if (kIsWeb) return [];
    final database = await db;
    final where = ["is_deleted = 0", "purok_zone IS NOT NULL", "purok_zone <> ''"];
    final args  = <dynamic>[];
    if (barangay != null) {
      where.add('barangay = ?');
      args.add(barangay);
    }
    final rows = await database.rawQuery(
      'SELECT DISTINCT purok_zone FROM beneficiaries WHERE ${where.join(' AND ')} ORDER BY purok_zone',
      args,
    );
    return rows.map((r) => r['purok_zone'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentBeneficiaries({int limit = 5, String? barangay}) async {
    if (kIsWeb) return [];
    final database = await db;
    final where = ['b.is_deleted = 0'];
    final args  = <dynamic>[];
    if (barangay != null) {
      where.add('b.barangay = ?');
      args.add(barangay);
    }
    args.add(limit);
    return database.rawQuery('''
      SELECT
        b.*,
        a.nutritional_status AS latest_status,
        a.assessment_date    AS latest_assessment_date
      FROM beneficiaries b
      LEFT JOIN assessments a ON a.id = (
        SELECT id FROM assessments
        WHERE beneficiary_id = b.id
        ORDER BY assessment_date DESC
        LIMIT 1
      )
      WHERE ${where.join(' AND ')}
      ORDER BY b.updated_at DESC, b.created_at DESC
      LIMIT ?
    ''', args);
  }

  // -------------------------------------------------------
  // ASSESSMENTS
  // -------------------------------------------------------

  Future<void> upsertAssessments(List<Map<String, dynamic>> rows) async {
    if (kIsWeb) return;
    final database = await db;
    final batch = database.batch();
    for (final row in rows) {
      final filtered = {
        for (final e in row.entries)
          if (_assessColumns.contains(e.key)) e.key: e.value,
        'is_synced': 1,
      };
      batch.insert(
        'assessments',
        filtered,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<bool> assessmentExistsForPeriod(int beneficiaryId, String period, int year) async {
    if (kIsWeb) return false;
    final database = await db;
    final rows = await database.query(
      'assessments',
      columns:   ['id'],
      where:     'beneficiary_id = ? AND period = ? AND assessment_year = ?',
      whereArgs: [beneficiaryId, period, year],
      limit:     1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getAssessmentsByBeneficiary(
      int beneficiaryId) async {
    if (kIsWeb) return [];
    final database = await db;
    return database.query(
      'assessments',
      where:     'beneficiary_id = ?',
      whereArgs: [beneficiaryId],
      orderBy:   'assessment_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllAssessments({
    int? year,
    String? period,
    String? barangay,
    int page    = 1,
    int perPage = 30,
  }) async {
    if (kIsWeb) return [];
    final database = await db;
    final where = <String>[];
    final args  = <dynamic>[];

    if (year != null) {
      where.add('a.assessment_year = ?');
      args.add(year);
    }
    if (period != null) {
      where.add('a.period = ?');
      args.add(period);
    }

    if (barangay != null) {
      where.insert(0, 'b.barangay = ?');
      args.insert(0, barangay);
    }
    final allArgs = [...args, perPage, (page - 1) * perPage];
    final sql = '''
      SELECT a.*, b.last_name, b.first_name, b.barangay
      FROM assessments a
      LEFT JOIN beneficiaries b ON b.id = a.beneficiary_id
      ${where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : ''}
      ORDER BY a.assessment_date DESC
      LIMIT ? OFFSET ?
    ''';

    return database.rawQuery(sql, allArgs);
  }

  Future<int> insertOfflineAssessment(Map<String, dynamic> data) async {
    if (kIsWeb) return 0;
    final database = await db;
    return database.insert('assessments', {...data, 'is_synced': 0});
  }

  // -------------------------------------------------------
  // OFFLINE QUEUE
  // -------------------------------------------------------

  Future<List<Map<String, dynamic>>> getUnsyncedBeneficiaries() async {
    if (kIsWeb) return [];
    final database = await db;
    return database.query('beneficiaries', where: 'is_synced = 0');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAssessments() async {
    if (kIsWeb) return [];
    final database = await db;
    return database.query('assessments', where: 'is_synced = 0');
  }

  Future<int> getUnsyncedCount() async {
    if (kIsWeb) return 0;
    final benes      = await getUnsyncedBeneficiaries();
    final assessments = await getUnsyncedAssessments();
    return benes.length + assessments.length;
  }

  Future<void> markBeneficiarySynced(String localId, int serverId) async {
    if (kIsWeb) return;
    final database = await db;
    // UPDATE OR REPLACE handles the case where another pulled row already
    // occupies serverId — it deletes the conflicting row and proceeds.
    await database.rawUpdate(
      'UPDATE OR REPLACE beneficiaries SET id = ?, is_synced = 1 WHERE local_id = ?',
      [serverId, localId],
    );
  }

  Future<void> markAssessmentSynced(String localId, int serverId) async {
    if (kIsWeb) return;
    final database = await db;
    await database.rawUpdate(
      'UPDATE OR REPLACE assessments SET id = ?, is_synced = 1 WHERE local_id = ?',
      [serverId, localId],
    );
  }

  // -------------------------------------------------------
  // BARANGAYS
  // -------------------------------------------------------

  Future<void> upsertBarangays(List<String> names) async {
    if (kIsWeb) return;
    final database = await db;
    final batch = database.batch();
    for (final name in names) {
      batch.insert(
        'barangays',
        {'name': name},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<String>> getBarangays() async {
    if (kIsWeb) return [];
    final database = await db;
    final rows = await database.query('barangays', orderBy: 'name');
    return rows.map((r) => r['name'] as String).toList();
  }

  // -------------------------------------------------------
  // UTILS
  // -------------------------------------------------------

  Future<void> clearAll() async {
    if (kIsWeb) return;
    final database = await db;
    await database.delete('beneficiaries');
    await database.delete('assessments');
    await database.delete('barangays');
  }

  Future<void> close() async {
    if (kIsWeb) return;
    await _db?.close();
    _db = null;
  }
}
