// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ClientsTable extends Clients with TableInfo<$ClientsTable, ClientRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\' COLLATE NOCASE',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\' COLLATE NOCASE',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _postalCodeMeta = const VerificationMeta(
    'postalCode',
  );
  @override
  late final GeneratedColumn<String> postalCode = GeneratedColumn<String>(
    'postal_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _gstinMeta = const VerificationMeta('gstin');
  @override
  late final GeneratedColumn<String> gstin = GeneratedColumn<String>(
    'gstin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _companyNameMeta = const VerificationMeta(
    'companyName',
  );
  @override
  late final GeneratedColumn<String> companyName = GeneratedColumn<String>(
    'company_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'COLLATE NOCASE',
  );
  static const VerificationMeta _industryMeta = const VerificationMeta(
    'industry',
  );
  @override
  late final GeneratedColumn<String> industry = GeneratedColumn<String>(
    'industry',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creditLimitMeta = const VerificationMeta(
    'creditLimit',
  );
  @override
  late final GeneratedColumn<double> creditLimit = GeneratedColumn<double>(
    'credit_limit',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isBulkBuyerMeta = const VerificationMeta(
    'isBulkBuyer',
  );
  @override
  late final GeneratedColumn<bool> isBulkBuyer = GeneratedColumn<bool>(
    'is_bulk_buyer',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_bulk_buyer" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _bulkDiscountPercentMeta =
      const VerificationMeta('bulkDiscountPercent');
  @override
  late final GeneratedColumn<double> bulkDiscountPercent =
      GeneratedColumn<double>(
        'bulk_discount_percent',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.0),
      );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastEditedByMeta = const VerificationMeta(
    'lastEditedBy',
  );
  @override
  late final GeneratedColumn<String> lastEditedBy = GeneratedColumn<String>(
    'last_edited_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastEditedAtMeta = const VerificationMeta(
    'lastEditedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastEditedAt = GeneratedColumn<DateTime>(
    'last_edited_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    email,
    phone,
    address,
    city,
    state,
    country,
    postalCode,
    gstin,
    companyName,
    industry,
    creditLimit,
    isBulkBuyer,
    bulkDiscountPercent,
    createdBy,
    lastEditedBy,
    lastEditedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clients';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClientRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    }
    if (data.containsKey('postal_code')) {
      context.handle(
        _postalCodeMeta,
        postalCode.isAcceptableOrUnknown(data['postal_code']!, _postalCodeMeta),
      );
    }
    if (data.containsKey('gstin')) {
      context.handle(
        _gstinMeta,
        gstin.isAcceptableOrUnknown(data['gstin']!, _gstinMeta),
      );
    }
    if (data.containsKey('company_name')) {
      context.handle(
        _companyNameMeta,
        companyName.isAcceptableOrUnknown(
          data['company_name']!,
          _companyNameMeta,
        ),
      );
    }
    if (data.containsKey('industry')) {
      context.handle(
        _industryMeta,
        industry.isAcceptableOrUnknown(data['industry']!, _industryMeta),
      );
    }
    if (data.containsKey('credit_limit')) {
      context.handle(
        _creditLimitMeta,
        creditLimit.isAcceptableOrUnknown(
          data['credit_limit']!,
          _creditLimitMeta,
        ),
      );
    }
    if (data.containsKey('is_bulk_buyer')) {
      context.handle(
        _isBulkBuyerMeta,
        isBulkBuyer.isAcceptableOrUnknown(
          data['is_bulk_buyer']!,
          _isBulkBuyerMeta,
        ),
      );
    }
    if (data.containsKey('bulk_discount_percent')) {
      context.handle(
        _bulkDiscountPercentMeta,
        bulkDiscountPercent.isAcceptableOrUnknown(
          data['bulk_discount_percent']!,
          _bulkDiscountPercentMeta,
        ),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('last_edited_by')) {
      context.handle(
        _lastEditedByMeta,
        lastEditedBy.isAcceptableOrUnknown(
          data['last_edited_by']!,
          _lastEditedByMeta,
        ),
      );
    }
    if (data.containsKey('last_edited_at')) {
      context.handle(
        _lastEditedAtMeta,
        lastEditedAt.isAcceptableOrUnknown(
          data['last_edited_at']!,
          _lastEditedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClientRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClientRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      )!,
      postalCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}postal_code'],
      )!,
      gstin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gstin'],
      ),
      companyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_name'],
      ),
      industry: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}industry'],
      ),
      creditLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}credit_limit'],
      ),
      isBulkBuyer: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_bulk_buyer'],
      )!,
      bulkDiscountPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bulk_discount_percent'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      lastEditedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_edited_by'],
      ),
      lastEditedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_edited_at'],
      ),
    );
  }

  @override
  $ClientsTable createAlias(String alias) {
    return $ClientsTable(attachedDatabase, alias);
  }
}

class ClientRow extends DataClass implements Insertable<ClientRow> {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final String? gstin;
  final String? companyName;
  final String? industry;
  final double? creditLimit;
  final bool isBulkBuyer;
  final double bulkDiscountPercent;
  final String? createdBy;
  final String? lastEditedBy;
  final DateTime? lastEditedAt;
  const ClientRow({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    this.gstin,
    this.companyName,
    this.industry,
    this.creditLimit,
    required this.isBulkBuyer,
    required this.bulkDiscountPercent,
    this.createdBy,
    this.lastEditedBy,
    this.lastEditedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['email'] = Variable<String>(email);
    map['phone'] = Variable<String>(phone);
    map['address'] = Variable<String>(address);
    map['city'] = Variable<String>(city);
    map['state'] = Variable<String>(state);
    map['country'] = Variable<String>(country);
    map['postal_code'] = Variable<String>(postalCode);
    if (!nullToAbsent || gstin != null) {
      map['gstin'] = Variable<String>(gstin);
    }
    if (!nullToAbsent || companyName != null) {
      map['company_name'] = Variable<String>(companyName);
    }
    if (!nullToAbsent || industry != null) {
      map['industry'] = Variable<String>(industry);
    }
    if (!nullToAbsent || creditLimit != null) {
      map['credit_limit'] = Variable<double>(creditLimit);
    }
    map['is_bulk_buyer'] = Variable<bool>(isBulkBuyer);
    map['bulk_discount_percent'] = Variable<double>(bulkDiscountPercent);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || lastEditedBy != null) {
      map['last_edited_by'] = Variable<String>(lastEditedBy);
    }
    if (!nullToAbsent || lastEditedAt != null) {
      map['last_edited_at'] = Variable<DateTime>(lastEditedAt);
    }
    return map;
  }

