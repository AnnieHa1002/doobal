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
    );
  }

  @override
  $JourneysTable createAlias(String alias) {
    return $JourneysTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<JourneyStatus, String, String> $converterstatus =
      const EnumNameConverter<JourneyStatus>(JourneyStatus.values);
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
          ..write('arrivedUtc: $arrivedUtc')
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
          other.arrivedUtc == this.arrivedUtc);
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

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $StepMinutesTable stepMinutes = $StepMinutesTable(this);
  late final $DaySummariesTable daySummaries = $DaySummariesTable(this);
  late final $WalkSessionsTable walkSessions = $WalkSessionsTable(this);
  late final $JourneysTable journeys = $JourneysTable(this);
  late final $TravelFundTable travelFund = $TravelFundTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
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
}
