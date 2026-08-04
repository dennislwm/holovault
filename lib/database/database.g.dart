// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CollectionItemsTable extends CollectionItems
    with TableInfo<$CollectionItemsTable, CollectionItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _importedIdMeta =
      const VerificationMeta('importedId');
  @override
  late final GeneratedColumn<String> importedId = GeneratedColumn<String>(
      'imported_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _extraMeta = const VerificationMeta('extra');
  @override
  late final GeneratedColumn<String> extra = GeneratedColumn<String>(
      'extra', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _setNameMeta =
      const VerificationMeta('setName');
  @override
  late final GeneratedColumn<String> setName = GeneratedColumn<String>(
      'set_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _brandNameMeta =
      const VerificationMeta('brandName');
  @override
  late final GeneratedColumn<String> brandName = GeneratedColumn<String>(
      'brand_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _discriminatorMeta =
      const VerificationMeta('discriminator');
  @override
  late final GeneratedColumn<String> discriminator = GeneratedColumn<String>(
      'discriminator', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rarityMeta = const VerificationMeta('rarity');
  @override
  late final GeneratedColumn<String> rarity = GeneratedColumn<String>(
      'rarity', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _valueTotalMeta =
      const VerificationMeta('valueTotal');
  @override
  late final GeneratedColumn<double> valueTotal = GeneratedColumn<double>(
      'value_total', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _valuePerUnitMeta =
      const VerificationMeta('valuePerUnit');
  @override
  late final GeneratedColumn<double> valuePerUnit = GeneratedColumn<double>(
      'value_per_unit', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _valueCurrencyMeta =
      const VerificationMeta('valueCurrency');
  @override
  late final GeneratedColumn<String> valueCurrency = GeneratedColumn<String>(
      'value_currency', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _paidTotalMeta =
      const VerificationMeta('paidTotal');
  @override
  late final GeneratedColumn<double> paidTotal = GeneratedColumn<double>(
      'paid_total', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _paidPerUnitMeta =
      const VerificationMeta('paidPerUnit');
  @override
  late final GeneratedColumn<double> paidPerUnit = GeneratedColumn<double>(
      'paid_per_unit', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _paidCurrencyMeta =
      const VerificationMeta('paidCurrency');
  @override
  late final GeneratedColumn<String> paidCurrency = GeneratedColumn<String>(
      'paid_currency', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _gradeTypeMeta =
      const VerificationMeta('gradeType');
  @override
  late final GeneratedColumn<String> gradeType = GeneratedColumn<String>(
      'grade_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _gradeSubtypeMeta =
      const VerificationMeta('gradeSubtype');
  @override
  late final GeneratedColumn<String> gradeSubtype = GeneratedColumn<String>(
      'grade_subtype', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _groupNameMeta =
      const VerificationMeta('groupName');
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
      'group_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _groupWishlistMeta =
      const VerificationMeta('groupWishlist');
  @override
  late final GeneratedColumn<bool> groupWishlist = GeneratedColumn<bool>(
      'group_wishlist', aliasedName, true,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("group_wishlist" IN (0, 1))'));
  static const VerificationMeta _tcgplayerIdMeta =
      const VerificationMeta('tcgplayerId');
  @override
  late final GeneratedColumn<String> tcgplayerId = GeneratedColumn<String>(
      'tcgplayer_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pricechartingIdMeta =
      const VerificationMeta('pricechartingId');
  @override
  late final GeneratedColumn<String> pricechartingId = GeneratedColumn<String>(
      'pricecharting_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _doubleholoIdMeta =
      const VerificationMeta('doubleholoId');
  @override
  late final GeneratedColumn<String> doubleholoId = GeneratedColumn<String>(
      'doubleholo_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dateAddedMeta =
      const VerificationMeta('dateAdded');
  @override
  late final GeneratedColumn<DateTime> dateAdded = GeneratedColumn<DateTime>(
      'date_added', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
      'tag', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        importedId,
        name,
        extra,
        setName,
        brandName,
        discriminator,
        rarity,
        quantity,
        valueTotal,
        valuePerUnit,
        valueCurrency,
        paidTotal,
        paidPerUnit,
        paidCurrency,
        gradeType,
        gradeSubtype,
        groupName,
        groupWishlist,
        tcgplayerId,
        pricechartingId,
        doubleholoId,
        dateAdded,
        tag
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_items';
  @override
  VerificationContext validateIntegrity(Insertable<CollectionItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('imported_id')) {
      context.handle(
          _importedIdMeta,
          importedId.isAcceptableOrUnknown(
              data['imported_id']!, _importedIdMeta));
    } else if (isInserting) {
      context.missing(_importedIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('extra')) {
      context.handle(
          _extraMeta, extra.isAcceptableOrUnknown(data['extra']!, _extraMeta));
    }
    if (data.containsKey('set_name')) {
      context.handle(_setNameMeta,
          setName.isAcceptableOrUnknown(data['set_name']!, _setNameMeta));
    }
    if (data.containsKey('brand_name')) {
      context.handle(_brandNameMeta,
          brandName.isAcceptableOrUnknown(data['brand_name']!, _brandNameMeta));
    }
    if (data.containsKey('discriminator')) {
      context.handle(
          _discriminatorMeta,
          discriminator.isAcceptableOrUnknown(
              data['discriminator']!, _discriminatorMeta));
    }
    if (data.containsKey('rarity')) {
      context.handle(_rarityMeta,
          rarity.isAcceptableOrUnknown(data['rarity']!, _rarityMeta));
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    }
    if (data.containsKey('value_total')) {
      context.handle(
          _valueTotalMeta,
          valueTotal.isAcceptableOrUnknown(
              data['value_total']!, _valueTotalMeta));
    }
    if (data.containsKey('value_per_unit')) {
      context.handle(
          _valuePerUnitMeta,
          valuePerUnit.isAcceptableOrUnknown(
              data['value_per_unit']!, _valuePerUnitMeta));
    }
    if (data.containsKey('value_currency')) {
      context.handle(
          _valueCurrencyMeta,
          valueCurrency.isAcceptableOrUnknown(
              data['value_currency']!, _valueCurrencyMeta));
    }
    if (data.containsKey('paid_total')) {
      context.handle(_paidTotalMeta,
          paidTotal.isAcceptableOrUnknown(data['paid_total']!, _paidTotalMeta));
    }
    if (data.containsKey('paid_per_unit')) {
      context.handle(
          _paidPerUnitMeta,
          paidPerUnit.isAcceptableOrUnknown(
              data['paid_per_unit']!, _paidPerUnitMeta));
    }
    if (data.containsKey('paid_currency')) {
      context.handle(
          _paidCurrencyMeta,
          paidCurrency.isAcceptableOrUnknown(
              data['paid_currency']!, _paidCurrencyMeta));
    }
    if (data.containsKey('grade_type')) {
      context.handle(_gradeTypeMeta,
          gradeType.isAcceptableOrUnknown(data['grade_type']!, _gradeTypeMeta));
    }
    if (data.containsKey('grade_subtype')) {
      context.handle(
          _gradeSubtypeMeta,
          gradeSubtype.isAcceptableOrUnknown(
              data['grade_subtype']!, _gradeSubtypeMeta));
    }
    if (data.containsKey('group_name')) {
      context.handle(_groupNameMeta,
          groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta));
    }
    if (data.containsKey('group_wishlist')) {
      context.handle(
          _groupWishlistMeta,
          groupWishlist.isAcceptableOrUnknown(
              data['group_wishlist']!, _groupWishlistMeta));
    }
    if (data.containsKey('tcgplayer_id')) {
      context.handle(
          _tcgplayerIdMeta,
          tcgplayerId.isAcceptableOrUnknown(
              data['tcgplayer_id']!, _tcgplayerIdMeta));
    }
    if (data.containsKey('pricecharting_id')) {
      context.handle(
          _pricechartingIdMeta,
          pricechartingId.isAcceptableOrUnknown(
              data['pricecharting_id']!, _pricechartingIdMeta));
    }
    if (data.containsKey('doubleholo_id')) {
      context.handle(
          _doubleholoIdMeta,
          doubleholoId.isAcceptableOrUnknown(
              data['doubleholo_id']!, _doubleholoIdMeta));
    }
    if (data.containsKey('date_added')) {
      context.handle(_dateAddedMeta,
          dateAdded.isAcceptableOrUnknown(data['date_added']!, _dateAddedMeta));
    }
    if (data.containsKey('tag')) {
      context.handle(
          _tagMeta, tag.isAcceptableOrUnknown(data['tag']!, _tagMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CollectionItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      importedId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}imported_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      extra: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}extra']),
      setName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}set_name']),
      brandName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brand_name']),
      discriminator: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}discriminator']),
      rarity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rarity']),
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity']),
      valueTotal: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}value_total']),
      valuePerUnit: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}value_per_unit']),
      valueCurrency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value_currency']),
      paidTotal: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}paid_total']),
      paidPerUnit: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}paid_per_unit']),
      paidCurrency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}paid_currency']),
      gradeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}grade_type']),
      gradeSubtype: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}grade_subtype']),
      groupName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_name']),
      groupWishlist: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}group_wishlist']),
      tcgplayerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tcgplayer_id']),
      pricechartingId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}pricecharting_id']),
      doubleholoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}doubleholo_id']),
      dateAdded: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date_added']),
      tag: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tag']),
    );
  }

  @override
  $CollectionItemsTable createAlias(String alias) {
    return $CollectionItemsTable(attachedDatabase, alias);
  }
}

class CollectionItem extends DataClass implements Insertable<CollectionItem> {
  final int id;
  final String importedId;
  final String name;
  final String? extra;
  final String? setName;
  final String? brandName;
  final String? discriminator;
  final String? rarity;
  final int? quantity;
  final double? valueTotal;
  final double? valuePerUnit;
  final String? valueCurrency;
  final double? paidTotal;
  final double? paidPerUnit;
  final String? paidCurrency;
  final String? gradeType;
  final String? gradeSubtype;
  final String? groupName;
  final bool? groupWishlist;
  final String? tcgplayerId;
  final String? pricechartingId;
  final String? doubleholoId;
  final DateTime? dateAdded;
  final String? tag;
  const CollectionItem(
      {required this.id,
      required this.importedId,
      required this.name,
      this.extra,
      this.setName,
      this.brandName,
      this.discriminator,
      this.rarity,
      this.quantity,
      this.valueTotal,
      this.valuePerUnit,
      this.valueCurrency,
      this.paidTotal,
      this.paidPerUnit,
      this.paidCurrency,
      this.gradeType,
      this.gradeSubtype,
      this.groupName,
      this.groupWishlist,
      this.tcgplayerId,
      this.pricechartingId,
      this.doubleholoId,
      this.dateAdded,
      this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['imported_id'] = Variable<String>(importedId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || extra != null) {
      map['extra'] = Variable<String>(extra);
    }
    if (!nullToAbsent || setName != null) {
      map['set_name'] = Variable<String>(setName);
    }
    if (!nullToAbsent || brandName != null) {
      map['brand_name'] = Variable<String>(brandName);
    }
    if (!nullToAbsent || discriminator != null) {
      map['discriminator'] = Variable<String>(discriminator);
    }
    if (!nullToAbsent || rarity != null) {
      map['rarity'] = Variable<String>(rarity);
    }
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<int>(quantity);
    }
    if (!nullToAbsent || valueTotal != null) {
      map['value_total'] = Variable<double>(valueTotal);
    }
    if (!nullToAbsent || valuePerUnit != null) {
      map['value_per_unit'] = Variable<double>(valuePerUnit);
    }
    if (!nullToAbsent || valueCurrency != null) {
      map['value_currency'] = Variable<String>(valueCurrency);
    }
    if (!nullToAbsent || paidTotal != null) {
      map['paid_total'] = Variable<double>(paidTotal);
    }
    if (!nullToAbsent || paidPerUnit != null) {
      map['paid_per_unit'] = Variable<double>(paidPerUnit);
    }
    if (!nullToAbsent || paidCurrency != null) {
      map['paid_currency'] = Variable<String>(paidCurrency);
    }
    if (!nullToAbsent || gradeType != null) {
      map['grade_type'] = Variable<String>(gradeType);
    }
    if (!nullToAbsent || gradeSubtype != null) {
      map['grade_subtype'] = Variable<String>(gradeSubtype);
    }
    if (!nullToAbsent || groupName != null) {
      map['group_name'] = Variable<String>(groupName);
    }
    if (!nullToAbsent || groupWishlist != null) {
      map['group_wishlist'] = Variable<bool>(groupWishlist);
    }
    if (!nullToAbsent || tcgplayerId != null) {
      map['tcgplayer_id'] = Variable<String>(tcgplayerId);
    }
    if (!nullToAbsent || pricechartingId != null) {
      map['pricecharting_id'] = Variable<String>(pricechartingId);
    }
    if (!nullToAbsent || doubleholoId != null) {
      map['doubleholo_id'] = Variable<String>(doubleholoId);
    }
    if (!nullToAbsent || dateAdded != null) {
      map['date_added'] = Variable<DateTime>(dateAdded);
    }
    if (!nullToAbsent || tag != null) {
      map['tag'] = Variable<String>(tag);
    }
    return map;
  }

  CollectionItemsCompanion toCompanion(bool nullToAbsent) {
    return CollectionItemsCompanion(
      id: Value(id),
      importedId: Value(importedId),
      name: Value(name),
      extra:
          extra == null && nullToAbsent ? const Value.absent() : Value(extra),
      setName: setName == null && nullToAbsent
          ? const Value.absent()
          : Value(setName),
      brandName: brandName == null && nullToAbsent
          ? const Value.absent()
          : Value(brandName),
      discriminator: discriminator == null && nullToAbsent
          ? const Value.absent()
          : Value(discriminator),
      rarity:
          rarity == null && nullToAbsent ? const Value.absent() : Value(rarity),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      valueTotal: valueTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(valueTotal),
      valuePerUnit: valuePerUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(valuePerUnit),
      valueCurrency: valueCurrency == null && nullToAbsent
          ? const Value.absent()
          : Value(valueCurrency),
      paidTotal: paidTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(paidTotal),
      paidPerUnit: paidPerUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(paidPerUnit),
      paidCurrency: paidCurrency == null && nullToAbsent
          ? const Value.absent()
          : Value(paidCurrency),
      gradeType: gradeType == null && nullToAbsent
          ? const Value.absent()
          : Value(gradeType),
      gradeSubtype: gradeSubtype == null && nullToAbsent
          ? const Value.absent()
          : Value(gradeSubtype),
      groupName: groupName == null && nullToAbsent
          ? const Value.absent()
          : Value(groupName),
      groupWishlist: groupWishlist == null && nullToAbsent
          ? const Value.absent()
          : Value(groupWishlist),
      tcgplayerId: tcgplayerId == null && nullToAbsent
          ? const Value.absent()
          : Value(tcgplayerId),
      pricechartingId: pricechartingId == null && nullToAbsent
          ? const Value.absent()
          : Value(pricechartingId),
      doubleholoId: doubleholoId == null && nullToAbsent
          ? const Value.absent()
          : Value(doubleholoId),
      dateAdded: dateAdded == null && nullToAbsent
          ? const Value.absent()
          : Value(dateAdded),
      tag: tag == null && nullToAbsent ? const Value.absent() : Value(tag),
    );
  }

  factory CollectionItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionItem(
      id: serializer.fromJson<int>(json['id']),
      importedId: serializer.fromJson<String>(json['importedId']),
      name: serializer.fromJson<String>(json['name']),
      extra: serializer.fromJson<String?>(json['extra']),
      setName: serializer.fromJson<String?>(json['setName']),
      brandName: serializer.fromJson<String?>(json['brandName']),
      discriminator: serializer.fromJson<String?>(json['discriminator']),
      rarity: serializer.fromJson<String?>(json['rarity']),
      quantity: serializer.fromJson<int?>(json['quantity']),
      valueTotal: serializer.fromJson<double?>(json['valueTotal']),
      valuePerUnit: serializer.fromJson<double?>(json['valuePerUnit']),
      valueCurrency: serializer.fromJson<String?>(json['valueCurrency']),
      paidTotal: serializer.fromJson<double?>(json['paidTotal']),
      paidPerUnit: serializer.fromJson<double?>(json['paidPerUnit']),
      paidCurrency: serializer.fromJson<String?>(json['paidCurrency']),
      gradeType: serializer.fromJson<String?>(json['gradeType']),
      gradeSubtype: serializer.fromJson<String?>(json['gradeSubtype']),
      groupName: serializer.fromJson<String?>(json['groupName']),
      groupWishlist: serializer.fromJson<bool?>(json['groupWishlist']),
      tcgplayerId: serializer.fromJson<String?>(json['tcgplayerId']),
      pricechartingId: serializer.fromJson<String?>(json['pricechartingId']),
      doubleholoId: serializer.fromJson<String?>(json['doubleholoId']),
      dateAdded: serializer.fromJson<DateTime?>(json['dateAdded']),
      tag: serializer.fromJson<String?>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'importedId': serializer.toJson<String>(importedId),
      'name': serializer.toJson<String>(name),
      'extra': serializer.toJson<String?>(extra),
      'setName': serializer.toJson<String?>(setName),
      'brandName': serializer.toJson<String?>(brandName),
      'discriminator': serializer.toJson<String?>(discriminator),
      'rarity': serializer.toJson<String?>(rarity),
      'quantity': serializer.toJson<int?>(quantity),
      'valueTotal': serializer.toJson<double?>(valueTotal),
      'valuePerUnit': serializer.toJson<double?>(valuePerUnit),
      'valueCurrency': serializer.toJson<String?>(valueCurrency),
      'paidTotal': serializer.toJson<double?>(paidTotal),
      'paidPerUnit': serializer.toJson<double?>(paidPerUnit),
      'paidCurrency': serializer.toJson<String?>(paidCurrency),
      'gradeType': serializer.toJson<String?>(gradeType),
      'gradeSubtype': serializer.toJson<String?>(gradeSubtype),
      'groupName': serializer.toJson<String?>(groupName),
      'groupWishlist': serializer.toJson<bool?>(groupWishlist),
      'tcgplayerId': serializer.toJson<String?>(tcgplayerId),
      'pricechartingId': serializer.toJson<String?>(pricechartingId),
      'doubleholoId': serializer.toJson<String?>(doubleholoId),
      'dateAdded': serializer.toJson<DateTime?>(dateAdded),
      'tag': serializer.toJson<String?>(tag),
    };
  }

  CollectionItem copyWith(
          {int? id,
          String? importedId,
          String? name,
          Value<String?> extra = const Value.absent(),
          Value<String?> setName = const Value.absent(),
          Value<String?> brandName = const Value.absent(),
          Value<String?> discriminator = const Value.absent(),
          Value<String?> rarity = const Value.absent(),
          Value<int?> quantity = const Value.absent(),
          Value<double?> valueTotal = const Value.absent(),
          Value<double?> valuePerUnit = const Value.absent(),
          Value<String?> valueCurrency = const Value.absent(),
          Value<double?> paidTotal = const Value.absent(),
          Value<double?> paidPerUnit = const Value.absent(),
          Value<String?> paidCurrency = const Value.absent(),
          Value<String?> gradeType = const Value.absent(),
          Value<String?> gradeSubtype = const Value.absent(),
          Value<String?> groupName = const Value.absent(),
          Value<bool?> groupWishlist = const Value.absent(),
          Value<String?> tcgplayerId = const Value.absent(),
          Value<String?> pricechartingId = const Value.absent(),
          Value<String?> doubleholoId = const Value.absent(),
          Value<DateTime?> dateAdded = const Value.absent(),
          Value<String?> tag = const Value.absent()}) =>
      CollectionItem(
        id: id ?? this.id,
        importedId: importedId ?? this.importedId,
        name: name ?? this.name,
        extra: extra.present ? extra.value : this.extra,
        setName: setName.present ? setName.value : this.setName,
        brandName: brandName.present ? brandName.value : this.brandName,
        discriminator:
            discriminator.present ? discriminator.value : this.discriminator,
        rarity: rarity.present ? rarity.value : this.rarity,
        quantity: quantity.present ? quantity.value : this.quantity,
        valueTotal: valueTotal.present ? valueTotal.value : this.valueTotal,
        valuePerUnit:
            valuePerUnit.present ? valuePerUnit.value : this.valuePerUnit,
        valueCurrency:
            valueCurrency.present ? valueCurrency.value : this.valueCurrency,
        paidTotal: paidTotal.present ? paidTotal.value : this.paidTotal,
        paidPerUnit: paidPerUnit.present ? paidPerUnit.value : this.paidPerUnit,
        paidCurrency:
            paidCurrency.present ? paidCurrency.value : this.paidCurrency,
        gradeType: gradeType.present ? gradeType.value : this.gradeType,
        gradeSubtype:
            gradeSubtype.present ? gradeSubtype.value : this.gradeSubtype,
        groupName: groupName.present ? groupName.value : this.groupName,
        groupWishlist:
            groupWishlist.present ? groupWishlist.value : this.groupWishlist,
        tcgplayerId: tcgplayerId.present ? tcgplayerId.value : this.tcgplayerId,
        pricechartingId: pricechartingId.present
            ? pricechartingId.value
            : this.pricechartingId,
        doubleholoId:
            doubleholoId.present ? doubleholoId.value : this.doubleholoId,
        dateAdded: dateAdded.present ? dateAdded.value : this.dateAdded,
        tag: tag.present ? tag.value : this.tag,
      );
  CollectionItem copyWithCompanion(CollectionItemsCompanion data) {
    return CollectionItem(
      id: data.id.present ? data.id.value : this.id,
      importedId:
          data.importedId.present ? data.importedId.value : this.importedId,
      name: data.name.present ? data.name.value : this.name,
      extra: data.extra.present ? data.extra.value : this.extra,
      setName: data.setName.present ? data.setName.value : this.setName,
      brandName: data.brandName.present ? data.brandName.value : this.brandName,
      discriminator: data.discriminator.present
          ? data.discriminator.value
          : this.discriminator,
      rarity: data.rarity.present ? data.rarity.value : this.rarity,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      valueTotal:
          data.valueTotal.present ? data.valueTotal.value : this.valueTotal,
      valuePerUnit: data.valuePerUnit.present
          ? data.valuePerUnit.value
          : this.valuePerUnit,
      valueCurrency: data.valueCurrency.present
          ? data.valueCurrency.value
          : this.valueCurrency,
      paidTotal: data.paidTotal.present ? data.paidTotal.value : this.paidTotal,
      paidPerUnit:
          data.paidPerUnit.present ? data.paidPerUnit.value : this.paidPerUnit,
      paidCurrency: data.paidCurrency.present
          ? data.paidCurrency.value
          : this.paidCurrency,
      gradeType: data.gradeType.present ? data.gradeType.value : this.gradeType,
      gradeSubtype: data.gradeSubtype.present
          ? data.gradeSubtype.value
          : this.gradeSubtype,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      groupWishlist: data.groupWishlist.present
          ? data.groupWishlist.value
          : this.groupWishlist,
      tcgplayerId:
          data.tcgplayerId.present ? data.tcgplayerId.value : this.tcgplayerId,
      pricechartingId: data.pricechartingId.present
          ? data.pricechartingId.value
          : this.pricechartingId,
      doubleholoId: data.doubleholoId.present
          ? data.doubleholoId.value
          : this.doubleholoId,
      dateAdded: data.dateAdded.present ? data.dateAdded.value : this.dateAdded,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionItem(')
          ..write('id: $id, ')
          ..write('importedId: $importedId, ')
          ..write('name: $name, ')
          ..write('extra: $extra, ')
          ..write('setName: $setName, ')
          ..write('brandName: $brandName, ')
          ..write('discriminator: $discriminator, ')
          ..write('rarity: $rarity, ')
          ..write('quantity: $quantity, ')
          ..write('valueTotal: $valueTotal, ')
          ..write('valuePerUnit: $valuePerUnit, ')
          ..write('valueCurrency: $valueCurrency, ')
          ..write('paidTotal: $paidTotal, ')
          ..write('paidPerUnit: $paidPerUnit, ')
          ..write('paidCurrency: $paidCurrency, ')
          ..write('gradeType: $gradeType, ')
          ..write('gradeSubtype: $gradeSubtype, ')
          ..write('groupName: $groupName, ')
          ..write('groupWishlist: $groupWishlist, ')
          ..write('tcgplayerId: $tcgplayerId, ')
          ..write('pricechartingId: $pricechartingId, ')
          ..write('doubleholoId: $doubleholoId, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        importedId,
        name,
        extra,
        setName,
        brandName,
        discriminator,
        rarity,
        quantity,
        valueTotal,
        valuePerUnit,
        valueCurrency,
        paidTotal,
        paidPerUnit,
        paidCurrency,
        gradeType,
        gradeSubtype,
        groupName,
        groupWishlist,
        tcgplayerId,
        pricechartingId,
        doubleholoId,
        dateAdded,
        tag
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionItem &&
          other.id == this.id &&
          other.importedId == this.importedId &&
          other.name == this.name &&
          other.extra == this.extra &&
          other.setName == this.setName &&
          other.brandName == this.brandName &&
          other.discriminator == this.discriminator &&
          other.rarity == this.rarity &&
          other.quantity == this.quantity &&
          other.valueTotal == this.valueTotal &&
          other.valuePerUnit == this.valuePerUnit &&
          other.valueCurrency == this.valueCurrency &&
          other.paidTotal == this.paidTotal &&
          other.paidPerUnit == this.paidPerUnit &&
          other.paidCurrency == this.paidCurrency &&
          other.gradeType == this.gradeType &&
          other.gradeSubtype == this.gradeSubtype &&
          other.groupName == this.groupName &&
          other.groupWishlist == this.groupWishlist &&
          other.tcgplayerId == this.tcgplayerId &&
          other.pricechartingId == this.pricechartingId &&
          other.doubleholoId == this.doubleholoId &&
          other.dateAdded == this.dateAdded &&
          other.tag == this.tag);
}

class CollectionItemsCompanion extends UpdateCompanion<CollectionItem> {
  final Value<int> id;
  final Value<String> importedId;
  final Value<String> name;
  final Value<String?> extra;
  final Value<String?> setName;
  final Value<String?> brandName;
  final Value<String?> discriminator;
  final Value<String?> rarity;
  final Value<int?> quantity;
  final Value<double?> valueTotal;
  final Value<double?> valuePerUnit;
  final Value<String?> valueCurrency;
  final Value<double?> paidTotal;
  final Value<double?> paidPerUnit;
  final Value<String?> paidCurrency;
  final Value<String?> gradeType;
  final Value<String?> gradeSubtype;
  final Value<String?> groupName;
  final Value<bool?> groupWishlist;
  final Value<String?> tcgplayerId;
  final Value<String?> pricechartingId;
  final Value<String?> doubleholoId;
  final Value<DateTime?> dateAdded;
  final Value<String?> tag;
  const CollectionItemsCompanion({
    this.id = const Value.absent(),
    this.importedId = const Value.absent(),
    this.name = const Value.absent(),
    this.extra = const Value.absent(),
    this.setName = const Value.absent(),
    this.brandName = const Value.absent(),
    this.discriminator = const Value.absent(),
    this.rarity = const Value.absent(),
    this.quantity = const Value.absent(),
    this.valueTotal = const Value.absent(),
    this.valuePerUnit = const Value.absent(),
    this.valueCurrency = const Value.absent(),
    this.paidTotal = const Value.absent(),
    this.paidPerUnit = const Value.absent(),
    this.paidCurrency = const Value.absent(),
    this.gradeType = const Value.absent(),
    this.gradeSubtype = const Value.absent(),
    this.groupName = const Value.absent(),
    this.groupWishlist = const Value.absent(),
    this.tcgplayerId = const Value.absent(),
    this.pricechartingId = const Value.absent(),
    this.doubleholoId = const Value.absent(),
    this.dateAdded = const Value.absent(),
    this.tag = const Value.absent(),
  });
  CollectionItemsCompanion.insert({
    this.id = const Value.absent(),
    required String importedId,
    required String name,
    this.extra = const Value.absent(),
    this.setName = const Value.absent(),
    this.brandName = const Value.absent(),
    this.discriminator = const Value.absent(),
    this.rarity = const Value.absent(),
    this.quantity = const Value.absent(),
    this.valueTotal = const Value.absent(),
    this.valuePerUnit = const Value.absent(),
    this.valueCurrency = const Value.absent(),
    this.paidTotal = const Value.absent(),
    this.paidPerUnit = const Value.absent(),
    this.paidCurrency = const Value.absent(),
    this.gradeType = const Value.absent(),
    this.gradeSubtype = const Value.absent(),
    this.groupName = const Value.absent(),
    this.groupWishlist = const Value.absent(),
    this.tcgplayerId = const Value.absent(),
    this.pricechartingId = const Value.absent(),
    this.doubleholoId = const Value.absent(),
    this.dateAdded = const Value.absent(),
    this.tag = const Value.absent(),
  })  : importedId = Value(importedId),
        name = Value(name);
  static Insertable<CollectionItem> custom({
    Expression<int>? id,
    Expression<String>? importedId,
    Expression<String>? name,
    Expression<String>? extra,
    Expression<String>? setName,
    Expression<String>? brandName,
    Expression<String>? discriminator,
    Expression<String>? rarity,
    Expression<int>? quantity,
    Expression<double>? valueTotal,
    Expression<double>? valuePerUnit,
    Expression<String>? valueCurrency,
    Expression<double>? paidTotal,
    Expression<double>? paidPerUnit,
    Expression<String>? paidCurrency,
    Expression<String>? gradeType,
    Expression<String>? gradeSubtype,
    Expression<String>? groupName,
    Expression<bool>? groupWishlist,
    Expression<String>? tcgplayerId,
    Expression<String>? pricechartingId,
    Expression<String>? doubleholoId,
    Expression<DateTime>? dateAdded,
    Expression<String>? tag,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (importedId != null) 'imported_id': importedId,
      if (name != null) 'name': name,
      if (extra != null) 'extra': extra,
      if (setName != null) 'set_name': setName,
      if (brandName != null) 'brand_name': brandName,
      if (discriminator != null) 'discriminator': discriminator,
      if (rarity != null) 'rarity': rarity,
      if (quantity != null) 'quantity': quantity,
      if (valueTotal != null) 'value_total': valueTotal,
      if (valuePerUnit != null) 'value_per_unit': valuePerUnit,
      if (valueCurrency != null) 'value_currency': valueCurrency,
      if (paidTotal != null) 'paid_total': paidTotal,
      if (paidPerUnit != null) 'paid_per_unit': paidPerUnit,
      if (paidCurrency != null) 'paid_currency': paidCurrency,
      if (gradeType != null) 'grade_type': gradeType,
      if (gradeSubtype != null) 'grade_subtype': gradeSubtype,
      if (groupName != null) 'group_name': groupName,
      if (groupWishlist != null) 'group_wishlist': groupWishlist,
      if (tcgplayerId != null) 'tcgplayer_id': tcgplayerId,
      if (pricechartingId != null) 'pricecharting_id': pricechartingId,
      if (doubleholoId != null) 'doubleholo_id': doubleholoId,
      if (dateAdded != null) 'date_added': dateAdded,
      if (tag != null) 'tag': tag,
    });
  }

  CollectionItemsCompanion copyWith(
      {Value<int>? id,
      Value<String>? importedId,
      Value<String>? name,
      Value<String?>? extra,
      Value<String?>? setName,
      Value<String?>? brandName,
      Value<String?>? discriminator,
      Value<String?>? rarity,
      Value<int?>? quantity,
      Value<double?>? valueTotal,
      Value<double?>? valuePerUnit,
      Value<String?>? valueCurrency,
      Value<double?>? paidTotal,
      Value<double?>? paidPerUnit,
      Value<String?>? paidCurrency,
      Value<String?>? gradeType,
      Value<String?>? gradeSubtype,
      Value<String?>? groupName,
      Value<bool?>? groupWishlist,
      Value<String?>? tcgplayerId,
      Value<String?>? pricechartingId,
      Value<String?>? doubleholoId,
      Value<DateTime?>? dateAdded,
      Value<String?>? tag}) {
    return CollectionItemsCompanion(
      id: id ?? this.id,
      importedId: importedId ?? this.importedId,
      name: name ?? this.name,
      extra: extra ?? this.extra,
      setName: setName ?? this.setName,
      brandName: brandName ?? this.brandName,
      discriminator: discriminator ?? this.discriminator,
      rarity: rarity ?? this.rarity,
      quantity: quantity ?? this.quantity,
      valueTotal: valueTotal ?? this.valueTotal,
      valuePerUnit: valuePerUnit ?? this.valuePerUnit,
      valueCurrency: valueCurrency ?? this.valueCurrency,
      paidTotal: paidTotal ?? this.paidTotal,
      paidPerUnit: paidPerUnit ?? this.paidPerUnit,
      paidCurrency: paidCurrency ?? this.paidCurrency,
      gradeType: gradeType ?? this.gradeType,
      gradeSubtype: gradeSubtype ?? this.gradeSubtype,
      groupName: groupName ?? this.groupName,
      groupWishlist: groupWishlist ?? this.groupWishlist,
      tcgplayerId: tcgplayerId ?? this.tcgplayerId,
      pricechartingId: pricechartingId ?? this.pricechartingId,
      doubleholoId: doubleholoId ?? this.doubleholoId,
      dateAdded: dateAdded ?? this.dateAdded,
      tag: tag ?? this.tag,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (importedId.present) {
      map['imported_id'] = Variable<String>(importedId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (extra.present) {
      map['extra'] = Variable<String>(extra.value);
    }
    if (setName.present) {
      map['set_name'] = Variable<String>(setName.value);
    }
    if (brandName.present) {
      map['brand_name'] = Variable<String>(brandName.value);
    }
    if (discriminator.present) {
      map['discriminator'] = Variable<String>(discriminator.value);
    }
    if (rarity.present) {
      map['rarity'] = Variable<String>(rarity.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (valueTotal.present) {
      map['value_total'] = Variable<double>(valueTotal.value);
    }
    if (valuePerUnit.present) {
      map['value_per_unit'] = Variable<double>(valuePerUnit.value);
    }
    if (valueCurrency.present) {
      map['value_currency'] = Variable<String>(valueCurrency.value);
    }
    if (paidTotal.present) {
      map['paid_total'] = Variable<double>(paidTotal.value);
    }
    if (paidPerUnit.present) {
      map['paid_per_unit'] = Variable<double>(paidPerUnit.value);
    }
    if (paidCurrency.present) {
      map['paid_currency'] = Variable<String>(paidCurrency.value);
    }
    if (gradeType.present) {
      map['grade_type'] = Variable<String>(gradeType.value);
    }
    if (gradeSubtype.present) {
      map['grade_subtype'] = Variable<String>(gradeSubtype.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (groupWishlist.present) {
      map['group_wishlist'] = Variable<bool>(groupWishlist.value);
    }
    if (tcgplayerId.present) {
      map['tcgplayer_id'] = Variable<String>(tcgplayerId.value);
    }
    if (pricechartingId.present) {
      map['pricecharting_id'] = Variable<String>(pricechartingId.value);
    }
    if (doubleholoId.present) {
      map['doubleholo_id'] = Variable<String>(doubleholoId.value);
    }
    if (dateAdded.present) {
      map['date_added'] = Variable<DateTime>(dateAdded.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionItemsCompanion(')
          ..write('id: $id, ')
          ..write('importedId: $importedId, ')
          ..write('name: $name, ')
          ..write('extra: $extra, ')
          ..write('setName: $setName, ')
          ..write('brandName: $brandName, ')
          ..write('discriminator: $discriminator, ')
          ..write('rarity: $rarity, ')
          ..write('quantity: $quantity, ')
          ..write('valueTotal: $valueTotal, ')
          ..write('valuePerUnit: $valuePerUnit, ')
          ..write('valueCurrency: $valueCurrency, ')
          ..write('paidTotal: $paidTotal, ')
          ..write('paidPerUnit: $paidPerUnit, ')
          ..write('paidCurrency: $paidCurrency, ')
          ..write('gradeType: $gradeType, ')
          ..write('gradeSubtype: $gradeSubtype, ')
          ..write('groupName: $groupName, ')
          ..write('groupWishlist: $groupWishlist, ')
          ..write('tcgplayerId: $tcgplayerId, ')
          ..write('pricechartingId: $pricechartingId, ')
          ..write('doubleholoId: $doubleholoId, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CollectionItemsTable collectionItems =
      $CollectionItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [collectionItems];
}

typedef $$CollectionItemsTableCreateCompanionBuilder = CollectionItemsCompanion
    Function({
  Value<int> id,
  required String importedId,
  required String name,
  Value<String?> extra,
  Value<String?> setName,
  Value<String?> brandName,
  Value<String?> discriminator,
  Value<String?> rarity,
  Value<int?> quantity,
  Value<double?> valueTotal,
  Value<double?> valuePerUnit,
  Value<String?> valueCurrency,
  Value<double?> paidTotal,
  Value<double?> paidPerUnit,
  Value<String?> paidCurrency,
  Value<String?> gradeType,
  Value<String?> gradeSubtype,
  Value<String?> groupName,
  Value<bool?> groupWishlist,
  Value<String?> tcgplayerId,
  Value<String?> pricechartingId,
  Value<String?> doubleholoId,
  Value<DateTime?> dateAdded,
  Value<String?> tag,
});
typedef $$CollectionItemsTableUpdateCompanionBuilder = CollectionItemsCompanion
    Function({
  Value<int> id,
  Value<String> importedId,
  Value<String> name,
  Value<String?> extra,
  Value<String?> setName,
  Value<String?> brandName,
  Value<String?> discriminator,
  Value<String?> rarity,
  Value<int?> quantity,
  Value<double?> valueTotal,
  Value<double?> valuePerUnit,
  Value<String?> valueCurrency,
  Value<double?> paidTotal,
  Value<double?> paidPerUnit,
  Value<String?> paidCurrency,
  Value<String?> gradeType,
  Value<String?> gradeSubtype,
  Value<String?> groupName,
  Value<bool?> groupWishlist,
  Value<String?> tcgplayerId,
  Value<String?> pricechartingId,
  Value<String?> doubleholoId,
  Value<DateTime?> dateAdded,
  Value<String?> tag,
});

class $$CollectionItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionItemsTable> {
  $$CollectionItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get importedId => $composableBuilder(
      column: $table.importedId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get extra => $composableBuilder(
      column: $table.extra, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get setName => $composableBuilder(
      column: $table.setName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get brandName => $composableBuilder(
      column: $table.brandName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get discriminator => $composableBuilder(
      column: $table.discriminator, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rarity => $composableBuilder(
      column: $table.rarity, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get valueTotal => $composableBuilder(
      column: $table.valueTotal, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get valuePerUnit => $composableBuilder(
      column: $table.valuePerUnit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get valueCurrency => $composableBuilder(
      column: $table.valueCurrency, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get paidTotal => $composableBuilder(
      column: $table.paidTotal, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get paidPerUnit => $composableBuilder(
      column: $table.paidPerUnit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get paidCurrency => $composableBuilder(
      column: $table.paidCurrency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gradeType => $composableBuilder(
      column: $table.gradeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gradeSubtype => $composableBuilder(
      column: $table.gradeSubtype, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupName => $composableBuilder(
      column: $table.groupName, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get groupWishlist => $composableBuilder(
      column: $table.groupWishlist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tcgplayerId => $composableBuilder(
      column: $table.tcgplayerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pricechartingId => $composableBuilder(
      column: $table.pricechartingId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get doubleholoId => $composableBuilder(
      column: $table.doubleholoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dateAdded => $composableBuilder(
      column: $table.dateAdded, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tag => $composableBuilder(
      column: $table.tag, builder: (column) => ColumnFilters(column));
}

class $$CollectionItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionItemsTable> {
  $$CollectionItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get importedId => $composableBuilder(
      column: $table.importedId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get extra => $composableBuilder(
      column: $table.extra, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get setName => $composableBuilder(
      column: $table.setName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get brandName => $composableBuilder(
      column: $table.brandName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get discriminator => $composableBuilder(
      column: $table.discriminator,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rarity => $composableBuilder(
      column: $table.rarity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get valueTotal => $composableBuilder(
      column: $table.valueTotal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get valuePerUnit => $composableBuilder(
      column: $table.valuePerUnit,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get valueCurrency => $composableBuilder(
      column: $table.valueCurrency,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get paidTotal => $composableBuilder(
      column: $table.paidTotal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get paidPerUnit => $composableBuilder(
      column: $table.paidPerUnit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get paidCurrency => $composableBuilder(
      column: $table.paidCurrency,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gradeType => $composableBuilder(
      column: $table.gradeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gradeSubtype => $composableBuilder(
      column: $table.gradeSubtype,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupName => $composableBuilder(
      column: $table.groupName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get groupWishlist => $composableBuilder(
      column: $table.groupWishlist,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tcgplayerId => $composableBuilder(
      column: $table.tcgplayerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pricechartingId => $composableBuilder(
      column: $table.pricechartingId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get doubleholoId => $composableBuilder(
      column: $table.doubleholoId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dateAdded => $composableBuilder(
      column: $table.dateAdded, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tag => $composableBuilder(
      column: $table.tag, builder: (column) => ColumnOrderings(column));
}

class $$CollectionItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionItemsTable> {
  $$CollectionItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get importedId => $composableBuilder(
      column: $table.importedId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get extra =>
      $composableBuilder(column: $table.extra, builder: (column) => column);

  GeneratedColumn<String> get setName =>
      $composableBuilder(column: $table.setName, builder: (column) => column);

  GeneratedColumn<String> get brandName =>
      $composableBuilder(column: $table.brandName, builder: (column) => column);

  GeneratedColumn<String> get discriminator => $composableBuilder(
      column: $table.discriminator, builder: (column) => column);

  GeneratedColumn<String> get rarity =>
      $composableBuilder(column: $table.rarity, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get valueTotal => $composableBuilder(
      column: $table.valueTotal, builder: (column) => column);

  GeneratedColumn<double> get valuePerUnit => $composableBuilder(
      column: $table.valuePerUnit, builder: (column) => column);

  GeneratedColumn<String> get valueCurrency => $composableBuilder(
      column: $table.valueCurrency, builder: (column) => column);

  GeneratedColumn<double> get paidTotal =>
      $composableBuilder(column: $table.paidTotal, builder: (column) => column);

  GeneratedColumn<double> get paidPerUnit => $composableBuilder(
      column: $table.paidPerUnit, builder: (column) => column);

  GeneratedColumn<String> get paidCurrency => $composableBuilder(
      column: $table.paidCurrency, builder: (column) => column);

  GeneratedColumn<String> get gradeType =>
      $composableBuilder(column: $table.gradeType, builder: (column) => column);

  GeneratedColumn<String> get gradeSubtype => $composableBuilder(
      column: $table.gradeSubtype, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<bool> get groupWishlist => $composableBuilder(
      column: $table.groupWishlist, builder: (column) => column);

  GeneratedColumn<String> get tcgplayerId => $composableBuilder(
      column: $table.tcgplayerId, builder: (column) => column);

  GeneratedColumn<String> get pricechartingId => $composableBuilder(
      column: $table.pricechartingId, builder: (column) => column);

  GeneratedColumn<String> get doubleholoId => $composableBuilder(
      column: $table.doubleholoId, builder: (column) => column);

  GeneratedColumn<DateTime> get dateAdded =>
      $composableBuilder(column: $table.dateAdded, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);
}

class $$CollectionItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CollectionItemsTable,
    CollectionItem,
    $$CollectionItemsTableFilterComposer,
    $$CollectionItemsTableOrderingComposer,
    $$CollectionItemsTableAnnotationComposer,
    $$CollectionItemsTableCreateCompanionBuilder,
    $$CollectionItemsTableUpdateCompanionBuilder,
    (
      CollectionItem,
      BaseReferences<_$AppDatabase, $CollectionItemsTable, CollectionItem>
    ),
    CollectionItem,
    PrefetchHooks Function()> {
  $$CollectionItemsTableTableManager(
      _$AppDatabase db, $CollectionItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> importedId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> extra = const Value.absent(),
            Value<String?> setName = const Value.absent(),
            Value<String?> brandName = const Value.absent(),
            Value<String?> discriminator = const Value.absent(),
            Value<String?> rarity = const Value.absent(),
            Value<int?> quantity = const Value.absent(),
            Value<double?> valueTotal = const Value.absent(),
            Value<double?> valuePerUnit = const Value.absent(),
            Value<String?> valueCurrency = const Value.absent(),
            Value<double?> paidTotal = const Value.absent(),
            Value<double?> paidPerUnit = const Value.absent(),
            Value<String?> paidCurrency = const Value.absent(),
            Value<String?> gradeType = const Value.absent(),
            Value<String?> gradeSubtype = const Value.absent(),
            Value<String?> groupName = const Value.absent(),
            Value<bool?> groupWishlist = const Value.absent(),
            Value<String?> tcgplayerId = const Value.absent(),
            Value<String?> pricechartingId = const Value.absent(),
            Value<String?> doubleholoId = const Value.absent(),
            Value<DateTime?> dateAdded = const Value.absent(),
            Value<String?> tag = const Value.absent(),
          }) =>
              CollectionItemsCompanion(
            id: id,
            importedId: importedId,
            name: name,
            extra: extra,
            setName: setName,
            brandName: brandName,
            discriminator: discriminator,
            rarity: rarity,
            quantity: quantity,
            valueTotal: valueTotal,
            valuePerUnit: valuePerUnit,
            valueCurrency: valueCurrency,
            paidTotal: paidTotal,
            paidPerUnit: paidPerUnit,
            paidCurrency: paidCurrency,
            gradeType: gradeType,
            gradeSubtype: gradeSubtype,
            groupName: groupName,
            groupWishlist: groupWishlist,
            tcgplayerId: tcgplayerId,
            pricechartingId: pricechartingId,
            doubleholoId: doubleholoId,
            dateAdded: dateAdded,
            tag: tag,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String importedId,
            required String name,
            Value<String?> extra = const Value.absent(),
            Value<String?> setName = const Value.absent(),
            Value<String?> brandName = const Value.absent(),
            Value<String?> discriminator = const Value.absent(),
            Value<String?> rarity = const Value.absent(),
            Value<int?> quantity = const Value.absent(),
            Value<double?> valueTotal = const Value.absent(),
            Value<double?> valuePerUnit = const Value.absent(),
            Value<String?> valueCurrency = const Value.absent(),
            Value<double?> paidTotal = const Value.absent(),
            Value<double?> paidPerUnit = const Value.absent(),
            Value<String?> paidCurrency = const Value.absent(),
            Value<String?> gradeType = const Value.absent(),
            Value<String?> gradeSubtype = const Value.absent(),
            Value<String?> groupName = const Value.absent(),
            Value<bool?> groupWishlist = const Value.absent(),
            Value<String?> tcgplayerId = const Value.absent(),
            Value<String?> pricechartingId = const Value.absent(),
            Value<String?> doubleholoId = const Value.absent(),
            Value<DateTime?> dateAdded = const Value.absent(),
            Value<String?> tag = const Value.absent(),
          }) =>
              CollectionItemsCompanion.insert(
            id: id,
            importedId: importedId,
            name: name,
            extra: extra,
            setName: setName,
            brandName: brandName,
            discriminator: discriminator,
            rarity: rarity,
            quantity: quantity,
            valueTotal: valueTotal,
            valuePerUnit: valuePerUnit,
            valueCurrency: valueCurrency,
            paidTotal: paidTotal,
            paidPerUnit: paidPerUnit,
            paidCurrency: paidCurrency,
            gradeType: gradeType,
            gradeSubtype: gradeSubtype,
            groupName: groupName,
            groupWishlist: groupWishlist,
            tcgplayerId: tcgplayerId,
            pricechartingId: pricechartingId,
            doubleholoId: doubleholoId,
            dateAdded: dateAdded,
            tag: tag,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CollectionItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CollectionItemsTable,
    CollectionItem,
    $$CollectionItemsTableFilterComposer,
    $$CollectionItemsTableOrderingComposer,
    $$CollectionItemsTableAnnotationComposer,
    $$CollectionItemsTableCreateCompanionBuilder,
    $$CollectionItemsTableUpdateCompanionBuilder,
    (
      CollectionItem,
      BaseReferences<_$AppDatabase, $CollectionItemsTable, CollectionItem>
    ),
    CollectionItem,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CollectionItemsTableTableManager get collectionItems =>
      $$CollectionItemsTableTableManager(_db, _db.collectionItems);
}
