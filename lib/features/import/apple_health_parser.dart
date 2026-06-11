import 'package:xml/xml.dart';

/// All recognized Apple Health record types we care about
class AppleHealthParser {
  static const _stepCount = 'HKQuantityTypeIdentifierStepCount';
  static const _activeEnergy = 'HKQuantityTypeIdentifierActiveEnergyBurned';
  static const _restingHR = 'HKQuantityTypeIdentifierRestingHeartRate';
  static const _hrv = 'HKQuantityTypeIdentifierHeartRateVariabilitySDNN';
  static const _spo2 = 'HKQuantityTypeIdentifierOxygenSaturation';
  static const _weight = 'HKQuantityTypeIdentifierBodyMass';
  static const _bodyFat = 'HKQuantityTypeIdentifierBodyFatPercentage';
  static const _leanMass = 'HKQuantityTypeIdentifierLeanBodyMass';
  static const _sleepAnalysis = 'HKCategoryTypeIdentifierSleepAnalysis';
  static const _distanceWalking = 'HKQuantityTypeIdentifierDistanceWalkingRunning';
  static const _distanceCycling = 'HKQuantityTypeIdentifierDistanceCycling';
  static const _distanceSwimming = 'HKQuantityTypeIdentifierDistanceSwimming';
  static const _flightsClimbed = 'HKQuantityTypeIdentifierFlightsClimbed';
  static const _heartRate = 'HKQuantityTypeIdentifierHeartRate';
  static const _respiratoryRate = 'HKQuantityTypeIdentifierRespiratoryRate';
  static const _bodyTemp = 'HKQuantityTypeIdentifierBodyTemperature';
  static const _wristTemp = 'HKQuantityTypeIdentifierAppleSleepingWristTemperature';

  static ParseResult parse(String xmlContent, {void Function(double)? onProgress}) {
    final result = ParseResult();

    final doc = XmlDocument.parse(xmlContent);
    final records = doc.findAllElements('Record').toList();
    final workouts = doc.findAllElements('Workout').toList();

    final total = records.length + workouts.length;
    int processed = 0;

    // Group daily wearable data by date
    final Map<String, _DailyWearable> dailyWearable = {};
    // Group sleep records by date
    final Map<String, _SleepAgg> sleepAgg = {};

    for (final record in records) {
      final type = record.getAttribute('type') ?? '';
      final value = record.getAttribute('value') ?? '';
      final startDate = record.getAttribute('startDate') ?? '';
      final date = startDate.isNotEmpty ? startDate.substring(0, 10) : '';

      if (date.isEmpty) {
        processed++;
        if (processed % 1000 == 0) onProgress?.call(processed / total);
        continue;
      }

      dailyWearable.putIfAbsent(date, () => _DailyWearable(date));
      final dw = dailyWearable[date]!;

      switch (type) {
        case _stepCount:
          dw.steps = (dw.steps ?? 0) + (double.tryParse(value)?.toInt() ?? 0);
        case _activeEnergy:
          dw.activeCalories = (dw.activeCalories ?? 0) + (double.tryParse(value) ?? 0);
        case _restingHR:
          dw.restingHRValues.add(double.tryParse(value) ?? 0);
        case _hrv:
          dw.hrvValues.add(double.tryParse(value) ?? 0);
        case _spo2:
          final pct = double.tryParse(value) ?? 0;
          dw.spo2Values.add(pct > 1 ? pct : pct * 100);
        case _weight:
          result.bodyComps.add({
            'date': date,
            'weight_kg': double.tryParse(value),
            'scan_type': 'Apple Health',
          });
        case _bodyFat:
          final fat = double.tryParse(value) ?? 0;
          result.bodyFatByDate[date] = fat > 1 ? fat : fat * 100;
        case _sleepAnalysis:
          final endDate = record.getAttribute('endDate') ?? '';
          final sleepValue = record.getAttribute('value') ?? '';
          _processSleepRecord(date, startDate, endDate, sleepValue, sleepAgg);
        case _distanceWalking:
          final km = _toKm(value, record.getAttribute('unit') ?? 'km');
          dw.walkDistanceKm = (dw.walkDistanceKm ?? 0) + km;
        case _distanceCycling:
          final km = _toKm(value, record.getAttribute('unit') ?? 'km');
          dw.rideDistanceKm = (dw.rideDistanceKm ?? 0) + km;
      }

      processed++;
      if (processed % 1000 == 0) onProgress?.call(processed / total);
    }

    // Parse workouts
    for (final workout in workouts) {
      final actType = workout.getAttribute('workoutActivityType') ?? '';
      final startDate = workout.getAttribute('startDate') ?? '';
      final endDate = workout.getAttribute('endDate') ?? '';
      final duration = workout.getAttribute('duration') ?? '0';
      final energyBurned = workout.getAttribute('totalEnergyBurned') ?? '0';
      final distance = workout.getAttribute('totalDistance') ?? '0';

      if (startDate.isEmpty) { processed++; continue; }

      final date = startDate.substring(0, 10);
      final type = _workoutActivityType(actType);
      final durationMin = double.tryParse(duration);
      final calories = double.tryParse(energyBurned);
      final distKm = distance != '0' ? _toKm(distance, workout.getAttribute('totalDistanceUnit') ?? 'km') : null;

      result.activities.add({
        'date': date,
        'type': type,
        'name': type,
        'duration_minutes': durationMin,
        'distance_km': distKm,
        'calories': calories,
      });

      processed++;
      if (processed % 100 == 0) onProgress?.call(processed / total);
    }

    // Finalize daily wearable
    for (final entry in dailyWearable.entries) {
      final dw = entry.value;
      final avgHRV = dw.hrvValues.isNotEmpty ? dw.hrvValues.reduce((a, b) => a + b) / dw.hrvValues.length : null;
      final avgRHR = dw.restingHRValues.isNotEmpty ? dw.restingHRValues.reduce((a, b) => a + b) / dw.restingHRValues.length : null;
      final avgSpo2 = dw.spo2Values.isNotEmpty ? dw.spo2Values.reduce((a, b) => a + b) / dw.spo2Values.length : null;

      result.wearableData.add({
        'date': dw.date,
        'source': 'Apple Health',
        'steps': dw.steps,
        'active_calories': dw.activeCalories,
        'resting_hr': avgRHR,
        'hrv': avgHRV,
        'spo2': avgSpo2,
      });
    }

    // Finalize sleep
    for (final entry in sleepAgg.entries) {
      final s = entry.value;
      final totalH = s.totalSec / 3600;
      final deepH = s.deepSec / 3600;
      final remH = s.remSec / 3600;
      final lightH = s.lightSec / 3600;

      if (totalH > 0.5) {
        result.sleepLogs.add({
          'date': entry.key,
          'total_hours': totalH,
          'deep_hours': deepH,
          'rem_hours': remH,
          'light_hours': lightH,
          'awake_hours': s.awakeSec / 3600,
        });
      }
    }

    // Merge body fat into body comps
    for (final bc in result.bodyComps) {
      final date = bc['date'] as String;
      if (result.bodyFatByDate.containsKey(date)) {
        bc['body_fat_percent'] = result.bodyFatByDate[date];
      }
    }

    onProgress?.call(1.0);
    return result;
  }

