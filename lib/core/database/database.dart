import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'healthvault.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createOmicsTables(db);
    if (oldVersion < 3) await _createRemindersTable(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE diagnoses (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        icd_code TEXT,
        diagnosed_date TEXT,
        status TEXT,
        notes TEXT,
        follow_up_plan TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE appointments (
        id TEXT PRIMARY KEY,
        diagnosis_id TEXT,
        title TEXT NOT NULL,
        provider TEXT,
        location TEXT,
        date_time TEXT NOT NULL,
        notes TEXT,
        completed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE lab_results (
        id TEXT PRIMARY KEY,
        test_name TEXT NOT NULL,
        value REAL,
        unit TEXT,
        reference_range TEXT,
        status TEXT,
        date TEXT NOT NULL,
        lab_name TEXT,
        ordered_by TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE body_compositions (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        weight_kg REAL,
        body_fat_percent REAL,
        lean_mass_kg REAL,
        bone_density REAL,
        visceral_fat REAL,
        scan_type TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE imaging_results (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        facility TEXT,
        findings TEXT,
        impression TEXT,
        cac_score REAL,
        report_path TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE wearable_data (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        source TEXT,
        steps INTEGER,
        active_calories REAL,
        resting_hr REAL,
        hrv REAL,
        spo2 REAL,
        sleep_hours REAL,
        deep_sleep_hours REAL,
        rem_sleep_hours REAL,
        sleep_score INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE genetic_data (
        id TEXT PRIMARY KEY,
        provider TEXT,
        upload_date TEXT NOT NULL,
        rsid TEXT,
        chromosome TEXT,
        genotype TEXT,
        trait TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE food_logs (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        meal_type TEXT,
        food_name TEXT NOT NULL,
        brand TEXT,
        serving_size REAL,
        serving_unit TEXT,
        calories REAL,
        protein_g REAL,
        carbs_g REAL,
        fat_g REAL,
        fiber_g REAL,
        sugar_g REAL,
        sodium_mg REAL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE water_logs (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        amount_ml REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        name TEXT,
        duration_minutes REAL,
        distance_km REAL,
        calories REAL,
        avg_hr REAL,
        max_hr REAL,
        avg_pace TEXT,
        elevation_m REAL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workouts (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        name TEXT NOT NULL,
        notes TEXT,
        duration_minutes REAL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_sets (
        id TEXT PRIMARY KEY,
        workout_id TEXT NOT NULL,
        exercise_name TEXT NOT NULL,
        set_number INTEGER,
        reps INTEGER,
        weight_kg REAL,
        rpe REAL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (workout_id) REFERENCES workouts(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sleep_logs (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        bedtime TEXT,
        wake_time TEXT,
        total_hours REAL,
        deep_hours REAL,
        rem_hours REAL,
        light_hours REAL,
        awake_hours REAL,
        sleep_score INTEGER,
        hrv_avg REAL,
        resting_hr REAL,
        temperature_deviation REAL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE symptoms (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        time TEXT,
        symptom TEXT NOT NULL,
        severity INTEGER,
        duration_minutes INTEGER,
        triggers TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE mood_logs (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        time TEXT,
        mood INTEGER,
        energy INTEGER,
        anxiety INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE supplements (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT,
        brand TEXT,
        dose TEXT,
        unit TEXT,
        timing TEXT,
        frequency TEXT,
        purpose TEXT,
        notes TEXT,
        active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE supplement_logs (
        id TEXT PRIMARY KEY,
        supplement_id TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT,
        dose_taken TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (supplement_id) REFERENCES supplements(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT,
        file_name TEXT,
        file_size INTEGER,
        mime_type TEXT,
        bytes BLOB,
        date TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE oauth_tokens (
        id TEXT PRIMARY KEY,
        provider TEXT NOT NULL UNIQUE,
        access_token TEXT,
        refresh_token TEXT,
        expires_at TEXT,
        scope TEXT,
        athlete_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_conversations (
        id TEXT PRIMARY KEY,
        title TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await _createOmicsTables(db);
    await _createRemindersTable(db);

    await db.execute('''
      CREATE TABLE ai_messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES ai_conversations(id)
      )
    ''');
  }

  static Future<void> _createRemindersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT,
        type TEXT NOT NULL,
        frequency TEXT NOT NULL,
        time_of_day TEXT,
        days_of_week TEXT,
        next_due TEXT,
        last_triggered TEXT,
        enabled INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createOmicsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS epigenetic_clocks (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        clock_name TEXT NOT NULL,
        biological_age REAL,
        chronological_age REAL,
        age_delta REAL,
        pace_of_aging REAL,
        telomere_length REAL,
        provider TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS snp_variants (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        gene TEXT NOT NULL,
        rsid TEXT,
        variant TEXT,
        genotype TEXT,
        risk_allele TEXT,
        effect TEXT,
        odds_ratio REAL,
        category TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS proteomics_results (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        panel_name TEXT NOT NULL,
        provider TEXT,
        protein_name TEXT NOT NULL,
        protein_id TEXT,
        value REAL,
        unit TEXT,
        percentile REAL,
        z_score REAL,
        flag TEXT,
        pathway TEXT,
        category TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS senescence_scores (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        score_type TEXT NOT NULL,
        score_value REAL,
        unit TEXT,
        percentile REAL,
        provider TEXT,
        interpretation TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS metabolomics_results (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        panel_type TEXT NOT NULL,
        metabolite TEXT NOT NULL,
        hmdb_id TEXT,
        value REAL,
        unit TEXT,
        pathway TEXT,
        percentile REAL,
        flag TEXT,
        provider TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS microbiome_snapshots (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        provider TEXT,
        shannon_diversity REAL,
        species_richness INTEGER,
        firmicutes_pct REAL,
        bacteroidetes_pct REAL,
        proteobacteria_pct REAL,
        actinobacteria_pct REAL,
        fb_ratio REAL,
        dysbiosis_score REAL,
        gut_age REAL,
        keystone_species TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS omics_other (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        test_name TEXT NOT NULL,
        value TEXT,
        unit TEXT,
        percentile REAL,
        flag TEXT,
        provider TEXT,
        notes TEXT,
        raw_json TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }
}
