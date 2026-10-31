// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $StepMinutesTable extends StepMinutes
    with TableInfo<$StepMinutesTable, StepMinuteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StepMinutesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _minuteUtcMeta = const VerificationMeta(
    'minuteUtc',
  );
  @override
  late final GeneratedColumn<int> minuteUtc = GeneratedColumn<int>(
    'minute_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
    'steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [minuteUtc, steps];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'step_minutes';
  @override
  VerificationContext validateIntegrity(
    Insertable<StepMinuteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('minute_utc')) {
      context.handle(
        _minuteUtcMeta,
        minuteUtc.isAcceptableOrUnknown(data['minute_utc']!, _minuteUtcMeta),
      );
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    } else if (isInserting) {
      context.missing(_stepsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {minuteUtc};
  @override
  StepMinuteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StepMinuteRow(
      minuteUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute_utc'],
      )!,
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}steps'],
      )!,
    );
  }

  @override
  $StepMinutesTable createAlias(String alias) {
    return $StepMinutesTable(attachedDatabase, alias);
  }
}

class StepMinuteRow extends DataClass implements Insertable<StepMinuteRow> {
  final int minuteUtc;
  final int steps;
  const StepMinuteRow({required this.minuteUtc, required this.steps});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['minute_utc'] = Variable<int>(minuteUtc);
    map['steps'] = Variable<int>(steps);
    return map;
  }

  StepMinutesCompanion toCompanion(bool nullToAbsent) {
    return StepMinutesCompanion(
      minuteUtc: Value(minuteUtc),
      steps: Value(steps),
    );
  }

  factory StepMinuteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StepMinuteRow(
      minuteUtc: serializer.fromJson<int>(json['minuteUtc']),
      steps: serializer.fromJson<int>(json['steps']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'minuteUtc': serializer.toJson<int>(minuteUtc),
      'steps': serializer.toJson<int>(steps),
    };
  }

  StepMinuteRow copyWith({int? minuteUtc, int? steps}) => StepMinuteRow(
    minuteUtc: minuteUtc ?? this.minuteUtc,
    steps: steps ?? this.steps,
  );
  StepMinuteRow copyWithCompanion(StepMinutesCompanion data) {
    return StepMinuteRow(
      minuteUtc: data.minuteUtc.present ? data.minuteUtc.value : this.minuteUtc,
      steps: data.steps.present ? data.steps.value : this.steps,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StepMinuteRow(')
          ..write('minuteUtc: $minuteUtc, ')
          ..write('steps: $steps')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(minuteUtc, steps);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StepMinuteRow &&
          other.minuteUtc == this.minuteUtc &&
          other.steps == this.steps);
}

class StepMinutesCompanion extends UpdateCompanion<StepMinuteRow> {
  final Value<int> minuteUtc;
  final Value<int> steps;
  const StepMinutesCompanion({
    this.minuteUtc = const Value.absent(),
    this.steps = const Value.absent(),
  });
  StepMinutesCompanion.insert({
    this.minuteUtc = const Value.absent(),
    required int steps,
  }) : steps = Value(steps);
  static Insertable<StepMinuteRow> custom({
    Expression<int>? minuteUtc,
    Expression<int>? steps,
  }) {
    return RawValuesInsertable({
      if (minuteUtc != null) 'minute_utc': minuteUtc,
      if (steps != null) 'steps': steps,
    });
  }

  StepMinutesCompanion copyWith({Value<int>? minuteUtc, Value<int>? steps}) {
    return StepMinutesCompanion(
      minuteUtc: minuteUtc ?? this.minuteUtc,
      steps: steps ?? this.steps,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (minuteUtc.present) {
      map['minute_utc'] = Variable<int>(minuteUtc.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StepMinutesCompanion(')
          ..write('minuteUtc: $minuteUtc, ')
          ..write('steps: $steps')
          ..write(')'))
        .toString();
  }
}

class $DaySummariesTable extends DaySummaries
    with TableInfo<$DaySummariesTable, DaySummaryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DaySummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
    'steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _distanceMMeta = const VerificationMeta(
    'distanceM',
  );
  @override
  late final GeneratedColumn<double> distanceM = GeneratedColumn<double>(
    'distance_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countedSessionsMeta = const VerificationMeta(
    'countedSessions',
  );
  @override
  late final GeneratedColumn<int> countedSessions = GeneratedColumn<int>(
    'counted_sessions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    day,
    steps,
    distanceM,
    countedSessions,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DaySummaryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    } else if (isInserting) {
      context.missing(_stepsMeta);
    }
    if (data.containsKey('distance_m')) {
      context.handle(
        _distanceMMeta,
        distanceM.isAcceptableOrUnknown(data['distance_m']!, _distanceMMeta),
      );
    } else if (isInserting) {
      context.missing(_distanceMMeta);
    }
    if (data.containsKey('counted_sessions')) {
      context.handle(
        _countedSessionsMeta,
        countedSessions.isAcceptableOrUnknown(
          data['counted_sessions']!,
          _countedSessionsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_countedSessionsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  DaySummaryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DaySummaryRow(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}steps'],
      )!,
      distanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_m'],
      )!,
      countedSessions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}counted_sessions'],
      )!,
    );
  }

  @override
  $DaySummariesTable createAlias(String alias) {
    return $DaySummariesTable(attachedDatabase, alias);
  }
}

class DaySummaryRow extends DataClass implements Insertable<DaySummaryRow> {
  final String day;
  final int steps;
  final double distanceM;
  final int countedSessions;
  const DaySummaryRow({
    required this.day,
    required this.steps,
    required this.distanceM,
    required this.countedSessions,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<String>(day);
    map['steps'] = Variable<int>(steps);
    map['distance_m'] = Variable<double>(distanceM);
    map['counted_sessions'] = Variable<int>(countedSessions);
    return map;
  }

  DaySummariesCompanion toCompanion(bool nullToAbsent) {
    return DaySummariesCompanion(
      day: Value(day),
      steps: Value(steps),
      distanceM: Value(distanceM),
      countedSessions: Value(countedSessions),
    );
  }

  factory DaySummaryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DaySummaryRow(
      day: serializer.fromJson<String>(json['day']),
      steps: serializer.fromJson<int>(json['steps']),
      distanceM: serializer.fromJson<double>(json['distanceM']),
      countedSessions: serializer.fromJson<int>(json['countedSessions']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<String>(day),
      'steps': serializer.toJson<int>(steps),
      'distanceM': serializer.toJson<double>(distanceM),
      'countedSessions': serializer.toJson<int>(countedSessions),
    };
  }

  DaySummaryRow copyWith({
    String? day,
    int? steps,
    double? distanceM,
    int? countedSessions,
  }) => DaySummaryRow(
    day: day ?? this.day,
    steps: steps ?? this.steps,
    distanceM: distanceM ?? this.distanceM,
    countedSessions: countedSessions ?? this.countedSessions,
  );
  DaySummaryRow copyWithCompanion(DaySummariesCompanion data) {
    return DaySummaryRow(
      day: data.day.present ? data.day.value : this.day,
      steps: data.steps.present ? data.steps.value : this.steps,
      distanceM: data.distanceM.present ? data.distanceM.value : this.distanceM,
      countedSessions: data.countedSessions.present
          ? data.countedSessions.value
          : this.countedSessions,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DaySummaryRow(')
          ..write('day: $day, ')
          ..write('steps: $steps, ')
          ..write('distanceM: $distanceM, ')
          ..write('countedSessions: $countedSessions')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(day, steps, distanceM, countedSessions);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DaySummaryRow &&
          other.day == this.day &&
          other.steps == this.steps &&
          other.distanceM == this.distanceM &&
          other.countedSessions == this.countedSessions);
}

class DaySummariesCompanion extends UpdateCompanion<DaySummaryRow> {
  final Value<String> day;
  final Value<int> steps;
  final Value<double> distanceM;
  final Value<int> countedSessions;
  final Value<int> rowid;
  const DaySummariesCompanion({
    this.day = const Value.absent(),
    this.steps = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.countedSessions = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DaySummariesCompanion.insert({
    required String day,
    required int steps,
    required double distanceM,
    required int countedSessions,
    this.rowid = const Value.absent(),
  }) : day = Value(day),
       steps = Value(steps),
       distanceM = Value(distanceM),
       countedSessions = Value(countedSessions);
  static Insertable<DaySummaryRow> custom({
    Expression<String>? day,
    Expression<int>? steps,
    Expression<double>? distanceM,
    Expression<int>? countedSessions,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (steps != null) 'steps': steps,
      if (distanceM != null) 'distance_m': distanceM,
      if (countedSessions != null) 'counted_sessions': countedSessions,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DaySummariesCompanion copyWith({
    Value<String>? day,
    Value<int>? steps,
    Value<double>? distanceM,
    Value<int>? countedSessions,
    Value<int>? rowid,
  }) {
    return DaySummariesCompanion(
      day: day ?? this.day,
      steps: steps ?? this.steps,
      distanceM: distanceM ?? this.distanceM,
      countedSessions: countedSessions ?? this.countedSessions,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (distanceM.present) {
      map['distance_m'] = Variable<double>(distanceM.value);
    }
    if (countedSessions.present) {
      map['counted_sessions'] = Variable<int>(countedSessions.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DaySummariesCompanion(')
          ..write('day: $day, ')
          ..write('steps: $steps, ')
          ..write('distanceM: $distanceM, ')
          ..write('countedSessions: $countedSessions, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WalkSessionsTable extends WalkSessions
    with TableInfo<$WalkSessionsTable, WalkSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalkSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _startUtcMeta = const VerificationMeta(
    'startUtc',
  );
  @override
  late final GeneratedColumn<int> startUtc = GeneratedColumn<int>(
    'start_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endUtcMeta = const VerificationMeta('endUtc');
  @override
  late final GeneratedColumn<int> endUtc = GeneratedColumn<int>(
    'end_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
    'steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _distanceMMeta = const VerificationMeta(
    'distanceM',
  );
  @override
  late final GeneratedColumn<double> distanceM = GeneratedColumn<double>(
    'distance_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runRatioMeta = const VerificationMeta(
    'runRatio',
  );
  @override
  late final GeneratedColumn<double> runRatio = GeneratedColumn<double>(
    'run_ratio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualifiedMeta = const VerificationMeta(
    'qualified',
  );
  @override
  late final GeneratedColumn<bool> qualified = GeneratedColumn<bool>(
    'qualified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("qualified" IN (0, 1))',
    ),
  );
  static const VerificationMeta _countedMeta = const VerificationMeta(
    'counted',
  );
  @override
  late final GeneratedColumn<bool> counted = GeneratedColumn<bool>(
    'counted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("counted" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    startUtc,
    endUtc,
    steps,
    distanceM,
    runRatio,
    qualified,
    counted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'walk_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalkSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('start_utc')) {
      context.handle(
        _startUtcMeta,
        startUtc.isAcceptableOrUnknown(data['start_utc']!, _startUtcMeta),
      );
    }
    if (data.containsKey('end_utc')) {
      context.handle(
        _endUtcMeta,
        endUtc.isAcceptableOrUnknown(data['end_utc']!, _endUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_endUtcMeta);
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    } else if (isInserting) {
      context.missing(_stepsMeta);
    }
    if (data.containsKey('distance_m')) {
      context.handle(
        _distanceMMeta,
        distanceM.isAcceptableOrUnknown(data['distance_m']!, _distanceMMeta),
      );
    } else if (isInserting) {
      context.missing(_distanceMMeta);
    }
    if (data.containsKey('run_ratio')) {
      context.handle(
        _runRatioMeta,
        runRatio.isAcceptableOrUnknown(data['run_ratio']!, _runRatioMeta),
      );
    } else if (isInserting) {
      context.missing(_runRatioMeta);
    }
    if (data.containsKey('qualified')) {
      context.handle(
        _qualifiedMeta,
        qualified.isAcceptableOrUnknown(data['qualified']!, _qualifiedMeta),
      );
    } else if (isInserting) {
      context.missing(_qualifiedMeta);
    }
    if (data.containsKey('counted')) {
      context.handle(
        _countedMeta,
        counted.isAcceptableOrUnknown(data['counted']!, _countedMeta),
      );
    } else if (isInserting) {
      context.missing(_countedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {startUtc};
  @override
  WalkSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalkSessionRow(
      startUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_utc'],
      )!,
      endUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_utc'],
      )!,
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}steps'],
      )!,
      distanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_m'],
      )!,
      runRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}run_ratio'],
      )!,
      qualified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}qualified'],
      )!,
      counted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}counted'],
      )!,
    );
  }

  @override
  $WalkSessionsTable createAlias(String alias) {
    return $WalkSessionsTable(attachedDatabase, alias);
  }
}

class WalkSessionRow extends DataClass implements Insertable<WalkSessionRow> {
  final int startUtc;
  final int endUtc;
  final int steps;
  final double distanceM;
  final double runRatio;
  final bool qualified;
  final bool counted;
  const WalkSessionRow({
    required this.startUtc,
    required this.endUtc,
    required this.steps,
    required this.distanceM,
    required this.runRatio,
    required this.qualified,
    required this.counted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['start_utc'] = Variable<int>(startUtc);
    map['end_utc'] = Variable<int>(endUtc);
    map['steps'] = Variable<int>(steps);
    map['distance_m'] = Variable<double>(distanceM);
    map['run_ratio'] = Variable<double>(runRatio);
    map['qualified'] = Variable<bool>(qualified);
    map['counted'] = Variable<bool>(counted);
    return map;
  }

  WalkSessionsCompanion toCompanion(bool nullToAbsent) {
    return WalkSessionsCompanion(
      startUtc: Value(startUtc),
      endUtc: Value(endUtc),
      steps: Value(steps),
      distanceM: Value(distanceM),
      runRatio: Value(runRatio),
      qualified: Value(qualified),
      counted: Value(counted),
    );
  }

  factory WalkSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalkSessionRow(
      startUtc: serializer.fromJson<int>(json['startUtc']),
      endUtc: serializer.fromJson<int>(json['endUtc']),
      steps: serializer.fromJson<int>(json['steps']),
      distanceM: serializer.fromJson<double>(json['distanceM']),
      runRatio: serializer.fromJson<double>(json['runRatio']),
      qualified: serializer.fromJson<bool>(json['qualified']),
      counted: serializer.fromJson<bool>(json['counted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'startUtc': serializer.toJson<int>(startUtc),
      'endUtc': serializer.toJson<int>(endUtc),
      'steps': serializer.toJson<int>(steps),
      'distanceM': serializer.toJson<double>(distanceM),
      'runRatio': serializer.toJson<double>(runRatio),
      'qualified': serializer.toJson<bool>(qualified),
      'counted': serializer.toJson<bool>(counted),
    };
  }

  WalkSessionRow copyWith({
    int? startUtc,
    int? endUtc,
    int? steps,
    double? distanceM,
    double? runRatio,
    bool? qualified,
    bool? counted,
  }) => WalkSessionRow(
    startUtc: startUtc ?? this.startUtc,
    endUtc: endUtc ?? this.endUtc,
    steps: steps ?? this.steps,
    distanceM: distanceM ?? this.distanceM,
    runRatio: runRatio ?? this.runRatio,
    qualified: qualified ?? this.qualified,
    counted: counted ?? this.counted,
  );
  WalkSessionRow copyWithCompanion(WalkSessionsCompanion data) {
    return WalkSessionRow(
      startUtc: data.startUtc.present ? data.startUtc.value : this.startUtc,
      endUtc: data.endUtc.present ? data.endUtc.value : this.endUtc,
      steps: data.steps.present ? data.steps.value : this.steps,
      distanceM: data.distanceM.present ? data.distanceM.value : this.distanceM,
      runRatio: data.runRatio.present ? data.runRatio.value : this.runRatio,
      qualified: data.qualified.present ? data.qualified.value : this.qualified,
      counted: data.counted.present ? data.counted.value : this.counted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalkSessionRow(')
          ..write('startUtc: $startUtc, ')
          ..write('endUtc: $endUtc, ')
          ..write('steps: $steps, ')
          ..write('distanceM: $distanceM, ')
          ..write('runRatio: $runRatio, ')
          ..write('qualified: $qualified, ')
          ..write('counted: $counted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    startUtc,
    endUtc,
    steps,
    distanceM,
    runRatio,
    qualified,
    counted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalkSessionRow &&
          other.startUtc == this.startUtc &&
          other.endUtc == this.endUtc &&
          other.steps == this.steps &&
          other.distanceM == this.distanceM &&
          other.runRatio == this.runRatio &&
          other.qualified == this.qualified &&
          other.counted == this.counted);
}

class WalkSessionsCompanion extends UpdateCompanion<WalkSessionRow> {
  final Value<int> startUtc;
  final Value<int> endUtc;
  final Value<int> steps;
  final Value<double> distanceM;
  final Value<double> runRatio;
  final Value<bool> qualified;
  final Value<bool> counted;
  const WalkSessionsCompanion({
    this.startUtc = const Value.absent(),
    this.endUtc = const Value.absent(),
    this.steps = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.runRatio = const Value.absent(),
    this.qualified = const Value.absent(),
    this.counted = const Value.absent(),
  });
  WalkSessionsCompanion.insert({
    this.startUtc = const Value.absent(),
    required int endUtc,
    required int steps,
    required double distanceM,
    required double runRatio,
    required bool qualified,
    required bool counted,
  }) : endUtc = Value(endUtc),
       steps = Value(steps),
       distanceM = Value(distanceM),
       runRatio = Value(runRatio),
       qualified = Value(qualified),
       counted = Value(counted);
  static Insertable<WalkSessionRow> custom({
    Expression<int>? startUtc,
    Expression<int>? endUtc,
    Expression<int>? steps,
    Expression<double>? distanceM,
    Expression<double>? runRatio,
    Expression<bool>? qualified,
    Expression<bool>? counted,
  }) {
    return RawValuesInsertable({
      if (startUtc != null) 'start_utc': startUtc,
      if (endUtc != null) 'end_utc': endUtc,
      if (steps != null) 'steps': steps,
      if (distanceM != null) 'distance_m': distanceM,
      if (runRatio != null) 'run_ratio': runRatio,
      if (qualified != null) 'qualified': qualified,
      if (counted != null) 'counted': counted,
    });
  }

  WalkSessionsCompanion copyWith({
    Value<int>? startUtc,
    Value<int>? endUtc,
    Value<int>? steps,
    Value<double>? distanceM,
    Value<double>? runRatio,
    Value<bool>? qualified,
    Value<bool>? counted,
  }) {
    return WalkSessionsCompanion(
      startUtc: startUtc ?? this.startUtc,
      endUtc: endUtc ?? this.endUtc,
      steps: steps ?? this.steps,
      distanceM: distanceM ?? this.distanceM,
      runRatio: runRatio ?? this.runRatio,
      qualified: qualified ?? this.qualified,
      counted: counted ?? this.counted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (startUtc.present) {
      map['start_utc'] = Variable<int>(startUtc.value);
    }
    if (endUtc.present) {
      map['end_utc'] = Variable<int>(endUtc.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (distanceM.present) {
      map['distance_m'] = Variable<double>(distanceM.value);
    }
    if (runRatio.present) {
      map['run_ratio'] = Variable<double>(runRatio.value);
    }
    if (qualified.present) {
      map['qualified'] = Variable<bool>(qualified.value);
    }
    if (counted.present) {
      map['counted'] = Variable<bool>(counted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalkSessionsCompanion(')
          ..write('startUtc: $startUtc, ')
          ..write('endUtc: $endUtc, ')
          ..write('steps: $steps, ')
          ..write('distanceM: $distanceM, ')
          ..write('runRatio: $runRatio, ')
          ..write('qualified: $qualified, ')
          ..write('counted: $counted')
          ..write(')'))
        .toString();
  }
}

class $JourneysTable extends Journeys
    with TableInfo<$JourneysTable, JourneyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JourneysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originLatMeta = const VerificationMeta(
    'originLat',
  );
  @override
  late final GeneratedColumn<double> originLat = GeneratedColumn<double>(
    'origin_lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originLngMeta = const VerificationMeta(
    'originLng',
  );
  @override
  late final GeneratedColumn<double> originLng = GeneratedColumn<double>(
    'origin_lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destIdMeta = const VerificationMeta('destId');
  @override
  late final GeneratedColumn<String> destId = GeneratedColumn<String>(
    'dest_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startUtcMeta = const VerificationMeta(
    'startUtc',
  );
  @override
  late final GeneratedColumn<int> startUtc = GeneratedColumn<int>(
    'start_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fundKmMeta = const VerificationMeta('fundKm');
  @override
  late final GeneratedColumn<double> fundKm = GeneratedColumn<double>(
    'fund_km',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalEffectiveKmMeta = const VerificationMeta(
    'totalEffectiveKm',
  );
  @override
  late final GeneratedColumn<double> totalEffectiveKm = GeneratedColumn<double>(
    'total_effective_km',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<JourneyStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<JourneyStatus>($JourneysTable.$converterstatus);
  static const VerificationMeta _arrivedUtcMeta = const VerificationMeta(
    'arrivedUtc',
  );
  @override
  late final GeneratedColumn<int> arrivedUtc = GeneratedColumn<int>(
    'arrived_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endLatMeta = const VerificationMeta('endLat');
  @override
  late final GeneratedColumn<double> endLat = GeneratedColumn<double>(
    'end_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endLngMeta = const VerificationMeta('endLng');
  @override
  late final GeneratedColumn<double> endLng = GeneratedColumn<double>(
    'end_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endedUtcMeta = const VerificationMeta(
    'endedUtc',
  );
  @override
  late final GeneratedColumn<int> endedUtc = GeneratedColumn<int>(
    'ended_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _visitNoMeta = const VerificationMeta(
    'visitNo',
  );
  @override
  late final GeneratedColumn<int> visitNo = GeneratedColumn<int>(
    'visit_no',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Frame?, String> prevFrame =
      GeneratedColumn<String>(
        'prev_frame',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Frame?>($JourneysTable.$converterprevFramen);
  @override
  late final GeneratedColumnWithTypeConverter<Frame?, String> newFrame =
      GeneratedColumn<String>(
        'new_frame',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Frame?>($JourneysTable.$converternewFramen);
  static const VerificationMeta _arrivalShownMeta = const VerificationMeta(
    'arrivalShown',
  );
  @override
  late final GeneratedColumn<bool> arrivalShown = GeneratedColumn<bool>(
    'arrival_shown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("arrival_shown" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _destLatMeta = const VerificationMeta(
    'destLat',
  );
  @override
  late final GeneratedColumn<double> destLat = GeneratedColumn<double>(
    'dest_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _destLngMeta = const VerificationMeta(
    'destLng',
  );
  @override
  late final GeneratedColumn<double> destLng = GeneratedColumn<double>(
    'dest_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    originLat,
    originLng,
    destId,
    startUtc,
    fundKm,
    totalEffectiveKm,
    status,
    arrivedUtc,
    endLat,
    endLng,
    endedUtc,
    visitNo,
    prevFrame,
    newFrame,
    arrivalShown,
    destLat,
    destLng,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journeys';
  @override
  VerificationContext validateIntegrity(
    Insertable<JourneyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('origin_lat')) {
      context.handle(
        _originLatMeta,
        originLat.isAcceptableOrUnknown(data['origin_lat']!, _originLatMeta),
      );
    } else if (isInserting) {
      context.missing(_originLatMeta);
    }
    if (data.containsKey('origin_lng')) {
      context.handle(
        _originLngMeta,
        originLng.isAcceptableOrUnknown(data['origin_lng']!, _originLngMeta),
      );
    } else if (isInserting) {
      context.missing(_originLngMeta);
    }
    if (data.containsKey('dest_id')) {
      context.handle(
        _destIdMeta,
        destId.isAcceptableOrUnknown(data['dest_id']!, _destIdMeta),
      );
    } else if (isInserting) {
      context.missing(_destIdMeta);
    }
    if (data.containsKey('start_utc')) {
      context.handle(
        _startUtcMeta,
        startUtc.isAcceptableOrUnknown(data['start_utc']!, _startUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_startUtcMeta);
    }
    if (data.containsKey('fund_km')) {
      context.handle(
        _fundKmMeta,
        fundKm.isAcceptableOrUnknown(data['fund_km']!, _fundKmMeta),
      );
    } else if (isInserting) {
      context.missing(_fundKmMeta);
    }
    if (data.containsKey('total_effective_km')) {
      context.handle(
        _totalEffectiveKmMeta,
        totalEffectiveKm.isAcceptableOrUnknown(
          data['total_effective_km']!,
          _totalEffectiveKmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalEffectiveKmMeta);
    }
    if (data.containsKey('arrived_utc')) {
      context.handle(
        _arrivedUtcMeta,
        arrivedUtc.isAcceptableOrUnknown(data['arrived_utc']!, _arrivedUtcMeta),
      );
    }
    if (data.containsKey('end_lat')) {
      context.handle(
        _endLatMeta,
        endLat.isAcceptableOrUnknown(data['end_lat']!, _endLatMeta),
      );
    }
    if (data.containsKey('end_lng')) {
      context.handle(
        _endLngMeta,
        endLng.isAcceptableOrUnknown(data['end_lng']!, _endLngMeta),
      );
    }
    if (data.containsKey('ended_utc')) {
      context.handle(
        _endedUtcMeta,
        endedUtc.isAcceptableOrUnknown(data['ended_utc']!, _endedUtcMeta),
      );
    }
    if (data.containsKey('visit_no')) {
      context.handle(
        _visitNoMeta,
        visitNo.isAcceptableOrUnknown(data['visit_no']!, _visitNoMeta),
      );
    }
    if (data.containsKey('arrival_shown')) {
      context.handle(
        _arrivalShownMeta,
        arrivalShown.isAcceptableOrUnknown(
          data['arrival_shown']!,
          _arrivalShownMeta,
        ),
      );
    }
    if (data.containsKey('dest_lat')) {
      context.handle(
        _destLatMeta,
        destLat.isAcceptableOrUnknown(data['dest_lat']!, _destLatMeta),
      );
    }
    if (data.containsKey('dest_lng')) {
      context.handle(
        _destLngMeta,
        destLng.isAcceptableOrUnknown(data['dest_lng']!, _destLngMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JourneyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JourneyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      originLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}origin_lat'],
      )!,
      originLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}origin_lng'],
      )!,
      destId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dest_id'],
      )!,
      startUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_utc'],
      )!,
      fundKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fund_km'],
      )!,
      totalEffectiveKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_effective_km'],
      )!,
      status: $JourneysTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      arrivedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}arrived_utc'],
      ),
      endLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}end_lat'],
      ),
      endLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}end_lng'],
      ),
      endedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_utc'],
      ),
      visitNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}visit_no'],
      ),
      prevFrame: $JourneysTable.$converterprevFramen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}prev_frame'],
        ),
      ),
      newFrame: $JourneysTable.$converternewFramen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}new_frame'],
        ),
      ),
      arrivalShown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}arrival_shown'],
      )!,
      destLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dest_lat'],
      ),
      destLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dest_lng'],
      ),
    );
  }

  @override
  $JourneysTable createAlias(String alias) {
    return $JourneysTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<JourneyStatus, String, String> $converterstatus =
      const EnumNameConverter<JourneyStatus>(JourneyStatus.values);
  static JsonTypeConverter2<Frame, String, String> $converterprevFrame =
      const EnumNameConverter<Frame>(Frame.values);
  static JsonTypeConverter2<Frame?, String?, String?> $converterprevFramen =
      JsonTypeConverter2.asNullable($converterprevFrame);
  static JsonTypeConverter2<Frame, String, String> $converternewFrame =
      const EnumNameConverter<Frame>(Frame.values);
  static JsonTypeConverter2<Frame?, String?, String?> $converternewFramen =
      JsonTypeConverter2.asNullable($converternewFrame);
}

