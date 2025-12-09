// dart format width=80
// GENERATED CODE, DO NOT EDIT BY HAND.
// ignore_for_file: type=lint
import 'package:drift/drift.dart';

class FhirResource extends Table
    with TableInfo<FhirResource, FhirResourceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  FhirResource(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
      'source_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> resourceType = GeneratedColumn<String>(
      'resource_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
      'resource_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<String> resourceRaw = GeneratedColumn<String>(
      'resource_raw', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> encounterId = GeneratedColumn<String>(
      'encounter_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
      'subject_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sourceId,
        resourceType,
        resourceId,
        title,
        date,
        resourceRaw,
        encounterId,
        subjectId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fhir_resource';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FhirResourceData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FhirResourceData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_id']),
      resourceType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resource_type']),
      resourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resource_id']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date']),
      resourceRaw: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resource_raw'])!,
      encounterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}encounter_id']),
      subjectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject_id']),
    );
  }

  @override
  FhirResource createAlias(String alias) {
    return FhirResource(attachedDatabase, alias);
  }
}

class FhirResourceData extends DataClass
    implements Insertable<FhirResourceData> {
  final String id;
  final String? sourceId;
  final String? resourceType;
  final String? resourceId;
  final String? title;
  final DateTime? date;
  final String resourceRaw;
  final String? encounterId;
  final String? subjectId;
  const FhirResourceData(
      {required this.id,
      this.sourceId,
      this.resourceType,
      this.resourceId,
      this.title,
      this.date,
      required this.resourceRaw,
      this.encounterId,
      this.subjectId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    if (!nullToAbsent || resourceType != null) {
      map['resource_type'] = Variable<String>(resourceType);
    }
    if (!nullToAbsent || resourceId != null) {
      map['resource_id'] = Variable<String>(resourceId);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<DateTime>(date);
    }
    map['resource_raw'] = Variable<String>(resourceRaw);
    if (!nullToAbsent || encounterId != null) {
      map['encounter_id'] = Variable<String>(encounterId);
    }
    if (!nullToAbsent || subjectId != null) {
      map['subject_id'] = Variable<String>(subjectId);
    }
    return map;
  }

  FhirResourceCompanion toCompanion(bool nullToAbsent) {
    return FhirResourceCompanion(
      id: Value(id),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      resourceType: resourceType == null && nullToAbsent
          ? const Value.absent()
          : Value(resourceType),
      resourceId: resourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(resourceId),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      resourceRaw: Value(resourceRaw),
      encounterId: encounterId == null && nullToAbsent
          ? const Value.absent()
          : Value(encounterId),
      subjectId: subjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectId),
    );
  }

  factory FhirResourceData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FhirResourceData(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      resourceType: serializer.fromJson<String?>(json['resourceType']),
      resourceId: serializer.fromJson<String?>(json['resourceId']),
      title: serializer.fromJson<String?>(json['title']),
      date: serializer.fromJson<DateTime?>(json['date']),
      resourceRaw: serializer.fromJson<String>(json['resourceRaw']),
      encounterId: serializer.fromJson<String?>(json['encounterId']),
      subjectId: serializer.fromJson<String?>(json['subjectId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String?>(sourceId),
      'resourceType': serializer.toJson<String?>(resourceType),
      'resourceId': serializer.toJson<String?>(resourceId),
      'title': serializer.toJson<String?>(title),
      'date': serializer.toJson<DateTime?>(date),
      'resourceRaw': serializer.toJson<String>(resourceRaw),
      'encounterId': serializer.toJson<String?>(encounterId),
      'subjectId': serializer.toJson<String?>(subjectId),
    };
  }

  FhirResourceData copyWith(
          {String? id,
          Value<String?> sourceId = const Value.absent(),
          Value<String?> resourceType = const Value.absent(),
          Value<String?> resourceId = const Value.absent(),
          Value<String?> title = const Value.absent(),
          Value<DateTime?> date = const Value.absent(),
          String? resourceRaw,
          Value<String?> encounterId = const Value.absent(),
          Value<String?> subjectId = const Value.absent()}) =>
      FhirResourceData(
        id: id ?? this.id,
        sourceId: sourceId.present ? sourceId.value : this.sourceId,
        resourceType:
            resourceType.present ? resourceType.value : this.resourceType,
        resourceId: resourceId.present ? resourceId.value : this.resourceId,
        title: title.present ? title.value : this.title,
        date: date.present ? date.value : this.date,
        resourceRaw: resourceRaw ?? this.resourceRaw,
        encounterId: encounterId.present ? encounterId.value : this.encounterId,
        subjectId: subjectId.present ? subjectId.value : this.subjectId,
      );
  FhirResourceData copyWithCompanion(FhirResourceCompanion data) {
    return FhirResourceData(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      resourceType: data.resourceType.present
          ? data.resourceType.value
          : this.resourceType,
      resourceId:
          data.resourceId.present ? data.resourceId.value : this.resourceId,
      title: data.title.present ? data.title.value : this.title,
      date: data.date.present ? data.date.value : this.date,
      resourceRaw:
          data.resourceRaw.present ? data.resourceRaw.value : this.resourceRaw,
      encounterId:
          data.encounterId.present ? data.encounterId.value : this.encounterId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FhirResourceData(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('resourceType: $resourceType, ')
          ..write('resourceId: $resourceId, ')
          ..write('title: $title, ')
          ..write('date: $date, ')
          ..write('resourceRaw: $resourceRaw, ')
          ..write('encounterId: $encounterId, ')
          ..write('subjectId: $subjectId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sourceId, resourceType, resourceId, title,
      date, resourceRaw, encounterId, subjectId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FhirResourceData &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.resourceType == this.resourceType &&
          other.resourceId == this.resourceId &&
          other.title == this.title &&
          other.date == this.date &&
          other.resourceRaw == this.resourceRaw &&
          other.encounterId == this.encounterId &&
          other.subjectId == this.subjectId);
}

class FhirResourceCompanion extends UpdateCompanion<FhirResourceData> {
  final Value<String> id;
  final Value<String?> sourceId;
  final Value<String?> resourceType;
  final Value<String?> resourceId;
  final Value<String?> title;
  final Value<DateTime?> date;
  final Value<String> resourceRaw;
  final Value<String?> encounterId;
  final Value<String?> subjectId;
  final Value<int> rowid;
  const FhirResourceCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.resourceType = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.title = const Value.absent(),
    this.date = const Value.absent(),
    this.resourceRaw = const Value.absent(),
    this.encounterId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FhirResourceCompanion.insert({
    required String id,
    this.sourceId = const Value.absent(),
    this.resourceType = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.title = const Value.absent(),
    this.date = const Value.absent(),
    required String resourceRaw,
    this.encounterId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        resourceRaw = Value(resourceRaw);
  static Insertable<FhirResourceData> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? resourceType,
    Expression<String>? resourceId,
    Expression<String>? title,
    Expression<DateTime>? date,
    Expression<String>? resourceRaw,
    Expression<String>? encounterId,
    Expression<String>? subjectId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (resourceType != null) 'resource_type': resourceType,
      if (resourceId != null) 'resource_id': resourceId,
      if (title != null) 'title': title,
      if (date != null) 'date': date,
      if (resourceRaw != null) 'resource_raw': resourceRaw,
      if (encounterId != null) 'encounter_id': encounterId,
      if (subjectId != null) 'subject_id': subjectId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FhirResourceCompanion copyWith(
      {Value<String>? id,
      Value<String?>? sourceId,
      Value<String?>? resourceType,
      Value<String?>? resourceId,
      Value<String?>? title,
      Value<DateTime?>? date,
      Value<String>? resourceRaw,
      Value<String?>? encounterId,
      Value<String?>? subjectId,
      Value<int>? rowid}) {
    return FhirResourceCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      resourceType: resourceType ?? this.resourceType,
      resourceId: resourceId ?? this.resourceId,
      title: title ?? this.title,
      date: date ?? this.date,
      resourceRaw: resourceRaw ?? this.resourceRaw,
      encounterId: encounterId ?? this.encounterId,
      subjectId: subjectId ?? this.subjectId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (resourceType.present) {
      map['resource_type'] = Variable<String>(resourceType.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (resourceRaw.present) {
      map['resource_raw'] = Variable<String>(resourceRaw.value);
    }
    if (encounterId.present) {
      map['encounter_id'] = Variable<String>(encounterId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FhirResourceCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('resourceType: $resourceType, ')
          ..write('resourceId: $resourceId, ')
          ..write('title: $title, ')
          ..write('date: $date, ')
          ..write('resourceRaw: $resourceRaw, ')
          ..write('encounterId: $encounterId, ')
          ..write('subjectId: $subjectId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Sources extends Table with TableInfo<Sources, SourcesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Sources(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> platformName = GeneratedColumn<String>(
      'platform_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> logo = GeneratedColumn<String>(
      'logo', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> labelSource = GeneratedColumn<String>(
      'label_source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> platformType = GeneratedColumn<String>(
      'platform_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const CustomExpression('\'wallet\''));
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, platformName, logo, labelSource, platformType, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sources';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SourcesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourcesData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      platformName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}platform_name']),
      logo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}logo']),
      labelSource: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label_source']),
      platformType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}platform_type'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  Sources createAlias(String alias) {
    return Sources(attachedDatabase, alias);
  }
}

class SourcesData extends DataClass implements Insertable<SourcesData> {
  final String id;
  final String? platformName;
  final String? logo;
  final String? labelSource;
  final String platformType;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const SourcesData(
      {required this.id,
      this.platformName,
      this.logo,
      this.labelSource,
      required this.platformType,
      this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || platformName != null) {
      map['platform_name'] = Variable<String>(platformName);
    }
    if (!nullToAbsent || logo != null) {
      map['logo'] = Variable<String>(logo);
    }
    if (!nullToAbsent || labelSource != null) {
      map['label_source'] = Variable<String>(labelSource);
    }
    map['platform_type'] = Variable<String>(platformType);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  SourcesCompanion toCompanion(bool nullToAbsent) {
    return SourcesCompanion(
      id: Value(id),
      platformName: platformName == null && nullToAbsent
          ? const Value.absent()
          : Value(platformName),
      logo: logo == null && nullToAbsent ? const Value.absent() : Value(logo),
      labelSource: labelSource == null && nullToAbsent
          ? const Value.absent()
          : Value(labelSource),
      platformType: Value(platformType),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory SourcesData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourcesData(
      id: serializer.fromJson<String>(json['id']),
      platformName: serializer.fromJson<String?>(json['platformName']),
      logo: serializer.fromJson<String?>(json['logo']),
      labelSource: serializer.fromJson<String?>(json['labelSource']),
      platformType: serializer.fromJson<String>(json['platformType']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'platformName': serializer.toJson<String?>(platformName),
      'logo': serializer.toJson<String?>(logo),
      'labelSource': serializer.toJson<String?>(labelSource),
      'platformType': serializer.toJson<String>(platformType),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  SourcesData copyWith(
          {String? id,
          Value<String?> platformName = const Value.absent(),
          Value<String?> logo = const Value.absent(),
          Value<String?> labelSource = const Value.absent(),
          String? platformType,
          Value<DateTime?> createdAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      SourcesData(
        id: id ?? this.id,
        platformName:
            platformName.present ? platformName.value : this.platformName,
        logo: logo.present ? logo.value : this.logo,
        labelSource: labelSource.present ? labelSource.value : this.labelSource,
        platformType: platformType ?? this.platformType,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  SourcesData copyWithCompanion(SourcesCompanion data) {
    return SourcesData(
      id: data.id.present ? data.id.value : this.id,
      platformName: data.platformName.present
          ? data.platformName.value
          : this.platformName,
      logo: data.logo.present ? data.logo.value : this.logo,
      labelSource:
          data.labelSource.present ? data.labelSource.value : this.labelSource,
      platformType: data.platformType.present
          ? data.platformType.value
          : this.platformType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourcesData(')
          ..write('id: $id, ')
          ..write('platformName: $platformName, ')
          ..write('logo: $logo, ')
          ..write('labelSource: $labelSource, ')
          ..write('platformType: $platformType, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, platformName, logo, labelSource, platformType, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourcesData &&
          other.id == this.id &&
          other.platformName == this.platformName &&
          other.logo == this.logo &&
          other.labelSource == this.labelSource &&
          other.platformType == this.platformType &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SourcesCompanion extends UpdateCompanion<SourcesData> {
  final Value<String> id;
  final Value<String?> platformName;
  final Value<String?> logo;
  final Value<String?> labelSource;
  final Value<String> platformType;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const SourcesCompanion({
    this.id = const Value.absent(),
    this.platformName = const Value.absent(),
    this.logo = const Value.absent(),
    this.labelSource = const Value.absent(),
    this.platformType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourcesCompanion.insert({
    required String id,
    this.platformName = const Value.absent(),
    this.logo = const Value.absent(),
    this.labelSource = const Value.absent(),
    this.platformType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<SourcesData> custom({
    Expression<String>? id,
    Expression<String>? platformName,
    Expression<String>? logo,
    Expression<String>? labelSource,
    Expression<String>? platformType,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (platformName != null) 'platform_name': platformName,
      if (logo != null) 'logo': logo,
      if (labelSource != null) 'label_source': labelSource,
      if (platformType != null) 'platform_type': platformType,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourcesCompanion copyWith(
      {Value<String>? id,
      Value<String?>? platformName,
      Value<String?>? logo,
      Value<String?>? labelSource,
      Value<String>? platformType,
      Value<DateTime?>? createdAt,
      Value<DateTime?>? updatedAt,
      Value<int>? rowid}) {
    return SourcesCompanion(
      id: id ?? this.id,
      platformName: platformName ?? this.platformName,
      logo: logo ?? this.logo,
      labelSource: labelSource ?? this.labelSource,
      platformType: platformType ?? this.platformType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (platformName.present) {
      map['platform_name'] = Variable<String>(platformName.value);
    }
    if (logo.present) {
      map['logo'] = Variable<String>(logo.value);
    }
    if (labelSource.present) {
      map['label_source'] = Variable<String>(labelSource.value);
    }
    if (platformType.present) {
      map['platform_type'] = Variable<String>(platformType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourcesCompanion(')
          ..write('id: $id, ')
          ..write('platformName: $platformName, ')
          ..write('logo: $logo, ')
          ..write('labelSource: $labelSource, ')
          ..write('platformType: $platformType, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class RecordNotes extends Table with TableInfo<RecordNotes, RecordNotesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  RecordNotes(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
      'resource_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
      'source_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sources (id)'));
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, resourceId, sourceId, content, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'record_notes';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordNotesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordNotesData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      resourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resource_id'])!,
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_id']),
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  RecordNotes createAlias(String alias) {
    return RecordNotes(attachedDatabase, alias);
  }
}

class RecordNotesData extends DataClass implements Insertable<RecordNotesData> {
  final int id;
  final String resourceId;
  final String? sourceId;
  final String content;
  final DateTime timestamp;
  const RecordNotesData(
      {required this.id,
      required this.resourceId,
      this.sourceId,
      required this.content,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['resource_id'] = Variable<String>(resourceId);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    map['content'] = Variable<String>(content);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  RecordNotesCompanion toCompanion(bool nullToAbsent) {
    return RecordNotesCompanion(
      id: Value(id),
      resourceId: Value(resourceId),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      content: Value(content),
      timestamp: Value(timestamp),
    );
  }

  factory RecordNotesData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordNotesData(
      id: serializer.fromJson<int>(json['id']),
      resourceId: serializer.fromJson<String>(json['resourceId']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      content: serializer.fromJson<String>(json['content']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'resourceId': serializer.toJson<String>(resourceId),
      'sourceId': serializer.toJson<String?>(sourceId),
      'content': serializer.toJson<String>(content),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  RecordNotesData copyWith(
          {int? id,
          String? resourceId,
          Value<String?> sourceId = const Value.absent(),
          String? content,
          DateTime? timestamp}) =>
      RecordNotesData(
        id: id ?? this.id,
        resourceId: resourceId ?? this.resourceId,
        sourceId: sourceId.present ? sourceId.value : this.sourceId,
        content: content ?? this.content,
        timestamp: timestamp ?? this.timestamp,
      );
  RecordNotesData copyWithCompanion(RecordNotesCompanion data) {
    return RecordNotesData(
      id: data.id.present ? data.id.value : this.id,
      resourceId:
          data.resourceId.present ? data.resourceId.value : this.resourceId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      content: data.content.present ? data.content.value : this.content,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordNotesData(')
          ..write('id: $id, ')
          ..write('resourceId: $resourceId, ')
          ..write('sourceId: $sourceId, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, resourceId, sourceId, content, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordNotesData &&
          other.id == this.id &&
          other.resourceId == this.resourceId &&
          other.sourceId == this.sourceId &&
          other.content == this.content &&
          other.timestamp == this.timestamp);
}

class RecordNotesCompanion extends UpdateCompanion<RecordNotesData> {
  final Value<int> id;
  final Value<String> resourceId;
  final Value<String?> sourceId;
  final Value<String> content;
  final Value<DateTime> timestamp;
  const RecordNotesCompanion({
    this.id = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.content = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  RecordNotesCompanion.insert({
    this.id = const Value.absent(),
    required String resourceId,
    this.sourceId = const Value.absent(),
    required String content,
    required DateTime timestamp,
  })  : resourceId = Value(resourceId),
        content = Value(content),
        timestamp = Value(timestamp);
  static Insertable<RecordNotesData> custom({
    Expression<int>? id,
    Expression<String>? resourceId,
    Expression<String>? sourceId,
    Expression<String>? content,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (resourceId != null) 'resource_id': resourceId,
      if (sourceId != null) 'source_id': sourceId,
      if (content != null) 'content': content,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  RecordNotesCompanion copyWith(
      {Value<int>? id,
      Value<String>? resourceId,
      Value<String?>? sourceId,
      Value<String>? content,
      Value<DateTime>? timestamp}) {
    return RecordNotesCompanion(
      id: id ?? this.id,
      resourceId: resourceId ?? this.resourceId,
      sourceId: sourceId ?? this.sourceId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordNotesCompanion(')
          ..write('id: $id, ')
          ..write('resourceId: $resourceId, ')
          ..write('sourceId: $sourceId, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class ProcessingSessions extends Table
    with TableInfo<ProcessingSessions, ProcessingSessionsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ProcessingSessions(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> filePaths = GeneratedColumn<String>(
      'file_paths', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> resources = GeneratedColumn<String>(
      'resources', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
      'origin', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: const CustomExpression(
          'CAST(strftime(\'%s\', CURRENT_TIMESTAMP) AS INTEGER)'));
  @override
  List<GeneratedColumn> get $columns =>
      [id, filePaths, resources, status, origin, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'processing_sessions';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProcessingSessionsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProcessingSessionsData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      filePaths: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_paths']),
      resources: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resources']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status']),
      origin: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}origin']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  ProcessingSessions createAlias(String alias) {
    return ProcessingSessions(attachedDatabase, alias);
  }
}

class ProcessingSessionsData extends DataClass
    implements Insertable<ProcessingSessionsData> {
  final String id;
  final String? filePaths;
  final String? resources;
  final String? status;
  final String? origin;
  final DateTime createdAt;
  const ProcessingSessionsData(
      {required this.id,
      this.filePaths,
      this.resources,
      this.status,
      this.origin,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || filePaths != null) {
      map['file_paths'] = Variable<String>(filePaths);
    }
    if (!nullToAbsent || resources != null) {
      map['resources'] = Variable<String>(resources);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || origin != null) {
      map['origin'] = Variable<String>(origin);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProcessingSessionsCompanion toCompanion(bool nullToAbsent) {
    return ProcessingSessionsCompanion(
      id: Value(id),
      filePaths: filePaths == null && nullToAbsent
          ? const Value.absent()
          : Value(filePaths),
      resources: resources == null && nullToAbsent
          ? const Value.absent()
          : Value(resources),
      status:
          status == null && nullToAbsent ? const Value.absent() : Value(status),
      origin:
          origin == null && nullToAbsent ? const Value.absent() : Value(origin),
      createdAt: Value(createdAt),
    );
  }

  factory ProcessingSessionsData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProcessingSessionsData(
      id: serializer.fromJson<String>(json['id']),
      filePaths: serializer.fromJson<String?>(json['filePaths']),
      resources: serializer.fromJson<String?>(json['resources']),
      status: serializer.fromJson<String?>(json['status']),
      origin: serializer.fromJson<String?>(json['origin']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'filePaths': serializer.toJson<String?>(filePaths),
      'resources': serializer.toJson<String?>(resources),
      'status': serializer.toJson<String?>(status),
      'origin': serializer.toJson<String?>(origin),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProcessingSessionsData copyWith(
          {String? id,
          Value<String?> filePaths = const Value.absent(),
          Value<String?> resources = const Value.absent(),
          Value<String?> status = const Value.absent(),
          Value<String?> origin = const Value.absent(),
          DateTime? createdAt}) =>
      ProcessingSessionsData(
        id: id ?? this.id,
        filePaths: filePaths.present ? filePaths.value : this.filePaths,
        resources: resources.present ? resources.value : this.resources,
        status: status.present ? status.value : this.status,
        origin: origin.present ? origin.value : this.origin,
        createdAt: createdAt ?? this.createdAt,
      );
  ProcessingSessionsData copyWithCompanion(ProcessingSessionsCompanion data) {
    return ProcessingSessionsData(
      id: data.id.present ? data.id.value : this.id,
      filePaths: data.filePaths.present ? data.filePaths.value : this.filePaths,
      resources: data.resources.present ? data.resources.value : this.resources,
      status: data.status.present ? data.status.value : this.status,
      origin: data.origin.present ? data.origin.value : this.origin,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProcessingSessionsData(')
          ..write('id: $id, ')
          ..write('filePaths: $filePaths, ')
          ..write('resources: $resources, ')
          ..write('status: $status, ')
          ..write('origin: $origin, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, filePaths, resources, status, origin, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProcessingSessionsData &&
          other.id == this.id &&
          other.filePaths == this.filePaths &&
          other.resources == this.resources &&
          other.status == this.status &&
          other.origin == this.origin &&
          other.createdAt == this.createdAt);
}

class ProcessingSessionsCompanion
    extends UpdateCompanion<ProcessingSessionsData> {
  final Value<String> id;
  final Value<String?> filePaths;
  final Value<String?> resources;
  final Value<String?> status;
  final Value<String?> origin;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProcessingSessionsCompanion({
    this.id = const Value.absent(),
    this.filePaths = const Value.absent(),
    this.resources = const Value.absent(),
    this.status = const Value.absent(),
    this.origin = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProcessingSessionsCompanion.insert({
    required String id,
    this.filePaths = const Value.absent(),
    this.resources = const Value.absent(),
    this.status = const Value.absent(),
    this.origin = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<ProcessingSessionsData> custom({
    Expression<String>? id,
    Expression<String>? filePaths,
    Expression<String>? resources,
    Expression<String>? status,
    Expression<String>? origin,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filePaths != null) 'file_paths': filePaths,
      if (resources != null) 'resources': resources,
      if (status != null) 'status': status,
      if (origin != null) 'origin': origin,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProcessingSessionsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? filePaths,
      Value<String?>? resources,
      Value<String?>? status,
      Value<String?>? origin,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ProcessingSessionsCompanion(
      id: id ?? this.id,
      filePaths: filePaths ?? this.filePaths,
      resources: resources ?? this.resources,
      status: status ?? this.status,
      origin: origin ?? this.origin,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (filePaths.present) {
      map['file_paths'] = Variable<String>(filePaths.value);
    }
    if (resources.present) {
      map['resources'] = Variable<String>(resources.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProcessingSessionsCompanion(')
          ..write('id: $id, ')
          ..write('filePaths: $filePaths, ')
          ..write('resources: $resources, ')
          ..write('status: $status, ')
          ..write('origin: $origin, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class DatabaseAtV5 extends GeneratedDatabase {
  DatabaseAtV5(QueryExecutor e) : super(e);
  late final FhirResource fhirResource = FhirResource(this);
  late final Sources sources = Sources(this);
  late final RecordNotes recordNotes = RecordNotes(this);
  late final ProcessingSessions processingSessions = ProcessingSessions(this);
  late final Index resourceType = Index('resourceType',
      'CREATE INDEX resourceType ON fhir_resource (resource_type)');
  late final Index resourceId = Index(
      'resourceId', 'CREATE INDEX resourceId ON fhir_resource (resource_id)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        fhirResource,
        sources,
        recordNotes,
        processingSessions,
        resourceType,
        resourceId
      ];
  @override
  int get schemaVersion => 5;
}
