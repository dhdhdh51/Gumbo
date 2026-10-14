import 'enums.dart';

/// A published source. Every shipped number resolves to one of these so the
/// app can always show where a figure came from.
class DataSource {
  const DataSource({
    required this.id,
    required this.name,
    required this.publisher,
    required this.year,
    required this.url,
    this.edition,
    this.accessed,
  });

  final String id;
  final String name;
  final String publisher;
  final int year;
  final String url;
  final String? edition;
  final String? accessed;

  /// Short citation used next to values in the UI.
  String get shortLabel => '$publisher, $year';

  static DataSource fromJson(Map<String, dynamic> j) => DataSource(
    id: j['id'] as String,
    name: j['name'] as String,
    publisher: j['publisher'] as String,
    year: (j['year'] as num).toInt(),
    url: j['url'] as String,
    edition: j['edition'] as String?,
    accessed: j['accessed'] as String?,
  );
}

/// WHO physical activity recommendation for one age band.
class ActivityBand {
  const ActivityBand({
    required this.id,
    required this.minAge,
    required this.maxAge,
    required this.label,
    required this.muscleStrengtheningDaysPerWeek,
    required this.sourceId,
    this.aerobicMinutesPerDayAverage,
    this.aerobicMinutesPerWeek,
    this.aerobicMinutesPerWeekMin,
    this.aerobicMinutesPerWeekMax,
    this.vigorousMinutesPerWeekMin,
    this.vigorousMinutesPerWeekMax,
    this.balanceAndStrengthDaysPerWeek,
    this.muscleStrengtheningNote,
    this.balanceNote,
    this.sedentaryNote,
    this.additionalBenefitNote,
  });

  final String id;
  final int minAge;
  final int? maxAge;
  final String label;
  final int muscleStrengtheningDaysPerWeek;
  final String sourceId;

  /// Set for the 5-17 band, which is expressed per day rather than per week.
  final int? aerobicMinutesPerDayAverage;
  final int? aerobicMinutesPerWeek;

  /// Set for the adult and older-adult bands.
  final int? aerobicMinutesPerWeekMin;
  final int? aerobicMinutesPerWeekMax;
  final int? vigorousMinutesPerWeekMin;
  final int? vigorousMinutesPerWeekMax;

  /// Only the 65+ band carries this.
  final int? balanceAndStrengthDaysPerWeek;

  final String? muscleStrengtheningNote;
  final String? balanceNote;
  final String? sedentaryNote;
  final String? additionalBenefitNote;

  bool matchesAge(int age) =>
      age >= minAge && (maxAge == null || age <= maxAge!);

  /// Weekly moderate-intensity aerobic minutes to show as the headline target.
  int get weeklyAerobicTarget =>
      aerobicMinutesPerWeek ?? aerobicMinutesPerWeekMin ?? 0;

  static ActivityBand fromJson(Map<String, dynamic> j) => ActivityBand(
    id: j['id'] as String,
    minAge: (j['minAge'] as num).toInt(),
    maxAge: (j['maxAge'] as num?)?.toInt(),
    label: j['label'] as String,
    muscleStrengtheningDaysPerWeek:
        (j['muscleStrengtheningDaysPerWeek'] as num?)?.toInt() ?? 0,
    sourceId: j['sourceId'] as String,
    aerobicMinutesPerDayAverage:
        (j['aerobicMinutesPerDayAverage'] as num?)?.toInt(),
    aerobicMinutesPerWeek: (j['aerobicMinutesPerWeek'] as num?)?.toInt(),
    aerobicMinutesPerWeekMin: (j['aerobicMinutesPerWeekMin'] as num?)?.toInt(),
    aerobicMinutesPerWeekMax: (j['aerobicMinutesPerWeekMax'] as num?)?.toInt(),
    vigorousMinutesPerWeekMin:
        (j['vigorousMinutesPerWeekMin'] as num?)?.toInt(),
    vigorousMinutesPerWeekMax:
        (j['vigorousMinutesPerWeekMax'] as num?)?.toInt(),
    balanceAndStrengthDaysPerWeek:
        (j['balanceAndStrengthDaysPerWeek'] as num?)?.toInt(),
    muscleStrengtheningNote: j['muscleStrengtheningNote'] as String?,
    balanceNote: j['balanceNote'] as String?,
    sedentaryNote: j['sedentaryNote'] as String?,
    additionalBenefitNote: j['additionalBenefitNote'] as String?,
  );
}

/// A short, citable note shown on safety and sources screens.
class GuidelineNote {
  const GuidelineNote({
    required this.id,
    required this.text,
    required this.sourceId,
  });

  final String id;
  final String text;
  final String sourceId;

  static GuidelineNote fromJson(Map<String, dynamic> j) => GuidelineNote(
    id: j['id'] as String,
    text: j['text'] as String,
    sourceId: j['sourceId'] as String,
  );
}