  static void _processSleepRecord(String date, String startDate, String endDate, String value, Map<String, _SleepAgg> sleepAgg) {
    DateTime? start, end;
    try {
      start = DateTime.parse(startDate.replaceAll(' ', 'T').substring(0, 19));
      end = DateTime.parse(endDate.replaceAll(' ', 'T').substring(0, 19));
    } catch (_) { return; }

    final durationSec = end.difference(start).inSeconds;
    if (durationSec <= 0 || durationSec > 86400) return;

    // Use wake date as key
    final key = end.hour < 14 ? endDate.substring(0, 10) : startDate.substring(0, 10);
    sleepAgg.putIfAbsent(key, () => _SleepAgg());
    final s = sleepAgg[key]!;

    // HK sleep values
    if (value.contains('Asleep') || value == '1') {
      s.totalSec += durationSec;
      if (value.contains('Deep')) s.deepSec += durationSec;
      else if (value.contains('REM')) s.remSec += durationSec;
      else s.lightSec += durationSec;
    } else if (value.contains('Awake') || value == '2') {
      s.awakeSec += durationSec;
    } else if (value == '0') {
      // InBed - skip (Apple Watch older format)
    }
  }

  static double _toKm(String value, String unit) {
    final v = double.tryParse(value) ?? 0;
    if (unit == 'm' || unit == 'meters') return v / 1000;
    if (unit == 'mi' || unit == 'miles') return v * 1.60934;
    return v; // km
  }

  static String _workoutActivityType(String hkType) {
    if (hkType.contains('Running')) return 'Run';
    if (hkType.contains('Cycling')) return 'Ride';
    if (hkType.contains('Swimming')) return 'Swim';
    if (hkType.contains('Walking')) return 'Walk';
    if (hkType.contains('Hiking')) return 'Hike';
    if (hkType.contains('Rowing')) return 'Rowing';
    if (hkType.contains('HIIT') || hkType.contains('FunctionalStrength')) return 'HIIT';
    if (hkType.contains('Strength') || hkType.contains('TraditionalStrength')) return 'Strength';
    if (hkType.contains('Yoga')) return 'Yoga';
    return 'Other';
  }
}

class _DailyWearable {
  final String date;
  int? steps;
  double? activeCalories;
  double? walkDistanceKm;
  double? rideDistanceKm;
  final List<double> restingHRValues = [];
  final List<double> hrvValues = [];
  final List<double> spo2Values = [];
  _DailyWearable(this.date);
}

class _SleepAgg {
  int totalSec = 0;
  int deepSec = 0;
  int remSec = 0;
  int lightSec = 0;
  int awakeSec = 0;
}

class ParseResult {
  final List<Map<String, dynamic>> wearableData = [];
  final List<Map<String, dynamic>> sleepLogs = [];
  final List<Map<String, dynamic>> activities = [];
  final List<Map<String, dynamic>> bodyComps = [];
  final Map<String, double> bodyFatByDate = {};

  int get totalRecords => wearableData.length + sleepLogs.length + activities.length + bodyComps.length;
}