  ClientsCompanion toCompanion(bool nullToAbsent) {
    return ClientsCompanion(
      id: Value(id),
      name: Value(name),
      email: Value(email),
      phone: Value(phone),
      address: Value(address),
      city: Value(city),
      state: Value(state),
      country: Value(country),
      postalCode: Value(postalCode),
      gstin: gstin == null && nullToAbsent
          ? const Value.absent()
          : Value(gstin),
      companyName: companyName == null && nullToAbsent
          ? const Value.absent()
          : Value(companyName),
      industry: industry == null && nullToAbsent
          ? const Value.absent()
          : Value(industry),
      creditLimit: creditLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(creditLimit),
      isBulkBuyer: Value(isBulkBuyer),
      bulkDiscountPercent: Value(bulkDiscountPercent),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      lastEditedBy: lastEditedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEditedBy),
      lastEditedAt: lastEditedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEditedAt),
    );
  }

  factory ClientRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClientRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      email: serializer.fromJson<String>(json['email']),
      phone: serializer.fromJson<String>(json['phone']),
      address: serializer.fromJson<String>(json['address']),
      city: serializer.fromJson<String>(json['city']),
      state: serializer.fromJson<String>(json['state']),
      country: serializer.fromJson<String>(json['country']),
      postalCode: serializer.fromJson<String>(json['postalCode']),
      gstin: serializer.fromJson<String?>(json['gstin']),
      companyName: serializer.fromJson<String?>(json['companyName']),
      industry: serializer.fromJson<String?>(json['industry']),
      creditLimit: serializer.fromJson<double?>(json['creditLimit']),
      isBulkBuyer: serializer.fromJson<bool>(json['isBulkBuyer']),
      bulkDiscountPercent: serializer.fromJson<double>(
        json['bulkDiscountPercent'],
      ),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      lastEditedBy: serializer.fromJson<String?>(json['lastEditedBy']),
      lastEditedAt: serializer.fromJson<DateTime?>(json['lastEditedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'email': serializer.toJson<String>(email),
      'phone': serializer.toJson<String>(phone),
      'address': serializer.toJson<String>(address),
      'city': serializer.toJson<String>(city),
      'state': serializer.toJson<String>(state),
      'country': serializer.toJson<String>(country),
      'postalCode': serializer.toJson<String>(postalCode),
      'gstin': serializer.toJson<String?>(gstin),
      'companyName': serializer.toJson<String?>(companyName),
      'industry': serializer.toJson<String?>(industry),
      'creditLimit': serializer.toJson<double?>(creditLimit),
      'isBulkBuyer': serializer.toJson<bool>(isBulkBuyer),
      'bulkDiscountPercent': serializer.toJson<double>(bulkDiscountPercent),
      'createdBy': serializer.toJson<String?>(createdBy),
      'lastEditedBy': serializer.toJson<String?>(lastEditedBy),
      'lastEditedAt': serializer.toJson<DateTime?>(lastEditedAt),
    };
  }

  ClientRow copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    Value<String?> gstin = const Value.absent(),
    Value<String?> companyName = const Value.absent(),
    Value<String?> industry = const Value.absent(),
    Value<double?> creditLimit = const Value.absent(),
    bool? isBulkBuyer,
    double? bulkDiscountPercent,
    Value<String?> createdBy = const Value.absent(),
    Value<String?> lastEditedBy = const Value.absent(),
    Value<DateTime?> lastEditedAt = const Value.absent(),
  }) => ClientRow(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    city: city ?? this.city,
    state: state ?? this.state,
    country: country ?? this.country,
    postalCode: postalCode ?? this.postalCode,
    gstin: gstin.present ? gstin.value : this.gstin,
    companyName: companyName.present ? companyName.value : this.companyName,
    industry: industry.present ? industry.value : this.industry,
    creditLimit: creditLimit.present ? creditLimit.value : this.creditLimit,
    isBulkBuyer: isBulkBuyer ?? this.isBulkBuyer,
    bulkDiscountPercent: bulkDiscountPercent ?? this.bulkDiscountPercent,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    lastEditedBy: lastEditedBy.present ? lastEditedBy.value : this.lastEditedBy,
    lastEditedAt: lastEditedAt.present ? lastEditedAt.value : this.lastEditedAt,
  );
  ClientRow copyWithCompanion(ClientsCompanion data) {
    return ClientRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      address: data.address.present ? data.address.value : this.address,
      city: data.city.present ? data.city.value : this.city,
      state: data.state.present ? data.state.value : this.state,
      country: data.country.present ? data.country.value : this.country,
      postalCode: data.postalCode.present
          ? data.postalCode.value
          : this.postalCode,
      gstin: data.gstin.present ? data.gstin.value : this.gstin,
      companyName: data.companyName.present
          ? data.companyName.value
          : this.companyName,
      industry: data.industry.present ? data.industry.value : this.industry,
      creditLimit: data.creditLimit.present
          ? data.creditLimit.value
          : this.creditLimit,
      isBulkBuyer: data.isBulkBuyer.present
          ? data.isBulkBuyer.value
          : this.isBulkBuyer,
      bulkDiscountPercent: data.bulkDiscountPercent.present
          ? data.bulkDiscountPercent.value
          : this.bulkDiscountPercent,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      lastEditedBy: data.lastEditedBy.present
          ? data.lastEditedBy.value
          : this.lastEditedBy,
      lastEditedAt: data.lastEditedAt.present
          ? data.lastEditedAt.value
          : this.lastEditedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClientRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('city: $city, ')
          ..write('state: $state, ')
          ..write('country: $country, ')
          ..write('postalCode: $postalCode, ')
          ..write('gstin: $gstin, ')
          ..write('companyName: $companyName, ')
          ..write('industry: $industry, ')
          ..write('creditLimit: $creditLimit, ')
          ..write('isBulkBuyer: $isBulkBuyer, ')
          ..write('bulkDiscountPercent: $bulkDiscountPercent, ')
          ..write('createdBy: $createdBy, ')
          ..write('lastEditedBy: $lastEditedBy, ')
          ..write('lastEditedAt: $lastEditedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    email,
    phone,
    address,
    city,
    state,
    country,
    postalCode,
    gstin,
    companyName,
    industry,
    creditLimit,
    isBulkBuyer,
    bulkDiscountPercent,
    createdBy,
    lastEditedBy,
    lastEditedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClientRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.address == this.address &&
          other.city == this.city &&
          other.state == this.state &&
          other.country == this.country &&
          other.postalCode == this.postalCode &&
          other.gstin == this.gstin &&
          other.companyName == this.companyName &&
          other.industry == this.industry &&
          other.creditLimit == this.creditLimit &&
          other.isBulkBuyer == this.isBulkBuyer &&
          other.bulkDiscountPercent == this.bulkDiscountPercent &&
          other.createdBy == this.createdBy &&
          other.lastEditedBy == this.lastEditedBy &&
          other.lastEditedAt == this.lastEditedAt);
}