/// Physical activity level and published energy requirement for one of the
/// three ICMR-NIN activity categories.
class ActivityEnergy {
  const ActivityEnergy({
    required this.referenceWeightKg,
    required this.kcalPerDay,
    required this.kcalPerKgPerDay,
    required this.pal,
    required this.palDerived,
    this.palFormula,
  });

  final double referenceWeightKg;
  final int kcalPerDay;
  final double kcalPerKgPerDay;
  final double pal;

  /// True when the PAL is arithmetic on published values rather than printed
  /// directly in the source. The UI says so wherever it shows the number.
  final bool palDerived;
  final String? palFormula;

  static ActivityEnergy fromJson(Map<String, dynamic> j) => ActivityEnergy(
    referenceWeightKg: (j['referenceWeightKg'] as num).toDouble(),
    kcalPerDay: (j['kcalPerDay'] as num).toInt(),
    kcalPerKgPerDay: (j['kcalPerKgPerDay'] as num).toDouble(),
    pal: (j['pal'] as num).toDouble(),
    palDerived: j['palDerived'] == true,
    palFormula: j['palFormula'] as String?,
  );
}

class ActivityLevelEnergy {
  const ActivityLevelEnergy({
    required this.id,
    required this.label,
    required this.male,
    required this.female,
    required this.sourceId,
    this.palNote,
  });

  final String id;
  final String label;
  final ActivityEnergy male;
  final ActivityEnergy female;
  final String sourceId;
  final String? palNote;

  ActivityEnergy forSex(Sex sex) => sex == Sex.male ? male : female;

  static ActivityLevelEnergy fromJson(Map<String, dynamic> j) =>
      ActivityLevelEnergy(
        id: j['id'] as String,
        label: j['label'] as String,
        male: ActivityEnergy.fromJson(j['male'] as Map<String, dynamic>),
        female: ActivityEnergy.fromJson(j['female'] as Map<String, dynamic>),
        sourceId: j['sourceId'] as String,
        palNote: j['palNote'] as String?,
      );
}

/// ICMR-NIN protein requirement row, for adults or an adolescent band.
class ProteinRequirement {
  const ProteinRequirement({
    required this.referenceWeightKg,
    required this.earGPerKg,
    required this.rdaGPerKg,
    required this.earGPerDay,
    required this.rdaGPerDay,
    required this.sourceId,
    this.sex,
    this.minAge,
    this.maxAge,
    this.group,
  });

  final double referenceWeightKg;
  final double earGPerKg;
  final double rdaGPerKg;
  final double earGPerDay;
  final double rdaGPerDay;
  final String sourceId;
  final Sex? sex;
  final int? minAge;
  final int? maxAge;
  final String? group;

  bool matches(int age, Sex s) {
    if (sex != null && sex != s) return false;
    if (minAge != null && age < minAge!) return false;
    if (maxAge != null && age > maxAge!) return false;
    return true;
  }

  static ProteinRequirement fromJson(Map<String, dynamic> j) =>
      ProteinRequirement(
        referenceWeightKg: (j['referenceWeightKg'] as num).toDouble(),
        earGPerKg: (j['earGPerKg'] as num).toDouble(),
        rdaGPerKg: (j['rdaGPerKg'] as num).toDouble(),
        earGPerDay: (j['earGPerDay'] as num).toDouble(),
        rdaGPerDay: (j['rdaGPerDay'] as num).toDouble(),
        sourceId: j['sourceId'] as String,
        sex: j['sex'] == null ? null : Sex.fromName(j['sex'] as String),
        minAge: (j['minAge'] as num?)?.toInt(),
        maxAge: (j['maxAge'] as num?)?.toInt(),
        group: j['group'] as String?,
      );
}

/// A min-max band with a note and a source, used for several protein and
/// macronutrient ranges.
class SourcedRange {
  const SourcedRange({
    required this.min,
    required this.max,
    required this.sourceId,
    this.note,
  });

  final double min;
  final double max;
  final String sourceId;
  final String? note;

  static SourcedRange fromJson(Map<String, dynamic> j) => SourcedRange(
    min: (j['min'] as num).toDouble(),
    max: (j['max'] as num).toDouble(),
    sourceId: j['sourceId'] as String,
    note: j['note'] as String?,
  );
}

/// A single value with a note, a source and an origin flag.
///
/// [origin] is "source" when the number is printed in the publication and
/// "app_policy" when it is a guard chosen for this app. The UI labels the two
/// differently so a conservative app rule is never dressed up as a citation.
class SourcedValue {
  const SourcedValue({
    required this.value,
    required this.origin,
    this.note,
    this.sourceId,
    this.supportingSourceId,
  });

  final double value;
  final String origin;
  final String? note;
  final String? sourceId;
  final String? supportingSourceId;

  bool get isFromSource => origin == 'source';