class JourneyRow extends DataClass implements Insertable<JourneyRow> {
  final String id;
  final double originLat;
  final double originLng;
  final String destId;
  final int startUtc;
  final double fundKm;
  final double totalEffectiveKm;
  final JourneyStatus status;
  final int? arrivedUtc;

  /// 여정이 끝난 곳: 도착이면 목적지, 멈춤이면 멈춘 지점. 진행 중이면 null
  final double? endLat;
  final double? endLng;

  /// 멈춘 시각 (도착은 arrivedUtc)
  final int? endedUtc;

  /// 도착 화면에 쓸 값 (도착한 여정만): 몇 번째 방문, 도착 전·후 액자
  final int? visitNo;
  final Frame? prevFrame;
  final Frame? newFrame;

  /// 도착 화면을 보여 줬는지. 앱 밖에서 도착하면 다음 실행 때 먼저 보여 준다
  final bool arrivalShown;

  /// 가상 목적지의 좌표 (destId가 'sketch'인 첫 여정만). 명소 여정은 null
  final double? destLat;
  final double? destLng;
  const JourneyRow({
    required this.id,
    required this.originLat,
    required this.originLng,
    required this.destId,
    required this.startUtc,
    required this.fundKm,
    required this.totalEffectiveKm,
    required this.status,
    this.arrivedUtc,
    this.endLat,
    this.endLng,
    this.endedUtc,
    this.visitNo,
    this.prevFrame,
    this.newFrame,
    required this.arrivalShown,
    this.destLat,
    this.destLng,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['origin_lat'] = Variable<double>(originLat);
    map['origin_lng'] = Variable<double>(originLng);
    map['dest_id'] = Variable<String>(destId);
    map['start_utc'] = Variable<int>(startUtc);
    map['fund_km'] = Variable<double>(fundKm);
    map['total_effective_km'] = Variable<double>(totalEffectiveKm);
    {
      map['status'] = Variable<String>(
        $JourneysTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || arrivedUtc != null) {
      map['arrived_utc'] = Variable<int>(arrivedUtc);
    }
    if (!nullToAbsent || endLat != null) {
      map['end_lat'] = Variable<double>(endLat);
    }
    if (!nullToAbsent || endLng != null) {
      map['end_lng'] = Variable<double>(endLng);
    }
    if (!nullToAbsent || endedUtc != null) {
      map['ended_utc'] = Variable<int>(endedUtc);
    }
    if (!nullToAbsent || visitNo != null) {
      map['visit_no'] = Variable<int>(visitNo);
    }
    if (!nullToAbsent || prevFrame != null) {
      map['prev_frame'] = Variable<String>(
        $JourneysTable.$converterprevFramen.toSql(prevFrame),
      );
    }
    if (!nullToAbsent || newFrame != null) {
      map['new_frame'] = Variable<String>(
        $JourneysTable.$converternewFramen.toSql(newFrame),
      );
    }
    map['arrival_shown'] = Variable<bool>(arrivalShown);
    if (!nullToAbsent || destLat != null) {
      map['dest_lat'] = Variable<double>(destLat);
    }
    if (!nullToAbsent || destLng != null) {
      map['dest_lng'] = Variable<double>(destLng);
    }
    return map;
  }

  JourneysCompanion toCompanion(bool nullToAbsent) {
    return JourneysCompanion(
      id: Value(id),
      originLat: Value(originLat),
      originLng: Value(originLng),
      destId: Value(destId),
      startUtc: Value(startUtc),
      fundKm: Value(fundKm),
      totalEffectiveKm: Value(totalEffectiveKm),
      status: Value(status),
      arrivedUtc: arrivedUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(arrivedUtc),
      endLat: endLat == null && nullToAbsent
          ? const Value.absent()
          : Value(endLat),
      endLng: endLng == null && nullToAbsent
          ? const Value.absent()
          : Value(endLng),
      endedUtc: endedUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(endedUtc),
      visitNo: visitNo == null && nullToAbsent
          ? const Value.absent()
          : Value(visitNo),
      prevFrame: prevFrame == null && nullToAbsent
          ? const Value.absent()
          : Value(prevFrame),
      newFrame: newFrame == null && nullToAbsent
          ? const Value.absent()
          : Value(newFrame),
      arrivalShown: Value(arrivalShown),
      destLat: destLat == null && nullToAbsent
          ? const Value.absent()
          : Value(destLat),
      destLng: destLng == null && nullToAbsent
          ? const Value.absent()
          : Value(destLng),
    );
  }

  factory JourneyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JourneyRow(
      id: serializer.fromJson<String>(json['id']),
      originLat: serializer.fromJson<double>(json['originLat']),
      originLng: serializer.fromJson<double>(json['originLng']),
      destId: serializer.fromJson<String>(json['destId']),
      startUtc: serializer.fromJson<int>(json['startUtc']),
      fundKm: serializer.fromJson<double>(json['fundKm']),
      totalEffectiveKm: serializer.fromJson<double>(json['totalEffectiveKm']),
      status: $JourneysTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      arrivedUtc: serializer.fromJson<int?>(json['arrivedUtc']),
      endLat: serializer.fromJson<double?>(json['endLat']),
      endLng: serializer.fromJson<double?>(json['endLng']),
      endedUtc: serializer.fromJson<int?>(json['endedUtc']),
      visitNo: serializer.fromJson<int?>(json['visitNo']),
      prevFrame: $JourneysTable.$converterprevFramen.fromJson(
        serializer.fromJson<String?>(json['prevFrame']),
      ),
      newFrame: $JourneysTable.$converternewFramen.fromJson(
        serializer.fromJson<String?>(json['newFrame']),
      ),
      arrivalShown: serializer.fromJson<bool>(json['arrivalShown']),
      destLat: serializer.fromJson<double?>(json['destLat']),
      destLng: serializer.fromJson<double?>(json['destLng']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'originLat': serializer.toJson<double>(originLat),
      'originLng': serializer.toJson<double>(originLng),
      'destId': serializer.toJson<String>(destId),
      'startUtc': serializer.toJson<int>(startUtc),
      'fundKm': serializer.toJson<double>(fundKm),
      'totalEffectiveKm': serializer.toJson<double>(totalEffectiveKm),
      'status': serializer.toJson<String>(
        $JourneysTable.$converterstatus.toJson(status),
      ),
      'arrivedUtc': serializer.toJson<int?>(arrivedUtc),
      'endLat': serializer.toJson<double?>(endLat),
      'endLng': serializer.toJson<double?>(endLng),
      'endedUtc': serializer.toJson<int?>(endedUtc),
      'visitNo': serializer.toJson<int?>(visitNo),
      'prevFrame': serializer.toJson<String?>(
        $JourneysTable.$converterprevFramen.toJson(prevFrame),
      ),
      'newFrame': serializer.toJson<String?>(
        $JourneysTable.$converternewFramen.toJson(newFrame),
      ),
      'arrivalShown': serializer.toJson<bool>(arrivalShown),
      'destLat': serializer.toJson<double?>(destLat),
      'destLng': serializer.toJson<double?>(destLng),
    };
  }

  JourneyRow copyWith({
    String? id,
    double? originLat,
    double? originLng,
    String? destId,
    int? startUtc,
    double? fundKm,
    double? totalEffectiveKm,
    JourneyStatus? status,
    Value<int?> arrivedUtc = const Value.absent(),
    Value<double?> endLat = const Value.absent(),
    Value<double?> endLng = const Value.absent(),
    Value<int?> endedUtc = const Value.absent(),
    Value<int?> visitNo = const Value.absent(),
    Value<Frame?> prevFrame = const Value.absent(),
    Value<Frame?> newFrame = const Value.absent(),
    bool? arrivalShown,
    Value<double?> destLat = const Value.absent(),
    Value<double?> destLng = const Value.absent(),
  }) => JourneyRow(
    id: id ?? this.id,
    originLat: originLat ?? this.originLat,
    originLng: originLng ?? this.originLng,
    destId: destId ?? this.destId,
    startUtc: startUtc ?? this.startUtc,
    fundKm: fundKm ?? this.fundKm,
    totalEffectiveKm: totalEffectiveKm ?? this.totalEffectiveKm,
    status: status ?? this.status,
    arrivedUtc: arrivedUtc.present ? arrivedUtc.value : this.arrivedUtc,
    endLat: endLat.present ? endLat.value : this.endLat,
    endLng: endLng.present ? endLng.value : this.endLng,
    endedUtc: endedUtc.present ? endedUtc.value : this.endedUtc,
    visitNo: visitNo.present ? visitNo.value : this.visitNo,
    prevFrame: prevFrame.present ? prevFrame.value : this.prevFrame,
    newFrame: newFrame.present ? newFrame.value : this.newFrame,
    arrivalShown: arrivalShown ?? this.arrivalShown,
    destLat: destLat.present ? destLat.value : this.destLat,
    destLng: destLng.present ? destLng.value : this.destLng,
  );
  JourneyRow copyWithCompanion(JourneysCompanion data) {
    return JourneyRow(
      id: data.id.present ? data.id.value : this.id,
      originLat: data.originLat.present ? data.originLat.value : this.originLat,
      originLng: data.originLng.present ? data.originLng.value : this.originLng,
      destId: data.destId.present ? data.destId.value : this.destId,
      startUtc: data.startUtc.present ? data.startUtc.value : this.startUtc,
      fundKm: data.fundKm.present ? data.fundKm.value : this.fundKm,
      totalEffectiveKm: data.totalEffectiveKm.present
          ? data.totalEffectiveKm.value
          : this.totalEffectiveKm,
      status: data.status.present ? data.status.value : this.status,
      arrivedUtc: data.arrivedUtc.present
          ? data.arrivedUtc.value
          : this.arrivedUtc,
      endLat: data.endLat.present ? data.endLat.value : this.endLat,
      endLng: data.endLng.present ? data.endLng.value : this.endLng,
      endedUtc: data.endedUtc.present ? data.endedUtc.value : this.endedUtc,
      visitNo: data.visitNo.present ? data.visitNo.value : this.visitNo,
      prevFrame: data.prevFrame.present ? data.prevFrame.value : this.prevFrame,
      newFrame: data.newFrame.present ? data.newFrame.value : this.newFrame,
      arrivalShown: data.arrivalShown.present
          ? data.arrivalShown.value
          : this.arrivalShown,
      destLat: data.destLat.present ? data.destLat.value : this.destLat,
      destLng: data.destLng.present ? data.destLng.value : this.destLng,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JourneyRow(')
          ..write('id: $id, ')
          ..write('originLat: $originLat, ')
          ..write('originLng: $originLng, ')
          ..write('destId: $destId, ')
          ..write('startUtc: $startUtc, ')
          ..write('fundKm: $fundKm, ')
          ..write('totalEffectiveKm: $totalEffectiveKm, ')
          ..write('status: $status, ')
          ..write('arrivedUtc: $arrivedUtc, ')
          ..write('endLat: $endLat, ')
          ..write('endLng: $endLng, ')
          ..write('endedUtc: $endedUtc, ')
          ..write('visitNo: $visitNo, ')
          ..write('prevFrame: $prevFrame, ')
          ..write('newFrame: $newFrame, ')
          ..write('arrivalShown: $arrivalShown, ')
          ..write('destLat: $destLat, ')
          ..write('destLng: $destLng')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    originLat,
    originLng,
    destId,
    startUtc,
    fundKm,
    totalEffectiveKm,
    status,
    arrivedUtc,
    endLat,
    endLng,
    endedUtc,
    visitNo,
    prevFrame,
    newFrame,
    arrivalShown,
    destLat,
    destLng,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JourneyRow &&
          other.id == this.id &&
          other.originLat == this.originLat &&
          other.originLng == this.originLng &&
          other.destId == this.destId &&
          other.startUtc == this.startUtc &&
          other.fundKm == this.fundKm &&
          other.totalEffectiveKm == this.totalEffectiveKm &&
          other.status == this.status &&
          other.arrivedUtc == this.arrivedUtc &&
          other.endLat == this.endLat &&
          other.endLng == this.endLng &&
          other.endedUtc == this.endedUtc &&
          other.visitNo == this.visitNo &&
          other.prevFrame == this.prevFrame &&
          other.newFrame == this.newFrame &&
          other.arrivalShown == this.arrivalShown &&
          other.destLat == this.destLat &&
          other.destLng == this.destLng);
}

class JourneysCompanion extends UpdateCompanion<JourneyRow> {
  final Value<String> id;
  final Value<double> originLat;
  final Value<double> originLng;
  final Value<String> destId;
  final Value<int> startUtc;
  final Value<double> fundKm;
  final Value<double> totalEffectiveKm;
  final Value<JourneyStatus> status;
  final Value<int?> arrivedUtc;
  final Value<double?> endLat;
  final Value<double?> endLng;
  final Value<int?> endedUtc;
  final Value<int?> visitNo;
  final Value<Frame?> prevFrame;
  final Value<Frame?> newFrame;
  final Value<bool> arrivalShown;
  final Value<double?> destLat;
  final Value<double?> destLng;
  final Value<int> rowid;
  const JourneysCompanion({
    this.id = const Value.absent(),
    this.originLat = const Value.absent(),
    this.originLng = const Value.absent(),
    this.destId = const Value.absent(),
    this.startUtc = const Value.absent(),
    this.fundKm = const Value.absent(),
    this.totalEffectiveKm = const Value.absent(),
    this.status = const Value.absent(),
    this.arrivedUtc = const Value.absent(),
    this.endLat = const Value.absent(),
    this.endLng = const Value.absent(),
    this.endedUtc = const Value.absent(),
    this.visitNo = const Value.absent(),
    this.prevFrame = const Value.absent(),
    this.newFrame = const Value.absent(),
    this.arrivalShown = const Value.absent(),
    this.destLat = const Value.absent(),
    this.destLng = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JourneysCompanion.insert({
    required String id,
    required double originLat,
    required double originLng,
    required String destId,
    required int startUtc,
    required double fundKm,
    required double totalEffectiveKm,
    required JourneyStatus status,
    this.arrivedUtc = const Value.absent(),
    this.endLat = const Value.absent(),
    this.endLng = const Value.absent(),
    this.endedUtc = const Value.absent(),
    this.visitNo = const Value.absent(),
    this.prevFrame = const Value.absent(),
    this.newFrame = const Value.absent(),
    this.arrivalShown = const Value.absent(),
    this.destLat = const Value.absent(),
    this.destLng = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       originLat = Value(originLat),
       originLng = Value(originLng),
       destId = Value(destId),
       startUtc = Value(startUtc),
       fundKm = Value(fundKm),
       totalEffectiveKm = Value(totalEffectiveKm),
       status = Value(status);
  static Insertable<JourneyRow> custom({
    Expression<String>? id,
    Expression<double>? originLat,
    Expression<double>? originLng,
    Expression<String>? destId,
    Expression<int>? startUtc,
    Expression<double>? fundKm,
    Expression<double>? totalEffectiveKm,
    Expression<String>? status,
    Expression<int>? arrivedUtc,
    Expression<double>? endLat,
    Expression<double>? endLng,
    Expression<int>? endedUtc,
    Expression<int>? visitNo,
    Expression<String>? prevFrame,
    Expression<String>? newFrame,
    Expression<bool>? arrivalShown,
    Expression<double>? destLat,
    Expression<double>? destLng,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (originLat != null) 'origin_lat': originLat,
      if (originLng != null) 'origin_lng': originLng,
      if (destId != null) 'dest_id': destId,
      if (startUtc != null) 'start_utc': startUtc,
      if (fundKm != null) 'fund_km': fundKm,
      if (totalEffectiveKm != null) 'total_effective_km': totalEffectiveKm,
      if (status != null) 'status': status,
      if (arrivedUtc != null) 'arrived_utc': arrivedUtc,
      if (endLat != null) 'end_lat': endLat,
      if (endLng != null) 'end_lng': endLng,
      if (endedUtc != null) 'ended_utc': endedUtc,
      if (visitNo != null) 'visit_no': visitNo,
      if (prevFrame != null) 'prev_frame': prevFrame,
      if (newFrame != null) 'new_frame': newFrame,
      if (arrivalShown != null) 'arrival_shown': arrivalShown,
      if (destLat != null) 'dest_lat': destLat,
      if (destLng != null) 'dest_lng': destLng,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JourneysCompanion copyWith({
    Value<String>? id,
    Value<double>? originLat,
    Value<double>? originLng,
    Value<String>? destId,
    Value<int>? startUtc,
    Value<double>? fundKm,
    Value<double>? totalEffectiveKm,
    Value<JourneyStatus>? status,
    Value<int?>? arrivedUtc,
    Value<double?>? endLat,
    Value<double?>? endLng,
    Value<int?>? endedUtc,
    Value<int?>? visitNo,
    Value<Frame?>? prevFrame,
    Value<Frame?>? newFrame,
    Value<bool>? arrivalShown,
    Value<double?>? destLat,
    Value<double?>? destLng,
    Value<int>? rowid,
  }) {
    return JourneysCompanion(
      id: id ?? this.id,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      destId: destId ?? this.destId,
      startUtc: startUtc ?? this.startUtc,
      fundKm: fundKm ?? this.fundKm,
      totalEffectiveKm: totalEffectiveKm ?? this.totalEffectiveKm,
      status: status ?? this.status,
      arrivedUtc: arrivedUtc ?? this.arrivedUtc,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      endedUtc: endedUtc ?? this.endedUtc,
      visitNo: visitNo ?? this.visitNo,
      prevFrame: prevFrame ?? this.prevFrame,
      newFrame: newFrame ?? this.newFrame,
      arrivalShown: arrivalShown ?? this.arrivalShown,
      destLat: destLat ?? this.destLat,
      destLng: destLng ?? this.destLng,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (originLat.present) {
      map['origin_lat'] = Variable<double>(originLat.value);
    }
    if (originLng.present) {
      map['origin_lng'] = Variable<double>(originLng.value);
    }
    if (destId.present) {
      map['dest_id'] = Variable<String>(destId.value);
    }
    if (startUtc.present) {
      map['start_utc'] = Variable<int>(startUtc.value);
    }
    if (fundKm.present) {
      map['fund_km'] = Variable<double>(fundKm.value);
    }
    if (totalEffectiveKm.present) {
      map['total_effective_km'] = Variable<double>(totalEffectiveKm.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $JourneysTable.$converterstatus.toSql(status.value),
      );
    }
    if (arrivedUtc.present) {
      map['arrived_utc'] = Variable<int>(arrivedUtc.value);
    }
    if (endLat.present) {
      map['end_lat'] = Variable<double>(endLat.value);
    }
    if (endLng.present) {
      map['end_lng'] = Variable<double>(endLng.value);
    }
    if (endedUtc.present) {
      map['ended_utc'] = Variable<int>(endedUtc.value);
    }
    if (visitNo.present) {
      map['visit_no'] = Variable<int>(visitNo.value);
    }
    if (prevFrame.present) {
      map['prev_frame'] = Variable<String>(
        $JourneysTable.$converterprevFramen.toSql(prevFrame.value),
      );
    }
    if (newFrame.present) {
      map['new_frame'] = Variable<String>(
        $JourneysTable.$converternewFramen.toSql(newFrame.value),
      );
    }
    if (arrivalShown.present) {
      map['arrival_shown'] = Variable<bool>(arrivalShown.value);
    }
    if (destLat.present) {
      map['dest_lat'] = Variable<double>(destLat.value);
    }
    if (destLng.present) {
      map['dest_lng'] = Variable<double>(destLng.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JourneysCompanion(')
          ..write('id: $id, ')
          ..write('originLat: $originLat, ')
          ..write('originLng: $originLng, ')
          ..write('destId: $destId, ')
          ..write('startUtc: $startUtc, ')
          ..write('fundKm: $fundKm, ')
          ..write('totalEffectiveKm: $totalEffectiveKm, ')
          ..write('status: $status, ')
          ..write('arrivedUtc: $arrivedUtc, ')
          ..write('endLat: $endLat, ')
          ..write('endLng: $endLng, ')
          ..write('endedUtc: $endedUtc, ')
          ..write('visitNo: $visitNo, ')
          ..write('prevFrame: $prevFrame, ')
          ..write('newFrame: $newFrame, ')
          ..write('arrivalShown: $arrivalShown, ')
          ..write('destLat: $destLat, ')
          ..write('destLng: $destLng, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TravelFundTable extends TravelFund
    with TableInfo<$TravelFundTable, TravelFundRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TravelFundTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kmMeta = const VerificationMeta('km');
  @override
  late final GeneratedColumn<double> km = GeneratedColumn<double>(
    'km',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fundedUntilUtcMeta = const VerificationMeta(
    'fundedUntilUtc',
  );
  @override
  late final GeneratedColumn<int> fundedUntilUtc = GeneratedColumn<int>(
    'funded_until_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, km, fundedUntilUtc];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'travel_fund';
  @override
  VerificationContext validateIntegrity(
    Insertable<TravelFundRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('km')) {
      context.handle(_kmMeta, km.isAcceptableOrUnknown(data['km']!, _kmMeta));
    } else if (isInserting) {
      context.missing(_kmMeta);
    }
    if (data.containsKey('funded_until_utc')) {
      context.handle(
        _fundedUntilUtcMeta,
        fundedUntilUtc.isAcceptableOrUnknown(
          data['funded_until_utc']!,
          _fundedUntilUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fundedUntilUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TravelFundRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TravelFundRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      km: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}km'],
      )!,
      fundedUntilUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}funded_until_utc'],
      )!,
    );
  }

  @override
  $TravelFundTable createAlias(String alias) {
    return $TravelFundTable(attachedDatabase, alias);
  }
}

class TravelFundRow extends DataClass implements Insertable<TravelFundRow> {
  final int id;
  final double km;
  final int fundedUntilUtc;
  const TravelFundRow({
    required this.id,
    required this.km,
    required this.fundedUntilUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['km'] = Variable<double>(km);
    map['funded_until_utc'] = Variable<int>(fundedUntilUtc);
    return map;
  }

  TravelFundCompanion toCompanion(bool nullToAbsent) {
    return TravelFundCompanion(
      id: Value(id),
      km: Value(km),
      fundedUntilUtc: Value(fundedUntilUtc),
    );
  }

  factory TravelFundRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TravelFundRow(
      id: serializer.fromJson<int>(json['id']),
      km: serializer.fromJson<double>(json['km']),
      fundedUntilUtc: serializer.fromJson<int>(json['fundedUntilUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'km': serializer.toJson<double>(km),
      'fundedUntilUtc': serializer.toJson<int>(fundedUntilUtc),
    };
  }

  TravelFundRow copyWith({int? id, double? km, int? fundedUntilUtc}) =>
      TravelFundRow(
        id: id ?? this.id,
        km: km ?? this.km,
        fundedUntilUtc: fundedUntilUtc ?? this.fundedUntilUtc,
      );
  TravelFundRow copyWithCompanion(TravelFundCompanion data) {
    return TravelFundRow(
      id: data.id.present ? data.id.value : this.id,
      km: data.km.present ? data.km.value : this.km,
      fundedUntilUtc: data.fundedUntilUtc.present
          ? data.fundedUntilUtc.value
          : this.fundedUntilUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TravelFundRow(')
          ..write('id: $id, ')
          ..write('km: $km, ')
          ..write('fundedUntilUtc: $fundedUntilUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, km, fundedUntilUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TravelFundRow &&
          other.id == this.id &&
          other.km == this.km &&
          other.fundedUntilUtc == this.fundedUntilUtc);
}

class TravelFundCompanion extends UpdateCompanion<TravelFundRow> {
  final Value<int> id;
  final Value<double> km;
  final Value<int> fundedUntilUtc;
  const TravelFundCompanion({
    this.id = const Value.absent(),
    this.km = const Value.absent(),
    this.fundedUntilUtc = const Value.absent(),
  });
  TravelFundCompanion.insert({
    this.id = const Value.absent(),
    required double km,
    required int fundedUntilUtc,
  }) : km = Value(km),
       fundedUntilUtc = Value(fundedUntilUtc);
  static Insertable<TravelFundRow> custom({
    Expression<int>? id,
    Expression<double>? km,
    Expression<int>? fundedUntilUtc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (km != null) 'km': km,
      if (fundedUntilUtc != null) 'funded_until_utc': fundedUntilUtc,
    });
  }

  TravelFundCompanion copyWith({
    Value<int>? id,
    Value<double>? km,
    Value<int>? fundedUntilUtc,
  }) {
    return TravelFundCompanion(
      id: id ?? this.id,
      km: km ?? this.km,
      fundedUntilUtc: fundedUntilUtc ?? this.fundedUntilUtc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (km.present) {
      map['km'] = Variable<double>(km.value);
    }
    if (fundedUntilUtc.present) {
      map['funded_until_utc'] = Variable<int>(fundedUntilUtc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TravelFundCompanion(')
          ..write('id: $id, ')
          ..write('km: $km, ')
          ..write('fundedUntilUtc: $fundedUntilUtc')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastFetchedUtcMeta = const VerificationMeta(
    'lastFetchedUtc',
  );
  @override
  late final GeneratedColumn<int> lastFetchedUtc = GeneratedColumn<int>(
    'last_fetched_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstRecordDayMeta = const VerificationMeta(
    'firstRecordDay',
  );
  @override
  late final GeneratedColumn<String> firstRecordDay = GeneratedColumn<String>(
    'first_record_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _installUtcMeta = const VerificationMeta(
    'installUtc',
  );
  @override
  late final GeneratedColumn<int> installUtc = GeneratedColumn<int>(
    'install_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restoreFloorDayMeta = const VerificationMeta(
    'restoreFloorDay',
  );
  @override
  late final GeneratedColumn<String> restoreFloorDay = GeneratedColumn<String>(
    'restore_floor_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lastFetchedUtc,
    firstRecordDay,
    installUtc,
    restoreFloorDay,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('last_fetched_utc')) {
      context.handle(
        _lastFetchedUtcMeta,
        lastFetchedUtc.isAcceptableOrUnknown(
          data['last_fetched_utc']!,
          _lastFetchedUtcMeta,
        ),
      );
    }
    if (data.containsKey('first_record_day')) {
      context.handle(
        _firstRecordDayMeta,
        firstRecordDay.isAcceptableOrUnknown(
          data['first_record_day']!,
          _firstRecordDayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstRecordDayMeta);
    }
    if (data.containsKey('install_utc')) {
      context.handle(
        _installUtcMeta,
        installUtc.isAcceptableOrUnknown(data['install_utc']!, _installUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_installUtcMeta);
    }
    if (data.containsKey('restore_floor_day')) {
      context.handle(
        _restoreFloorDayMeta,
        restoreFloorDay.isAcceptableOrUnknown(
          data['restore_floor_day']!,
          _restoreFloorDayMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lastFetchedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_fetched_utc'],
      ),
      firstRecordDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_record_day'],
      )!,
      installUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}install_utc'],
      )!,
      restoreFloorDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}restore_floor_day'],
      ),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final int id;
  final int? lastFetchedUtc;
  final String firstRecordDay;
  final int installUtc;

  /// 백업을 복원한 기기에서, 복원한 하루 요약의 마지막 날 (한국 날짜 키 'YYYY-MM-DD').
  /// 이 날까지의 하루 요약은 건강 앱에서 다시 계산한 값이 복원값보다 작으면 복원값을 지킨다
  /// (새 기기의 건강 앱에는 그 기록이 없을 수 있다). 복원한 적이 없으면 null.
  /// 이 기기에만 두는 값이라 백업에 넣지 않는다
  final String? restoreFloorDay;
  const SyncStateRow({
    required this.id,
    this.lastFetchedUtc,
    required this.firstRecordDay,
    required this.installUtc,
    this.restoreFloorDay,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || lastFetchedUtc != null) {
      map['last_fetched_utc'] = Variable<int>(lastFetchedUtc);
    }
    map['first_record_day'] = Variable<String>(firstRecordDay);
    map['install_utc'] = Variable<int>(installUtc);
    if (!nullToAbsent || restoreFloorDay != null) {
      map['restore_floor_day'] = Variable<String>(restoreFloorDay);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      id: Value(id),
      lastFetchedUtc: lastFetchedUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFetchedUtc),
      firstRecordDay: Value(firstRecordDay),
      installUtc: Value(installUtc),
      restoreFloorDay: restoreFloorDay == null && nullToAbsent
          ? const Value.absent()
          : Value(restoreFloorDay),
    );
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      id: serializer.fromJson<int>(json['id']),
      lastFetchedUtc: serializer.fromJson<int?>(json['lastFetchedUtc']),
      firstRecordDay: serializer.fromJson<String>(json['firstRecordDay']),
      installUtc: serializer.fromJson<int>(json['installUtc']),
      restoreFloorDay: serializer.fromJson<String?>(json['restoreFloorDay']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lastFetchedUtc': serializer.toJson<int?>(lastFetchedUtc),
      'firstRecordDay': serializer.toJson<String>(firstRecordDay),
      'installUtc': serializer.toJson<int>(installUtc),
      'restoreFloorDay': serializer.toJson<String?>(restoreFloorDay),
    };
  }

  SyncStateRow copyWith({
    int? id,
    Value<int?> lastFetchedUtc = const Value.absent(),
    String? firstRecordDay,
    int? installUtc,
    Value<String?> restoreFloorDay = const Value.absent(),
  }) => SyncStateRow(
    id: id ?? this.id,
    lastFetchedUtc: lastFetchedUtc.present
        ? lastFetchedUtc.value
        : this.lastFetchedUtc,
    firstRecordDay: firstRecordDay ?? this.firstRecordDay,
    installUtc: installUtc ?? this.installUtc,
    restoreFloorDay: restoreFloorDay.present
        ? restoreFloorDay.value
        : this.restoreFloorDay,
  );
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      id: data.id.present ? data.id.value : this.id,
      lastFetchedUtc: data.lastFetchedUtc.present
          ? data.lastFetchedUtc.value
          : this.lastFetchedUtc,
      firstRecordDay: data.firstRecordDay.present
          ? data.firstRecordDay.value
          : this.firstRecordDay,
      installUtc: data.installUtc.present
          ? data.installUtc.value
          : this.installUtc,
      restoreFloorDay: data.restoreFloorDay.present
          ? data.restoreFloorDay.value
          : this.restoreFloorDay,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('id: $id, ')
          ..write('lastFetchedUtc: $lastFetchedUtc, ')
          ..write('firstRecordDay: $firstRecordDay, ')
          ..write('installUtc: $installUtc, ')
          ..write('restoreFloorDay: $restoreFloorDay')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lastFetchedUtc,
    firstRecordDay,
    installUtc,
    restoreFloorDay,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.id == this.id &&
          other.lastFetchedUtc == this.lastFetchedUtc &&
          other.firstRecordDay == this.firstRecordDay &&
          other.installUtc == this.installUtc &&
          other.restoreFloorDay == this.restoreFloorDay);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<int> id;
  final Value<int?> lastFetchedUtc;
  final Value<String> firstRecordDay;
  final Value<int> installUtc;
  final Value<String?> restoreFloorDay;
  const SyncStateCompanion({
    this.id = const Value.absent(),
    this.lastFetchedUtc = const Value.absent(),
    this.firstRecordDay = const Value.absent(),
    this.installUtc = const Value.absent(),
    this.restoreFloorDay = const Value.absent(),
  });
  SyncStateCompanion.insert({
    this.id = const Value.absent(),
    this.lastFetchedUtc = const Value.absent(),
    required String firstRecordDay,
    required int installUtc,
    this.restoreFloorDay = const Value.absent(),
  }) : firstRecordDay = Value(firstRecordDay),
       installUtc = Value(installUtc);
  static Insertable<SyncStateRow> custom({
    Expression<int>? id,
    Expression<int>? lastFetchedUtc,
    Expression<String>? firstRecordDay,
    Expression<int>? installUtc,
    Expression<String>? restoreFloorDay,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lastFetchedUtc != null) 'last_fetched_utc': lastFetchedUtc,
      if (firstRecordDay != null) 'first_record_day': firstRecordDay,
      if (installUtc != null) 'install_utc': installUtc,
      if (restoreFloorDay != null) 'restore_floor_day': restoreFloorDay,
    });
  }

  SyncStateCompanion copyWith({
    Value<int>? id,
    Value<int?>? lastFetchedUtc,
    Value<String>? firstRecordDay,
    Value<int>? installUtc,
    Value<String?>? restoreFloorDay,
  }) {
    return SyncStateCompanion(
      id: id ?? this.id,
      lastFetchedUtc: lastFetchedUtc ?? this.lastFetchedUtc,
      firstRecordDay: firstRecordDay ?? this.firstRecordDay,
      installUtc: installUtc ?? this.installUtc,
      restoreFloorDay: restoreFloorDay ?? this.restoreFloorDay,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lastFetchedUtc.present) {
      map['last_fetched_utc'] = Variable<int>(lastFetchedUtc.value);
    }
    if (firstRecordDay.present) {
      map['first_record_day'] = Variable<String>(firstRecordDay.value);
    }
    if (installUtc.present) {
      map['install_utc'] = Variable<int>(installUtc.value);
    }
    if (restoreFloorDay.present) {
      map['restore_floor_day'] = Variable<String>(restoreFloorDay.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('id: $id, ')
          ..write('lastFetchedUtc: $lastFetchedUtc, ')
          ..write('firstRecordDay: $firstRecordDay, ')
          ..write('installUtc: $installUtc, ')
          ..write('restoreFloorDay: $restoreFloorDay')
          ..write(')'))
        .toString();
  }
}

class $PaintingsOwnedTable extends PaintingsOwned
    with TableInfo<$PaintingsOwnedTable, PaintingOwnedRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaintingsOwnedTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _landmarkIdMeta = const VerificationMeta(
    'landmarkId',
  );
  @override
  late final GeneratedColumn<String> landmarkId = GeneratedColumn<String>(
    'landmark_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visitsMeta = const VerificationMeta('visits');
  @override
  late final GeneratedColumn<int> visits = GeneratedColumn<int>(
    'visits',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Frame, String> frame =
      GeneratedColumn<String>(
        'frame',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Frame>($PaintingsOwnedTable.$converterframe);
  static const VerificationMeta _bestKmMeta = const VerificationMeta('bestKm');
  @override
  late final GeneratedColumn<double> bestKm = GeneratedColumn<double>(
    'best_km',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstArrivedUtcMeta = const VerificationMeta(
    'firstArrivedUtc',
  );
  @override
  late final GeneratedColumn<int> firstArrivedUtc = GeneratedColumn<int>(
    'first_arrived_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastArrivedUtcMeta = const VerificationMeta(
    'lastArrivedUtc',
  );
  @override
  late final GeneratedColumn<int> lastArrivedUtc = GeneratedColumn<int>(
    'last_arrived_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seenMeta = const VerificationMeta('seen');
  @override
  late final GeneratedColumn<bool> seen = GeneratedColumn<bool>(
    'seen',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("seen" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    landmarkId,
    visits,
    frame,
    bestKm,
    firstArrivedUtc,
    lastArrivedUtc,
    seen,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'paintings_owned';
  @override
  VerificationContext validateIntegrity(
    Insertable<PaintingOwnedRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('landmark_id')) {
      context.handle(
        _landmarkIdMeta,
        landmarkId.isAcceptableOrUnknown(data['landmark_id']!, _landmarkIdMeta),
      );
    } else if (isInserting) {
      context.missing(_landmarkIdMeta);
    }
    if (data.containsKey('visits')) {
      context.handle(
        _visitsMeta,
        visits.isAcceptableOrUnknown(data['visits']!, _visitsMeta),
      );
    } else if (isInserting) {
      context.missing(_visitsMeta);
    }
    if (data.containsKey('best_km')) {
      context.handle(
        _bestKmMeta,
        bestKm.isAcceptableOrUnknown(data['best_km']!, _bestKmMeta),
      );
    } else if (isInserting) {
      context.missing(_bestKmMeta);
    }
    if (data.containsKey('first_arrived_utc')) {
      context.handle(
        _firstArrivedUtcMeta,
        firstArrivedUtc.isAcceptableOrUnknown(
          data['first_arrived_utc']!,
          _firstArrivedUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstArrivedUtcMeta);
    }
    if (data.containsKey('last_arrived_utc')) {
      context.handle(
        _lastArrivedUtcMeta,
        lastArrivedUtc.isAcceptableOrUnknown(
          data['last_arrived_utc']!,
          _lastArrivedUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastArrivedUtcMeta);
    }
    if (data.containsKey('seen')) {
      context.handle(
        _seenMeta,
        seen.isAcceptableOrUnknown(data['seen']!, _seenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {landmarkId};
  @override
  PaintingOwnedRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaintingOwnedRow(
      landmarkId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}landmark_id'],
      )!,
      visits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}visits'],
      )!,
      frame: $PaintingsOwnedTable.$converterframe.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}frame'],
        )!,
      ),
      bestKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}best_km'],
      )!,
      firstArrivedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_arrived_utc'],
      )!,
      lastArrivedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_arrived_utc'],
      )!,
      seen: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}seen'],
      )!,
    );
  }

  @override
  $PaintingsOwnedTable createAlias(String alias) {
    return $PaintingsOwnedTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Frame, String, String> $converterframe =
      const EnumNameConverter<Frame>(Frame.values);
}

class PaintingOwnedRow extends DataClass
    implements Insertable<PaintingOwnedRow> {
  final String landmarkId;
  final int visits;
  final Frame frame;

  /// 가장 멀리서 걸어 온 환산 거리(km)
  final double bestKm;
  final int firstArrivedUtc;
  final int lastArrivedUtc;
  final bool seen;
  const PaintingOwnedRow({
    required this.landmarkId,
    required this.visits,
    required this.frame,
    required this.bestKm,
    required this.firstArrivedUtc,
    required this.lastArrivedUtc,
    required this.seen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['landmark_id'] = Variable<String>(landmarkId);
    map['visits'] = Variable<int>(visits);
    {
      map['frame'] = Variable<String>(
        $PaintingsOwnedTable.$converterframe.toSql(frame),
      );
    }
    map['best_km'] = Variable<double>(bestKm);
    map['first_arrived_utc'] = Variable<int>(firstArrivedUtc);
    map['last_arrived_utc'] = Variable<int>(lastArrivedUtc);
    map['seen'] = Variable<bool>(seen);
    return map;
  }

  PaintingsOwnedCompanion toCompanion(bool nullToAbsent) {
    return PaintingsOwnedCompanion(
      landmarkId: Value(landmarkId),
      visits: Value(visits),
      frame: Value(frame),
      bestKm: Value(bestKm),
      firstArrivedUtc: Value(firstArrivedUtc),
      lastArrivedUtc: Value(lastArrivedUtc),
      seen: Value(seen),
    );
  }

  factory PaintingOwnedRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaintingOwnedRow(
      landmarkId: serializer.fromJson<String>(json['landmarkId']),
      visits: serializer.fromJson<int>(json['visits']),
      frame: $PaintingsOwnedTable.$converterframe.fromJson(
        serializer.fromJson<String>(json['frame']),
      ),
      bestKm: serializer.fromJson<double>(json['bestKm']),
      firstArrivedUtc: serializer.fromJson<int>(json['firstArrivedUtc']),
      lastArrivedUtc: serializer.fromJson<int>(json['lastArrivedUtc']),
      seen: serializer.fromJson<bool>(json['seen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'landmarkId': serializer.toJson<String>(landmarkId),
      'visits': serializer.toJson<int>(visits),
      'frame': serializer.toJson<String>(
        $PaintingsOwnedTable.$converterframe.toJson(frame),
      ),
      'bestKm': serializer.toJson<double>(bestKm),
      'firstArrivedUtc': serializer.toJson<int>(firstArrivedUtc),
      'lastArrivedUtc': serializer.toJson<int>(lastArrivedUtc),
      'seen': serializer.toJson<bool>(seen),
    };
  }

  PaintingOwnedRow copyWith({
    String? landmarkId,
    int? visits,
    Frame? frame,
    double? bestKm,
    int? firstArrivedUtc,
    int? lastArrivedUtc,
    bool? seen,
  }) => PaintingOwnedRow(
    landmarkId: landmarkId ?? this.landmarkId,
    visits: visits ?? this.visits,
    frame: frame ?? this.frame,
    bestKm: bestKm ?? this.bestKm,
    firstArrivedUtc: firstArrivedUtc ?? this.firstArrivedUtc,
    lastArrivedUtc: lastArrivedUtc ?? this.lastArrivedUtc,
    seen: seen ?? this.seen,
  );
  PaintingOwnedRow copyWithCompanion(PaintingsOwnedCompanion data) {
    return PaintingOwnedRow(
      landmarkId: data.landmarkId.present
          ? data.landmarkId.value
          : this.landmarkId,
      visits: data.visits.present ? data.visits.value : this.visits,
      frame: data.frame.present ? data.frame.value : this.frame,
      bestKm: data.bestKm.present ? data.bestKm.value : this.bestKm,
      firstArrivedUtc: data.firstArrivedUtc.present
          ? data.firstArrivedUtc.value
          : this.firstArrivedUtc,
      lastArrivedUtc: data.lastArrivedUtc.present
          ? data.lastArrivedUtc.value
          : this.lastArrivedUtc,
      seen: data.seen.present ? data.seen.value : this.seen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaintingOwnedRow(')
          ..write('landmarkId: $landmarkId, ')
          ..write('visits: $visits, ')
          ..write('frame: $frame, ')
          ..write('bestKm: $bestKm, ')
          ..write('firstArrivedUtc: $firstArrivedUtc, ')
          ..write('lastArrivedUtc: $lastArrivedUtc, ')
          ..write('seen: $seen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    landmarkId,
    visits,
    frame,
    bestKm,
    firstArrivedUtc,
    lastArrivedUtc,
    seen,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaintingOwnedRow &&
          other.landmarkId == this.landmarkId &&
          other.visits == this.visits &&
          other.frame == this.frame &&
          other.bestKm == this.bestKm &&
          other.firstArrivedUtc == this.firstArrivedUtc &&
          other.lastArrivedUtc == this.lastArrivedUtc &&
          other.seen == this.seen);
}

class PaintingsOwnedCompanion extends UpdateCompanion<PaintingOwnedRow> {
  final Value<String> landmarkId;
  final Value<int> visits;
  final Value<Frame> frame;
  final Value<double> bestKm;
  final Value<int> firstArrivedUtc;
  final Value<int> lastArrivedUtc;
  final Value<bool> seen;
  final Value<int> rowid;
  const PaintingsOwnedCompanion({
    this.landmarkId = const Value.absent(),
    this.visits = const Value.absent(),
    this.frame = const Value.absent(),
    this.bestKm = const Value.absent(),
    this.firstArrivedUtc = const Value.absent(),
    this.lastArrivedUtc = const Value.absent(),
    this.seen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaintingsOwnedCompanion.insert({
    required String landmarkId,
    required int visits,
    required Frame frame,
    required double bestKm,
    required int firstArrivedUtc,
    required int lastArrivedUtc,
    this.seen = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : landmarkId = Value(landmarkId),
       visits = Value(visits),
       frame = Value(frame),
       bestKm = Value(bestKm),
       firstArrivedUtc = Value(firstArrivedUtc),
       lastArrivedUtc = Value(lastArrivedUtc);
  static Insertable<PaintingOwnedRow> custom({
    Expression<String>? landmarkId,
    Expression<int>? visits,
    Expression<String>? frame,
    Expression<double>? bestKm,
    Expression<int>? firstArrivedUtc,
    Expression<int>? lastArrivedUtc,
    Expression<bool>? seen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (landmarkId != null) 'landmark_id': landmarkId,
      if (visits != null) 'visits': visits,
      if (frame != null) 'frame': frame,
      if (bestKm != null) 'best_km': bestKm,
      if (firstArrivedUtc != null) 'first_arrived_utc': firstArrivedUtc,
      if (lastArrivedUtc != null) 'last_arrived_utc': lastArrivedUtc,
      if (seen != null) 'seen': seen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaintingsOwnedCompanion copyWith({
    Value<String>? landmarkId,
    Value<int>? visits,
    Value<Frame>? frame,
    Value<double>? bestKm,
    Value<int>? firstArrivedUtc,
    Value<int>? lastArrivedUtc,
    Value<bool>? seen,
    Value<int>? rowid,
  }) {
    return PaintingsOwnedCompanion(
      landmarkId: landmarkId ?? this.landmarkId,
      visits: visits ?? this.visits,
      frame: frame ?? this.frame,
      bestKm: bestKm ?? this.bestKm,
      firstArrivedUtc: firstArrivedUtc ?? this.firstArrivedUtc,
      lastArrivedUtc: lastArrivedUtc ?? this.lastArrivedUtc,
      seen: seen ?? this.seen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (landmarkId.present) {
      map['landmark_id'] = Variable<String>(landmarkId.value);
    }
    if (visits.present) {
      map['visits'] = Variable<int>(visits.value);
    }
    if (frame.present) {
      map['frame'] = Variable<String>(
        $PaintingsOwnedTable.$converterframe.toSql(frame.value),
      );
    }
    if (bestKm.present) {
      map['best_km'] = Variable<double>(bestKm.value);
    }
    if (firstArrivedUtc.present) {
      map['first_arrived_utc'] = Variable<int>(firstArrivedUtc.value);
    }
    if (lastArrivedUtc.present) {
      map['last_arrived_utc'] = Variable<int>(lastArrivedUtc.value);
    }
    if (seen.present) {
      map['seen'] = Variable<bool>(seen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaintingsOwnedCompanion(')
          ..write('landmarkId: $landmarkId, ')
          ..write('visits: $visits, ')
          ..write('frame: $frame, ')
          ..write('bestKm: $bestKm, ')
          ..write('firstArrivedUtc: $firstArrivedUtc, ')
          ..write('lastArrivedUtc: $lastArrivedUtc, ')
          ..write('seen: $seen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PropsOwnedTable extends PropsOwned
    with TableInfo<$PropsOwnedTable, PropOwnedRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PropsOwnedTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _propIdMeta = const VerificationMeta('propId');
  @override
  late final GeneratedColumn<String> propId = GeneratedColumn<String>(
    'prop_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unlockedUtcMeta = const VerificationMeta(
    'unlockedUtc',
  );
  @override
  late final GeneratedColumn<int> unlockedUtc = GeneratedColumn<int>(
    'unlocked_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seenMeta = const VerificationMeta('seen');
  @override
  late final GeneratedColumn<bool> seen = GeneratedColumn<bool>(
    'seen',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("seen" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [propId, unlockedUtc, seen];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'props_owned';
  @override
  VerificationContext validateIntegrity(
    Insertable<PropOwnedRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('prop_id')) {
      context.handle(
        _propIdMeta,
        propId.isAcceptableOrUnknown(data['prop_id']!, _propIdMeta),
      );
    } else if (isInserting) {
      context.missing(_propIdMeta);
    }
    if (data.containsKey('unlocked_utc')) {
      context.handle(
        _unlockedUtcMeta,
        unlockedUtc.isAcceptableOrUnknown(
          data['unlocked_utc']!,
          _unlockedUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unlockedUtcMeta);
    }
    if (data.containsKey('seen')) {
      context.handle(
        _seenMeta,
        seen.isAcceptableOrUnknown(data['seen']!, _seenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {propId};
  @override
  PropOwnedRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PropOwnedRow(
      propId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prop_id'],
      )!,
      unlockedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unlocked_utc'],
      )!,
      seen: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}seen'],
      )!,
    );
  }

  @override
  $PropsOwnedTable createAlias(String alias) {
    return $PropsOwnedTable(attachedDatabase, alias);
  }
}

class PropOwnedRow extends DataClass implements Insertable<PropOwnedRow> {
  final String propId;
  final int unlockedUtc;
  final bool seen;
  const PropOwnedRow({
    required this.propId,
    required this.unlockedUtc,
    required this.seen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['prop_id'] = Variable<String>(propId);
    map['unlocked_utc'] = Variable<int>(unlockedUtc);
    map['seen'] = Variable<bool>(seen);
    return map;
  }

  PropsOwnedCompanion toCompanion(bool nullToAbsent) {
    return PropsOwnedCompanion(
      propId: Value(propId),
      unlockedUtc: Value(unlockedUtc),
      seen: Value(seen),
    );
  }

  factory PropOwnedRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PropOwnedRow(
      propId: serializer.fromJson<String>(json['propId']),
      unlockedUtc: serializer.fromJson<int>(json['unlockedUtc']),
      seen: serializer.fromJson<bool>(json['seen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'propId': serializer.toJson<String>(propId),
      'unlockedUtc': serializer.toJson<int>(unlockedUtc),
      'seen': serializer.toJson<bool>(seen),
    };
  }

  PropOwnedRow copyWith({String? propId, int? unlockedUtc, bool? seen}) =>
      PropOwnedRow(
        propId: propId ?? this.propId,
        unlockedUtc: unlockedUtc ?? this.unlockedUtc,
        seen: seen ?? this.seen,
      );
  PropOwnedRow copyWithCompanion(PropsOwnedCompanion data) {
    return PropOwnedRow(
      propId: data.propId.present ? data.propId.value : this.propId,
      unlockedUtc: data.unlockedUtc.present
          ? data.unlockedUtc.value
          : this.unlockedUtc,
      seen: data.seen.present ? data.seen.value : this.seen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PropOwnedRow(')
          ..write('propId: $propId, ')
          ..write('unlockedUtc: $unlockedUtc, ')
          ..write('seen: $seen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(propId, unlockedUtc, seen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PropOwnedRow &&
          other.propId == this.propId &&
          other.unlockedUtc == this.unlockedUtc &&
          other.seen == this.seen);
}

class PropsOwnedCompanion extends UpdateCompanion<PropOwnedRow> {
  final Value<String> propId;
  final Value<int> unlockedUtc;
  final Value<bool> seen;
  final Value<int> rowid;
  const PropsOwnedCompanion({
    this.propId = const Value.absent(),
    this.unlockedUtc = const Value.absent(),
    this.seen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PropsOwnedCompanion.insert({
    required String propId,
    required int unlockedUtc,
    this.seen = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : propId = Value(propId),
       unlockedUtc = Value(unlockedUtc);
  static Insertable<PropOwnedRow> custom({
    Expression<String>? propId,
    Expression<int>? unlockedUtc,
    Expression<bool>? seen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (propId != null) 'prop_id': propId,
      if (unlockedUtc != null) 'unlocked_utc': unlockedUtc,
      if (seen != null) 'seen': seen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PropsOwnedCompanion copyWith({
    Value<String>? propId,
    Value<int>? unlockedUtc,
    Value<bool>? seen,
    Value<int>? rowid,
  }) {
    return PropsOwnedCompanion(
      propId: propId ?? this.propId,
      unlockedUtc: unlockedUtc ?? this.unlockedUtc,
      seen: seen ?? this.seen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (propId.present) {
      map['prop_id'] = Variable<String>(propId.value);
    }
    if (unlockedUtc.present) {
      map['unlocked_utc'] = Variable<int>(unlockedUtc.value);
    }
    if (seen.present) {
      map['seen'] = Variable<bool>(seen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PropsOwnedCompanion(')
          ..write('propId: $propId, ')
          ..write('unlockedUtc: $unlockedUtc, ')
          ..write('seen: $seen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfileTable extends Profile with TableInfo<$ProfileTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfileTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _homeNameMeta = const VerificationMeta(
    'homeName',
  );
  @override
  late final GeneratedColumn<String> homeName = GeneratedColumn<String>(
    'home_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _homeLatMeta = const VerificationMeta(
    'homeLat',
  );
  @override
  late final GeneratedColumn<double> homeLat = GeneratedColumn<double>(
    'home_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _homeLngMeta = const VerificationMeta(
    'homeLng',
  );
  @override
  late final GeneratedColumn<double> homeLng = GeneratedColumn<double>(
    'home_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _homeIdMeta = const VerificationMeta('homeId');
  @override
  late final GeneratedColumn<String> homeId = GeneratedColumn<String>(
    'home_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ageConfirmedAtMeta = const VerificationMeta(
    'ageConfirmedAt',
  );
  @override
  late final GeneratedColumn<int> ageConfirmedAt = GeneratedColumn<int>(
    'age_confirmed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _installIdMeta = const VerificationMeta(
    'installId',
  );
  @override
  late final GeneratedColumn<String> installId = GeneratedColumn<String>(
    'install_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lookMeta = const VerificationMeta('look');
  @override
  late final GeneratedColumn<String> look = GeneratedColumn<String>(
    'look',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _onboardedAtMeta = const VerificationMeta(
    'onboardedAt',
  );
  @override
  late final GeneratedColumn<int> onboardedAt = GeneratedColumn<int>(
    'onboarded_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkConsentAtMeta = const VerificationMeta(
    'linkConsentAt',
  );
  @override
  late final GeneratedColumn<int> linkConsentAt = GeneratedColumn<int>(
    'link_consent_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _guestbookConsentAtMeta =
      const VerificationMeta('guestbookConsentAt');
  @override
  late final GeneratedColumn<int> guestbookConsentAt = GeneratedColumn<int>(
    'guestbook_consent_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    homeName,
    homeLat,
    homeLng,
    homeId,
    ageConfirmedAt,
    installId,
    nickname,
    look,
    onboardedAt,
    linkConsentAt,
    guestbookConsentAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('home_name')) {
      context.handle(
        _homeNameMeta,
        homeName.isAcceptableOrUnknown(data['home_name']!, _homeNameMeta),
      );
    }
    if (data.containsKey('home_lat')) {
      context.handle(
        _homeLatMeta,
        homeLat.isAcceptableOrUnknown(data['home_lat']!, _homeLatMeta),
      );
    }
    if (data.containsKey('home_lng')) {
      context.handle(
        _homeLngMeta,
        homeLng.isAcceptableOrUnknown(data['home_lng']!, _homeLngMeta),
      );
    }
    if (data.containsKey('home_id')) {
      context.handle(
        _homeIdMeta,
        homeId.isAcceptableOrUnknown(data['home_id']!, _homeIdMeta),
      );
    }
    if (data.containsKey('age_confirmed_at')) {
      context.handle(
        _ageConfirmedAtMeta,
        ageConfirmedAt.isAcceptableOrUnknown(
          data['age_confirmed_at']!,
          _ageConfirmedAtMeta,
        ),
      );
    }
    if (data.containsKey('install_id')) {
      context.handle(
        _installIdMeta,
        installId.isAcceptableOrUnknown(data['install_id']!, _installIdMeta),
      );
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    }
    if (data.containsKey('look')) {
      context.handle(
        _lookMeta,
        look.isAcceptableOrUnknown(data['look']!, _lookMeta),
      );
    }
    if (data.containsKey('onboarded_at')) {
      context.handle(
        _onboardedAtMeta,
        onboardedAt.isAcceptableOrUnknown(
          data['onboarded_at']!,
          _onboardedAtMeta,
        ),
      );
    }
    if (data.containsKey('link_consent_at')) {
      context.handle(
        _linkConsentAtMeta,
        linkConsentAt.isAcceptableOrUnknown(
          data['link_consent_at']!,
          _linkConsentAtMeta,
        ),
      );
    }
    if (data.containsKey('guestbook_consent_at')) {
      context.handle(
        _guestbookConsentAtMeta,
        guestbookConsentAt.isAcceptableOrUnknown(
          data['guestbook_consent_at']!,
          _guestbookConsentAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      homeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_name'],
      ),
      homeLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}home_lat'],
      ),
      homeLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}home_lng'],
      ),
      homeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_id'],
      ),
      ageConfirmedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age_confirmed_at'],
      ),
      installId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}install_id'],
      ),
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      ),
      look: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}look'],
      ),
      onboardedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}onboarded_at'],
      ),
      linkConsentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}link_consent_at'],
      ),
      guestbookConsentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}guestbook_consent_at'],
      ),
    );
  }

  @override
  $ProfileTable createAlias(String alias) {
    return $ProfileTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final int id;

  /// 사용자가 고른 출발 동네: 시·군·구 이름(label)과 대표 좌표, 시·군·구 id
  final String? homeName;
  final double? homeLat;
  final double? homeLng;
  final String? homeId;

  /// 만 14세 확인을 누른 시각 (epoch ms). 이게 있어야 설치 번호를 만들고 권한을 묻는다
  final int? ageConfirmedAt;

  /// 설치 번호 (16바이트 hex 32자). 만 14세 확인 때 한 번 만든다
  final String? installId;
  final String? nickname;

  /// 모습 JSON (domain/look.dart의 Look)
  final String? look;

  /// 시작 흐름의 마지막(권한) 단계를 마친 시각 (epoch ms)
  final int? onboardedAt;

  /// 계정 연결·방명록 동의 시각 (epoch ms). 쓰는 곳은 M5에서 붙인다
  final int? linkConsentAt;
  final int? guestbookConsentAt;
  const ProfileRow({
    required this.id,
    this.homeName,
    this.homeLat,
    this.homeLng,
    this.homeId,
    this.ageConfirmedAt,
    this.installId,
    this.nickname,
    this.look,
    this.onboardedAt,
    this.linkConsentAt,
    this.guestbookConsentAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || homeName != null) {
      map['home_name'] = Variable<String>(homeName);
    }
    if (!nullToAbsent || homeLat != null) {
      map['home_lat'] = Variable<double>(homeLat);
    }
    if (!nullToAbsent || homeLng != null) {
      map['home_lng'] = Variable<double>(homeLng);
    }
    if (!nullToAbsent || homeId != null) {
      map['home_id'] = Variable<String>(homeId);
    }
    if (!nullToAbsent || ageConfirmedAt != null) {
      map['age_confirmed_at'] = Variable<int>(ageConfirmedAt);
    }
    if (!nullToAbsent || installId != null) {
      map['install_id'] = Variable<String>(installId);
    }
    if (!nullToAbsent || nickname != null) {
      map['nickname'] = Variable<String>(nickname);
    }
    if (!nullToAbsent || look != null) {
      map['look'] = Variable<String>(look);
    }
    if (!nullToAbsent || onboardedAt != null) {
      map['onboarded_at'] = Variable<int>(onboardedAt);
    }
    if (!nullToAbsent || linkConsentAt != null) {
      map['link_consent_at'] = Variable<int>(linkConsentAt);
    }
    if (!nullToAbsent || guestbookConsentAt != null) {
      map['guestbook_consent_at'] = Variable<int>(guestbookConsentAt);
    }
    return map;
  }

  ProfileCompanion toCompanion(bool nullToAbsent) {
    return ProfileCompanion(
      id: Value(id),
      homeName: homeName == null && nullToAbsent
          ? const Value.absent()
          : Value(homeName),
      homeLat: homeLat == null && nullToAbsent
          ? const Value.absent()
          : Value(homeLat),
      homeLng: homeLng == null && nullToAbsent
          ? const Value.absent()
          : Value(homeLng),
      homeId: homeId == null && nullToAbsent
          ? const Value.absent()
          : Value(homeId),
      ageConfirmedAt: ageConfirmedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(ageConfirmedAt),
      installId: installId == null && nullToAbsent
          ? const Value.absent()
          : Value(installId),
      nickname: nickname == null && nullToAbsent
          ? const Value.absent()
          : Value(nickname),
      look: look == null && nullToAbsent ? const Value.absent() : Value(look),
      onboardedAt: onboardedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(onboardedAt),
      linkConsentAt: linkConsentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(linkConsentAt),
      guestbookConsentAt: guestbookConsentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(guestbookConsentAt),
    );
  }

  factory ProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<int>(json['id']),
      homeName: serializer.fromJson<String?>(json['homeName']),
      homeLat: serializer.fromJson<double?>(json['homeLat']),
      homeLng: serializer.fromJson<double?>(json['homeLng']),
      homeId: serializer.fromJson<String?>(json['homeId']),
      ageConfirmedAt: serializer.fromJson<int?>(json['ageConfirmedAt']),
      installId: serializer.fromJson<String?>(json['installId']),
      nickname: serializer.fromJson<String?>(json['nickname']),
      look: serializer.fromJson<String?>(json['look']),
      onboardedAt: serializer.fromJson<int?>(json['onboardedAt']),
      linkConsentAt: serializer.fromJson<int?>(json['linkConsentAt']),
      guestbookConsentAt: serializer.fromJson<int?>(json['guestbookConsentAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'homeName': serializer.toJson<String?>(homeName),
      'homeLat': serializer.toJson<double?>(homeLat),
      'homeLng': serializer.toJson<double?>(homeLng),
      'homeId': serializer.toJson<String?>(homeId),
      'ageConfirmedAt': serializer.toJson<int?>(ageConfirmedAt),
      'installId': serializer.toJson<String?>(installId),
      'nickname': serializer.toJson<String?>(nickname),
      'look': serializer.toJson<String?>(look),
      'onboardedAt': serializer.toJson<int?>(onboardedAt),
      'linkConsentAt': serializer.toJson<int?>(linkConsentAt),
      'guestbookConsentAt': serializer.toJson<int?>(guestbookConsentAt),
    };
  }

  ProfileRow copyWith({
    int? id,
    Value<String?> homeName = const Value.absent(),
    Value<double?> homeLat = const Value.absent(),
    Value<double?> homeLng = const Value.absent(),
    Value<String?> homeId = const Value.absent(),
    Value<int?> ageConfirmedAt = const Value.absent(),
    Value<String?> installId = const Value.absent(),
    Value<String?> nickname = const Value.absent(),
    Value<String?> look = const Value.absent(),
    Value<int?> onboardedAt = const Value.absent(),
    Value<int?> linkConsentAt = const Value.absent(),
    Value<int?> guestbookConsentAt = const Value.absent(),
  }) => ProfileRow(
    id: id ?? this.id,
    homeName: homeName.present ? homeName.value : this.homeName,
    homeLat: homeLat.present ? homeLat.value : this.homeLat,
    homeLng: homeLng.present ? homeLng.value : this.homeLng,
    homeId: homeId.present ? homeId.value : this.homeId,
    ageConfirmedAt: ageConfirmedAt.present
        ? ageConfirmedAt.value
        : this.ageConfirmedAt,
    installId: installId.present ? installId.value : this.installId,
    nickname: nickname.present ? nickname.value : this.nickname,
    look: look.present ? look.value : this.look,
    onboardedAt: onboardedAt.present ? onboardedAt.value : this.onboardedAt,
    linkConsentAt: linkConsentAt.present
        ? linkConsentAt.value
        : this.linkConsentAt,
    guestbookConsentAt: guestbookConsentAt.present
        ? guestbookConsentAt.value
        : this.guestbookConsentAt,
  );
  ProfileRow copyWithCompanion(ProfileCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      homeName: data.homeName.present ? data.homeName.value : this.homeName,
      homeLat: data.homeLat.present ? data.homeLat.value : this.homeLat,
      homeLng: data.homeLng.present ? data.homeLng.value : this.homeLng,
      homeId: data.homeId.present ? data.homeId.value : this.homeId,
      ageConfirmedAt: data.ageConfirmedAt.present
          ? data.ageConfirmedAt.value
          : this.ageConfirmedAt,
      installId: data.installId.present ? data.installId.value : this.installId,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      look: data.look.present ? data.look.value : this.look,
      onboardedAt: data.onboardedAt.present
          ? data.onboardedAt.value
          : this.onboardedAt,
      linkConsentAt: data.linkConsentAt.present
          ? data.linkConsentAt.value
          : this.linkConsentAt,
      guestbookConsentAt: data.guestbookConsentAt.present
          ? data.guestbookConsentAt.value
          : this.guestbookConsentAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('homeName: $homeName, ')
          ..write('homeLat: $homeLat, ')
          ..write('homeLng: $homeLng, ')
          ..write('homeId: $homeId, ')
          ..write('ageConfirmedAt: $ageConfirmedAt, ')
          ..write('installId: $installId, ')
          ..write('nickname: $nickname, ')
          ..write('look: $look, ')
          ..write('onboardedAt: $onboardedAt, ')
          ..write('linkConsentAt: $linkConsentAt, ')
          ..write('guestbookConsentAt: $guestbookConsentAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    homeName,
    homeLat,
    homeLng,
    homeId,
    ageConfirmedAt,
    installId,
    nickname,
    look,
    onboardedAt,
    linkConsentAt,
    guestbookConsentAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.homeName == this.homeName &&
          other.homeLat == this.homeLat &&
          other.homeLng == this.homeLng &&
          other.homeId == this.homeId &&
          other.ageConfirmedAt == this.ageConfirmedAt &&
          other.installId == this.installId &&
          other.nickname == this.nickname &&
          other.look == this.look &&
          other.onboardedAt == this.onboardedAt &&
          other.linkConsentAt == this.linkConsentAt &&
          other.guestbookConsentAt == this.guestbookConsentAt);
}

class ProfileCompanion extends UpdateCompanion<ProfileRow> {
  final Value<int> id;
  final Value<String?> homeName;
  final Value<double?> homeLat;
  final Value<double?> homeLng;
  final Value<String?> homeId;
  final Value<int?> ageConfirmedAt;
  final Value<String?> installId;
  final Value<String?> nickname;
  final Value<String?> look;
  final Value<int?> onboardedAt;
  final Value<int?> linkConsentAt;
  final Value<int?> guestbookConsentAt;
  const ProfileCompanion({
    this.id = const Value.absent(),
    this.homeName = const Value.absent(),
    this.homeLat = const Value.absent(),
    this.homeLng = const Value.absent(),
    this.homeId = const Value.absent(),
    this.ageConfirmedAt = const Value.absent(),
    this.installId = const Value.absent(),
    this.nickname = const Value.absent(),
    this.look = const Value.absent(),
    this.onboardedAt = const Value.absent(),
    this.linkConsentAt = const Value.absent(),
    this.guestbookConsentAt = const Value.absent(),
  });
  ProfileCompanion.insert({
    this.id = const Value.absent(),
    this.homeName = const Value.absent(),
    this.homeLat = const Value.absent(),
    this.homeLng = const Value.absent(),
    this.homeId = const Value.absent(),
    this.ageConfirmedAt = const Value.absent(),
    this.installId = const Value.absent(),
    this.nickname = const Value.absent(),
    this.look = const Value.absent(),
    this.onboardedAt = const Value.absent(),
    this.linkConsentAt = const Value.absent(),
    this.guestbookConsentAt = const Value.absent(),
  });
  static Insertable<ProfileRow> custom({
    Expression<int>? id,
    Expression<String>? homeName,
    Expression<double>? homeLat,
    Expression<double>? homeLng,
    Expression<String>? homeId,
    Expression<int>? ageConfirmedAt,
    Expression<String>? installId,
    Expression<String>? nickname,
    Expression<String>? look,
    Expression<int>? onboardedAt,
    Expression<int>? linkConsentAt,
    Expression<int>? guestbookConsentAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (homeName != null) 'home_name': homeName,
      if (homeLat != null) 'home_lat': homeLat,
      if (homeLng != null) 'home_lng': homeLng,
      if (homeId != null) 'home_id': homeId,
      if (ageConfirmedAt != null) 'age_confirmed_at': ageConfirmedAt,
      if (installId != null) 'install_id': installId,
      if (nickname != null) 'nickname': nickname,
      if (look != null) 'look': look,
      if (onboardedAt != null) 'onboarded_at': onboardedAt,
      if (linkConsentAt != null) 'link_consent_at': linkConsentAt,
      if (guestbookConsentAt != null)
        'guestbook_consent_at': guestbookConsentAt,
    });
  }

  ProfileCompanion copyWith({
    Value<int>? id,
    Value<String?>? homeName,
    Value<double?>? homeLat,
    Value<double?>? homeLng,
    Value<String?>? homeId,
    Value<int?>? ageConfirmedAt,
    Value<String?>? installId,
    Value<String?>? nickname,
    Value<String?>? look,
    Value<int?>? onboardedAt,
    Value<int?>? linkConsentAt,
    Value<int?>? guestbookConsentAt,
  }) {
    return ProfileCompanion(
      id: id ?? this.id,
      homeName: homeName ?? this.homeName,
      homeLat: homeLat ?? this.homeLat,
      homeLng: homeLng ?? this.homeLng,
      homeId: homeId ?? this.homeId,
      ageConfirmedAt: ageConfirmedAt ?? this.ageConfirmedAt,
      installId: installId ?? this.installId,
      nickname: nickname ?? this.nickname,
      look: look ?? this.look,
      onboardedAt: onboardedAt ?? this.onboardedAt,
      linkConsentAt: linkConsentAt ?? this.linkConsentAt,
      guestbookConsentAt: guestbookConsentAt ?? this.guestbookConsentAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (homeName.present) {
      map['home_name'] = Variable<String>(homeName.value);
    }
    if (homeLat.present) {
      map['home_lat'] = Variable<double>(homeLat.value);
    }
    if (homeLng.present) {
      map['home_lng'] = Variable<double>(homeLng.value);
    }
    if (homeId.present) {
      map['home_id'] = Variable<String>(homeId.value);
    }
    if (ageConfirmedAt.present) {
      map['age_confirmed_at'] = Variable<int>(ageConfirmedAt.value);
    }
    if (installId.present) {
      map['install_id'] = Variable<String>(installId.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (look.present) {
      map['look'] = Variable<String>(look.value);
    }
    if (onboardedAt.present) {
      map['onboarded_at'] = Variable<int>(onboardedAt.value);
    }
    if (linkConsentAt.present) {
      map['link_consent_at'] = Variable<int>(linkConsentAt.value);
    }
    if (guestbookConsentAt.present) {
      map['guestbook_consent_at'] = Variable<int>(guestbookConsentAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfileCompanion(')
          ..write('id: $id, ')
          ..write('homeName: $homeName, ')
          ..write('homeLat: $homeLat, ')
          ..write('homeLng: $homeLng, ')
          ..write('homeId: $homeId, ')
          ..write('ageConfirmedAt: $ageConfirmedAt, ')
          ..write('installId: $installId, ')
          ..write('nickname: $nickname, ')
          ..write('look: $look, ')
          ..write('onboardedAt: $onboardedAt, ')
          ..write('linkConsentAt: $linkConsentAt, ')
          ..write('guestbookConsentAt: $guestbookConsentAt')
          ..write(')'))
        .toString();
  }
}

class $WallSlotsTable extends WallSlots
    with TableInfo<$WallSlotsTable, WallSlotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WallSlotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _landmarkIdMeta = const VerificationMeta(
    'landmarkId',
  );
  @override
  late final GeneratedColumn<String> landmarkId = GeneratedColumn<String>(
    'landmark_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [slot, landmarkId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wall_slots';
  @override
  VerificationContext validateIntegrity(
    Insertable<WallSlotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    }
    if (data.containsKey('landmark_id')) {
      context.handle(
        _landmarkIdMeta,
        landmarkId.isAcceptableOrUnknown(data['landmark_id']!, _landmarkIdMeta),
      );
    } else if (isInserting) {
      context.missing(_landmarkIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slot};
  @override
  WallSlotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WallSlotRow(
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot'],
      )!,
      landmarkId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}landmark_id'],
      )!,
    );
  }

  @override
  $WallSlotsTable createAlias(String alias) {
    return $WallSlotsTable(attachedDatabase, alias);
  }
}

class WallSlotRow extends DataClass implements Insertable<WallSlotRow> {
  final int slot;
  final String landmarkId;
  const WallSlotRow({required this.slot, required this.landmarkId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slot'] = Variable<int>(slot);
    map['landmark_id'] = Variable<String>(landmarkId);
    return map;
  }

  WallSlotsCompanion toCompanion(bool nullToAbsent) {
    return WallSlotsCompanion(slot: Value(slot), landmarkId: Value(landmarkId));
  }

  factory WallSlotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WallSlotRow(
      slot: serializer.fromJson<int>(json['slot']),
      landmarkId: serializer.fromJson<String>(json['landmarkId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slot': serializer.toJson<int>(slot),
      'landmarkId': serializer.toJson<String>(landmarkId),
    };
  }

  WallSlotRow copyWith({int? slot, String? landmarkId}) => WallSlotRow(
    slot: slot ?? this.slot,
    landmarkId: landmarkId ?? this.landmarkId,
  );
  WallSlotRow copyWithCompanion(WallSlotsCompanion data) {
    return WallSlotRow(
      slot: data.slot.present ? data.slot.value : this.slot,
      landmarkId: data.landmarkId.present
          ? data.landmarkId.value
          : this.landmarkId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WallSlotRow(')
          ..write('slot: $slot, ')
          ..write('landmarkId: $landmarkId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(slot, landmarkId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WallSlotRow &&
          other.slot == this.slot &&
          other.landmarkId == this.landmarkId);
}

class WallSlotsCompanion extends UpdateCompanion<WallSlotRow> {
  final Value<int> slot;
  final Value<String> landmarkId;
  const WallSlotsCompanion({
    this.slot = const Value.absent(),
    this.landmarkId = const Value.absent(),
  });
  WallSlotsCompanion.insert({
    this.slot = const Value.absent(),
    required String landmarkId,
  }) : landmarkId = Value(landmarkId);
  static Insertable<WallSlotRow> custom({
    Expression<int>? slot,
    Expression<String>? landmarkId,
  }) {
    return RawValuesInsertable({
      if (slot != null) 'slot': slot,
      if (landmarkId != null) 'landmark_id': landmarkId,
    });
  }

  WallSlotsCompanion copyWith({Value<int>? slot, Value<String>? landmarkId}) {
    return WallSlotsCompanion(
      slot: slot ?? this.slot,
      landmarkId: landmarkId ?? this.landmarkId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
    }
    if (landmarkId.present) {
      map['landmark_id'] = Variable<String>(landmarkId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WallSlotsCompanion(')
          ..write('slot: $slot, ')
          ..write('landmarkId: $landmarkId')
          ..write(')'))
        .toString();
  }
}

class $GuestbookTicketsTable extends GuestbookTickets
    with TableInfo<$GuestbookTicketsTable, GuestbookTicketRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GuestbookTicketsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TicketKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TicketKind>($GuestbookTicketsTable.$converterkind);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openedUtcMeta = const VerificationMeta(
    'openedUtc',
  );
  @override
  late final GeneratedColumn<int> openedUtc = GeneratedColumn<int>(
    'opened_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usedUtcMeta = const VerificationMeta(
    'usedUtc',
  );
  @override
  late final GeneratedColumn<int> usedUtc = GeneratedColumn<int>(
    'used_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closedUtcMeta = const VerificationMeta(
    'closedUtc',
  );
  @override
  late final GeneratedColumn<int> closedUtc = GeneratedColumn<int>(
    'closed_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    scope,
    openedUtc,
    usedUtc,
    closedUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'guestbook_tickets';
  @override
  VerificationContext validateIntegrity(
    Insertable<GuestbookTicketRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('opened_utc')) {
      context.handle(
        _openedUtcMeta,
        openedUtc.isAcceptableOrUnknown(data['opened_utc']!, _openedUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_openedUtcMeta);
    }
    if (data.containsKey('used_utc')) {
      context.handle(
        _usedUtcMeta,
        usedUtc.isAcceptableOrUnknown(data['used_utc']!, _usedUtcMeta),
      );
    }
    if (data.containsKey('closed_utc')) {
      context.handle(
        _closedUtcMeta,
        closedUtc.isAcceptableOrUnknown(data['closed_utc']!, _closedUtcMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GuestbookTicketRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GuestbookTicketRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: $GuestbookTicketsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      openedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opened_utc'],
      )!,
      usedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}used_utc'],
      ),
      closedUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}closed_utc'],
      ),
    );
  }

  @override
  $GuestbookTicketsTable createAlias(String alias) {
    return $GuestbookTicketsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TicketKind, String, String> $converterkind =
      const EnumNameConverter<TicketKind>(TicketKind.values);
}

class GuestbookTicketRow extends DataClass
    implements Insertable<GuestbookTicketRow> {
  final String id;
  final TicketKind kind;
  final String scope;
  final int openedUtc;
  final int? usedUtc;
  final int? closedUtc;
  const GuestbookTicketRow({
    required this.id,
    required this.kind,
    required this.scope,
    required this.openedUtc,
    this.usedUtc,
    this.closedUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['kind'] = Variable<String>(
        $GuestbookTicketsTable.$converterkind.toSql(kind),
      );
    }
    map['scope'] = Variable<String>(scope);
    map['opened_utc'] = Variable<int>(openedUtc);
    if (!nullToAbsent || usedUtc != null) {
      map['used_utc'] = Variable<int>(usedUtc);
    }
    if (!nullToAbsent || closedUtc != null) {
      map['closed_utc'] = Variable<int>(closedUtc);
    }
    return map;
  }

  GuestbookTicketsCompanion toCompanion(bool nullToAbsent) {
    return GuestbookTicketsCompanion(
      id: Value(id),
      kind: Value(kind),
      scope: Value(scope),
      openedUtc: Value(openedUtc),
      usedUtc: usedUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(usedUtc),
      closedUtc: closedUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(closedUtc),
    );
  }

  factory GuestbookTicketRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GuestbookTicketRow(
      id: serializer.fromJson<String>(json['id']),
      kind: $GuestbookTicketsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      scope: serializer.fromJson<String>(json['scope']),
      openedUtc: serializer.fromJson<int>(json['openedUtc']),
      usedUtc: serializer.fromJson<int?>(json['usedUtc']),
      closedUtc: serializer.fromJson<int?>(json['closedUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(
        $GuestbookTicketsTable.$converterkind.toJson(kind),
      ),
      'scope': serializer.toJson<String>(scope),
      'openedUtc': serializer.toJson<int>(openedUtc),
      'usedUtc': serializer.toJson<int?>(usedUtc),
      'closedUtc': serializer.toJson<int?>(closedUtc),
    };
  }

  GuestbookTicketRow copyWith({
    String? id,
    TicketKind? kind,
    String? scope,
    int? openedUtc,
    Value<int?> usedUtc = const Value.absent(),
    Value<int?> closedUtc = const Value.absent(),
  }) => GuestbookTicketRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    scope: scope ?? this.scope,
    openedUtc: openedUtc ?? this.openedUtc,
    usedUtc: usedUtc.present ? usedUtc.value : this.usedUtc,
    closedUtc: closedUtc.present ? closedUtc.value : this.closedUtc,
  );
  GuestbookTicketRow copyWithCompanion(GuestbookTicketsCompanion data) {
    return GuestbookTicketRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      scope: data.scope.present ? data.scope.value : this.scope,
      openedUtc: data.openedUtc.present ? data.openedUtc.value : this.openedUtc,
      usedUtc: data.usedUtc.present ? data.usedUtc.value : this.usedUtc,
      closedUtc: data.closedUtc.present ? data.closedUtc.value : this.closedUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GuestbookTicketRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('scope: $scope, ')
          ..write('openedUtc: $openedUtc, ')
          ..write('usedUtc: $usedUtc, ')
          ..write('closedUtc: $closedUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, scope, openedUtc, usedUtc, closedUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GuestbookTicketRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.scope == this.scope &&
          other.openedUtc == this.openedUtc &&
          other.usedUtc == this.usedUtc &&
          other.closedUtc == this.closedUtc);
}

class GuestbookTicketsCompanion extends UpdateCompanion<GuestbookTicketRow> {
  final Value<String> id;
  final Value<TicketKind> kind;
  final Value<String> scope;
  final Value<int> openedUtc;
  final Value<int?> usedUtc;
  final Value<int?> closedUtc;
  final Value<int> rowid;
  const GuestbookTicketsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.scope = const Value.absent(),
    this.openedUtc = const Value.absent(),
    this.usedUtc = const Value.absent(),
    this.closedUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GuestbookTicketsCompanion.insert({
    required String id,
    required TicketKind kind,
    required String scope,
    required int openedUtc,
    this.usedUtc = const Value.absent(),
    this.closedUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       scope = Value(scope),
       openedUtc = Value(openedUtc);
  static Insertable<GuestbookTicketRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? scope,
    Expression<int>? openedUtc,
    Expression<int>? usedUtc,
    Expression<int>? closedUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (scope != null) 'scope': scope,
      if (openedUtc != null) 'opened_utc': openedUtc,
      if (usedUtc != null) 'used_utc': usedUtc,
      if (closedUtc != null) 'closed_utc': closedUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GuestbookTicketsCompanion copyWith({
    Value<String>? id,
    Value<TicketKind>? kind,
    Value<String>? scope,
    Value<int>? openedUtc,
    Value<int?>? usedUtc,
    Value<int?>? closedUtc,
    Value<int>? rowid,
  }) {
    return GuestbookTicketsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      scope: scope ?? this.scope,
      openedUtc: openedUtc ?? this.openedUtc,
      usedUtc: usedUtc ?? this.usedUtc,
      closedUtc: closedUtc ?? this.closedUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $GuestbookTicketsTable.$converterkind.toSql(kind.value),
      );
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (openedUtc.present) {
      map['opened_utc'] = Variable<int>(openedUtc.value);
    }
    if (usedUtc.present) {
      map['used_utc'] = Variable<int>(usedUtc.value);
    }
    if (closedUtc.present) {
      map['closed_utc'] = Variable<int>(closedUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GuestbookTicketsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('scope: $scope, ')
          ..write('openedUtc: $openedUtc, ')
          ..write('usedUtc: $usedUtc, ')
          ..write('closedUtc: $closedUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GuestbookPostsTable extends GuestbookPosts
    with TableInfo<$GuestbookPostsTable, GuestbookPostRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GuestbookPostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ticketIdMeta = const VerificationMeta(
    'ticketId',
  );
  @override
  late final GeneratedColumn<String> ticketId = GeneratedColumn<String>(
    'ticket_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdUtcMeta = const VerificationMeta(
    'createdUtc',
  );
  @override
  late final GeneratedColumn<int> createdUtc = GeneratedColumn<int>(
    'created_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PostStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PostStatus>($GuestbookPostsTable.$converterstatus);
  @override
  List<GeneratedColumn> get $columns => [
    ticketId,
    scope,
    body,
    createdUtc,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'guestbook_posts';
  @override
  VerificationContext validateIntegrity(
    Insertable<GuestbookPostRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ticket_id')) {
      context.handle(
        _ticketIdMeta,
        ticketId.isAcceptableOrUnknown(data['ticket_id']!, _ticketIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ticketIdMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_utc')) {
      context.handle(
        _createdUtcMeta,
        createdUtc.isAcceptableOrUnknown(data['created_utc']!, _createdUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_createdUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ticketId};
  @override
  GuestbookPostRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GuestbookPostRow(
      ticketId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ticket_id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      createdUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_utc'],
      )!,
      status: $GuestbookPostsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
    );
  }

  @override
  $GuestbookPostsTable createAlias(String alias) {
    return $GuestbookPostsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PostStatus, String, String> $converterstatus =
      const EnumNameConverter<PostStatus>(PostStatus.values);
}

class GuestbookPostRow extends DataClass
    implements Insertable<GuestbookPostRow> {
  final String ticketId;
  final String scope;
  final String body;
  final int createdUtc;
  final PostStatus status;
  const GuestbookPostRow({
    required this.ticketId,
    required this.scope,
    required this.body,
    required this.createdUtc,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ticket_id'] = Variable<String>(ticketId);
    map['scope'] = Variable<String>(scope);
    map['body'] = Variable<String>(body);
    map['created_utc'] = Variable<int>(createdUtc);
    {
      map['status'] = Variable<String>(
        $GuestbookPostsTable.$converterstatus.toSql(status),
      );
    }
    return map;
  }

  GuestbookPostsCompanion toCompanion(bool nullToAbsent) {
    return GuestbookPostsCompanion(
      ticketId: Value(ticketId),
      scope: Value(scope),
      body: Value(body),
      createdUtc: Value(createdUtc),
      status: Value(status),
    );
  }

  factory GuestbookPostRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GuestbookPostRow(
      ticketId: serializer.fromJson<String>(json['ticketId']),
      scope: serializer.fromJson<String>(json['scope']),
      body: serializer.fromJson<String>(json['body']),
      createdUtc: serializer.fromJson<int>(json['createdUtc']),
      status: $GuestbookPostsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ticketId': serializer.toJson<String>(ticketId),
      'scope': serializer.toJson<String>(scope),
      'body': serializer.toJson<String>(body),
      'createdUtc': serializer.toJson<int>(createdUtc),
      'status': serializer.toJson<String>(
        $GuestbookPostsTable.$converterstatus.toJson(status),
      ),
    };
  }

  GuestbookPostRow copyWith({
    String? ticketId,
    String? scope,
    String? body,
    int? createdUtc,
    PostStatus? status,
  }) => GuestbookPostRow(
    ticketId: ticketId ?? this.ticketId,
    scope: scope ?? this.scope,
    body: body ?? this.body,
    createdUtc: createdUtc ?? this.createdUtc,
    status: status ?? this.status,
  );
  GuestbookPostRow copyWithCompanion(GuestbookPostsCompanion data) {
    return GuestbookPostRow(
      ticketId: data.ticketId.present ? data.ticketId.value : this.ticketId,
      scope: data.scope.present ? data.scope.value : this.scope,
      body: data.body.present ? data.body.value : this.body,
      createdUtc: data.createdUtc.present
          ? data.createdUtc.value
          : this.createdUtc,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GuestbookPostRow(')
          ..write('ticketId: $ticketId, ')
          ..write('scope: $scope, ')
          ..write('body: $body, ')
          ..write('createdUtc: $createdUtc, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ticketId, scope, body, createdUtc, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GuestbookPostRow &&
          other.ticketId == this.ticketId &&
          other.scope == this.scope &&
          other.body == this.body &&
          other.createdUtc == this.createdUtc &&
          other.status == this.status);
}

class GuestbookPostsCompanion extends UpdateCompanion<GuestbookPostRow> {
  final Value<String> ticketId;
  final Value<String> scope;
  final Value<String> body;
  final Value<int> createdUtc;
  final Value<PostStatus> status;
  final Value<int> rowid;
  const GuestbookPostsCompanion({
    this.ticketId = const Value.absent(),
    this.scope = const Value.absent(),
    this.body = const Value.absent(),
    this.createdUtc = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GuestbookPostsCompanion.insert({
    required String ticketId,
    required String scope,
    required String body,
    required int createdUtc,
    required PostStatus status,
    this.rowid = const Value.absent(),
  }) : ticketId = Value(ticketId),
       scope = Value(scope),
       body = Value(body),
       createdUtc = Value(createdUtc),
       status = Value(status);
  static Insertable<GuestbookPostRow> custom({
    Expression<String>? ticketId,
    Expression<String>? scope,
    Expression<String>? body,
    Expression<int>? createdUtc,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ticketId != null) 'ticket_id': ticketId,
      if (scope != null) 'scope': scope,
      if (body != null) 'body': body,
      if (createdUtc != null) 'created_utc': createdUtc,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GuestbookPostsCompanion copyWith({
    Value<String>? ticketId,
    Value<String>? scope,
    Value<String>? body,
    Value<int>? createdUtc,
    Value<PostStatus>? status,
    Value<int>? rowid,
  }) {
    return GuestbookPostsCompanion(
      ticketId: ticketId ?? this.ticketId,
      scope: scope ?? this.scope,
      body: body ?? this.body,
      createdUtc: createdUtc ?? this.createdUtc,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ticketId.present) {
      map['ticket_id'] = Variable<String>(ticketId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdUtc.present) {
      map['created_utc'] = Variable<int>(createdUtc.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $GuestbookPostsTable.$converterstatus.toSql(status.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GuestbookPostsCompanion(')
          ..write('ticketId: $ticketId, ')
          ..write('scope: $scope, ')
          ..write('body: $body, ')
          ..write('createdUtc: $createdUtc, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationLogTable extends NotificationLog
    with TableInfo<$NotificationLogTable, NotificationLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<NoticeKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<NoticeKind>($NotificationLogTable.$converterkind);
  static const VerificationMeta _refKeyMeta = const VerificationMeta('refKey');
  @override
  late final GeneratedColumn<String> refKey = GeneratedColumn<String>(
    'ref_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atUtcMeta = const VerificationMeta('atUtc');
  @override
  late final GeneratedColumn<int> atUtc = GeneratedColumn<int>(
    'at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<NoticeStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<NoticeStatus>($NotificationLogTable.$converterstatus);
  @override
  List<GeneratedColumn> get $columns => [id, kind, refKey, atUtc, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ref_key')) {
      context.handle(
        _refKeyMeta,
        refKey.isAcceptableOrUnknown(data['ref_key']!, _refKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_refKeyMeta);
    }
    if (data.containsKey('at_utc')) {
      context.handle(
        _atUtcMeta,
        atUtc.isAcceptableOrUnknown(data['at_utc']!, _atUtcMeta),
      );
    } else if (isInserting) {
      context.missing(_atUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: $NotificationLogTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      refKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_key'],
      )!,
      atUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at_utc'],
      )!,
      status: $NotificationLogTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
    );
  }

  @override
  $NotificationLogTable createAlias(String alias) {
    return $NotificationLogTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<NoticeKind, String, String> $converterkind =
      const EnumNameConverter<NoticeKind>(NoticeKind.values);
  static JsonTypeConverter2<NoticeStatus, String, String> $converterstatus =
      const EnumNameConverter<NoticeStatus>(NoticeStatus.values);
}

class NotificationLogRow extends DataClass
    implements Insertable<NotificationLogRow> {
  final int id;
  final NoticeKind kind;
  final String refKey;
  final int atUtc;
  final NoticeStatus status;
  const NotificationLogRow({
    required this.id,
    required this.kind,
    required this.refKey,
    required this.atUtc,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['kind'] = Variable<String>(
        $NotificationLogTable.$converterkind.toSql(kind),
      );
    }
    map['ref_key'] = Variable<String>(refKey);
    map['at_utc'] = Variable<int>(atUtc);
    {
      map['status'] = Variable<String>(
        $NotificationLogTable.$converterstatus.toSql(status),
      );
    }
    return map;
  }

  NotificationLogCompanion toCompanion(bool nullToAbsent) {
    return NotificationLogCompanion(
      id: Value(id),
      kind: Value(kind),
      refKey: Value(refKey),
      atUtc: Value(atUtc),
      status: Value(status),
    );
  }

  factory NotificationLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationLogRow(
      id: serializer.fromJson<int>(json['id']),
      kind: $NotificationLogTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      refKey: serializer.fromJson<String>(json['refKey']),
      atUtc: serializer.fromJson<int>(json['atUtc']),
      status: $NotificationLogTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(
        $NotificationLogTable.$converterkind.toJson(kind),
      ),
      'refKey': serializer.toJson<String>(refKey),
      'atUtc': serializer.toJson<int>(atUtc),
      'status': serializer.toJson<String>(
        $NotificationLogTable.$converterstatus.toJson(status),
      ),
    };
  }

  NotificationLogRow copyWith({
    int? id,
    NoticeKind? kind,
    String? refKey,
    int? atUtc,
    NoticeStatus? status,
  }) => NotificationLogRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    refKey: refKey ?? this.refKey,
    atUtc: atUtc ?? this.atUtc,
    status: status ?? this.status,
  );
  NotificationLogRow copyWithCompanion(NotificationLogCompanion data) {
    return NotificationLogRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      refKey: data.refKey.present ? data.refKey.value : this.refKey,
      atUtc: data.atUtc.present ? data.atUtc.value : this.atUtc,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationLogRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('refKey: $refKey, ')
          ..write('atUtc: $atUtc, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, refKey, atUtc, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationLogRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.refKey == this.refKey &&
          other.atUtc == this.atUtc &&
          other.status == this.status);
}

class NotificationLogCompanion extends UpdateCompanion<NotificationLogRow> {
  final Value<int> id;
  final Value<NoticeKind> kind;
  final Value<String> refKey;
  final Value<int> atUtc;
  final Value<NoticeStatus> status;
  const NotificationLogCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.refKey = const Value.absent(),
    this.atUtc = const Value.absent(),
    this.status = const Value.absent(),
  });
  NotificationLogCompanion.insert({
    this.id = const Value.absent(),
    required NoticeKind kind,
    required String refKey,
    required int atUtc,
    required NoticeStatus status,
  }) : kind = Value(kind),
       refKey = Value(refKey),
       atUtc = Value(atUtc),
       status = Value(status);
  static Insertable<NotificationLogRow> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? refKey,
    Expression<int>? atUtc,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (refKey != null) 'ref_key': refKey,
      if (atUtc != null) 'at_utc': atUtc,
      if (status != null) 'status': status,
    });
  }

  NotificationLogCompanion copyWith({
    Value<int>? id,
    Value<NoticeKind>? kind,
    Value<String>? refKey,
    Value<int>? atUtc,
    Value<NoticeStatus>? status,
  }) {
    return NotificationLogCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      refKey: refKey ?? this.refKey,
      atUtc: atUtc ?? this.atUtc,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $NotificationLogTable.$converterkind.toSql(kind.value),
      );
    }
    if (refKey.present) {
      map['ref_key'] = Variable<String>(refKey.value);
    }
    if (atUtc.present) {
      map['at_utc'] = Variable<int>(atUtc.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $NotificationLogTable.$converterstatus.toSql(status.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationLogCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('refKey: $refKey, ')
          ..write('atUtc: $atUtc, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $NotificationSettingsTable extends NotificationSettings
    with TableInfo<$NotificationSettingsTable, NotificationSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allOnMeta = const VerificationMeta('allOn');
  @override
  late final GeneratedColumn<bool> allOn = GeneratedColumn<bool>(
    'all_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("all_on" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _n1OnMeta = const VerificationMeta('n1On');
  @override
  late final GeneratedColumn<bool> n1On = GeneratedColumn<bool>(
    'n1_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("n1_on" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _n2OnMeta = const VerificationMeta('n2On');
  @override
  late final GeneratedColumn<bool> n2On = GeneratedColumn<bool>(
    'n2_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("n2_on" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _n3OnMeta = const VerificationMeta('n3On');
  @override
  late final GeneratedColumn<bool> n3On = GeneratedColumn<bool>(
    'n3_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("n3_on" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _n4OnMeta = const VerificationMeta('n4On');
  @override
  late final GeneratedColumn<bool> n4On = GeneratedColumn<bool>(
    'n4_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("n4_on" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _n5OnMeta = const VerificationMeta('n5On');
  @override
  late final GeneratedColumn<bool> n5On = GeneratedColumn<bool>(
    'n5_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("n5_on" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    allOn,
    n1On,
    n2On,
    n3On,
    n4On,
    n5On,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('all_on')) {
      context.handle(
        _allOnMeta,
        allOn.isAcceptableOrUnknown(data['all_on']!, _allOnMeta),
      );
    }
    if (data.containsKey('n1_on')) {
      context.handle(
        _n1OnMeta,
        n1On.isAcceptableOrUnknown(data['n1_on']!, _n1OnMeta),
      );
    }
    if (data.containsKey('n2_on')) {
      context.handle(
        _n2OnMeta,
        n2On.isAcceptableOrUnknown(data['n2_on']!, _n2OnMeta),
      );
    }
    if (data.containsKey('n3_on')) {
      context.handle(
        _n3OnMeta,
        n3On.isAcceptableOrUnknown(data['n3_on']!, _n3OnMeta),
      );
    }
    if (data.containsKey('n4_on')) {
      context.handle(
        _n4OnMeta,
        n4On.isAcceptableOrUnknown(data['n4_on']!, _n4OnMeta),
      );
    }
    if (data.containsKey('n5_on')) {
      context.handle(
        _n5OnMeta,
        n5On.isAcceptableOrUnknown(data['n5_on']!, _n5OnMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationSettingsRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationSettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      allOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}all_on'],
      )!,
      n1On: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}n1_on'],
      )!,
      n2On: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}n2_on'],
      )!,
      n3On: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}n3_on'],
      )!,
      n4On: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}n4_on'],
      )!,
      n5On: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}n5_on'],
      )!,
    );
  }

  @override
  $NotificationSettingsTable createAlias(String alias) {
    return $NotificationSettingsTable(attachedDatabase, alias);
  }
}

class NotificationSettingsRow extends DataClass
    implements Insertable<NotificationSettingsRow> {
  final int id;
  final bool allOn;
  final bool n1On;
  final bool n2On;
  final bool n3On;
  final bool n4On;
  final bool n5On;
  const NotificationSettingsRow({
    required this.id,
    required this.allOn,
    required this.n1On,
    required this.n2On,
    required this.n3On,
    required this.n4On,
    required this.n5On,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['all_on'] = Variable<bool>(allOn);
    map['n1_on'] = Variable<bool>(n1On);
    map['n2_on'] = Variable<bool>(n2On);
    map['n3_on'] = Variable<bool>(n3On);
    map['n4_on'] = Variable<bool>(n4On);
    map['n5_on'] = Variable<bool>(n5On);
    return map;
  }

  NotificationSettingsCompanion toCompanion(bool nullToAbsent) {
    return NotificationSettingsCompanion(
      id: Value(id),
      allOn: Value(allOn),
      n1On: Value(n1On),
      n2On: Value(n2On),
      n3On: Value(n3On),
      n4On: Value(n4On),
      n5On: Value(n5On),
    );
  }

  factory NotificationSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationSettingsRow(
      id: serializer.fromJson<int>(json['id']),
      allOn: serializer.fromJson<bool>(json['allOn']),
      n1On: serializer.fromJson<bool>(json['n1On']),
      n2On: serializer.fromJson<bool>(json['n2On']),
      n3On: serializer.fromJson<bool>(json['n3On']),
      n4On: serializer.fromJson<bool>(json['n4On']),
      n5On: serializer.fromJson<bool>(json['n5On']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'allOn': serializer.toJson<bool>(allOn),
      'n1On': serializer.toJson<bool>(n1On),
      'n2On': serializer.toJson<bool>(n2On),
      'n3On': serializer.toJson<bool>(n3On),
      'n4On': serializer.toJson<bool>(n4On),
      'n5On': serializer.toJson<bool>(n5On),
    };
  }

  NotificationSettingsRow copyWith({
    int? id,
    bool? allOn,
    bool? n1On,
    bool? n2On,
    bool? n3On,
    bool? n4On,
    bool? n5On,
  }) => NotificationSettingsRow(
    id: id ?? this.id,
    allOn: allOn ?? this.allOn,
    n1On: n1On ?? this.n1On,
    n2On: n2On ?? this.n2On,
    n3On: n3On ?? this.n3On,
    n4On: n4On ?? this.n4On,
    n5On: n5On ?? this.n5On,
  );
  NotificationSettingsRow copyWithCompanion(
    NotificationSettingsCompanion data,
  ) {
    return NotificationSettingsRow(
      id: data.id.present ? data.id.value : this.id,
      allOn: data.allOn.present ? data.allOn.value : this.allOn,
      n1On: data.n1On.present ? data.n1On.value : this.n1On,
      n2On: data.n2On.present ? data.n2On.value : this.n2On,
      n3On: data.n3On.present ? data.n3On.value : this.n3On,
      n4On: data.n4On.present ? data.n4On.value : this.n4On,
      n5On: data.n5On.present ? data.n5On.value : this.n5On,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationSettingsRow(')
          ..write('id: $id, ')
          ..write('allOn: $allOn, ')
          ..write('n1On: $n1On, ')
          ..write('n2On: $n2On, ')
          ..write('n3On: $n3On, ')
          ..write('n4On: $n4On, ')
          ..write('n5On: $n5On')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, allOn, n1On, n2On, n3On, n4On, n5On);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationSettingsRow &&
          other.id == this.id &&
          other.allOn == this.allOn &&
          other.n1On == this.n1On &&
          other.n2On == this.n2On &&
          other.n3On == this.n3On &&
          other.n4On == this.n4On &&
          other.n5On == this.n5On);
}

class NotificationSettingsCompanion
    extends UpdateCompanion<NotificationSettingsRow> {
  final Value<int> id;
  final Value<bool> allOn;
  final Value<bool> n1On;
  final Value<bool> n2On;
  final Value<bool> n3On;
  final Value<bool> n4On;
  final Value<bool> n5On;
  const NotificationSettingsCompanion({
    this.id = const Value.absent(),
    this.allOn = const Value.absent(),
    this.n1On = const Value.absent(),
    this.n2On = const Value.absent(),
    this.n3On = const Value.absent(),
    this.n4On = const Value.absent(),
    this.n5On = const Value.absent(),
  });
  NotificationSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.allOn = const Value.absent(),
    this.n1On = const Value.absent(),
    this.n2On = const Value.absent(),
    this.n3On = const Value.absent(),
    this.n4On = const Value.absent(),
    this.n5On = const Value.absent(),
  });
  static Insertable<NotificationSettingsRow> custom({
    Expression<int>? id,
    Expression<bool>? allOn,
    Expression<bool>? n1On,
    Expression<bool>? n2On,
    Expression<bool>? n3On,
    Expression<bool>? n4On,
    Expression<bool>? n5On,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (allOn != null) 'all_on': allOn,
      if (n1On != null) 'n1_on': n1On,
      if (n2On != null) 'n2_on': n2On,
      if (n3On != null) 'n3_on': n3On,
      if (n4On != null) 'n4_on': n4On,
      if (n5On != null) 'n5_on': n5On,
    });
  }

  NotificationSettingsCompanion copyWith({
    Value<int>? id,
    Value<bool>? allOn,
    Value<bool>? n1On,
    Value<bool>? n2On,
    Value<bool>? n3On,
    Value<bool>? n4On,
    Value<bool>? n5On,
  }) {
    return NotificationSettingsCompanion(
      id: id ?? this.id,
      allOn: allOn ?? this.allOn,
      n1On: n1On ?? this.n1On,
      n2On: n2On ?? this.n2On,
      n3On: n3On ?? this.n3On,
      n4On: n4On ?? this.n4On,
      n5On: n5On ?? this.n5On,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (allOn.present) {
      map['all_on'] = Variable<bool>(allOn.value);
    }
    if (n1On.present) {
      map['n1_on'] = Variable<bool>(n1On.value);
    }
    if (n2On.present) {
      map['n2_on'] = Variable<bool>(n2On.value);
    }
    if (n3On.present) {
      map['n3_on'] = Variable<bool>(n3On.value);
    }
    if (n4On.present) {
      map['n4_on'] = Variable<bool>(n4On.value);
    }
    if (n5On.present) {
      map['n5_on'] = Variable<bool>(n5On.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationSettingsCompanion(')
          ..write('id: $id, ')
          ..write('allOn: $allOn, ')
          ..write('n1On: $n1On, ')
          ..write('n2On: $n2On, ')
          ..write('n3On: $n3On, ')
          ..write('n4On: $n4On, ')
          ..write('n5On: $n5On')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $StepMinutesTable stepMinutes = $StepMinutesTable(this);
  late final $DaySummariesTable daySummaries = $DaySummariesTable(this);
  late final $WalkSessionsTable walkSessions = $WalkSessionsTable(this);
  late final $JourneysTable journeys = $JourneysTable(this);
  late final $TravelFundTable travelFund = $TravelFundTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $PaintingsOwnedTable paintingsOwned = $PaintingsOwnedTable(this);
  late final $PropsOwnedTable propsOwned = $PropsOwnedTable(this);
  late final $ProfileTable profile = $ProfileTable(this);
  late final $WallSlotsTable wallSlots = $WallSlotsTable(this);
  late final $GuestbookTicketsTable guestbookTickets = $GuestbookTicketsTable(
    this,
  );
  late final $GuestbookPostsTable guestbookPosts = $GuestbookPostsTable(this);
  late final $NotificationLogTable notificationLog = $NotificationLogTable(
    this,
  );
  late final $NotificationSettingsTable notificationSettings =
      $NotificationSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    stepMinutes,
    daySummaries,
    walkSessions,
    journeys,
    travelFund,
    syncState,
    paintingsOwned,
    propsOwned,
    profile,
    wallSlots,
    guestbookTickets,
    guestbookPosts,
    notificationLog,
    notificationSettings,
  ];
}

typedef $$StepMinutesTableCreateCompanionBuilder =
    StepMinutesCompanion Function({Value<int> minuteUtc, required int steps});
typedef $$StepMinutesTableUpdateCompanionBuilder =
    StepMinutesCompanion Function({Value<int> minuteUtc, Value<int> steps});

class $$StepMinutesTableFilterComposer
    extends Composer<_$AppDb, $StepMinutesTable> {
  $$StepMinutesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get minuteUtc => $composableBuilder(
    column: $table.minuteUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StepMinutesTableOrderingComposer
    extends Composer<_$AppDb, $StepMinutesTable> {
  $$StepMinutesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get minuteUtc => $composableBuilder(
    column: $table.minuteUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StepMinutesTableAnnotationComposer
    extends Composer<_$AppDb, $StepMinutesTable> {
  $$StepMinutesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get minuteUtc =>
      $composableBuilder(column: $table.minuteUtc, builder: (column) => column);

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);
}

class $$StepMinutesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $StepMinutesTable,
          StepMinuteRow,
          $$StepMinutesTableFilterComposer,
          $$StepMinutesTableOrderingComposer,
          $$StepMinutesTableAnnotationComposer,
          $$StepMinutesTableCreateCompanionBuilder,
          $$StepMinutesTableUpdateCompanionBuilder,
          (
            StepMinuteRow,
            BaseReferences<_$AppDb, $StepMinutesTable, StepMinuteRow>,
          ),
          StepMinuteRow,
          PrefetchHooks Function()
        > {
  $$StepMinutesTableTableManager(_$AppDb db, $StepMinutesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StepMinutesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StepMinutesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StepMinutesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> minuteUtc = const Value.absent(),
            Value<int> steps = const Value.absent(),
          }) => StepMinutesCompanion(minuteUtc: minuteUtc, steps: steps),
          createCompanionCallback: ({
            Value<int> minuteUtc = const Value.absent(),
            required int steps,
          }) => StepMinutesCompanion.insert(minuteUtc: minuteUtc, steps: steps),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StepMinutesTable, StepMinuteRow>(table),
                  BaseReferences<_$AppDb, $StepMinutesTable, StepMinuteRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StepMinutesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $StepMinutesTable,
      StepMinuteRow,
      $$StepMinutesTableFilterComposer,
      $$StepMinutesTableOrderingComposer,
      $$StepMinutesTableAnnotationComposer,
      $$StepMinutesTableCreateCompanionBuilder,
      $$StepMinutesTableUpdateCompanionBuilder,
      (
        StepMinuteRow,
        BaseReferences<_$AppDb, $StepMinutesTable, StepMinuteRow>,
      ),
      StepMinuteRow,
      PrefetchHooks Function()
    >;
typedef $$DaySummariesTableCreateCompanionBuilder =
    DaySummariesCompanion Function({
      required String day,
      required int steps,
      required double distanceM,
      required int countedSessions,
      Value<int> rowid,
    });
typedef $$DaySummariesTableUpdateCompanionBuilder =
    DaySummariesCompanion Function({
      Value<String> day,
      Value<int> steps,
      Value<double> distanceM,
      Value<int> countedSessions,
      Value<int> rowid,
    });

class $$DaySummariesTableFilterComposer
    extends Composer<_$AppDb, $DaySummariesTable> {
  $$DaySummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get countedSessions => $composableBuilder(
    column: $table.countedSessions,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DaySummariesTableOrderingComposer
    extends Composer<_$AppDb, $DaySummariesTable> {
  $$DaySummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get countedSessions => $composableBuilder(
    column: $table.countedSessions,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DaySummariesTableAnnotationComposer
    extends Composer<_$AppDb, $DaySummariesTable> {
  $$DaySummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<double> get distanceM =>
      $composableBuilder(column: $table.distanceM, builder: (column) => column);

  GeneratedColumn<int> get countedSessions => $composableBuilder(
    column: $table.countedSessions,
    builder: (column) => column,
  );
}

class $$DaySummariesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $DaySummariesTable,
          DaySummaryRow,
          $$DaySummariesTableFilterComposer,
          $$DaySummariesTableOrderingComposer,
          $$DaySummariesTableAnnotationComposer,
          $$DaySummariesTableCreateCompanionBuilder,
          $$DaySummariesTableUpdateCompanionBuilder,
          (
            DaySummaryRow,
            BaseReferences<_$AppDb, $DaySummariesTable, DaySummaryRow>,
          ),
          DaySummaryRow,
          PrefetchHooks Function()
        > {
  $$DaySummariesTableTableManager(_$AppDb db, $DaySummariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DaySummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DaySummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DaySummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> day = const Value.absent(),
                Value<int> steps = const Value.absent(),
                Value<double> distanceM = const Value.absent(),
                Value<int> countedSessions = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DaySummariesCompanion(
                day: day,
                steps: steps,
                distanceM: distanceM,
                countedSessions: countedSessions,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String day,
                required int steps,
                required double distanceM,
                required int countedSessions,
                Value<int> rowid = const Value.absent(),
              }) => DaySummariesCompanion.insert(
                day: day,
                steps: steps,
                distanceM: distanceM,
                countedSessions: countedSessions,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DaySummariesTable, DaySummaryRow>(table),
                  BaseReferences<_$AppDb, $DaySummariesTable, DaySummaryRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DaySummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $DaySummariesTable,
      DaySummaryRow,
      $$DaySummariesTableFilterComposer,
      $$DaySummariesTableOrderingComposer,
      $$DaySummariesTableAnnotationComposer,
      $$DaySummariesTableCreateCompanionBuilder,
      $$DaySummariesTableUpdateCompanionBuilder,
      (
        DaySummaryRow,
        BaseReferences<_$AppDb, $DaySummariesTable, DaySummaryRow>,
      ),
      DaySummaryRow,
      PrefetchHooks Function()
    >;
typedef $$WalkSessionsTableCreateCompanionBuilder =
    WalkSessionsCompanion Function({
      Value<int> startUtc,
      required int endUtc,
      required int steps,
      required double distanceM,
      required double runRatio,
      required bool qualified,
      required bool counted,
    });
typedef $$WalkSessionsTableUpdateCompanionBuilder =
    WalkSessionsCompanion Function({
      Value<int> startUtc,
      Value<int> endUtc,
      Value<int> steps,
      Value<double> distanceM,
      Value<double> runRatio,
      Value<bool> qualified,
      Value<bool> counted,
    });

class $$WalkSessionsTableFilterComposer
    extends Composer<_$AppDb, $WalkSessionsTable> {
  $$WalkSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endUtc => $composableBuilder(
    column: $table.endUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get runRatio => $composableBuilder(
    column: $table.runRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get qualified => $composableBuilder(
    column: $table.qualified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get counted => $composableBuilder(
    column: $table.counted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalkSessionsTableOrderingComposer
    extends Composer<_$AppDb, $WalkSessionsTable> {
  $$WalkSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endUtc => $composableBuilder(
    column: $table.endUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get runRatio => $composableBuilder(
    column: $table.runRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get qualified => $composableBuilder(
    column: $table.qualified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get counted => $composableBuilder(
    column: $table.counted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalkSessionsTableAnnotationComposer
    extends Composer<_$AppDb, $WalkSessionsTable> {
  $$WalkSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get startUtc =>
      $composableBuilder(column: $table.startUtc, builder: (column) => column);

  GeneratedColumn<int> get endUtc =>
      $composableBuilder(column: $table.endUtc, builder: (column) => column);

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<double> get distanceM =>
      $composableBuilder(column: $table.distanceM, builder: (column) => column);

  GeneratedColumn<double> get runRatio =>
      $composableBuilder(column: $table.runRatio, builder: (column) => column);

  GeneratedColumn<bool> get qualified =>
      $composableBuilder(column: $table.qualified, builder: (column) => column);

  GeneratedColumn<bool> get counted =>
      $composableBuilder(column: $table.counted, builder: (column) => column);
}

class $$WalkSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $WalkSessionsTable,
          WalkSessionRow,
          $$WalkSessionsTableFilterComposer,
          $$WalkSessionsTableOrderingComposer,
          $$WalkSessionsTableAnnotationComposer,
          $$WalkSessionsTableCreateCompanionBuilder,
          $$WalkSessionsTableUpdateCompanionBuilder,
          (
            WalkSessionRow,
            BaseReferences<_$AppDb, $WalkSessionsTable, WalkSessionRow>,
          ),
          WalkSessionRow,
          PrefetchHooks Function()
        > {
  $$WalkSessionsTableTableManager(_$AppDb db, $WalkSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalkSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalkSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalkSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> startUtc = const Value.absent(),
                Value<int> endUtc = const Value.absent(),
                Value<int> steps = const Value.absent(),
                Value<double> distanceM = const Value.absent(),
                Value<double> runRatio = const Value.absent(),
                Value<bool> qualified = const Value.absent(),
                Value<bool> counted = const Value.absent(),
              }) => WalkSessionsCompanion(
                startUtc: startUtc,
                endUtc: endUtc,
                steps: steps,
                distanceM: distanceM,
                runRatio: runRatio,
                qualified: qualified,
                counted: counted,
              ),
          createCompanionCallback:
              ({
                Value<int> startUtc = const Value.absent(),
                required int endUtc,
                required int steps,
                required double distanceM,
                required double runRatio,
                required bool qualified,
                required bool counted,
              }) => WalkSessionsCompanion.insert(
                startUtc: startUtc,
                endUtc: endUtc,
                steps: steps,
                distanceM: distanceM,
                runRatio: runRatio,
                qualified: qualified,
                counted: counted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WalkSessionsTable, WalkSessionRow>(table),
                  BaseReferences<_$AppDb, $WalkSessionsTable, WalkSessionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalkSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $WalkSessionsTable,
      WalkSessionRow,
      $$WalkSessionsTableFilterComposer,
      $$WalkSessionsTableOrderingComposer,
      $$WalkSessionsTableAnnotationComposer,
      $$WalkSessionsTableCreateCompanionBuilder,
      $$WalkSessionsTableUpdateCompanionBuilder,
      (
        WalkSessionRow,
        BaseReferences<_$AppDb, $WalkSessionsTable, WalkSessionRow>,
      ),
      WalkSessionRow,
      PrefetchHooks Function()
    >;
typedef $$JourneysTableCreateCompanionBuilder = JourneysCompanion Function({
  required String id,
  required double originLat,
  required double originLng,
  required String destId,
  required int startUtc,
  required double fundKm,
  required double totalEffectiveKm,
  required JourneyStatus status,
  Value<int?> arrivedUtc,
  Value<double?> endLat,
  Value<double?> endLng,
  Value<int?> endedUtc,
  Value<int?> visitNo,
  Value<Frame?> prevFrame,
  Value<Frame?> newFrame,
  Value<bool> arrivalShown,
  Value<double?> destLat,
  Value<double?> destLng,
  Value<int> rowid,
});
typedef $$JourneysTableUpdateCompanionBuilder = JourneysCompanion Function({
  Value<String> id,
  Value<double> originLat,
  Value<double> originLng,
  Value<String> destId,
  Value<int> startUtc,
  Value<double> fundKm,
  Value<double> totalEffectiveKm,
  Value<JourneyStatus> status,
  Value<int?> arrivedUtc,
  Value<double?> endLat,
  Value<double?> endLng,
  Value<int?> endedUtc,
  Value<int?> visitNo,
  Value<Frame?> prevFrame,
  Value<Frame?> newFrame,
  Value<bool> arrivalShown,
  Value<double?> destLat,
  Value<double?> destLng,
  Value<int> rowid,
});

class $$JourneysTableFilterComposer extends Composer<_$AppDb, $JourneysTable> {
  $$JourneysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get originLat => $composableBuilder(
    column: $table.originLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get originLng => $composableBuilder(
    column: $table.originLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destId => $composableBuilder(
    column: $table.destId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fundKm => $composableBuilder(
    column: $table.fundKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalEffectiveKm => $composableBuilder(
    column: $table.totalEffectiveKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<JourneyStatus, JourneyStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get arrivedUtc => $composableBuilder(
    column: $table.arrivedUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endLat => $composableBuilder(
    column: $table.endLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endLng => $composableBuilder(
    column: $table.endLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedUtc => $composableBuilder(
    column: $table.endedUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get visitNo => $composableBuilder(
    column: $table.visitNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Frame?, Frame, String> get prevFrame =>
      $composableBuilder(
        column: $table.prevFrame,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Frame?, Frame, String> get newFrame =>
      $composableBuilder(
        column: $table.newFrame,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get arrivalShown => $composableBuilder(
    column: $table.arrivalShown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get destLat => $composableBuilder(
    column: $table.destLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get destLng => $composableBuilder(
    column: $table.destLng,
    builder: (column) => ColumnFilters(column),
  );
}

class $$JourneysTableOrderingComposer
    extends Composer<_$AppDb, $JourneysTable> {
  $$JourneysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get originLat => $composableBuilder(
    column: $table.originLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get originLng => $composableBuilder(
    column: $table.originLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destId => $composableBuilder(
    column: $table.destId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startUtc => $composableBuilder(
    column: $table.startUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fundKm => $composableBuilder(
    column: $table.fundKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalEffectiveKm => $composableBuilder(
    column: $table.totalEffectiveKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get arrivedUtc => $composableBuilder(
    column: $table.arrivedUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endLat => $composableBuilder(
    column: $table.endLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endLng => $composableBuilder(
    column: $table.endLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedUtc => $composableBuilder(
    column: $table.endedUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get visitNo => $composableBuilder(
    column: $table.visitNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prevFrame => $composableBuilder(
    column: $table.prevFrame,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newFrame => $composableBuilder(
    column: $table.newFrame,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get arrivalShown => $composableBuilder(
    column: $table.arrivalShown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get destLat => $composableBuilder(
    column: $table.destLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get destLng => $composableBuilder(
    column: $table.destLng,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JourneysTableAnnotationComposer
    extends Composer<_$AppDb, $JourneysTable> {
  $$JourneysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get originLat =>
      $composableBuilder(column: $table.originLat, builder: (column) => column);

  GeneratedColumn<double> get originLng =>
      $composableBuilder(column: $table.originLng, builder: (column) => column);

  GeneratedColumn<String> get destId =>
      $composableBuilder(column: $table.destId, builder: (column) => column);

  GeneratedColumn<int> get startUtc =>
      $composableBuilder(column: $table.startUtc, builder: (column) => column);

  GeneratedColumn<double> get fundKm =>
      $composableBuilder(column: $table.fundKm, builder: (column) => column);

  GeneratedColumn<double> get totalEffectiveKm => $composableBuilder(
    column: $table.totalEffectiveKm,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<JourneyStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get arrivedUtc => $composableBuilder(
    column: $table.arrivedUtc,
    builder: (column) => column,
  );

  GeneratedColumn<double> get endLat =>
      $composableBuilder(column: $table.endLat, builder: (column) => column);

  GeneratedColumn<double> get endLng =>
      $composableBuilder(column: $table.endLng, builder: (column) => column);

  GeneratedColumn<int> get endedUtc =>
      $composableBuilder(column: $table.endedUtc, builder: (column) => column);

  GeneratedColumn<int> get visitNo =>
      $composableBuilder(column: $table.visitNo, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Frame?, String> get prevFrame =>
      $composableBuilder(column: $table.prevFrame, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Frame?, String> get newFrame =>
      $composableBuilder(column: $table.newFrame, builder: (column) => column);

  GeneratedColumn<bool> get arrivalShown => $composableBuilder(
    column: $table.arrivalShown,
    builder: (column) => column,
  );

  GeneratedColumn<double> get destLat =>
      $composableBuilder(column: $table.destLat, builder: (column) => column);

  GeneratedColumn<double> get destLng =>
      $composableBuilder(column: $table.destLng, builder: (column) => column);
}

class $$JourneysTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $JourneysTable,
          JourneyRow,
          $$JourneysTableFilterComposer,
          $$JourneysTableOrderingComposer,
          $$JourneysTableAnnotationComposer,
          $$JourneysTableCreateCompanionBuilder,
          $$JourneysTableUpdateCompanionBuilder,
          (JourneyRow, BaseReferences<_$AppDb, $JourneysTable, JourneyRow>),
          JourneyRow,
          PrefetchHooks Function()
        > {
  $$JourneysTableTableManager(_$AppDb db, $JourneysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JourneysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JourneysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JourneysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<double> originLat = const Value.absent(),
                Value<double> originLng = const Value.absent(),
                Value<String> destId = const Value.absent(),
                Value<int> startUtc = const Value.absent(),
                Value<double> fundKm = const Value.absent(),
                Value<double> totalEffectiveKm = const Value.absent(),
                Value<JourneyStatus> status = const Value.absent(),
                Value<int?> arrivedUtc = const Value.absent(),
                Value<double?> endLat = const Value.absent(),
                Value<double?> endLng = const Value.absent(),
                Value<int?> endedUtc = const Value.absent(),
                Value<int?> visitNo = const Value.absent(),
                Value<Frame?> prevFrame = const Value.absent(),
                Value<Frame?> newFrame = const Value.absent(),
                Value<bool> arrivalShown = const Value.absent(),
                Value<double?> destLat = const Value.absent(),
                Value<double?> destLng = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JourneysCompanion(
                id: id,
                originLat: originLat,
                originLng: originLng,
                destId: destId,
                startUtc: startUtc,
                fundKm: fundKm,
                totalEffectiveKm: totalEffectiveKm,
                status: status,
                arrivedUtc: arrivedUtc,
                endLat: endLat,
                endLng: endLng,
                endedUtc: endedUtc,
                visitNo: visitNo,
                prevFrame: prevFrame,
                newFrame: newFrame,
                arrivalShown: arrivalShown,
                destLat: destLat,
                destLng: destLng,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required double originLat,
                required double originLng,
                required String destId,
                required int startUtc,
                required double fundKm,
                required double totalEffectiveKm,
                required JourneyStatus status,
                Value<int?> arrivedUtc = const Value.absent(),
                Value<double?> endLat = const Value.absent(),
                Value<double?> endLng = const Value.absent(),
                Value<int?> endedUtc = const Value.absent(),
                Value<int?> visitNo = const Value.absent(),
                Value<Frame?> prevFrame = const Value.absent(),
                Value<Frame?> newFrame = const Value.absent(),
                Value<bool> arrivalShown = const Value.absent(),
                Value<double?> destLat = const Value.absent(),
                Value<double?> destLng = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JourneysCompanion.insert(
                id: id,
                originLat: originLat,
                originLng: originLng,
                destId: destId,
                startUtc: startUtc,
                fundKm: fundKm,
                totalEffectiveKm: totalEffectiveKm,
                status: status,
                arrivedUtc: arrivedUtc,
                endLat: endLat,
                endLng: endLng,
                endedUtc: endedUtc,
                visitNo: visitNo,
                prevFrame: prevFrame,
                newFrame: newFrame,
                arrivalShown: arrivalShown,
                destLat: destLat,
                destLng: destLng,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JourneysTable, JourneyRow>(table),
                  BaseReferences<_$AppDb, $JourneysTable, JourneyRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JourneysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $JourneysTable,
      JourneyRow,
      $$JourneysTableFilterComposer,
      $$JourneysTableOrderingComposer,
      $$JourneysTableAnnotationComposer,
      $$JourneysTableCreateCompanionBuilder,
      $$JourneysTableUpdateCompanionBuilder,
      (JourneyRow, BaseReferences<_$AppDb, $JourneysTable, JourneyRow>),
      JourneyRow,
      PrefetchHooks Function()
    >;
typedef $$TravelFundTableCreateCompanionBuilder = TravelFundCompanion Function({
  Value<int> id,
  required double km,
  required int fundedUntilUtc,
});
typedef $$TravelFundTableUpdateCompanionBuilder = TravelFundCompanion Function({
  Value<int> id,
  Value<double> km,
  Value<int> fundedUntilUtc,
});

class $$TravelFundTableFilterComposer
    extends Composer<_$AppDb, $TravelFundTable> {
  $$TravelFundTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get km => $composableBuilder(
    column: $table.km,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fundedUntilUtc => $composableBuilder(
    column: $table.fundedUntilUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TravelFundTableOrderingComposer
    extends Composer<_$AppDb, $TravelFundTable> {
  $$TravelFundTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get km => $composableBuilder(
    column: $table.km,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fundedUntilUtc => $composableBuilder(
    column: $table.fundedUntilUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TravelFundTableAnnotationComposer
    extends Composer<_$AppDb, $TravelFundTable> {
  $$TravelFundTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get km =>
      $composableBuilder(column: $table.km, builder: (column) => column);

  GeneratedColumn<int> get fundedUntilUtc => $composableBuilder(
    column: $table.fundedUntilUtc,
    builder: (column) => column,
  );
}

class $$TravelFundTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $TravelFundTable,
          TravelFundRow,
          $$TravelFundTableFilterComposer,
          $$TravelFundTableOrderingComposer,
          $$TravelFundTableAnnotationComposer,
          $$TravelFundTableCreateCompanionBuilder,
          $$TravelFundTableUpdateCompanionBuilder,
          (
            TravelFundRow,
            BaseReferences<_$AppDb, $TravelFundTable, TravelFundRow>,
          ),
          TravelFundRow,
          PrefetchHooks Function()
        > {
  $$TravelFundTableTableManager(_$AppDb db, $TravelFundTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TravelFundTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TravelFundTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TravelFundTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double> km = const Value.absent(),
                Value<int> fundedUntilUtc = const Value.absent(),
              }) => TravelFundCompanion(
                id: id,
                km: km,
                fundedUntilUtc: fundedUntilUtc,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required double km,
                required int fundedUntilUtc,
              }) => TravelFundCompanion.insert(
                id: id,
                km: km,
                fundedUntilUtc: fundedUntilUtc,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TravelFundTable, TravelFundRow>(table),
                  BaseReferences<_$AppDb, $TravelFundTable, TravelFundRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TravelFundTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $TravelFundTable,
      TravelFundRow,
      $$TravelFundTableFilterComposer,
      $$TravelFundTableOrderingComposer,
      $$TravelFundTableAnnotationComposer,
      $$TravelFundTableCreateCompanionBuilder,
      $$TravelFundTableUpdateCompanionBuilder,
      (TravelFundRow, BaseReferences<_$AppDb, $TravelFundTable, TravelFundRow>),
      TravelFundRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  Value<int> id,
  Value<int?> lastFetchedUtc,
  required String firstRecordDay,
  required int installUtc,
  Value<String?> restoreFloorDay,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<int> id,
  Value<int?> lastFetchedUtc,
  Value<String> firstRecordDay,
  Value<int> installUtc,
  Value<String?> restoreFloorDay,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDb, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastFetchedUtc => $composableBuilder(
    column: $table.lastFetchedUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstRecordDay => $composableBuilder(
    column: $table.firstRecordDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get installUtc => $composableBuilder(
    column: $table.installUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get restoreFloorDay => $composableBuilder(
    column: $table.restoreFloorDay,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDb, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastFetchedUtc => $composableBuilder(
    column: $table.lastFetchedUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstRecordDay => $composableBuilder(
    column: $table.firstRecordDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get installUtc => $composableBuilder(
    column: $table.installUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get restoreFloorDay => $composableBuilder(
    column: $table.restoreFloorDay,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDb, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lastFetchedUtc => $composableBuilder(
    column: $table.lastFetchedUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get firstRecordDay => $composableBuilder(
    column: $table.firstRecordDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get installUtc => $composableBuilder(
    column: $table.installUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get restoreFloorDay => $composableBuilder(
    column: $table.restoreFloorDay,
    builder: (column) => column,
  );
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SyncStateTable,
          SyncStateRow,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDb, $SyncStateTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDb db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> lastFetchedUtc = const Value.absent(),
                Value<String> firstRecordDay = const Value.absent(),
                Value<int> installUtc = const Value.absent(),
                Value<String?> restoreFloorDay = const Value.absent(),
              }) => SyncStateCompanion(
                id: id,
                lastFetchedUtc: lastFetchedUtc,
                firstRecordDay: firstRecordDay,
                installUtc: installUtc,
                restoreFloorDay: restoreFloorDay,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> lastFetchedUtc = const Value.absent(),
                required String firstRecordDay,
                required int installUtc,
                Value<String?> restoreFloorDay = const Value.absent(),
              }) => SyncStateCompanion.insert(
                id: id,
                lastFetchedUtc: lastFetchedUtc,
                firstRecordDay: firstRecordDay,
                installUtc: installUtc,
                restoreFloorDay: restoreFloorDay,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStateTable, SyncStateRow>(table),
                  BaseReferences<_$AppDb, $SyncStateTable, SyncStateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SyncStateTable,
      SyncStateRow,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (SyncStateRow, BaseReferences<_$AppDb, $SyncStateTable, SyncStateRow>),
      SyncStateRow,
      PrefetchHooks Function()
    >;
typedef $$PaintingsOwnedTableCreateCompanionBuilder =
    PaintingsOwnedCompanion Function({
      required String landmarkId,
      required int visits,
      required Frame frame,
      required double bestKm,
      required int firstArrivedUtc,
      required int lastArrivedUtc,
      Value<bool> seen,
      Value<int> rowid,
    });
typedef $$PaintingsOwnedTableUpdateCompanionBuilder =
    PaintingsOwnedCompanion Function({
      Value<String> landmarkId,
      Value<int> visits,
      Value<Frame> frame,
      Value<double> bestKm,
      Value<int> firstArrivedUtc,
      Value<int> lastArrivedUtc,
      Value<bool> seen,
      Value<int> rowid,
    });

class $$PaintingsOwnedTableFilterComposer
    extends Composer<_$AppDb, $PaintingsOwnedTable> {
  $$PaintingsOwnedTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get landmarkId => $composableBuilder(
    column: $table.landmarkId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get visits => $composableBuilder(
    column: $table.visits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Frame, Frame, String> get frame =>
      $composableBuilder(
        column: $table.frame,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get bestKm => $composableBuilder(
    column: $table.bestKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstArrivedUtc => $composableBuilder(
    column: $table.firstArrivedUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastArrivedUtc => $composableBuilder(
    column: $table.lastArrivedUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get seen => $composableBuilder(
    column: $table.seen,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PaintingsOwnedTableOrderingComposer
    extends Composer<_$AppDb, $PaintingsOwnedTable> {
  $$PaintingsOwnedTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get landmarkId => $composableBuilder(
    column: $table.landmarkId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get visits => $composableBuilder(
    column: $table.visits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frame => $composableBuilder(
    column: $table.frame,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bestKm => $composableBuilder(
    column: $table.bestKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstArrivedUtc => $composableBuilder(
    column: $table.firstArrivedUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastArrivedUtc => $composableBuilder(
    column: $table.lastArrivedUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get seen => $composableBuilder(
    column: $table.seen,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PaintingsOwnedTableAnnotationComposer
    extends Composer<_$AppDb, $PaintingsOwnedTable> {
  $$PaintingsOwnedTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get landmarkId => $composableBuilder(
    column: $table.landmarkId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get visits =>
      $composableBuilder(column: $table.visits, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Frame, String> get frame =>
      $composableBuilder(column: $table.frame, builder: (column) => column);

  GeneratedColumn<double> get bestKm =>
      $composableBuilder(column: $table.bestKm, builder: (column) => column);

  GeneratedColumn<int> get firstArrivedUtc => $composableBuilder(
    column: $table.firstArrivedUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastArrivedUtc => $composableBuilder(
    column: $table.lastArrivedUtc,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get seen =>
      $composableBuilder(column: $table.seen, builder: (column) => column);
}

class $$PaintingsOwnedTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PaintingsOwnedTable,
          PaintingOwnedRow,
          $$PaintingsOwnedTableFilterComposer,
          $$PaintingsOwnedTableOrderingComposer,
          $$PaintingsOwnedTableAnnotationComposer,
          $$PaintingsOwnedTableCreateCompanionBuilder,
          $$PaintingsOwnedTableUpdateCompanionBuilder,
          (
            PaintingOwnedRow,
            BaseReferences<_$AppDb, $PaintingsOwnedTable, PaintingOwnedRow>,
          ),
          PaintingOwnedRow,
          PrefetchHooks Function()
        > {
  $$PaintingsOwnedTableTableManager(_$AppDb db, $PaintingsOwnedTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaintingsOwnedTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaintingsOwnedTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaintingsOwnedTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> landmarkId = const Value.absent(),
                Value<int> visits = const Value.absent(),
                Value<Frame> frame = const Value.absent(),
                Value<double> bestKm = const Value.absent(),
                Value<int> firstArrivedUtc = const Value.absent(),
                Value<int> lastArrivedUtc = const Value.absent(),
                Value<bool> seen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaintingsOwnedCompanion(
                landmarkId: landmarkId,
                visits: visits,
                frame: frame,
                bestKm: bestKm,
                firstArrivedUtc: firstArrivedUtc,
                lastArrivedUtc: lastArrivedUtc,
                seen: seen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String landmarkId,
                required int visits,
                required Frame frame,
                required double bestKm,
                required int firstArrivedUtc,
                required int lastArrivedUtc,
                Value<bool> seen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaintingsOwnedCompanion.insert(
                landmarkId: landmarkId,
                visits: visits,
                frame: frame,
                bestKm: bestKm,
                firstArrivedUtc: firstArrivedUtc,
                lastArrivedUtc: lastArrivedUtc,
                seen: seen,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PaintingsOwnedTable, PaintingOwnedRow>(table),
                  BaseReferences<
                    _$AppDb,
                    $PaintingsOwnedTable,
                    PaintingOwnedRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PaintingsOwnedTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PaintingsOwnedTable,
      PaintingOwnedRow,
      $$PaintingsOwnedTableFilterComposer,
      $$PaintingsOwnedTableOrderingComposer,
      $$PaintingsOwnedTableAnnotationComposer,
      $$PaintingsOwnedTableCreateCompanionBuilder,
      $$PaintingsOwnedTableUpdateCompanionBuilder,
      (
        PaintingOwnedRow,
        BaseReferences<_$AppDb, $PaintingsOwnedTable, PaintingOwnedRow>,
      ),
      PaintingOwnedRow,
      PrefetchHooks Function()
    >;
typedef $$PropsOwnedTableCreateCompanionBuilder = PropsOwnedCompanion Function({
  required String propId,
  required int unlockedUtc,
  Value<bool> seen,
  Value<int> rowid,
});
typedef $$PropsOwnedTableUpdateCompanionBuilder = PropsOwnedCompanion Function({
  Value<String> propId,
  Value<int> unlockedUtc,
  Value<bool> seen,
  Value<int> rowid,
});

class $$PropsOwnedTableFilterComposer
    extends Composer<_$AppDb, $PropsOwnedTable> {
  $$PropsOwnedTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get propId => $composableBuilder(
    column: $table.propId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unlockedUtc => $composableBuilder(
    column: $table.unlockedUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get seen => $composableBuilder(
    column: $table.seen,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PropsOwnedTableOrderingComposer
    extends Composer<_$AppDb, $PropsOwnedTable> {
  $$PropsOwnedTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get propId => $composableBuilder(
    column: $table.propId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unlockedUtc => $composableBuilder(
    column: $table.unlockedUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get seen => $composableBuilder(
    column: $table.seen,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PropsOwnedTableAnnotationComposer
    extends Composer<_$AppDb, $PropsOwnedTable> {
  $$PropsOwnedTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get propId =>
      $composableBuilder(column: $table.propId, builder: (column) => column);

  GeneratedColumn<int> get unlockedUtc => $composableBuilder(
    column: $table.unlockedUtc,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get seen =>
      $composableBuilder(column: $table.seen, builder: (column) => column);
}

class $$PropsOwnedTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PropsOwnedTable,
          PropOwnedRow,
          $$PropsOwnedTableFilterComposer,
          $$PropsOwnedTableOrderingComposer,
          $$PropsOwnedTableAnnotationComposer,
          $$PropsOwnedTableCreateCompanionBuilder,
          $$PropsOwnedTableUpdateCompanionBuilder,
          (
            PropOwnedRow,
            BaseReferences<_$AppDb, $PropsOwnedTable, PropOwnedRow>,
          ),
          PropOwnedRow,
          PrefetchHooks Function()
        > {
  $$PropsOwnedTableTableManager(_$AppDb db, $PropsOwnedTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PropsOwnedTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PropsOwnedTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PropsOwnedTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> propId = const Value.absent(),
                Value<int> unlockedUtc = const Value.absent(),
                Value<bool> seen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PropsOwnedCompanion(
                propId: propId,
                unlockedUtc: unlockedUtc,
                seen: seen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String propId,
                required int unlockedUtc,
                Value<bool> seen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PropsOwnedCompanion.insert(
                propId: propId,
                unlockedUtc: unlockedUtc,
                seen: seen,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PropsOwnedTable, PropOwnedRow>(table),
                  BaseReferences<_$AppDb, $PropsOwnedTable, PropOwnedRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PropsOwnedTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PropsOwnedTable,
      PropOwnedRow,
      $$PropsOwnedTableFilterComposer,
      $$PropsOwnedTableOrderingComposer,
      $$PropsOwnedTableAnnotationComposer,
      $$PropsOwnedTableCreateCompanionBuilder,
      $$PropsOwnedTableUpdateCompanionBuilder,
      (PropOwnedRow, BaseReferences<_$AppDb, $PropsOwnedTable, PropOwnedRow>),
      PropOwnedRow,
      PrefetchHooks Function()
    >;
typedef $$ProfileTableCreateCompanionBuilder = ProfileCompanion Function({
  Value<int> id,
  Value<String?> homeName,
  Value<double?> homeLat,
  Value<double?> homeLng,
  Value<String?> homeId,
  Value<int?> ageConfirmedAt,
  Value<String?> installId,
  Value<String?> nickname,
  Value<String?> look,
  Value<int?> onboardedAt,
  Value<int?> linkConsentAt,
  Value<int?> guestbookConsentAt,
});
typedef $$ProfileTableUpdateCompanionBuilder = ProfileCompanion Function({
  Value<int> id,
  Value<String?> homeName,
  Value<double?> homeLat,
  Value<double?> homeLng,
  Value<String?> homeId,
  Value<int?> ageConfirmedAt,
  Value<String?> installId,
  Value<String?> nickname,
  Value<String?> look,
  Value<int?> onboardedAt,
  Value<int?> linkConsentAt,
  Value<int?> guestbookConsentAt,
});

class $$ProfileTableFilterComposer extends Composer<_$AppDb, $ProfileTable> {
  $$ProfileTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get homeName => $composableBuilder(
    column: $table.homeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get homeLat => $composableBuilder(
    column: $table.homeLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get homeLng => $composableBuilder(
    column: $table.homeLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ageConfirmedAt => $composableBuilder(
    column: $table.ageConfirmedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get installId => $composableBuilder(
    column: $table.installId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get look => $composableBuilder(
    column: $table.look,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get onboardedAt => $composableBuilder(
    column: $table.onboardedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get linkConsentAt => $composableBuilder(
    column: $table.linkConsentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get guestbookConsentAt => $composableBuilder(
    column: $table.guestbookConsentAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfileTableOrderingComposer extends Composer<_$AppDb, $ProfileTable> {
  $$ProfileTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get homeName => $composableBuilder(
    column: $table.homeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get homeLat => $composableBuilder(
    column: $table.homeLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get homeLng => $composableBuilder(
    column: $table.homeLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get homeId => $composableBuilder(
    column: $table.homeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ageConfirmedAt => $composableBuilder(
    column: $table.ageConfirmedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get installId => $composableBuilder(
    column: $table.installId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get look => $composableBuilder(
    column: $table.look,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get onboardedAt => $composableBuilder(
    column: $table.onboardedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get linkConsentAt => $composableBuilder(
    column: $table.linkConsentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get guestbookConsentAt => $composableBuilder(
    column: $table.guestbookConsentAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfileTableAnnotationComposer
    extends Composer<_$AppDb, $ProfileTable> {
  $$ProfileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get homeName =>
      $composableBuilder(column: $table.homeName, builder: (column) => column);

  GeneratedColumn<double> get homeLat =>
      $composableBuilder(column: $table.homeLat, builder: (column) => column);

  GeneratedColumn<double> get homeLng =>
      $composableBuilder(column: $table.homeLng, builder: (column) => column);

  GeneratedColumn<String> get homeId =>
      $composableBuilder(column: $table.homeId, builder: (column) => column);

  GeneratedColumn<int> get ageConfirmedAt => $composableBuilder(
    column: $table.ageConfirmedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get installId =>
      $composableBuilder(column: $table.installId, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get look =>
      $composableBuilder(column: $table.look, builder: (column) => column);

  GeneratedColumn<int> get onboardedAt => $composableBuilder(
    column: $table.onboardedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get linkConsentAt => $composableBuilder(
    column: $table.linkConsentAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get guestbookConsentAt => $composableBuilder(
    column: $table.guestbookConsentAt,
    builder: (column) => column,
  );
}

class $$ProfileTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ProfileTable,
          ProfileRow,
          $$ProfileTableFilterComposer,
          $$ProfileTableOrderingComposer,
          $$ProfileTableAnnotationComposer,
          $$ProfileTableCreateCompanionBuilder,
          $$ProfileTableUpdateCompanionBuilder,
          (ProfileRow, BaseReferences<_$AppDb, $ProfileTable, ProfileRow>),
          ProfileRow,
          PrefetchHooks Function()
        > {
  $$ProfileTableTableManager(_$AppDb db, $ProfileTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> homeName = const Value.absent(),
                Value<double?> homeLat = const Value.absent(),
                Value<double?> homeLng = const Value.absent(),
                Value<String?> homeId = const Value.absent(),
                Value<int?> ageConfirmedAt = const Value.absent(),
                Value<String?> installId = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                Value<String?> look = const Value.absent(),
                Value<int?> onboardedAt = const Value.absent(),
                Value<int?> linkConsentAt = const Value.absent(),
                Value<int?> guestbookConsentAt = const Value.absent(),
              }) => ProfileCompanion(
                id: id,
                homeName: homeName,
                homeLat: homeLat,
                homeLng: homeLng,
                homeId: homeId,
                ageConfirmedAt: ageConfirmedAt,
                installId: installId,
                nickname: nickname,
                look: look,
                onboardedAt: onboardedAt,
                linkConsentAt: linkConsentAt,
                guestbookConsentAt: guestbookConsentAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> homeName = const Value.absent(),
                Value<double?> homeLat = const Value.absent(),
                Value<double?> homeLng = const Value.absent(),
                Value<String?> homeId = const Value.absent(),
                Value<int?> ageConfirmedAt = const Value.absent(),
                Value<String?> installId = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                Value<String?> look = const Value.absent(),
                Value<int?> onboardedAt = const Value.absent(),
                Value<int?> linkConsentAt = const Value.absent(),
                Value<int?> guestbookConsentAt = const Value.absent(),
              }) => ProfileCompanion.insert(
                id: id,
                homeName: homeName,
                homeLat: homeLat,
                homeLng: homeLng,
                homeId: homeId,
                ageConfirmedAt: ageConfirmedAt,
                installId: installId,
                nickname: nickname,
                look: look,
                onboardedAt: onboardedAt,
                linkConsentAt: linkConsentAt,
                guestbookConsentAt: guestbookConsentAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfileTable, ProfileRow>(table),
                  BaseReferences<_$AppDb, $ProfileTable, ProfileRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfileTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ProfileTable,
      ProfileRow,
      $$ProfileTableFilterComposer,
      $$ProfileTableOrderingComposer,
      $$ProfileTableAnnotationComposer,
      $$ProfileTableCreateCompanionBuilder,
      $$ProfileTableUpdateCompanionBuilder,
      (ProfileRow, BaseReferences<_$AppDb, $ProfileTable, ProfileRow>),
      ProfileRow,
      PrefetchHooks Function()
    >;
typedef $$WallSlotsTableCreateCompanionBuilder = WallSlotsCompanion Function({
  Value<int> slot,
  required String landmarkId,
});
typedef $$WallSlotsTableUpdateCompanionBuilder = WallSlotsCompanion Function({
  Value<int> slot,
  Value<String> landmarkId,
});

class $$WallSlotsTableFilterComposer
    extends Composer<_$AppDb, $WallSlotsTable> {
  $$WallSlotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get landmarkId => $composableBuilder(
    column: $table.landmarkId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WallSlotsTableOrderingComposer
    extends Composer<_$AppDb, $WallSlotsTable> {
  $$WallSlotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get landmarkId => $composableBuilder(
    column: $table.landmarkId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WallSlotsTableAnnotationComposer
    extends Composer<_$AppDb, $WallSlotsTable> {
  $$WallSlotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get landmarkId => $composableBuilder(
    column: $table.landmarkId,
    builder: (column) => column,
  );
}

class $$WallSlotsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $WallSlotsTable,
          WallSlotRow,
          $$WallSlotsTableFilterComposer,
          $$WallSlotsTableOrderingComposer,
          $$WallSlotsTableAnnotationComposer,
          $$WallSlotsTableCreateCompanionBuilder,
          $$WallSlotsTableUpdateCompanionBuilder,
          (WallSlotRow, BaseReferences<_$AppDb, $WallSlotsTable, WallSlotRow>),
          WallSlotRow,
          PrefetchHooks Function()
        > {
  $$WallSlotsTableTableManager(_$AppDb db, $WallSlotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WallSlotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WallSlotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WallSlotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> slot = const Value.absent(),
            Value<String> landmarkId = const Value.absent(),
          }) => WallSlotsCompanion(slot: slot, landmarkId: landmarkId),
          createCompanionCallback: ({
            Value<int> slot = const Value.absent(),
            required String landmarkId,
          }) => WallSlotsCompanion.insert(slot: slot, landmarkId: landmarkId),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WallSlotsTable, WallSlotRow>(table),
                  BaseReferences<_$AppDb, $WallSlotsTable, WallSlotRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WallSlotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $WallSlotsTable,
      WallSlotRow,
      $$WallSlotsTableFilterComposer,
      $$WallSlotsTableOrderingComposer,
      $$WallSlotsTableAnnotationComposer,
      $$WallSlotsTableCreateCompanionBuilder,
      $$WallSlotsTableUpdateCompanionBuilder,
      (WallSlotRow, BaseReferences<_$AppDb, $WallSlotsTable, WallSlotRow>),
      WallSlotRow,
      PrefetchHooks Function()
    >;
typedef $$GuestbookTicketsTableCreateCompanionBuilder =
    GuestbookTicketsCompanion Function({
      required String id,
      required TicketKind kind,
      required String scope,
      required int openedUtc,
      Value<int?> usedUtc,
      Value<int?> closedUtc,
      Value<int> rowid,
    });
typedef $$GuestbookTicketsTableUpdateCompanionBuilder =
    GuestbookTicketsCompanion Function({
      Value<String> id,
      Value<TicketKind> kind,
      Value<String> scope,
      Value<int> openedUtc,
      Value<int?> usedUtc,
      Value<int?> closedUtc,
      Value<int> rowid,
    });

class $$GuestbookTicketsTableFilterComposer
    extends Composer<_$AppDb, $GuestbookTicketsTable> {
  $$GuestbookTicketsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TicketKind, TicketKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openedUtc => $composableBuilder(
    column: $table.openedUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usedUtc => $composableBuilder(
    column: $table.usedUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get closedUtc => $composableBuilder(
    column: $table.closedUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GuestbookTicketsTableOrderingComposer
    extends Composer<_$AppDb, $GuestbookTicketsTable> {
  $$GuestbookTicketsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openedUtc => $composableBuilder(
    column: $table.openedUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usedUtc => $composableBuilder(
    column: $table.usedUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get closedUtc => $composableBuilder(
    column: $table.closedUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GuestbookTicketsTableAnnotationComposer
    extends Composer<_$AppDb, $GuestbookTicketsTable> {
  $$GuestbookTicketsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TicketKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<int> get openedUtc =>
      $composableBuilder(column: $table.openedUtc, builder: (column) => column);

  GeneratedColumn<int> get usedUtc =>
      $composableBuilder(column: $table.usedUtc, builder: (column) => column);

  GeneratedColumn<int> get closedUtc =>
      $composableBuilder(column: $table.closedUtc, builder: (column) => column);
}

class $$GuestbookTicketsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $GuestbookTicketsTable,
          GuestbookTicketRow,
          $$GuestbookTicketsTableFilterComposer,
          $$GuestbookTicketsTableOrderingComposer,
          $$GuestbookTicketsTableAnnotationComposer,
          $$GuestbookTicketsTableCreateCompanionBuilder,
          $$GuestbookTicketsTableUpdateCompanionBuilder,
          (
            GuestbookTicketRow,
            BaseReferences<_$AppDb, $GuestbookTicketsTable, GuestbookTicketRow>,
          ),
          GuestbookTicketRow,
          PrefetchHooks Function()
        > {
  $$GuestbookTicketsTableTableManager(_$AppDb db, $GuestbookTicketsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GuestbookTicketsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GuestbookTicketsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GuestbookTicketsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<TicketKind> kind = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<int> openedUtc = const Value.absent(),
                Value<int?> usedUtc = const Value.absent(),
                Value<int?> closedUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GuestbookTicketsCompanion(
                id: id,
                kind: kind,
                scope: scope,
                openedUtc: openedUtc,
                usedUtc: usedUtc,
                closedUtc: closedUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required TicketKind kind,
                required String scope,
                required int openedUtc,
                Value<int?> usedUtc = const Value.absent(),
                Value<int?> closedUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GuestbookTicketsCompanion.insert(
                id: id,
                kind: kind,
                scope: scope,
                openedUtc: openedUtc,
                usedUtc: usedUtc,
                closedUtc: closedUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GuestbookTicketsTable, GuestbookTicketRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDb,
                    $GuestbookTicketsTable,
                    GuestbookTicketRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GuestbookTicketsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $GuestbookTicketsTable,
      GuestbookTicketRow,
      $$GuestbookTicketsTableFilterComposer,
      $$GuestbookTicketsTableOrderingComposer,
      $$GuestbookTicketsTableAnnotationComposer,
      $$GuestbookTicketsTableCreateCompanionBuilder,
      $$GuestbookTicketsTableUpdateCompanionBuilder,
      (
        GuestbookTicketRow,
        BaseReferences<_$AppDb, $GuestbookTicketsTable, GuestbookTicketRow>,
      ),
      GuestbookTicketRow,
      PrefetchHooks Function()
    >;
typedef $$GuestbookPostsTableCreateCompanionBuilder =
    GuestbookPostsCompanion Function({
      required String ticketId,
      required String scope,
      required String body,
      required int createdUtc,
      required PostStatus status,
      Value<int> rowid,
    });
typedef $$GuestbookPostsTableUpdateCompanionBuilder =
    GuestbookPostsCompanion Function({
      Value<String> ticketId,
      Value<String> scope,
      Value<String> body,
      Value<int> createdUtc,
      Value<PostStatus> status,
      Value<int> rowid,
    });

class $$GuestbookPostsTableFilterComposer
    extends Composer<_$AppDb, $GuestbookPostsTable> {
  $$GuestbookPostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ticketId => $composableBuilder(
    column: $table.ticketId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdUtc => $composableBuilder(
    column: $table.createdUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PostStatus, PostStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$GuestbookPostsTableOrderingComposer
    extends Composer<_$AppDb, $GuestbookPostsTable> {
  $$GuestbookPostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ticketId => $composableBuilder(
    column: $table.ticketId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdUtc => $composableBuilder(
    column: $table.createdUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GuestbookPostsTableAnnotationComposer
    extends Composer<_$AppDb, $GuestbookPostsTable> {
  $$GuestbookPostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ticketId =>
      $composableBuilder(column: $table.ticketId, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get createdUtc => $composableBuilder(
    column: $table.createdUtc,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<PostStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$GuestbookPostsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $GuestbookPostsTable,
          GuestbookPostRow,
          $$GuestbookPostsTableFilterComposer,
          $$GuestbookPostsTableOrderingComposer,
          $$GuestbookPostsTableAnnotationComposer,
          $$GuestbookPostsTableCreateCompanionBuilder,
          $$GuestbookPostsTableUpdateCompanionBuilder,
          (
            GuestbookPostRow,
            BaseReferences<_$AppDb, $GuestbookPostsTable, GuestbookPostRow>,
          ),
          GuestbookPostRow,
          PrefetchHooks Function()
        > {
  $$GuestbookPostsTableTableManager(_$AppDb db, $GuestbookPostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GuestbookPostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GuestbookPostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GuestbookPostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ticketId = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> createdUtc = const Value.absent(),
                Value<PostStatus> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GuestbookPostsCompanion(
                ticketId: ticketId,
                scope: scope,
                body: body,
                createdUtc: createdUtc,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ticketId,
                required String scope,
                required String body,
                required int createdUtc,
                required PostStatus status,
                Value<int> rowid = const Value.absent(),
              }) => GuestbookPostsCompanion.insert(
                ticketId: ticketId,
                scope: scope,
                body: body,
                createdUtc: createdUtc,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GuestbookPostsTable, GuestbookPostRow>(table),
                  BaseReferences<
                    _$AppDb,
                    $GuestbookPostsTable,
                    GuestbookPostRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GuestbookPostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $GuestbookPostsTable,
      GuestbookPostRow,
      $$GuestbookPostsTableFilterComposer,
      $$GuestbookPostsTableOrderingComposer,
      $$GuestbookPostsTableAnnotationComposer,
      $$GuestbookPostsTableCreateCompanionBuilder,
      $$GuestbookPostsTableUpdateCompanionBuilder,
      (
        GuestbookPostRow,
        BaseReferences<_$AppDb, $GuestbookPostsTable, GuestbookPostRow>,
      ),
      GuestbookPostRow,
      PrefetchHooks Function()
    >;
typedef $$NotificationLogTableCreateCompanionBuilder =
    NotificationLogCompanion Function({
      Value<int> id,
      required NoticeKind kind,
      required String refKey,
      required int atUtc,
      required NoticeStatus status,
    });
typedef $$NotificationLogTableUpdateCompanionBuilder =
    NotificationLogCompanion Function({
      Value<int> id,
      Value<NoticeKind> kind,
      Value<String> refKey,
      Value<int> atUtc,
      Value<NoticeStatus> status,
    });

class $$NotificationLogTableFilterComposer
    extends Composer<_$AppDb, $NotificationLogTable> {
  $$NotificationLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<NoticeKind, NoticeKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get refKey => $composableBuilder(
    column: $table.refKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atUtc => $composableBuilder(
    column: $table.atUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<NoticeStatus, NoticeStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$NotificationLogTableOrderingComposer
    extends Composer<_$AppDb, $NotificationLogTable> {
  $$NotificationLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refKey => $composableBuilder(
    column: $table.refKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atUtc => $composableBuilder(
    column: $table.atUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationLogTableAnnotationComposer
    extends Composer<_$AppDb, $NotificationLogTable> {
  $$NotificationLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<NoticeKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get refKey =>
      $composableBuilder(column: $table.refKey, builder: (column) => column);

  GeneratedColumn<int> get atUtc =>
      $composableBuilder(column: $table.atUtc, builder: (column) => column);

  GeneratedColumnWithTypeConverter<NoticeStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$NotificationLogTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $NotificationLogTable,
          NotificationLogRow,
          $$NotificationLogTableFilterComposer,
          $$NotificationLogTableOrderingComposer,
          $$NotificationLogTableAnnotationComposer,
          $$NotificationLogTableCreateCompanionBuilder,
          $$NotificationLogTableUpdateCompanionBuilder,
          (
            NotificationLogRow,
            BaseReferences<_$AppDb, $NotificationLogTable, NotificationLogRow>,
          ),
          NotificationLogRow,
          PrefetchHooks Function()
        > {
  $$NotificationLogTableTableManager(_$AppDb db, $NotificationLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<NoticeKind> kind = const Value.absent(),
                Value<String> refKey = const Value.absent(),
                Value<int> atUtc = const Value.absent(),
                Value<NoticeStatus> status = const Value.absent(),
              }) => NotificationLogCompanion(
                id: id,
                kind: kind,
                refKey: refKey,
                atUtc: atUtc,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required NoticeKind kind,
                required String refKey,
                required int atUtc,
                required NoticeStatus status,
              }) => NotificationLogCompanion.insert(
                id: id,
                kind: kind,
                refKey: refKey,
                atUtc: atUtc,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotificationLogTable, NotificationLogRow>(table),
                  BaseReferences<
                    _$AppDb,
                    $NotificationLogTable,
                    NotificationLogRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $NotificationLogTable,
      NotificationLogRow,
      $$NotificationLogTableFilterComposer,
      $$NotificationLogTableOrderingComposer,
      $$NotificationLogTableAnnotationComposer,
      $$NotificationLogTableCreateCompanionBuilder,
      $$NotificationLogTableUpdateCompanionBuilder,
      (
        NotificationLogRow,
        BaseReferences<_$AppDb, $NotificationLogTable, NotificationLogRow>,
      ),
      NotificationLogRow,
      PrefetchHooks Function()
    >;
typedef $$NotificationSettingsTableCreateCompanionBuilder =
    NotificationSettingsCompanion Function({
      Value<int> id,
      Value<bool> allOn,
      Value<bool> n1On,
      Value<bool> n2On,
      Value<bool> n3On,
      Value<bool> n4On,
      Value<bool> n5On,
    });
typedef $$NotificationSettingsTableUpdateCompanionBuilder =
    NotificationSettingsCompanion Function({
      Value<int> id,
      Value<bool> allOn,
      Value<bool> n1On,
      Value<bool> n2On,
      Value<bool> n3On,
      Value<bool> n4On,
      Value<bool> n5On,
    });

class $$NotificationSettingsTableFilterComposer
    extends Composer<_$AppDb, $NotificationSettingsTable> {
  $$NotificationSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allOn => $composableBuilder(
    column: $table.allOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get n1On => $composableBuilder(
    column: $table.n1On,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get n2On => $composableBuilder(
    column: $table.n2On,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get n3On => $composableBuilder(
    column: $table.n3On,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get n4On => $composableBuilder(
    column: $table.n4On,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get n5On => $composableBuilder(
    column: $table.n5On,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationSettingsTableOrderingComposer
    extends Composer<_$AppDb, $NotificationSettingsTable> {
  $$NotificationSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allOn => $composableBuilder(
    column: $table.allOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get n1On => $composableBuilder(
    column: $table.n1On,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get n2On => $composableBuilder(
    column: $table.n2On,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get n3On => $composableBuilder(
    column: $table.n3On,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get n4On => $composableBuilder(
    column: $table.n4On,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get n5On => $composableBuilder(
    column: $table.n5On,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationSettingsTableAnnotationComposer
    extends Composer<_$AppDb, $NotificationSettingsTable> {
  $$NotificationSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get allOn =>
      $composableBuilder(column: $table.allOn, builder: (column) => column);

  GeneratedColumn<bool> get n1On =>
      $composableBuilder(column: $table.n1On, builder: (column) => column);

  GeneratedColumn<bool> get n2On =>
      $composableBuilder(column: $table.n2On, builder: (column) => column);

  GeneratedColumn<bool> get n3On =>
      $composableBuilder(column: $table.n3On, builder: (column) => column);

  GeneratedColumn<bool> get n4On =>
      $composableBuilder(column: $table.n4On, builder: (column) => column);

  GeneratedColumn<bool> get n5On =>
      $composableBuilder(column: $table.n5On, builder: (column) => column);
}

class $$NotificationSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $NotificationSettingsTable,
          NotificationSettingsRow,
          $$NotificationSettingsTableFilterComposer,
          $$NotificationSettingsTableOrderingComposer,
          $$NotificationSettingsTableAnnotationComposer,
          $$NotificationSettingsTableCreateCompanionBuilder,
          $$NotificationSettingsTableUpdateCompanionBuilder,
          (
            NotificationSettingsRow,
            BaseReferences<
              _$AppDb,
              $NotificationSettingsTable,
              NotificationSettingsRow
            >,
          ),
          NotificationSettingsRow,
          PrefetchHooks Function()
        > {
  $$NotificationSettingsTableTableManager(
    _$AppDb db,
    $NotificationSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationSettingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationSettingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> allOn = const Value.absent(),
                Value<bool> n1On = const Value.absent(),
                Value<bool> n2On = const Value.absent(),
                Value<bool> n3On = const Value.absent(),
                Value<bool> n4On = const Value.absent(),
                Value<bool> n5On = const Value.absent(),
              }) => NotificationSettingsCompanion(
                id: id,
                allOn: allOn,
                n1On: n1On,
                n2On: n2On,
                n3On: n3On,
                n4On: n4On,
                n5On: n5On,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> allOn = const Value.absent(),
                Value<bool> n1On = const Value.absent(),
                Value<bool> n2On = const Value.absent(),
                Value<bool> n3On = const Value.absent(),
                Value<bool> n4On = const Value.absent(),
                Value<bool> n5On = const Value.absent(),
              }) => NotificationSettingsCompanion.insert(
                id: id,
                allOn: allOn,
                n1On: n1On,
                n2On: n2On,
                n3On: n3On,
                n4On: n4On,
                n5On: n5On,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $NotificationSettingsTable,
                    NotificationSettingsRow
                  >(table),
                  BaseReferences<
                    _$AppDb,
                    $NotificationSettingsTable,
                    NotificationSettingsRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $NotificationSettingsTable,
      NotificationSettingsRow,
      $$NotificationSettingsTableFilterComposer,
      $$NotificationSettingsTableOrderingComposer,
      $$NotificationSettingsTableAnnotationComposer,
      $$NotificationSettingsTableCreateCompanionBuilder,
      $$NotificationSettingsTableUpdateCompanionBuilder,
      (
        NotificationSettingsRow,
        BaseReferences<
          _$AppDb,
          $NotificationSettingsTable,
          NotificationSettingsRow
        >,
      ),
      NotificationSettingsRow,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$StepMinutesTableTableManager get stepMinutes =>
      $$StepMinutesTableTableManager(_db, _db.stepMinutes);
  $$DaySummariesTableTableManager get daySummaries =>
      $$DaySummariesTableTableManager(_db, _db.daySummaries);
  $$WalkSessionsTableTableManager get walkSessions =>
      $$WalkSessionsTableTableManager(_db, _db.walkSessions);
  $$JourneysTableTableManager get journeys =>
      $$JourneysTableTableManager(_db, _db.journeys);
  $$TravelFundTableTableManager get travelFund =>
      $$TravelFundTableTableManager(_db, _db.travelFund);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$PaintingsOwnedTableTableManager get paintingsOwned =>
      $$PaintingsOwnedTableTableManager(_db, _db.paintingsOwned);
  $$PropsOwnedTableTableManager get propsOwned =>
      $$PropsOwnedTableTableManager(_db, _db.propsOwned);
  $$ProfileTableTableManager get profile =>
      $$ProfileTableTableManager(_db, _db.profile);
  $$WallSlotsTableTableManager get wallSlots =>
      $$WallSlotsTableTableManager(_db, _db.wallSlots);
  $$GuestbookTicketsTableTableManager get guestbookTickets =>
      $$GuestbookTicketsTableTableManager(_db, _db.guestbookTickets);
  $$GuestbookPostsTableTableManager get guestbookPosts =>
      $$GuestbookPostsTableTableManager(_db, _db.guestbookPosts);
  $$NotificationLogTableTableManager get notificationLog =>
      $$NotificationLogTableTableManager(_db, _db.notificationLog);
  $$NotificationSettingsTableTableManager get notificationSettings =>
      $$NotificationSettingsTableTableManager(_db, _db.notificationSettings);
}