class ClientsCompanion extends UpdateCompanion<ClientRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> email;
  final Value<String> phone;
  final Value<String> address;
  final Value<String> city;
  final Value<String> state;
  final Value<String> country;
  final Value<String> postalCode;
  final Value<String?> gstin;
  final Value<String?> companyName;
  final Value<String?> industry;
  final Value<double?> creditLimit;
  final Value<bool> isBulkBuyer;
  final Value<double> bulkDiscountPercent;
  final Value<String?> createdBy;
  final Value<String?> lastEditedBy;
  final Value<DateTime?> lastEditedAt;
  final Value<int> rowid;
  const ClientsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.city = const Value.absent(),
    this.state = const Value.absent(),
    this.country = const Value.absent(),
    this.postalCode = const Value.absent(),
    this.gstin = const Value.absent(),
    this.companyName = const Value.absent(),
    this.industry = const Value.absent(),
    this.creditLimit = const Value.absent(),
    this.isBulkBuyer = const Value.absent(),
    this.bulkDiscountPercent = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.lastEditedBy = const Value.absent(),
    this.lastEditedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClientsCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.city = const Value.absent(),
    this.state = const Value.absent(),
    this.country = const Value.absent(),
    this.postalCode = const Value.absent(),
    this.gstin = const Value.absent(),
    this.companyName = const Value.absent(),
    this.industry = const Value.absent(),
    this.creditLimit = const Value.absent(),
    this.isBulkBuyer = const Value.absent(),
    this.bulkDiscountPercent = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.lastEditedBy = const Value.absent(),
    this.lastEditedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<ClientRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? address,
    Expression<String>? city,
    Expression<String>? state,
    Expression<String>? country,
    Expression<String>? postalCode,
    Expression<String>? gstin,
    Expression<String>? companyName,
    Expression<String>? industry,
    Expression<double>? creditLimit,
    Expression<bool>? isBulkBuyer,
    Expression<double>? bulkDiscountPercent,
    Expression<String>? createdBy,
    Expression<String>? lastEditedBy,
    Expression<DateTime>? lastEditedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (country != null) 'country': country,
      if (postalCode != null) 'postal_code': postalCode,
      if (gstin != null) 'gstin': gstin,
      if (companyName != null) 'company_name': companyName,
      if (industry != null) 'industry': industry,
      if (creditLimit != null) 'credit_limit': creditLimit,
      if (isBulkBuyer != null) 'is_bulk_buyer': isBulkBuyer,
      if (bulkDiscountPercent != null)
        'bulk_discount_percent': bulkDiscountPercent,
      if (createdBy != null) 'created_by': createdBy,
      if (lastEditedBy != null) 'last_edited_by': lastEditedBy,
      if (lastEditedAt != null) 'last_edited_at': lastEditedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClientsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? email,
    Value<String>? phone,
    Value<String>? address,
    Value<String>? city,
    Value<String>? state,
    Value<String>? country,
    Value<String>? postalCode,
    Value<String?>? gstin,
    Value<String?>? companyName,
    Value<String?>? industry,
    Value<double?>? creditLimit,
    Value<bool>? isBulkBuyer,
    Value<double>? bulkDiscountPercent,
    Value<String?>? createdBy,
    Value<String?>? lastEditedBy,
    Value<DateTime?>? lastEditedAt,
    Value<int>? rowid,
  }) {
    return ClientsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      gstin: gstin ?? this.gstin,
      companyName: companyName ?? this.companyName,
      industry: industry ?? this.industry,
      creditLimit: creditLimit ?? this.creditLimit,
      isBulkBuyer: isBulkBuyer ?? this.isBulkBuyer,
      bulkDiscountPercent: bulkDiscountPercent ?? this.bulkDiscountPercent,
      createdBy: createdBy ?? this.createdBy,
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (postalCode.present) {
      map['postal_code'] = Variable<String>(postalCode.value);
    }
    if (gstin.present) {
      map['gstin'] = Variable<String>(gstin.value);
    }
    if (companyName.present) {
      map['company_name'] = Variable<String>(companyName.value);
    }
    if (industry.present) {
      map['industry'] = Variable<String>(industry.value);
    }
    if (creditLimit.present) {
      map['credit_limit'] = Variable<double>(creditLimit.value);
    }
    if (isBulkBuyer.present) {
      map['is_bulk_buyer'] = Variable<bool>(isBulkBuyer.value);
    }
    if (bulkDiscountPercent.present) {
      map['bulk_discount_percent'] = Variable<double>(
        bulkDiscountPercent.value,
      );
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (lastEditedBy.present) {
      map['last_edited_by'] = Variable<String>(lastEditedBy.value);
    }
    if (lastEditedAt.present) {
      map['last_edited_at'] = Variable<DateTime>(lastEditedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('city: $city, ')
          ..write('state: $state, ')
          ..write('country: $country, ')
          ..write('postalCode: $postalCode, ')
          ..write('gstin: $gstin, ')
          ..write('companyName: $companyName, ')
          ..write('industry: $industry, ')
          ..write('creditLimit: $creditLimit, ')
          ..write('isBulkBuyer: $isBulkBuyer, ')
          ..write('bulkDiscountPercent: $bulkDiscountPercent, ')
          ..write('createdBy: $createdBy, ')
          ..write('lastEditedBy: $lastEditedBy, ')
          ..write('lastEditedAt: $lastEditedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServiceItemsTable extends ServiceItems
    with TableInfo<$ServiceItemsTable, ServiceItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServiceItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\' COLLATE NOCASE',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<double> rate = GeneratedColumn<double>(
    'rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _costPriceMeta = const VerificationMeta(
    'costPrice',
  );
  @override
  late final GeneratedColumn<double> costPrice = GeneratedColumn<double>(
    'cost_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taxPercentMeta = const VerificationMeta(
    'taxPercent',
  );
  @override
  late final GeneratedColumn<double> taxPercent = GeneratedColumn<double>(
    'tax_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hsnSacMeta = const VerificationMeta('hsnSac');
  @override
  late final GeneratedColumn<String> hsnSac = GeneratedColumn<String>(
    'hsn_sac',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'COLLATE NOCASE',
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackStockMeta = const VerificationMeta(
    'trackStock',
  );
  @override
  late final GeneratedColumn<bool> trackStock = GeneratedColumn<bool>(
    'track_stock',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("track_stock" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lowStockThresholdMeta = const VerificationMeta(
    'lowStockThreshold',
  );
  @override
  late final GeneratedColumn<double> lowStockThreshold =
      GeneratedColumn<double>(
        'low_stock_threshold',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastEditedAtMeta = const VerificationMeta(
    'lastEditedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastEditedAt = GeneratedColumn<DateTime>(
    'last_edited_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    rate,
    costPrice,
    taxPercent,
    unit,
    hsnSac,
    category,
    barcode,
    trackStock,
    lowStockThreshold,
    lastEditedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'service_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServiceItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    }
    if (data.containsKey('cost_price')) {
      context.handle(
        _costPriceMeta,
        costPrice.isAcceptableOrUnknown(data['cost_price']!, _costPriceMeta),
      );
    }
    if (data.containsKey('tax_percent')) {
      context.handle(
        _taxPercentMeta,
        taxPercent.isAcceptableOrUnknown(data['tax_percent']!, _taxPercentMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('hsn_sac')) {
      context.handle(
        _hsnSacMeta,
        hsnSac.isAcceptableOrUnknown(data['hsn_sac']!, _hsnSacMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('track_stock')) {
      context.handle(
        _trackStockMeta,
        trackStock.isAcceptableOrUnknown(data['track_stock']!, _trackStockMeta),
      );
    }
    if (data.containsKey('low_stock_threshold')) {
      context.handle(
        _lowStockThresholdMeta,
        lowStockThreshold.isAcceptableOrUnknown(
          data['low_stock_threshold']!,
          _lowStockThresholdMeta,
        ),
      );
    }
    if (data.containsKey('last_edited_at')) {
      context.handle(
        _lastEditedAtMeta,
        lastEditedAt.isAcceptableOrUnknown(
          data['last_edited_at']!,
          _lastEditedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServiceItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServiceItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rate'],
      )!,
      costPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost_price'],
      ),
      taxPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tax_percent'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      hsnSac: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hsn_sac'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      trackStock: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}track_stock'],
      )!,
      lowStockThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}low_stock_threshold'],
      ),
      lastEditedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_edited_at'],
      ),
    );
  }

  @override
  $ServiceItemsTable createAlias(String alias) {
    return $ServiceItemsTable(attachedDatabase, alias);
  }
}

class ServiceItemRow extends DataClass implements Insertable<ServiceItemRow> {
  final String id;
  final String name;
  final String? description;
  final double rate;
  final double? costPrice;
  final double taxPercent;
  final String? unit;
  final String? hsnSac;
  final String? category;
  final String? barcode;
  final bool trackStock;
  final double? lowStockThreshold;
  final DateTime? lastEditedAt;
  const ServiceItemRow({
    required this.id,
    required this.name,
    this.description,
    required this.rate,
    this.costPrice,
    required this.taxPercent,
    this.unit,
    this.hsnSac,
    this.category,
    this.barcode,
    required this.trackStock,
    this.lowStockThreshold,
    this.lastEditedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['rate'] = Variable<double>(rate);
    if (!nullToAbsent || costPrice != null) {
      map['cost_price'] = Variable<double>(costPrice);
    }
    map['tax_percent'] = Variable<double>(taxPercent);
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    if (!nullToAbsent || hsnSac != null) {
      map['hsn_sac'] = Variable<String>(hsnSac);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['track_stock'] = Variable<bool>(trackStock);
    if (!nullToAbsent || lowStockThreshold != null) {
      map['low_stock_threshold'] = Variable<double>(lowStockThreshold);
    }
    if (!nullToAbsent || lastEditedAt != null) {
      map['last_edited_at'] = Variable<DateTime>(lastEditedAt);
    }
    return map;
  }

  ServiceItemsCompanion toCompanion(bool nullToAbsent) {
    return ServiceItemsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      rate: Value(rate),
      costPrice: costPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(costPrice),
      taxPercent: Value(taxPercent),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      hsnSac: hsnSac == null && nullToAbsent
          ? const Value.absent()
          : Value(hsnSac),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      trackStock: Value(trackStock),
      lowStockThreshold: lowStockThreshold == null && nullToAbsent
          ? const Value.absent()
          : Value(lowStockThreshold),
      lastEditedAt: lastEditedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEditedAt),
    );
  }

  factory ServiceItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServiceItemRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      rate: serializer.fromJson<double>(json['rate']),
      costPrice: serializer.fromJson<double?>(json['costPrice']),
      taxPercent: serializer.fromJson<double>(json['taxPercent']),
      unit: serializer.fromJson<String?>(json['unit']),
      hsnSac: serializer.fromJson<String?>(json['hsnSac']),
      category: serializer.fromJson<String?>(json['category']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      trackStock: serializer.fromJson<bool>(json['trackStock']),
      lowStockThreshold: serializer.fromJson<double?>(
        json['lowStockThreshold'],
      ),
      lastEditedAt: serializer.fromJson<DateTime?>(json['lastEditedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'rate': serializer.toJson<double>(rate),
      'costPrice': serializer.toJson<double?>(costPrice),
      'taxPercent': serializer.toJson<double>(taxPercent),
      'unit': serializer.toJson<String?>(unit),
      'hsnSac': serializer.toJson<String?>(hsnSac),
      'category': serializer.toJson<String?>(category),
      'barcode': serializer.toJson<String?>(barcode),
      'trackStock': serializer.toJson<bool>(trackStock),
      'lowStockThreshold': serializer.toJson<double?>(lowStockThreshold),
      'lastEditedAt': serializer.toJson<DateTime?>(lastEditedAt),
    };
  }

  ServiceItemRow copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    double? rate,
    Value<double?> costPrice = const Value.absent(),
    double? taxPercent,
    Value<String?> unit = const Value.absent(),
    Value<String?> hsnSac = const Value.absent(),
    Value<String?> category = const Value.absent(),
    Value<String?> barcode = const Value.absent(),
    bool? trackStock,
    Value<double?> lowStockThreshold = const Value.absent(),
    Value<DateTime?> lastEditedAt = const Value.absent(),
  }) => ServiceItemRow(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    rate: rate ?? this.rate,
    costPrice: costPrice.present ? costPrice.value : this.costPrice,
    taxPercent: taxPercent ?? this.taxPercent,
    unit: unit.present ? unit.value : this.unit,
    hsnSac: hsnSac.present ? hsnSac.value : this.hsnSac,
    category: category.present ? category.value : this.category,
    barcode: barcode.present ? barcode.value : this.barcode,
    trackStock: trackStock ?? this.trackStock,
    lowStockThreshold: lowStockThreshold.present
        ? lowStockThreshold.value
        : this.lowStockThreshold,
    lastEditedAt: lastEditedAt.present ? lastEditedAt.value : this.lastEditedAt,
  );
  ServiceItemRow copyWithCompanion(ServiceItemsCompanion data) {
    return ServiceItemRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      rate: data.rate.present ? data.rate.value : this.rate,
      costPrice: data.costPrice.present ? data.costPrice.value : this.costPrice,
      taxPercent: data.taxPercent.present
          ? data.taxPercent.value
          : this.taxPercent,
      unit: data.unit.present ? data.unit.value : this.unit,
      hsnSac: data.hsnSac.present ? data.hsnSac.value : this.hsnSac,
      category: data.category.present ? data.category.value : this.category,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      trackStock: data.trackStock.present
          ? data.trackStock.value
          : this.trackStock,
      lowStockThreshold: data.lowStockThreshold.present
          ? data.lowStockThreshold.value
          : this.lowStockThreshold,
      lastEditedAt: data.lastEditedAt.present
          ? data.lastEditedAt.value
          : this.lastEditedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServiceItemRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('rate: $rate, ')
          ..write('costPrice: $costPrice, ')
          ..write('taxPercent: $taxPercent, ')
          ..write('unit: $unit, ')
          ..write('hsnSac: $hsnSac, ')
          ..write('category: $category, ')
          ..write('barcode: $barcode, ')
          ..write('trackStock: $trackStock, ')
          ..write('lowStockThreshold: $lowStockThreshold, ')
          ..write('lastEditedAt: $lastEditedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    rate,
    costPrice,
    taxPercent,
    unit,
    hsnSac,
    category,
    barcode,
    trackStock,
    lowStockThreshold,
    lastEditedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceItemRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.rate == this.rate &&
          other.costPrice == this.costPrice &&
          other.taxPercent == this.taxPercent &&
          other.unit == this.unit &&
          other.hsnSac == this.hsnSac &&
          other.category == this.category &&
          other.barcode == this.barcode &&
          other.trackStock == this.trackStock &&
          other.lowStockThreshold == this.lowStockThreshold &&
          other.lastEditedAt == this.lastEditedAt);
}

class ServiceItemsCompanion extends UpdateCompanion<ServiceItemRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<double> rate;
  final Value<double?> costPrice;
  final Value<double> taxPercent;
  final Value<String?> unit;
  final Value<String?> hsnSac;
  final Value<String?> category;
  final Value<String?> barcode;
  final Value<bool> trackStock;
  final Value<double?> lowStockThreshold;
  final Value<DateTime?> lastEditedAt;
  final Value<int> rowid;
  const ServiceItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.rate = const Value.absent(),
    this.costPrice = const Value.absent(),
    this.taxPercent = const Value.absent(),
    this.unit = const Value.absent(),
    this.hsnSac = const Value.absent(),
    this.category = const Value.absent(),
    this.barcode = const Value.absent(),
    this.trackStock = const Value.absent(),
    this.lowStockThreshold = const Value.absent(),
    this.lastEditedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServiceItemsCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.rate = const Value.absent(),
    this.costPrice = const Value.absent(),
    this.taxPercent = const Value.absent(),
    this.unit = const Value.absent(),
    this.hsnSac = const Value.absent(),
    this.category = const Value.absent(),
    this.barcode = const Value.absent(),
    this.trackStock = const Value.absent(),
    this.lowStockThreshold = const Value.absent(),
    this.lastEditedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<ServiceItemRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<double>? rate,
    Expression<double>? costPrice,
    Expression<double>? taxPercent,
    Expression<String>? unit,
    Expression<String>? hsnSac,
    Expression<String>? category,
    Expression<String>? barcode,
    Expression<bool>? trackStock,
    Expression<double>? lowStockThreshold,
    Expression<DateTime>? lastEditedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (rate != null) 'rate': rate,
      if (costPrice != null) 'cost_price': costPrice,
      if (taxPercent != null) 'tax_percent': taxPercent,
      if (unit != null) 'unit': unit,
      if (hsnSac != null) 'hsn_sac': hsnSac,
      if (category != null) 'category': category,
      if (barcode != null) 'barcode': barcode,
      if (trackStock != null) 'track_stock': trackStock,
      if (lowStockThreshold != null) 'low_stock_threshold': lowStockThreshold,
      if (lastEditedAt != null) 'last_edited_at': lastEditedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServiceItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<double>? rate,
    Value<double?>? costPrice,
    Value<double>? taxPercent,
    Value<String?>? unit,
    Value<String?>? hsnSac,
    Value<String?>? category,
    Value<String?>? barcode,
    Value<bool>? trackStock,
    Value<double?>? lowStockThreshold,
    Value<DateTime?>? lastEditedAt,
    Value<int>? rowid,
  }) {
    return ServiceItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      rate: rate ?? this.rate,
      costPrice: costPrice ?? this.costPrice,
      taxPercent: taxPercent ?? this.taxPercent,
      unit: unit ?? this.unit,
      hsnSac: hsnSac ?? this.hsnSac,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
      trackStock: trackStock ?? this.trackStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (rate.present) {
      map['rate'] = Variable<double>(rate.value);
    }
    if (costPrice.present) {
      map['cost_price'] = Variable<double>(costPrice.value);
    }
    if (taxPercent.present) {
      map['tax_percent'] = Variable<double>(taxPercent.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (hsnSac.present) {
      map['hsn_sac'] = Variable<String>(hsnSac.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (trackStock.present) {
      map['track_stock'] = Variable<bool>(trackStock.value);
    }
    if (lowStockThreshold.present) {
      map['low_stock_threshold'] = Variable<double>(lowStockThreshold.value);
    }
    if (lastEditedAt.present) {
      map['last_edited_at'] = Variable<DateTime>(lastEditedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServiceItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('rate: $rate, ')
          ..write('costPrice: $costPrice, ')
          ..write('taxPercent: $taxPercent, ')
          ..write('unit: $unit, ')
          ..write('hsnSac: $hsnSac, ')
          ..write('category: $category, ')
          ..write('barcode: $barcode, ')
          ..write('trackStock: $trackStock, ')
          ..write('lowStockThreshold: $lowStockThreshold, ')
          ..write('lastEditedAt: $lastEditedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductVariantsTable extends ProductVariants
    with TableInfo<$ProductVariantsTable, ProductVariantRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductVariantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<double> rate = GeneratedColumn<double>(
    'rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _costPriceMeta = const VerificationMeta(
    'costPrice',
  );
  @override
  late final GeneratedColumn<double> costPrice = GeneratedColumn<double>(
    'cost_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackStockMeta = const VerificationMeta(
    'trackStock',
  );
  @override
  late final GeneratedColumn<bool> trackStock = GeneratedColumn<bool>(
    'track_stock',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("track_stock" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lowStockThresholdMeta = const VerificationMeta(
    'lowStockThreshold',
  );
  @override
  late final GeneratedColumn<double> lowStockThreshold =
      GeneratedColumn<double>(
        'low_stock_threshold',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    name,
    rate,
    costPrice,
    barcode,
    trackStock,
    lowStockThreshold,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product_variants';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProductVariantRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    }
    if (data.containsKey('cost_price')) {
      context.handle(
        _costPriceMeta,
        costPrice.isAcceptableOrUnknown(data['cost_price']!, _costPriceMeta),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('track_stock')) {
      context.handle(
        _trackStockMeta,
        trackStock.isAcceptableOrUnknown(data['track_stock']!, _trackStockMeta),
      );
    }
    if (data.containsKey('low_stock_threshold')) {
      context.handle(
        _lowStockThresholdMeta,
        lowStockThreshold.isAcceptableOrUnknown(
          data['low_stock_threshold']!,
          _lowStockThresholdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductVariantRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductVariantRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rate'],
      )!,
      costPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost_price'],
      ),
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      trackStock: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}track_stock'],
      )!,
      lowStockThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}low_stock_threshold'],
      ),
    );
  }

  @override
  $ProductVariantsTable createAlias(String alias) {
    return $ProductVariantsTable(attachedDatabase, alias);
  }
}

class ProductVariantRow extends DataClass
    implements Insertable<ProductVariantRow> {
  final String id;
  final String itemId;
  final String name;
  final double rate;
  final double? costPrice;
  final String? barcode;
  final bool trackStock;
  final double? lowStockThreshold;
  const ProductVariantRow({
    required this.id,
    required this.itemId,
    required this.name,
    required this.rate,
    this.costPrice,
    this.barcode,
    required this.trackStock,
    this.lowStockThreshold,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['name'] = Variable<String>(name);
    map['rate'] = Variable<double>(rate);
    if (!nullToAbsent || costPrice != null) {
      map['cost_price'] = Variable<double>(costPrice);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['track_stock'] = Variable<bool>(trackStock);
    if (!nullToAbsent || lowStockThreshold != null) {
      map['low_stock_threshold'] = Variable<double>(lowStockThreshold);
    }
    return map;
  }

  ProductVariantsCompanion toCompanion(bool nullToAbsent) {
    return ProductVariantsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      name: Value(name),
      rate: Value(rate),
      costPrice: costPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(costPrice),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      trackStock: Value(trackStock),
      lowStockThreshold: lowStockThreshold == null && nullToAbsent
          ? const Value.absent()
          : Value(lowStockThreshold),
    );
  }

  factory ProductVariantRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductVariantRow(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      name: serializer.fromJson<String>(json['name']),
      rate: serializer.fromJson<double>(json['rate']),
      costPrice: serializer.fromJson<double?>(json['costPrice']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      trackStock: serializer.fromJson<bool>(json['trackStock']),
      lowStockThreshold: serializer.fromJson<double?>(
        json['lowStockThreshold'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'name': serializer.toJson<String>(name),
      'rate': serializer.toJson<double>(rate),
      'costPrice': serializer.toJson<double?>(costPrice),
      'barcode': serializer.toJson<String?>(barcode),
      'trackStock': serializer.toJson<bool>(trackStock),
      'lowStockThreshold': serializer.toJson<double?>(lowStockThreshold),
    };
  }

  ProductVariantRow copyWith({
    String? id,
    String? itemId,
    String? name,
    double? rate,
    Value<double?> costPrice = const Value.absent(),
    Value<String?> barcode = const Value.absent(),
    bool? trackStock,
    Value<double?> lowStockThreshold = const Value.absent(),
  }) => ProductVariantRow(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    name: name ?? this.name,
    rate: rate ?? this.rate,
    costPrice: costPrice.present ? costPrice.value : this.costPrice,
    barcode: barcode.present ? barcode.value : this.barcode,
    trackStock: trackStock ?? this.trackStock,
    lowStockThreshold: lowStockThreshold.present
        ? lowStockThreshold.value
        : this.lowStockThreshold,
  );
  ProductVariantRow copyWithCompanion(ProductVariantsCompanion data) {
    return ProductVariantRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      name: data.name.present ? data.name.value : this.name,
      rate: data.rate.present ? data.rate.value : this.rate,
      costPrice: data.costPrice.present ? data.costPrice.value : this.costPrice,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      trackStock: data.trackStock.present
          ? data.trackStock.value
          : this.trackStock,
      lowStockThreshold: data.lowStockThreshold.present
          ? data.lowStockThreshold.value
          : this.lowStockThreshold,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductVariantRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('name: $name, ')
          ..write('rate: $rate, ')
          ..write('costPrice: $costPrice, ')
          ..write('barcode: $barcode, ')
          ..write('trackStock: $trackStock, ')
          ..write('lowStockThreshold: $lowStockThreshold')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    name,
    rate,
    costPrice,
    barcode,
    trackStock,
    lowStockThreshold,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductVariantRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.name == this.name &&
          other.rate == this.rate &&
          other.costPrice == this.costPrice &&
          other.barcode == this.barcode &&
          other.trackStock == this.trackStock &&
          other.lowStockThreshold == this.lowStockThreshold);
}

class ProductVariantsCompanion extends UpdateCompanion<ProductVariantRow> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> name;
  final Value<double> rate;
  final Value<double?> costPrice;
  final Value<String?> barcode;
  final Value<bool> trackStock;
  final Value<double?> lowStockThreshold;
  final Value<int> rowid;
  const ProductVariantsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.name = const Value.absent(),
    this.rate = const Value.absent(),
    this.costPrice = const Value.absent(),
    this.barcode = const Value.absent(),
    this.trackStock = const Value.absent(),
    this.lowStockThreshold = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductVariantsCompanion.insert({
    required String id,
    required String itemId,
    this.name = const Value.absent(),
    this.rate = const Value.absent(),
    this.costPrice = const Value.absent(),
    this.barcode = const Value.absent(),
    this.trackStock = const Value.absent(),
    this.lowStockThreshold = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId);
  static Insertable<ProductVariantRow> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? name,
    Expression<double>? rate,
    Expression<double>? costPrice,
    Expression<String>? barcode,
    Expression<bool>? trackStock,
    Expression<double>? lowStockThreshold,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (name != null) 'name': name,
      if (rate != null) 'rate': rate,
      if (costPrice != null) 'cost_price': costPrice,
      if (barcode != null) 'barcode': barcode,
      if (trackStock != null) 'track_stock': trackStock,
      if (lowStockThreshold != null) 'low_stock_threshold': lowStockThreshold,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductVariantsCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String>? name,
    Value<double>? rate,
    Value<double?>? costPrice,
    Value<String?>? barcode,
    Value<bool>? trackStock,
    Value<double?>? lowStockThreshold,
    Value<int>? rowid,
  }) {
    return ProductVariantsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      rate: rate ?? this.rate,
      costPrice: costPrice ?? this.costPrice,
      barcode: barcode ?? this.barcode,
      trackStock: trackStock ?? this.trackStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rate.present) {
      map['rate'] = Variable<double>(rate.value);
    }
    if (costPrice.present) {
      map['cost_price'] = Variable<double>(costPrice.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (trackStock.present) {
      map['track_stock'] = Variable<bool>(trackStock.value);
    }
    if (lowStockThreshold.present) {
      map['low_stock_threshold'] = Variable<double>(lowStockThreshold.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductVariantsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('name: $name, ')
          ..write('rate: $rate, ')
          ..write('costPrice: $costPrice, ')
          ..write('barcode: $barcode, ')
          ..write('trackStock: $trackStock, ')
          ..write('lowStockThreshold: $lowStockThreshold, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemStockTable extends ItemStock
    with TableInfo<$ItemStockTable, ItemStockRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemStockTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<int> rowId = GeneratedColumn<int>(
    'row_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _variantIdMeta = const VerificationMeta(
    'variantId',
  );
  @override
  late final GeneratedColumn<String> variantId = GeneratedColumn<String>(
    'variant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _shopIdMeta = const VerificationMeta('shopId');
  @override
  late final GeneratedColumn<String> shopId = GeneratedColumn<String>(
    'shop_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    rowId,
    itemId,
    variantId,
    shopId,
    quantity,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_stock';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemStockRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('variant_id')) {
      context.handle(
        _variantIdMeta,
        variantId.isAcceptableOrUnknown(data['variant_id']!, _variantIdMeta),
      );
    }
    if (data.containsKey('shop_id')) {
      context.handle(
        _shopIdMeta,
        shopId.isAcceptableOrUnknown(data['shop_id']!, _shopIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shopIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rowId};
  @override
  ItemStockRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemStockRow(
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      variantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_id'],
      )!,
      shopId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shop_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
    );
  }

  @override
  $ItemStockTable createAlias(String alias) {
    return $ItemStockTable(attachedDatabase, alias);
  }
}

class ItemStockRow extends DataClass implements Insertable<ItemStockRow> {
  final int rowId;
  final String itemId;

  /// Empty string means the stock belongs to the item itself (no variant).
  final String variantId;
  final String shopId;
  final double quantity;
  const ItemStockRow({
    required this.rowId,
    required this.itemId,
    required this.variantId,
    required this.shopId,
    required this.quantity,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['row_id'] = Variable<int>(rowId);
    map['item_id'] = Variable<String>(itemId);
    map['variant_id'] = Variable<String>(variantId);
    map['shop_id'] = Variable<String>(shopId);
    map['quantity'] = Variable<double>(quantity);
    return map;
  }

  ItemStockCompanion toCompanion(bool nullToAbsent) {
    return ItemStockCompanion(
      rowId: Value(rowId),
      itemId: Value(itemId),
      variantId: Value(variantId),
      shopId: Value(shopId),
      quantity: Value(quantity),
    );
  }

  factory ItemStockRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemStockRow(
      rowId: serializer.fromJson<int>(json['rowId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      variantId: serializer.fromJson<String>(json['variantId']),
      shopId: serializer.fromJson<String>(json['shopId']),
      quantity: serializer.fromJson<double>(json['quantity']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rowId': serializer.toJson<int>(rowId),
      'itemId': serializer.toJson<String>(itemId),
      'variantId': serializer.toJson<String>(variantId),
      'shopId': serializer.toJson<String>(shopId),
      'quantity': serializer.toJson<double>(quantity),
    };
  }

  ItemStockRow copyWith({
    int? rowId,
    String? itemId,
    String? variantId,
    String? shopId,
    double? quantity,
  }) => ItemStockRow(
    rowId: rowId ?? this.rowId,
    itemId: itemId ?? this.itemId,
    variantId: variantId ?? this.variantId,
    shopId: shopId ?? this.shopId,
    quantity: quantity ?? this.quantity,
  );
  ItemStockRow copyWithCompanion(ItemStockCompanion data) {
    return ItemStockRow(
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      variantId: data.variantId.present ? data.variantId.value : this.variantId,
      shopId: data.shopId.present ? data.shopId.value : this.shopId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemStockRow(')
          ..write('rowId: $rowId, ')
          ..write('itemId: $itemId, ')
          ..write('variantId: $variantId, ')
          ..write('shopId: $shopId, ')
          ..write('quantity: $quantity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(rowId, itemId, variantId, shopId, quantity);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemStockRow &&
          other.rowId == this.rowId &&
          other.itemId == this.itemId &&
          other.variantId == this.variantId &&
          other.shopId == this.shopId &&
          other.quantity == this.quantity);
}

class ItemStockCompanion extends UpdateCompanion<ItemStockRow> {
  final Value<int> rowId;
  final Value<String> itemId;
  final Value<String> variantId;
  final Value<String> shopId;
  final Value<double> quantity;
  const ItemStockCompanion({
    this.rowId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.variantId = const Value.absent(),
    this.shopId = const Value.absent(),
    this.quantity = const Value.absent(),
  });
  ItemStockCompanion.insert({
    this.rowId = const Value.absent(),
    required String itemId,
    this.variantId = const Value.absent(),
    required String shopId,
    this.quantity = const Value.absent(),
  }) : itemId = Value(itemId),
       shopId = Value(shopId);
  static Insertable<ItemStockRow> custom({
    Expression<int>? rowId,
    Expression<String>? itemId,
    Expression<String>? variantId,
    Expression<String>? shopId,
    Expression<double>? quantity,
  }) {
    return RawValuesInsertable({
      if (rowId != null) 'row_id': rowId,
      if (itemId != null) 'item_id': itemId,
      if (variantId != null) 'variant_id': variantId,
      if (shopId != null) 'shop_id': shopId,
      if (quantity != null) 'quantity': quantity,
    });
  }

  ItemStockCompanion copyWith({
    Value<int>? rowId,
    Value<String>? itemId,
    Value<String>? variantId,
    Value<String>? shopId,
    Value<double>? quantity,
  }) {
    return ItemStockCompanion(
      rowId: rowId ?? this.rowId,
      itemId: itemId ?? this.itemId,
      variantId: variantId ?? this.variantId,
      shopId: shopId ?? this.shopId,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rowId.present) {
      map['row_id'] = Variable<int>(rowId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (variantId.present) {
      map['variant_id'] = Variable<String>(variantId.value);
    }
    if (shopId.present) {
      map['shop_id'] = Variable<String>(shopId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemStockCompanion(')
          ..write('rowId: $rowId, ')
          ..write('itemId: $itemId, ')
          ..write('variantId: $variantId, ')
          ..write('shopId: $shopId, ')
          ..write('quantity: $quantity')
          ..write(')'))
        .toString();
  }
}

class $InvoicesTable extends Invoices
    with TableInfo<$InvoicesTable, InvoiceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvoicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, dataJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'invoices';
  @override
  VerificationContext validateIntegrity(
    Insertable<InvoiceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InvoiceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InvoiceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
    );
  }

  @override
  $InvoicesTable createAlias(String alias) {
    return $InvoicesTable(attachedDatabase, alias);
  }
}

class InvoiceRow extends DataClass implements Insertable<InvoiceRow> {
  final String id;
  final String dataJson;
  const InvoiceRow({required this.id, required this.dataJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['data_json'] = Variable<String>(dataJson);
    return map;
  }

  InvoicesCompanion toCompanion(bool nullToAbsent) {
    return InvoicesCompanion(id: Value(id), dataJson: Value(dataJson));
  }

  factory InvoiceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InvoiceRow(
      id: serializer.fromJson<String>(json['id']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dataJson': serializer.toJson<String>(dataJson),
    };
  }

  InvoiceRow copyWith({String? id, String? dataJson}) =>
      InvoiceRow(id: id ?? this.id, dataJson: dataJson ?? this.dataJson);
  InvoiceRow copyWithCompanion(InvoicesCompanion data) {
    return InvoiceRow(
      id: data.id.present ? data.id.value : this.id,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceRow(')
          ..write('id: $id, ')
          ..write('dataJson: $dataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dataJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvoiceRow &&
          other.id == this.id &&
          other.dataJson == this.dataJson);
}

class InvoicesCompanion extends UpdateCompanion<InvoiceRow> {
  final Value<String> id;
  final Value<String> dataJson;
  final Value<int> rowid;
  const InvoicesCompanion({
    this.id = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvoicesCompanion.insert({
    required String id,
    required String dataJson,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dataJson = Value(dataJson);
  static Insertable<InvoiceRow> custom({
    Expression<String>? id,
    Expression<String>? dataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dataJson != null) 'data_json': dataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvoicesCompanion copyWith({
    Value<String>? id,
    Value<String>? dataJson,
    Value<int>? rowid,
  }) {
    return InvoicesCompanion(
      id: id ?? this.id,
      dataJson: dataJson ?? this.dataJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvoicesCompanion(')
          ..write('id: $id, ')
          ..write('dataJson: $dataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, DocumentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionMeta = const VerificationMeta(
    'collection',
  );
  @override
  late final GeneratedColumn<String> collection = GeneratedColumn<String>(
    'collection',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [collection, id, dataJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection')) {
      context.handle(
        _collectionMeta,
        collection.isAcceptableOrUnknown(data['collection']!, _collectionMeta),
      );
    } else if (isInserting) {
      context.missing(_collectionMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collection, id};
  @override
  DocumentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentRow(
      collection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }
}

class DocumentRow extends DataClass implements Insertable<DocumentRow> {
  final String collection;
  final String id;
  final String dataJson;
  const DocumentRow({
    required this.collection,
    required this.id,
    required this.dataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection'] = Variable<String>(collection);
    map['id'] = Variable<String>(id);
    map['data_json'] = Variable<String>(dataJson);
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      collection: Value(collection),
      id: Value(id),
      dataJson: Value(dataJson),
    );
  }

  factory DocumentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentRow(
      collection: serializer.fromJson<String>(json['collection']),
      id: serializer.fromJson<String>(json['id']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collection': serializer.toJson<String>(collection),
      'id': serializer.toJson<String>(id),
      'dataJson': serializer.toJson<String>(dataJson),
    };
  }

  DocumentRow copyWith({String? collection, String? id, String? dataJson}) =>
      DocumentRow(
        collection: collection ?? this.collection,
        id: id ?? this.id,
        dataJson: dataJson ?? this.dataJson,
      );
  DocumentRow copyWithCompanion(DocumentsCompanion data) {
    return DocumentRow(
      collection: data.collection.present
          ? data.collection.value
          : this.collection,
      id: data.id.present ? data.id.value : this.id,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentRow(')
          ..write('collection: $collection, ')
          ..write('id: $id, ')
          ..write('dataJson: $dataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collection, id, dataJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentRow &&
          other.collection == this.collection &&
          other.id == this.id &&
          other.dataJson == this.dataJson);
}

class DocumentsCompanion extends UpdateCompanion<DocumentRow> {
  final Value<String> collection;
  final Value<String> id;
  final Value<String> dataJson;
  final Value<int> rowid;
  const DocumentsCompanion({
    this.collection = const Value.absent(),
    this.id = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsCompanion.insert({
    required String collection,
    required String id,
    required String dataJson,
    this.rowid = const Value.absent(),
  }) : collection = Value(collection),
       id = Value(id),
       dataJson = Value(dataJson);
  static Insertable<DocumentRow> custom({
    Expression<String>? collection,
    Expression<String>? id,
    Expression<String>? dataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collection != null) 'collection': collection,
      if (id != null) 'id': id,
      if (dataJson != null) 'data_json': dataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsCompanion copyWith({
    Value<String>? collection,
    Value<String>? id,
    Value<String>? dataJson,
    Value<int>? rowid,
  }) {
    return DocumentsCompanion(
      collection: collection ?? this.collection,
      id: id ?? this.id,
      dataJson: dataJson ?? this.dataJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collection.present) {
      map['collection'] = Variable<String>(collection.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('collection: $collection, ')
          ..write('id: $id, ')
          ..write('dataJson: $dataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ClientsTable clients = $ClientsTable(this);
  late final $ServiceItemsTable serviceItems = $ServiceItemsTable(this);
  late final $ProductVariantsTable productVariants = $ProductVariantsTable(
    this,
  );
  late final $ItemStockTable itemStock = $ItemStockTable(this);
  late final $InvoicesTable invoices = $InvoicesTable(this);
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final Index idxClientsName = Index(
    'idx_clients_name',
    'CREATE INDEX idx_clients_name ON clients (name)',
  );
  late final Index idxClientsEmail = Index(
    'idx_clients_email',
    'CREATE INDEX idx_clients_email ON clients (email)',
  );
  late final Index idxClientsPhone = Index(
    'idx_clients_phone',
    'CREATE INDEX idx_clients_phone ON clients (phone)',
  );
  late final Index idxClientsCompany = Index(
    'idx_clients_company',
    'CREATE INDEX idx_clients_company ON clients (company_name)',
  );
  late final Index idxServiceItemsName = Index(
    'idx_service_items_name',
    'CREATE INDEX idx_service_items_name ON service_items (name)',
  );
  late final Index idxServiceItemsCategory = Index(
    'idx_service_items_category',
    'CREATE INDEX idx_service_items_category ON service_items (category)',
  );
  late final Index idxServiceItemsBarcode = Index(
    'idx_service_items_barcode',
    'CREATE UNIQUE INDEX idx_service_items_barcode ON service_items (barcode)',
  );
  late final Index idxProductVariantsItem = Index(
    'idx_product_variants_item',
    'CREATE INDEX idx_product_variants_item ON product_variants (item_id)',
  );
  late final Index idxProductVariantsBarcode = Index(
    'idx_product_variants_barcode',
    'CREATE UNIQUE INDEX idx_product_variants_barcode ON product_variants (barcode)',
  );
  late final Index idxItemStockItem = Index(
    'idx_item_stock_item',
    'CREATE INDEX idx_item_stock_item ON item_stock (item_id)',
  );
  late final Index idxItemStockUnique = Index(
    'idx_item_stock_unique',
    'CREATE UNIQUE INDEX idx_item_stock_unique ON item_stock (item_id, variant_id, shop_id)',
  );
  late final ClientsDao clientsDao = ClientsDao(this as AppDatabase);
  late final ItemsDao itemsDao = ItemsDao(this as AppDatabase);
  late final InvoicesDao invoicesDao = InvoicesDao(this as AppDatabase);
  late final DocumentsDao documentsDao = DocumentsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    clients,
    serviceItems,
    productVariants,
    itemStock,
    invoices,
    documents,
    idxClientsName,
    idxClientsEmail,
    idxClientsPhone,
    idxClientsCompany,
    idxServiceItemsName,
    idxServiceItemsCategory,
    idxServiceItemsBarcode,
    idxProductVariantsItem,
    idxProductVariantsBarcode,
    idxItemStockItem,
    idxItemStockUnique,
  ];
}

typedef $$ClientsTableCreateCompanionBuilder =
    ClientsCompanion Function({
      required String id,
      Value<String> name,
      Value<String> email,
      Value<String> phone,
      Value<String> address,
      Value<String> city,
      Value<String> state,
      Value<String> country,
      Value<String> postalCode,
      Value<String?> gstin,
      Value<String?> companyName,
      Value<String?> industry,
      Value<double?> creditLimit,
      Value<bool> isBulkBuyer,
      Value<double> bulkDiscountPercent,
      Value<String?> createdBy,
      Value<String?> lastEditedBy,
      Value<DateTime?> lastEditedAt,
      Value<int> rowid,
    });
typedef $$ClientsTableUpdateCompanionBuilder =
    ClientsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> email,
      Value<String> phone,
      Value<String> address,
      Value<String> city,
      Value<String> state,
      Value<String> country,
      Value<String> postalCode,
      Value<String?> gstin,
      Value<String?> companyName,
      Value<String?> industry,
      Value<double?> creditLimit,
      Value<bool> isBulkBuyer,
      Value<double> bulkDiscountPercent,
      Value<String?> createdBy,
      Value<String?> lastEditedBy,
      Value<DateTime?> lastEditedAt,
      Value<int> rowid,
    });

class $$ClientsTableFilterComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postalCode => $composableBuilder(
    column: $table.postalCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gstin => $composableBuilder(
    column: $table.gstin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get industry => $composableBuilder(
    column: $table.industry,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get creditLimit => $composableBuilder(
    column: $table.creditLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBulkBuyer => $composableBuilder(
    column: $table.isBulkBuyer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bulkDiscountPercent => $composableBuilder(
    column: $table.bulkDiscountPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastEditedBy => $composableBuilder(
    column: $table.lastEditedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastEditedAt => $composableBuilder(
    column: $table.lastEditedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClientsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postalCode => $composableBuilder(
    column: $table.postalCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gstin => $composableBuilder(
    column: $table.gstin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get industry => $composableBuilder(
    column: $table.industry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get creditLimit => $composableBuilder(
    column: $table.creditLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBulkBuyer => $composableBuilder(
    column: $table.isBulkBuyer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bulkDiscountPercent => $composableBuilder(
    column: $table.bulkDiscountPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastEditedBy => $composableBuilder(
    column: $table.lastEditedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastEditedAt => $composableBuilder(
    column: $table.lastEditedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientsTable> {
  $$ClientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get postalCode => $composableBuilder(
    column: $table.postalCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gstin =>
      $composableBuilder(column: $table.gstin, builder: (column) => column);

  GeneratedColumn<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get industry =>
      $composableBuilder(column: $table.industry, builder: (column) => column);

  GeneratedColumn<double> get creditLimit => $composableBuilder(
    column: $table.creditLimit,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBulkBuyer => $composableBuilder(
    column: $table.isBulkBuyer,
    builder: (column) => column,
  );

  GeneratedColumn<double> get bulkDiscountPercent => $composableBuilder(
    column: $table.bulkDiscountPercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get lastEditedBy => $composableBuilder(
    column: $table.lastEditedBy,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastEditedAt => $composableBuilder(
    column: $table.lastEditedAt,
    builder: (column) => column,
  );
}

class $$ClientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClientsTable,
          ClientRow,
          $$ClientsTableFilterComposer,
          $$ClientsTableOrderingComposer,
          $$ClientsTableAnnotationComposer,
          $$ClientsTableCreateCompanionBuilder,
          $$ClientsTableUpdateCompanionBuilder,
          (ClientRow, BaseReferences<_$AppDatabase, $ClientsTable, ClientRow>),
          ClientRow,
          PrefetchHooks Function()
        > {
  $$ClientsTableTableManager(_$AppDatabase db, $ClientsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String> country = const Value.absent(),
                Value<String> postalCode = const Value.absent(),
                Value<String?> gstin = const Value.absent(),
                Value<String?> companyName = const Value.absent(),
                Value<String?> industry = const Value.absent(),
                Value<double?> creditLimit = const Value.absent(),
                Value<bool> isBulkBuyer = const Value.absent(),
                Value<double> bulkDiscountPercent = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> lastEditedBy = const Value.absent(),
                Value<DateTime?> lastEditedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClientsCompanion(
                id: id,
                name: name,
                email: email,
                phone: phone,
                address: address,
                city: city,
                state: state,
                country: country,
                postalCode: postalCode,
                gstin: gstin,
                companyName: companyName,
                industry: industry,
                creditLimit: creditLimit,
                isBulkBuyer: isBulkBuyer,
                bulkDiscountPercent: bulkDiscountPercent,
                createdBy: createdBy,
                lastEditedBy: lastEditedBy,
                lastEditedAt: lastEditedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> name = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String> country = const Value.absent(),
                Value<String> postalCode = const Value.absent(),
                Value<String?> gstin = const Value.absent(),
                Value<String?> companyName = const Value.absent(),
                Value<String?> industry = const Value.absent(),
                Value<double?> creditLimit = const Value.absent(),
                Value<bool> isBulkBuyer = const Value.absent(),
                Value<double> bulkDiscountPercent = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> lastEditedBy = const Value.absent(),
                Value<DateTime?> lastEditedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClientsCompanion.insert(
                id: id,
                name: name,
                email: email,
                phone: phone,
                address: address,
                city: city,
                state: state,
                country: country,
                postalCode: postalCode,
                gstin: gstin,
                companyName: companyName,
                industry: industry,
                creditLimit: creditLimit,
                isBulkBuyer: isBulkBuyer,
                bulkDiscountPercent: bulkDiscountPercent,
                createdBy: createdBy,
                lastEditedBy: lastEditedBy,
                lastEditedAt: lastEditedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClientsTable,
      ClientRow,
      $$ClientsTableFilterComposer,
      $$ClientsTableOrderingComposer,
      $$ClientsTableAnnotationComposer,
      $$ClientsTableCreateCompanionBuilder,
      $$ClientsTableUpdateCompanionBuilder,
      (ClientRow, BaseReferences<_$AppDatabase, $ClientsTable, ClientRow>),
      ClientRow,
      PrefetchHooks Function()
    >;
typedef $$ServiceItemsTableCreateCompanionBuilder =
    ServiceItemsCompanion Function({
      required String id,
      Value<String> name,
      Value<String?> description,
      Value<double> rate,
      Value<double?> costPrice,
      Value<double> taxPercent,
      Value<String?> unit,
      Value<String?> hsnSac,
      Value<String?> category,
      Value<String?> barcode,
      Value<bool> trackStock,
      Value<double?> lowStockThreshold,
      Value<DateTime?> lastEditedAt,
      Value<int> rowid,
    });
typedef $$ServiceItemsTableUpdateCompanionBuilder =
    ServiceItemsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<double> rate,
      Value<double?> costPrice,
      Value<double> taxPercent,
      Value<String?> unit,
      Value<String?> hsnSac,
      Value<String?> category,
      Value<String?> barcode,
      Value<bool> trackStock,
      Value<double?> lowStockThreshold,
      Value<DateTime?> lastEditedAt,
      Value<int> rowid,
    });

class $$ServiceItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ServiceItemsTable> {
  $$ServiceItemsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get taxPercent => $composableBuilder(
    column: $table.taxPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hsnSac => $composableBuilder(
    column: $table.hsnSac,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get trackStock => $composableBuilder(
    column: $table.trackStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lowStockThreshold => $composableBuilder(
    column: $table.lowStockThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastEditedAt => $composableBuilder(
    column: $table.lastEditedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServiceItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ServiceItemsTable> {
  $$ServiceItemsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get taxPercent => $composableBuilder(
    column: $table.taxPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hsnSac => $composableBuilder(
    column: $table.hsnSac,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get trackStock => $composableBuilder(
    column: $table.trackStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lowStockThreshold => $composableBuilder(
    column: $table.lowStockThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastEditedAt => $composableBuilder(
    column: $table.lastEditedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServiceItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServiceItemsTable> {
  $$ServiceItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rate =>
      $composableBuilder(column: $table.rate, builder: (column) => column);

  GeneratedColumn<double> get costPrice =>
      $composableBuilder(column: $table.costPrice, builder: (column) => column);

  GeneratedColumn<double> get taxPercent => $composableBuilder(
    column: $table.taxPercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get hsnSac =>
      $composableBuilder(column: $table.hsnSac, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<bool> get trackStock => $composableBuilder(
    column: $table.trackStock,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lowStockThreshold => $composableBuilder(
    column: $table.lowStockThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastEditedAt => $composableBuilder(
    column: $table.lastEditedAt,
    builder: (column) => column,
  );
}

class $$ServiceItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServiceItemsTable,
          ServiceItemRow,
          $$ServiceItemsTableFilterComposer,
          $$ServiceItemsTableOrderingComposer,
          $$ServiceItemsTableAnnotationComposer,
          $$ServiceItemsTableCreateCompanionBuilder,
          $$ServiceItemsTableUpdateCompanionBuilder,
          (
            ServiceItemRow,
            BaseReferences<_$AppDatabase, $ServiceItemsTable, ServiceItemRow>,
          ),
          ServiceItemRow,
          PrefetchHooks Function()
        > {
  $$ServiceItemsTableTableManager(_$AppDatabase db, $ServiceItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServiceItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServiceItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServiceItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double> rate = const Value.absent(),
                Value<double?> costPrice = const Value.absent(),
                Value<double> taxPercent = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String?> hsnSac = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<bool> trackStock = const Value.absent(),
                Value<double?> lowStockThreshold = const Value.absent(),
                Value<DateTime?> lastEditedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServiceItemsCompanion(
                id: id,
                name: name,
                description: description,
                rate: rate,
                costPrice: costPrice,
                taxPercent: taxPercent,
                unit: unit,
                hsnSac: hsnSac,
                category: category,
                barcode: barcode,
                trackStock: trackStock,
                lowStockThreshold: lowStockThreshold,
                lastEditedAt: lastEditedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double> rate = const Value.absent(),
                Value<double?> costPrice = const Value.absent(),
                Value<double> taxPercent = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String?> hsnSac = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<bool> trackStock = const Value.absent(),
                Value<double?> lowStockThreshold = const Value.absent(),
                Value<DateTime?> lastEditedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServiceItemsCompanion.insert(
                id: id,
                name: name,
                description: description,
                rate: rate,
                costPrice: costPrice,
                taxPercent: taxPercent,
                unit: unit,
                hsnSac: hsnSac,
                category: category,
                barcode: barcode,
                trackStock: trackStock,
                lowStockThreshold: lowStockThreshold,
                lastEditedAt: lastEditedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServiceItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServiceItemsTable,
      ServiceItemRow,
      $$ServiceItemsTableFilterComposer,
      $$ServiceItemsTableOrderingComposer,
      $$ServiceItemsTableAnnotationComposer,
      $$ServiceItemsTableCreateCompanionBuilder,
      $$ServiceItemsTableUpdateCompanionBuilder,
      (
        ServiceItemRow,
        BaseReferences<_$AppDatabase, $ServiceItemsTable, ServiceItemRow>,
      ),
      ServiceItemRow,
      PrefetchHooks Function()
    >;
typedef $$ProductVariantsTableCreateCompanionBuilder =
    ProductVariantsCompanion Function({
      required String id,
      required String itemId,
      Value<String> name,
      Value<double> rate,
      Value<double?> costPrice,
      Value<String?> barcode,
      Value<bool> trackStock,
      Value<double?> lowStockThreshold,
      Value<int> rowid,
    });
typedef $$ProductVariantsTableUpdateCompanionBuilder =
    ProductVariantsCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<String> name,
      Value<double> rate,
      Value<double?> costPrice,
      Value<String?> barcode,
      Value<bool> trackStock,
      Value<double?> lowStockThreshold,
      Value<int> rowid,
    });

class $$ProductVariantsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductVariantsTable> {
  $$ProductVariantsTableFilterComposer({
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

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get trackStock => $composableBuilder(
    column: $table.trackStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lowStockThreshold => $composableBuilder(
    column: $table.lowStockThreshold,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProductVariantsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductVariantsTable> {
  $$ProductVariantsTableOrderingComposer({
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

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get trackStock => $composableBuilder(
    column: $table.trackStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lowStockThreshold => $composableBuilder(
    column: $table.lowStockThreshold,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProductVariantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductVariantsTable> {
  $$ProductVariantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get rate =>
      $composableBuilder(column: $table.rate, builder: (column) => column);

  GeneratedColumn<double> get costPrice =>
      $composableBuilder(column: $table.costPrice, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<bool> get trackStock => $composableBuilder(
    column: $table.trackStock,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lowStockThreshold => $composableBuilder(
    column: $table.lowStockThreshold,
    builder: (column) => column,
  );
}

class $$ProductVariantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductVariantsTable,
          ProductVariantRow,
          $$ProductVariantsTableFilterComposer,
          $$ProductVariantsTableOrderingComposer,
          $$ProductVariantsTableAnnotationComposer,
          $$ProductVariantsTableCreateCompanionBuilder,
          $$ProductVariantsTableUpdateCompanionBuilder,
          (
            ProductVariantRow,
            BaseReferences<
              _$AppDatabase,
              $ProductVariantsTable,
              ProductVariantRow
            >,
          ),
          ProductVariantRow,
          PrefetchHooks Function()
        > {
  $$ProductVariantsTableTableManager(
    _$AppDatabase db,
    $ProductVariantsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductVariantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductVariantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductVariantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> rate = const Value.absent(),
                Value<double?> costPrice = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<bool> trackStock = const Value.absent(),
                Value<double?> lowStockThreshold = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductVariantsCompanion(
                id: id,
                itemId: itemId,
                name: name,
                rate: rate,
                costPrice: costPrice,
                barcode: barcode,
                trackStock: trackStock,
                lowStockThreshold: lowStockThreshold,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                Value<String> name = const Value.absent(),
                Value<double> rate = const Value.absent(),
                Value<double?> costPrice = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<bool> trackStock = const Value.absent(),
                Value<double?> lowStockThreshold = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductVariantsCompanion.insert(
                id: id,
                itemId: itemId,
                name: name,
                rate: rate,
                costPrice: costPrice,
                barcode: barcode,
                trackStock: trackStock,
                lowStockThreshold: lowStockThreshold,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProductVariantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductVariantsTable,
      ProductVariantRow,
      $$ProductVariantsTableFilterComposer,
      $$ProductVariantsTableOrderingComposer,
      $$ProductVariantsTableAnnotationComposer,
      $$ProductVariantsTableCreateCompanionBuilder,
      $$ProductVariantsTableUpdateCompanionBuilder,
      (
        ProductVariantRow,
        BaseReferences<_$AppDatabase, $ProductVariantsTable, ProductVariantRow>,
      ),
      ProductVariantRow,
      PrefetchHooks Function()
    >;
typedef $$ItemStockTableCreateCompanionBuilder =
    ItemStockCompanion Function({
      Value<int> rowId,
      required String itemId,
      Value<String> variantId,
      required String shopId,
      Value<double> quantity,
    });
typedef $$ItemStockTableUpdateCompanionBuilder =
    ItemStockCompanion Function({
      Value<int> rowId,
      Value<String> itemId,
      Value<String> variantId,
      Value<String> shopId,
      Value<double> quantity,
    });

class $$ItemStockTableFilterComposer
    extends Composer<_$AppDatabase, $ItemStockTable> {
  $$ItemStockTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shopId => $composableBuilder(
    column: $table.shopId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ItemStockTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemStockTable> {
  $$ItemStockTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variantId => $composableBuilder(
    column: $table.variantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shopId => $composableBuilder(
    column: $table.shopId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ItemStockTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemStockTable> {
  $$ItemStockTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get variantId =>
      $composableBuilder(column: $table.variantId, builder: (column) => column);

  GeneratedColumn<String> get shopId =>
      $composableBuilder(column: $table.shopId, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);
}

class $$ItemStockTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemStockTable,
          ItemStockRow,
          $$ItemStockTableFilterComposer,
          $$ItemStockTableOrderingComposer,
          $$ItemStockTableAnnotationComposer,
          $$ItemStockTableCreateCompanionBuilder,
          $$ItemStockTableUpdateCompanionBuilder,
          (
            ItemStockRow,
            BaseReferences<_$AppDatabase, $ItemStockTable, ItemStockRow>,
          ),
          ItemStockRow,
          PrefetchHooks Function()
        > {
  $$ItemStockTableTableManager(_$AppDatabase db, $ItemStockTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemStockTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemStockTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemStockTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> rowId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> variantId = const Value.absent(),
                Value<String> shopId = const Value.absent(),
                Value<double> quantity = const Value.absent(),
              }) => ItemStockCompanion(
                rowId: rowId,
                itemId: itemId,
                variantId: variantId,
                shopId: shopId,
                quantity: quantity,
              ),
          createCompanionCallback:
              ({
                Value<int> rowId = const Value.absent(),
                required String itemId,
                Value<String> variantId = const Value.absent(),
                required String shopId,
                Value<double> quantity = const Value.absent(),
              }) => ItemStockCompanion.insert(
                rowId: rowId,
                itemId: itemId,
                variantId: variantId,
                shopId: shopId,
                quantity: quantity,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ItemStockTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemStockTable,
      ItemStockRow,
      $$ItemStockTableFilterComposer,
      $$ItemStockTableOrderingComposer,
      $$ItemStockTableAnnotationComposer,
      $$ItemStockTableCreateCompanionBuilder,
      $$ItemStockTableUpdateCompanionBuilder,
      (
        ItemStockRow,
        BaseReferences<_$AppDatabase, $ItemStockTable, ItemStockRow>,
      ),
      ItemStockRow,
      PrefetchHooks Function()
    >;
typedef $$InvoicesTableCreateCompanionBuilder =
    InvoicesCompanion Function({
      required String id,
      required String dataJson,
      Value<int> rowid,
    });
typedef $$InvoicesTableUpdateCompanionBuilder =
    InvoicesCompanion Function({
      Value<String> id,
      Value<String> dataJson,
      Value<int> rowid,
    });

class $$InvoicesTableFilterComposer
    extends Composer<_$AppDatabase, $InvoicesTable> {
  $$InvoicesTableFilterComposer({
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

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InvoicesTableOrderingComposer
    extends Composer<_$AppDatabase, $InvoicesTable> {
  $$InvoicesTableOrderingComposer({
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

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InvoicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvoicesTable> {
  $$InvoicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);
}

class $$InvoicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InvoicesTable,
          InvoiceRow,
          $$InvoicesTableFilterComposer,
          $$InvoicesTableOrderingComposer,
          $$InvoicesTableAnnotationComposer,
          $$InvoicesTableCreateCompanionBuilder,
          $$InvoicesTableUpdateCompanionBuilder,
          (
            InvoiceRow,
            BaseReferences<_$AppDatabase, $InvoicesTable, InvoiceRow>,
          ),
          InvoiceRow,
          PrefetchHooks Function()
        > {
  $$InvoicesTableTableManager(_$AppDatabase db, $InvoicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvoicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvoicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvoicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvoicesCompanion(id: id, dataJson: dataJson, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String dataJson,
                Value<int> rowid = const Value.absent(),
              }) => InvoicesCompanion.insert(
                id: id,
                dataJson: dataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InvoicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InvoicesTable,
      InvoiceRow,
      $$InvoicesTableFilterComposer,
      $$InvoicesTableOrderingComposer,
      $$InvoicesTableAnnotationComposer,
      $$InvoicesTableCreateCompanionBuilder,
      $$InvoicesTableUpdateCompanionBuilder,
      (InvoiceRow, BaseReferences<_$AppDatabase, $InvoicesTable, InvoiceRow>),
      InvoiceRow,
      PrefetchHooks Function()
    >;
typedef $$DocumentsTableCreateCompanionBuilder =
    DocumentsCompanion Function({
      required String collection,
      required String id,
      required String dataJson,
      Value<int> rowid,
    });
typedef $$DocumentsTableUpdateCompanionBuilder =
    DocumentsCompanion Function({
      Value<String> collection,
      Value<String> id,
      Value<String> dataJson,
      Value<int> rowid,
    });

class $$DocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collection => $composableBuilder(
    column: $table.collection,
    builder: (column) => column,
  );

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);
}

class $$DocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentsTable,
          DocumentRow,
          $$DocumentsTableFilterComposer,
          $$DocumentsTableOrderingComposer,
          $$DocumentsTableAnnotationComposer,
          $$DocumentsTableCreateCompanionBuilder,
          $$DocumentsTableUpdateCompanionBuilder,
          (
            DocumentRow,
            BaseReferences<_$AppDatabase, $DocumentsTable, DocumentRow>,
          ),
          DocumentRow,
          PrefetchHooks Function()
        > {
  $$DocumentsTableTableManager(_$AppDatabase db, $DocumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> collection = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion(
                collection: collection,
                id: id,
                dataJson: dataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collection,
                required String id,
                required String dataJson,
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion.insert(
                collection: collection,
                id: id,
                dataJson: dataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentsTable,
      DocumentRow,
      $$DocumentsTableFilterComposer,
      $$DocumentsTableOrderingComposer,
      $$DocumentsTableAnnotationComposer,
      $$DocumentsTableCreateCompanionBuilder,
      $$DocumentsTableUpdateCompanionBuilder,
      (
        DocumentRow,
        BaseReferences<_$AppDatabase, $DocumentsTable, DocumentRow>,
      ),
      DocumentRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ClientsTableTableManager get clients =>
      $$ClientsTableTableManager(_db, _db.clients);
  $$ServiceItemsTableTableManager get serviceItems =>
      $$ServiceItemsTableTableManager(_db, _db.serviceItems);
  $$ProductVariantsTableTableManager get productVariants =>
      $$ProductVariantsTableTableManager(_db, _db.productVariants);
  $$ItemStockTableTableManager get itemStock =>
      $$ItemStockTableTableManager(_db, _db.itemStock);
  $$InvoicesTableTableManager get invoices =>
      $$InvoicesTableTableManager(_db, _db.invoices);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db, _db.documents);
}