  /// The source to cite, if there is one at all.
  String? get citationSourceId => sourceId ?? supportingSourceId;

  static SourcedValue fromJson(Map<String, dynamic> j) => SourcedValue(
    value: (j['value'] as num).toDouble(),
    origin: (j['origin'] as String?) ?? 'source',
    note: j['note'] as String?,
    sourceId: j['sourceId'] as String?,
    supportingSourceId: j['supportingSourceId'] as String?,
  );
}

/// Age gate derived from safety_rules.json.
class AgeRule {
  const AgeRule({
    required this.id,
    required this.minAge,
    required this.maxAge,
    required this.access,
    required this.allowCalorieDeficit,
    required this.allowWeightLossGoal,
    this.message,
    this.activityBandId,
    this.activityBandIdFrom65,
    this.defaultIntensity,
    this.supportingSourceId,
    this.supportingNote,
  });

  final String id;
  final int minAge;
  final int? maxAge;
  final String access;
  final bool allowCalorieDeficit;
  final bool allowWeightLossGoal;
  final String? message;
  final String? activityBandId;
  final String? activityBandIdFrom65;
  final String? defaultIntensity;
  final String? supportingSourceId;
  final String? supportingNote;

  bool matchesAge(int age) =>
      age >= minAge && (maxAge == null || age <= maxAge!);

  AccessLevel get accessLevel => switch (access) {
    'blocked' => AccessLevel.blocked,
    'activity_only' => AccessLevel.activityOnly,
    'full_lighter_default' => AccessLevel.fullLighterDefault,
    _ => AccessLevel.full,
  };

  static AgeRule fromJson(Map<String, dynamic> j) => AgeRule(
    id: j['id'] as String,
    minAge: (j['minAge'] as num).toInt(),
    maxAge: (j['maxAge'] as num?)?.toInt(),
    access: j['access'] as String,
    allowCalorieDeficit: j['allowCalorieDeficit'] == true,
    allowWeightLossGoal: j['allowWeightLossGoal'] == true,
    message: j['message'] as String?,
    activityBandId: j['activityBandId'] as String?,
    activityBandIdFrom65: j['activityBandIdFrom65'] as String?,
    defaultIntensity: j['defaultIntensity'] as String?,
    supportingSourceId: j['supportingSourceId'] as String?,
    supportingNote: j['supportingNote'] as String?,
  );
}

/// One screening question.
class ScreeningItem {
  const ScreeningItem({
    required this.id,
    required this.severity,
    required this.labelKey,
  });

  final String id;

  /// "serious" answers trigger the medical-clearance gate; "caution" answers
  /// only show an advisory notice.
  final String severity;
  final String labelKey;

  bool get isSerious => severity == 'serious';

  static ScreeningItem fromJson(Map<String, dynamic> j) => ScreeningItem(
    id: j['id'] as String,
    severity: j['severity'] as String,
    labelKey: j['labelKey'] as String,
  );
}

/// BMI cut-offs for Indian adults.
class BmiCutoffs {
  const BmiCutoffs({
    required this.underweightBelow,
    required this.normalMin,
    required this.normalMax,
    required this.overweightMax,
    required this.sourceId,
    this.note,
  });

  final double underweightBelow;
  final double normalMin;
  final double normalMax;
  final double overweightMax;
  final String sourceId;
  final String? note;

  /// One of "underweight", "normal", "overweight", "obese".
  String categoryFor(double bmi) {
    if (bmi < underweightBelow) return 'underweight';
    if (bmi <= normalMax) return 'normal';
    if (bmi <= overweightMax) return 'overweight';
    return 'obese';
  }

  static BmiCutoffs fromJson(Map<String, dynamic> j) => BmiCutoffs(
    underweightBelow: (j['underweightBelow'] as num).toDouble(),
    normalMin: (j['normalMin'] as num).toDouble(),
    normalMax: (j['normalMax'] as num).toDouble(),
    overweightMax: (j['overweightMax'] as num).toDouble(),
    sourceId: j['sourceId'] as String,
    note: j['note'] as String?,
  );
}

/// A daily diet target or limit, such as water, fibre, salt or added sugar.
class DietTarget {
  const DietTarget({
    required this.id,
    required this.label,
    required this.sourceId,
    this.note,
    this.values = const {},
  });

  final String id;
  final String label;
  final String sourceId;
  final String? note;

  /// Raw numeric fields from the asset, kept generic because each target
  /// publishes a different combination of units.
  final Map<String, num> values;

  num? operator [](String key) => values[key];

  static DietTarget fromJson(Map<String, dynamic> j) {
    final values = <String, num>{};
    for (final e in j.entries) {
      if (e.value is num) values[e.key] = e.value as num;
    }
    return DietTarget(
      id: j['id'] as String,
      label: j['label'] as String,
      sourceId: (j['sourceId'] as String?) ?? '',
      note: j['note'] as String?,
      values: values,
    );
  }
}
