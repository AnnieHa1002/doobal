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
          ..write('arrivalShown: $arrivalShown')
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
          other.arrivalShown == this.arrivalShown);
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lastFetchedUtc,
    firstRecordDay,
    installUtc,
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
  const SyncStateRow({
    required this.id,
    this.lastFetchedUtc,
    required this.firstRecordDay,
    required this.installUtc,
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
    };
  }

  SyncStateRow copyWith({
    int? id,
    Value<int?> lastFetchedUtc = const Value.absent(),
    String? firstRecordDay,
    int? installUtc,
  }) => SyncStateRow(
    id: id ?? this.id,
    lastFetchedUtc: lastFetchedUtc.present
        ? lastFetchedUtc.value
        : this.lastFetchedUtc,
    firstRecordDay: firstRecordDay ?? this.firstRecordDay,
    installUtc: installUtc ?? this.installUtc,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('id: $id, ')
          ..write('lastFetchedUtc: $lastFetchedUtc, ')
          ..write('firstRecordDay: $firstRecordDay, ')
          ..write('installUtc: $installUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, lastFetchedUtc, firstRecordDay, installUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.id == this.id &&
          other.lastFetchedUtc == this.lastFetchedUtc &&
          other.firstRecordDay == this.firstRecordDay &&
          other.installUtc == this.installUtc);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<int> id;
  final Value<int?> lastFetchedUtc;
  final Value<String> firstRecordDay;
  final Value<int> installUtc;
  const SyncStateCompanion({
    this.id = const Value.absent(),
    this.lastFetchedUtc = const Value.absent(),
    this.firstRecordDay = const Value.absent(),
    this.installUtc = const Value.absent(),
  });
  SyncStateCompanion.insert({
    this.id = const Value.absent(),
    this.lastFetchedUtc = const Value.absent(),
    required String firstRecordDay,
    required int installUtc,
  }) : firstRecordDay = Value(firstRecordDay),
       installUtc = Value(installUtc);
  static Insertable<SyncStateRow> custom({
    Expression<int>? id,
    Expression<int>? lastFetchedUtc,
    Expression<String>? firstRecordDay,
    Expression<int>? installUtc,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lastFetchedUtc != null) 'last_fetched_utc': lastFetchedUtc,
      if (firstRecordDay != null) 'first_record_day': firstRecordDay,
      if (installUtc != null) 'install_utc': installUtc,
    });
  }

  SyncStateCompanion copyWith({
    Value<int>? id,
    Value<int?>? lastFetchedUtc,
    Value<String>? firstRecordDay,
    Value<int>? installUtc,
  }) {
    return SyncStateCompanion(
      id: id ?? this.id,
      lastFetchedUtc: lastFetchedUtc ?? this.lastFetchedUtc,
      firstRecordDay: firstRecordDay ?? this.firstRecordDay,
      installUtc: installUtc ?? this.installUtc,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('id: $id, ')
          ..write('lastFetchedUtc: $lastFetchedUtc, ')
          ..write('firstRecordDay: $firstRecordDay, ')
          ..write('installUtc: $installUtc')
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
  @override
  List<GeneratedColumn> get $columns => [id, homeName, homeLat, homeLng];
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
    );
  }

  @override
  $ProfileTable createAlias(String alias) {
    return $ProfileTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final int id;
  final String? homeName;
  final double? homeLat;
  final double? homeLng;
  const ProfileRow({
    required this.id,
    this.homeName,
    this.homeLat,
    this.homeLng,
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
    };
  }

  ProfileRow copyWith({
    int? id,
    Value<String?> homeName = const Value.absent(),
    Value<double?> homeLat = const Value.absent(),
    Value<double?> homeLng = const Value.absent(),
  }) => ProfileRow(
    id: id ?? this.id,
    homeName: homeName.present ? homeName.value : this.homeName,
    homeLat: homeLat.present ? homeLat.value : this.homeLat,
    homeLng: homeLng.present ? homeLng.value : this.homeLng,
  );
  ProfileRow copyWithCompanion(ProfileCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      homeName: data.homeName.present ? data.homeName.value : this.homeName,
      homeLat: data.homeLat.present ? data.homeLat.value : this.homeLat,
      homeLng: data.homeLng.present ? data.homeLng.value : this.homeLng,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('homeName: $homeName, ')
          ..write('homeLat: $homeLat, ')
          ..write('homeLng: $homeLng')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, homeName, homeLat, homeLng);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.homeName == this.homeName &&
          other.homeLat == this.homeLat &&
          other.homeLng == this.homeLng);
}

class ProfileCompanion extends UpdateCompanion<ProfileRow> {
  final Value<int> id;
  final Value<String?> homeName;
  final Value<double?> homeLat;
  final Value<double?> homeLng;
  const ProfileCompanion({
    this.id = const Value.absent(),
    this.homeName = const Value.absent(),
    this.homeLat = const Value.absent(),
    this.homeLng = const Value.absent(),
  });
  ProfileCompanion.insert({
    this.id = const Value.absent(),
    this.homeName = const Value.absent(),
    this.homeLat = const Value.absent(),
    this.homeLng = const Value.absent(),
  });
  static Insertable<ProfileRow> custom({
    Expression<int>? id,
    Expression<String>? homeName,
    Expression<double>? homeLat,
    Expression<double>? homeLng,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (homeName != null) 'home_name': homeName,
      if (homeLat != null) 'home_lat': homeLat,
      if (homeLng != null) 'home_lng': homeLng,
    });
  }

  ProfileCompanion copyWith({
    Value<int>? id,
    Value<String?>? homeName,
    Value<double?>? homeLat,
    Value<double?>? homeLng,
  }) {
    return ProfileCompanion(
      id: id ?? this.id,
      homeName: homeName ?? this.homeName,
      homeLat: homeLat ?? this.homeLat,
      homeLng: homeLng ?? this.homeLng,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfileCompanion(')
          ..write('id: $id, ')
          ..write('homeName: $homeName, ')
          ..write('homeLat: $homeLat, ')
          ..write('homeLng: $homeLng')
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
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<int> id,
  Value<int?> lastFetchedUtc,
  Value<String> firstRecordDay,
  Value<int> installUtc,
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
              }) => SyncStateCompanion(
                id: id,
                lastFetchedUtc: lastFetchedUtc,
                firstRecordDay: firstRecordDay,
                installUtc: installUtc,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> lastFetchedUtc = const Value.absent(),
                required String firstRecordDay,
                required int installUtc,
              }) => SyncStateCompanion.insert(
                id: id,
                lastFetchedUtc: lastFetchedUtc,
                firstRecordDay: firstRecordDay,
                installUtc: installUtc,
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
});
typedef $$ProfileTableUpdateCompanionBuilder = ProfileCompanion Function({
  Value<int> id,
  Value<String?> homeName,
  Value<double?> homeLat,
  Value<double?> homeLng,
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
              }) => ProfileCompanion(
                id: id,
                homeName: homeName,
                homeLat: homeLat,
                homeLng: homeLng,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> homeName = const Value.absent(),
                Value<double?> homeLat = const Value.absent(),
                Value<double?> homeLng = const Value.absent(),
              }) => ProfileCompanion.insert(
                id: id,
                homeName: homeName,
                homeLat: homeLat,
                homeLng: homeLng,
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
}
