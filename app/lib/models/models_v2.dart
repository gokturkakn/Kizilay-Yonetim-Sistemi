/// v2 veri modelleri — docs/API-V2.md sözleşmesine göre.
library;

import '../core/strings_v2.dart';

int _int(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? _intOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double _double(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? fallback;
  return fallback;
}

double? _doubleOrNull(dynamic v) => v == null ? null : _double(v);

bool _bool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return fallback;
}

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// `{data:[...], total:n}` biçimini ayrıştırır.
class PagedRaw {
  const PagedRaw(this.rows, this.total);

  final List<Map<String, dynamic>> rows;
  final int total;

  static PagedRaw of(dynamic resp) {
    final list = resp is List ? resp : (resp is Map ? resp['data'] : null);
    final rows = list is List
        ? list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];
    final total =
        resp is Map && resp['total'] is num ? (resp['total'] as num).toInt() : rows.length;
    return PagedRaw(rows, total);
  }
}

class Paged2<T> {
  const Paged2({required this.data, required this.total});

  final List<T> data;
  final int total;

  bool get isEmpty => data.isEmpty;
}

// ---------------------------------------------------------------------------
// Tanımlar (lookups) — API-V2 §2
// ---------------------------------------------------------------------------

class LookupCategory {
  const LookupCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.isSystem,
    required this.itemCount,
  });

  factory LookupCategory.fromJson(Map<String, dynamic> j) => LookupCategory(
        id: _int(j['id']),
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        isSystem: _bool(j['is_system']),
        itemCount: _int(j['item_count']),
      );

  final int id;
  final String code;
  final String name;
  final bool isSystem;
  final int itemCount;
}

class LookupItem {
  const LookupItem({
    required this.id,
    required this.name,
    this.code,
    this.parentId,
    this.categoryCode,
    this.categoryId,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory LookupItem.fromJson(Map<String, dynamic> j) => LookupItem(
        id: _int(j['id']),
        name: j['name']?.toString() ?? '',
        code: _str(j['code']),
        parentId: _intOrNull(j['parent_id']),
        categoryCode: _str(j['category_code']),
        categoryId: _intOrNull(j['category_id']),
        sortOrder: _int(j['sort_order']),
        isActive: _bool(j['is_active'], true),
      );

  final int id;
  final String name;
  final String? code;
  final int? parentId;
  final String? categoryCode;
  final int? categoryId;
  final int sortOrder;
  final bool isActive;
}

// ---------------------------------------------------------------------------
// Bölgeler — API-V2 §3
// ---------------------------------------------------------------------------

class Region {
  const Region({
    required this.id,
    required this.code,
    required this.name,
    this.provinceCount = 0,
  });

  factory Region.fromJson(Map<String, dynamic> j) => Region(
        id: _int(j['id']),
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        provinceCount: _int(j['province_count']),
      );

  final int id;
  final String code;
  final String name;
  final int provinceCount;
}

// ---------------------------------------------------------------------------
// Teşkilat birimleri — API-V2 §4
// ---------------------------------------------------------------------------

class OrgUnitType {
  const OrgUnitType._();

  static const koordinasyonKurulu = 'koordinasyon_kurulu';
  static const bolgeTemsilciligi = 'bolge_temsilciligi';
  static const komisyon = 'komisyon';
  static const ilBaskanligi = 'il_baskanligi';
  static const ilceBaskanligi = 'ilce_baskanligi';
  static const temsilcilik = 'temsilcilik';

  static String label(String type) {
    switch (type) {
      case koordinasyonKurulu:
        return 'Koordinasyon Kurulu';
      case bolgeTemsilciligi:
        return 'Bölge Temsilciliği';
      case komisyon:
        return 'Komisyon';
      case ilBaskanligi:
        return 'İl Kadın Başkanlığı';
      case ilceBaskanligi:
        return 'İlçe Kadın Başkanlığı';
      case temsilcilik:
        return 'Temsilcilik';
      default:
        return type;
    }
  }
}

class OrgUnit {
  const OrgUnit({
    required this.id,
    required this.type,
    required this.name,
    required this.status,
    this.code,
    this.regionId,
    this.provinceId,
    this.districtId,
    this.parentId,
    this.bodyId,
    this.notes,
    this.assignmentCount = 0,
    this.regionName,
    this.provinceName,
    this.districtName,
  });

  factory OrgUnit.fromJson(Map<String, dynamic> j) => OrgUnit(
        id: _int(j['id']),
        type: j['type']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        status: j['status']?.toString() ?? 'pasif',
        code: _str(j['code']),
        regionId: _intOrNull(j['region_id']),
        provinceId: _intOrNull(j['province_id']),
        districtId: _intOrNull(j['district_id']),
        parentId: _intOrNull(j['parent_id']),
        bodyId: _intOrNull(j['body_id']),
        notes: _str(j['notes']),
        assignmentCount: _int(j['assignment_count']),
        regionName: _str(j['region_name']),
        provinceName: _str(j['province_name']),
        districtName: _str(j['district_name']),
      );

  final int id;
  final String type;
  final String name;
  final String status;
  final String? code;
  final int? regionId;
  final int? provinceId;
  final int? districtId;
  final int? parentId;
  final int? bodyId;
  final String? notes;
  final int assignmentCount;
  final String? regionName;
  final String? provinceName;
  final String? districtName;

  /// Künye 2. satırı: `{Bölge} · {İl} · {İlçe}` — yalnız dolu olanlar.
  String get locationLabel {
    final parts = [regionName, provinceName, districtName]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.join(' · ');
  }
}

class OrgUnitSummary {
  const OrgUnitSummary({
    required this.total,
    required this.byStatus,
    required this.byType,
    required this.byRegion,
  });

  factory OrgUnitSummary.fromJson(Map<String, dynamic> j) {
    final st = (j['by_status'] as Map?)?.cast<String, dynamic>() ?? const {};
    return OrgUnitSummary(
      total: _int(j['total']),
      byStatus: {
        'aktif': _int(st['aktif']),
        'pasif': _int(st['pasif']),
        'teskilat_yok': _int(st['teskilat_yok']),
      },
      byType: PagedRaw.of(j['by_type']).rows.map(StatusBreakdown.fromJson).toList(),
      byRegion:
          PagedRaw.of(j['by_region']).rows.map(StatusBreakdown.fromJson).toList(),
    );
  }

  final int total;
  final Map<String, int> byStatus;
  final List<StatusBreakdown> byType;
  final List<StatusBreakdown> byRegion;

  int get aktif => byStatus['aktif'] ?? 0;
  int get pasif => byStatus['pasif'] ?? 0;
  int get teskilatYok => byStatus['teskilat_yok'] ?? 0;
}

/// Bölge/tür bazlı 3 durum kırılımı.
class StatusBreakdown {
  const StatusBreakdown({
    required this.key,
    required this.name,
    required this.aktif,
    required this.pasif,
    required this.teskilatYok,
    required this.total,
    this.id,
  });

  factory StatusBreakdown.fromJson(Map<String, dynamic> j) {
    final aktif = _int(j['aktif'] ?? j['org_units_aktif']);
    final pasif = _int(j['pasif'] ?? j['org_units_pasif']);
    final yok = _int(j['teskilat_yok'] ?? j['org_units_teskilat_yok']);
    final total = j['total'] != null || j['org_units_total'] != null
        ? _int(j['total'] ?? j['org_units_total'])
        : aktif + pasif + yok;
    return StatusBreakdown(
      key: (j['type'] ?? j['region_id'] ?? j['province_id'] ?? '').toString(),
      name: (j['region_name'] ?? j['province_name'] ?? j['name'] ??
              (j['type'] != null ? OrgUnitType.label(j['type'].toString()) : ''))
          .toString(),
      id: _intOrNull(j['region_id'] ?? j['province_id'] ?? j['id']),
      aktif: aktif,
      pasif: pasif,
      teskilatYok: yok,
      total: total,
    );
  }

  final String key;
  final String name;
  final int? id;
  final int aktif;
  final int pasif;
  final int teskilatYok;
  final int total;
}

// ---------------------------------------------------------------------------
// Görevlendirmeler — API-V2 §5
// ---------------------------------------------------------------------------

class OrgAssignment {
  const OrgAssignment({
    required this.id,
    required this.orgUnitId,
    required this.personId,
    required this.startDate,
    required this.status,
    this.roleTitle,
    this.roleId,
    this.endDate,
    this.notes,
    this.personName,
    this.orgUnitName,
  });

  factory OrgAssignment.fromJson(Map<String, dynamic> j) => OrgAssignment(
        id: _int(j['id']),
        orgUnitId: _int(j['org_unit_id']),
        personId: _int(j['person_id']),
        startDate: j['start_date']?.toString() ?? '',
        status: j['status']?.toString() ?? 'aktif',
        roleTitle: _str(j['role_title']),
        roleId: _intOrNull(j['role_id']),
        endDate: _str(j['end_date']),
        notes: _str(j['notes']),
        personName: _str(j['person_name']),
        orgUnitName: _str(j['org_unit_name']),
      );

  final int id;
  final int orgUnitId;
  final int personId;
  final String startDate;
  final String status;
  final String? roleTitle;
  final int? roleId;
  final String? endDate;
  final String? notes;
  final String? personName;
  final String? orgUnitName;

  bool get isActive => status == 'aktif';
}

// ---------------------------------------------------------------------------
// Saha faaliyetleri — API-V2 §6
// ---------------------------------------------------------------------------

class TaskRecord {
  const TaskRecord({
    required this.id,
    required this.taskDate,
    this.regionId,
    this.provinceId,
    this.districtId,
    this.branch,
    this.orgUnitId,
    this.taskTypeId,
    this.subTaskId,
    this.volunteerCount = 0,
    this.beneficiaryCount = 0,
    this.durationHours,
    this.notes,
    this.attachmentCount = 0,
    this.taskTypeName,
    this.subTaskName,
    this.provinceName,
    this.districtName,
    this.regionName,
  });

  factory TaskRecord.fromJson(Map<String, dynamic> j) => TaskRecord(
        id: _int(j['id']),
        taskDate: j['task_date']?.toString() ?? '',
        regionId: _intOrNull(j['region_id']),
        provinceId: _intOrNull(j['province_id']),
        districtId: _intOrNull(j['district_id']),
        branch: _str(j['branch']),
        orgUnitId: _intOrNull(j['org_unit_id']),
        taskTypeId: _intOrNull(j['task_type_id']),
        subTaskId: _intOrNull(j['sub_task_id']),
        volunteerCount: _int(j['volunteer_count']),
        beneficiaryCount: _int(j['beneficiary_count']),
        durationHours: _doubleOrNull(j['duration_hours']),
        notes: _str(j['notes']),
        attachmentCount: _int(j['attachment_count']),
        taskTypeName: _str(j['task_type_name']),
        subTaskName: _str(j['sub_task_name']),
        provinceName: _str(j['province_name']),
        districtName: _str(j['district_name']),
        regionName: _str(j['region_name']),
      );

  final int id;
  final String taskDate;
  final int? regionId;
  final int? provinceId;
  final int? districtId;
  final String? branch;
  final int? orgUnitId;
  final int? taskTypeId;
  final int? subTaskId;
  final int volunteerCount;
  final int beneficiaryCount;
  final double? durationHours;
  final String? notes;
  final int attachmentCount;
  final String? taskTypeName;
  final String? subTaskName;
  final String? provinceName;
  final String? districtName;
  final String? regionName;
}

class TrainingRecord {
  const TrainingRecord({
    required this.id,
    required this.trainingDate,
    this.regionId,
    this.provinceId,
    this.orgUnitId,
    this.trainer,
    this.topicId,
    this.categoryId,
    this.methodId,
    this.platform,
    this.participantCount = 0,
    this.volunteerCount = 0,
    this.durationHours,
    this.notes,
    this.attachmentCount = 0,
    this.topicName,
    this.categoryName,
    this.methodName,
    this.provinceName,
    this.orgUnitName,
  });

  factory TrainingRecord.fromJson(Map<String, dynamic> j) => TrainingRecord(
        id: _int(j['id']),
        trainingDate: j['training_date']?.toString() ?? '',
        regionId: _intOrNull(j['region_id']),
        provinceId: _intOrNull(j['province_id']),
        orgUnitId: _intOrNull(j['org_unit_id']),
        trainer: _str(j['trainer']),
        topicId: _intOrNull(j['topic_id']),
        categoryId: _intOrNull(j['category_id']),
        methodId: _intOrNull(j['method_id']),
        platform: _str(j['platform']),
        participantCount: _int(j['participant_count']),
        volunteerCount: _int(j['volunteer_count']),
        durationHours: _doubleOrNull(j['duration_hours']),
        notes: _str(j['notes']),
        attachmentCount: _int(j['attachment_count']),
        topicName: _str(j['topic_name']),
        categoryName: _str(j['category_name']),
        methodName: _str(j['method_name']),
        provinceName: _str(j['province_name']),
        orgUnitName: _str(j['org_unit_name']),
      );

  final int id;
  final String trainingDate;
  final int? regionId;
  final int? provinceId;
  final int? orgUnitId;
  final String? trainer;
  final int? topicId;
  final int? categoryId;
  final int? methodId;
  final String? platform;
  final int participantCount;
  final int volunteerCount;
  final double? durationHours;
  final String? notes;
  final int attachmentCount;
  final String? topicName;
  final String? categoryName;
  final String? methodName;
  final String? provinceName;
  final String? orgUnitName;
}

class EventRecord {
  const EventRecord({
    required this.id,
    required this.eventDate,
    this.calendarEventId,
    this.eventTypeId,
    this.regionId,
    this.provinceId,
    this.orgUnitId,
    this.participantCount = 0,
    this.volunteerCount = 0,
    this.beneficiaryCount = 0,
    this.notes,
    this.attachmentCount = 0,
    this.calendarEventName,
    this.eventTypeName,
    this.provinceName,
    this.orgUnitName,
  });

  factory EventRecord.fromJson(Map<String, dynamic> j) => EventRecord(
        id: _int(j['id']),
        eventDate: j['event_date']?.toString() ?? '',
        calendarEventId: _intOrNull(j['calendar_event_id']),
        eventTypeId: _intOrNull(j['event_type_id']),
        regionId: _intOrNull(j['region_id']),
        provinceId: _intOrNull(j['province_id']),
        orgUnitId: _intOrNull(j['org_unit_id']),
        participantCount: _int(j['participant_count']),
        volunteerCount: _int(j['volunteer_count']),
        beneficiaryCount: _int(j['beneficiary_count']),
        notes: _str(j['notes']),
        attachmentCount: _int(j['attachment_count']),
        calendarEventName: _str(j['calendar_event_name']),
        eventTypeName: _str(j['event_type_name']),
        provinceName: _str(j['province_name']),
        orgUnitName: _str(j['org_unit_name']),
      );

  final int id;
  final String eventDate;
  final int? calendarEventId;
  final int? eventTypeId;
  final int? regionId;
  final int? provinceId;
  final int? orgUnitId;
  final int participantCount;
  final int volunteerCount;
  final int beneficiaryCount;
  final String? notes;
  final int attachmentCount;
  final String? calendarEventName;
  final String? eventTypeName;
  final String? provinceName;
  final String? orgUnitName;
}

class MeetingV2 {
  const MeetingV2({
    required this.id,
    required this.meetingDate,
    this.bodyId,
    this.meetingTypeId,
    this.methodId,
    this.location,
    this.platform,
    this.orgUnitId,
    this.regionId,
    this.provinceId,
    this.participants,
    this.participantCount,
    this.agenda,
    this.decision,
    this.outcome,
    this.attachmentCount = 0,
    this.meetingTypeName,
    this.methodName,
    this.orgUnitName,
  });

  factory MeetingV2.fromJson(Map<String, dynamic> j) => MeetingV2(
        id: _int(j['id']),
        meetingDate: j['meeting_date']?.toString() ?? '',
        bodyId: _intOrNull(j['body_id']),
        meetingTypeId: _intOrNull(j['meeting_type_id']),
        methodId: _intOrNull(j['method_id']),
        location: _str(j['location']),
        platform: _str(j['platform']),
        orgUnitId: _intOrNull(j['org_unit_id']),
        regionId: _intOrNull(j['region_id']),
        provinceId: _intOrNull(j['province_id']),
        participants: _str(j['participants']),
        participantCount: _intOrNull(j['participant_count']),
        agenda: _str(j['agenda']),
        decision: _str(j['decision']),
        outcome: _str(j['outcome']),
        attachmentCount: _int(j['attachment_count']),
        meetingTypeName: _str(j['meeting_type_name']),
        methodName: _str(j['method_name']),
        orgUnitName: _str(j['org_unit_name']),
      );

  final int id;
  final String meetingDate;
  final int? bodyId;
  final int? meetingTypeId;
  final int? methodId;
  final String? location;
  final String? platform;
  final int? orgUnitId;
  final int? regionId;
  final int? provinceId;
  final String? participants;

  /// API notu N-6: sunucu bu alanı eklerse okunur, yoksa `null` kalır.
  final int? participantCount;
  final String? agenda;
  final String? decision;
  final String? outcome;
  final int attachmentCount;
  final String? meetingTypeName;
  final String? methodName;
  final String? orgUnitName;

  bool get isOnline => (platform ?? '').isNotEmpty;
}

// ---------------------------------------------------------------------------
// Lojistik — API-V2 §7
// ---------------------------------------------------------------------------

class MaterialRequest {
  const MaterialRequest({
    required this.id,
    required this.requestDate,
    required this.status,
    this.orgUnitId,
    this.regionId,
    this.provinceId,
    this.productId,
    this.quantity = 0,
    this.requestedByPersonId,
    this.notes,
    this.productName,
    this.orgUnitName,
    this.shippedQuantity = 0,
  });

  factory MaterialRequest.fromJson(Map<String, dynamic> j) => MaterialRequest(
        id: _int(j['id']),
        requestDate: j['request_date']?.toString() ?? '',
        status: j['status']?.toString() ?? 'talep',
        orgUnitId: _intOrNull(j['org_unit_id']),
        regionId: _intOrNull(j['region_id']),
        provinceId: _intOrNull(j['province_id']),
        productId: _intOrNull(j['product_id']),
        quantity: _int(j['quantity']),
        requestedByPersonId: _intOrNull(j['requested_by_person_id']),
        notes: _str(j['notes']),
        productName: _str(j['product_name']),
        orgUnitName: _str(j['org_unit_name']),
        shippedQuantity: _int(j['shipped_quantity']),
      );

  final int id;
  final String requestDate;
  final String status;
  final int? orgUnitId;
  final int? regionId;
  final int? provinceId;
  final int? productId;
  final int quantity;
  final int? requestedByPersonId;
  final String? notes;
  final String? productName;
  final String? orgUnitName;
  final int shippedQuantity;

  int get remainingQuantity =>
      (quantity - shippedQuantity) < 0 ? 0 : quantity - shippedQuantity;
}

class Shipment {
  const Shipment({
    required this.id,
    required this.requestId,
    required this.shipmentDate,
    this.shippingMethodId,
    this.trackingNo,
    this.quantity = 0,
    this.receivedBy,
    this.receivedDate,
    this.notes,
    this.productId,
    this.productName,
    this.shippingMethodName,
    this.requestDate,
    this.orgUnitName,
  });

  factory Shipment.fromJson(Map<String, dynamic> j) => Shipment(
        id: _int(j['id']),
        requestId: _int(j['request_id']),
        shipmentDate: j['shipment_date']?.toString() ?? '',
        shippingMethodId: _intOrNull(j['shipping_method_id']),
        trackingNo: _str(j['tracking_no']),
        quantity: _int(j['quantity']),
        receivedBy: _str(j['received_by']),
        receivedDate: _str(j['received_date']),
        notes: _str(j['notes']),
        productId: _intOrNull(j['product_id']),
        productName: _str(j['product_name']),
        shippingMethodName: _str(j['shipping_method_name']),
        requestDate: _str(j['request_date']),
        orgUnitName: _str(j['org_unit_name']),
      );

  final int id;
  final int requestId;
  final String shipmentDate;
  final int? shippingMethodId;
  final String? trackingNo;
  final int quantity;
  final String? receivedBy;
  final String? receivedDate;
  final String? notes;
  final int? productId;
  final String? productName;
  final String? shippingMethodName;
  final String? requestDate;
  final String? orgUnitName;
}

class StockItem {
  const StockItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.minQuantity,
    required this.isLow,
  });

  factory StockItem.fromJson(Map<String, dynamic> j) => StockItem(
        productId: _int(j['product_id']),
        productName: j['product_name']?.toString() ?? '',
        quantity: _int(j['quantity']),
        minQuantity: _int(j['min_quantity']),
        isLow: _bool(j['is_low']),
      );

  final int productId;
  final String productName;
  final int quantity;
  final int minQuantity;
  final bool isLow;
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.direction,
    required this.quantity,
    this.reason,
    this.createdAt,
    this.productName,
  });

  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
        id: _int(j['id']),
        productId: _int(j['product_id']),
        direction: j['direction']?.toString() ?? 'giris',
        quantity: _int(j['quantity']),
        reason: _str(j['reason']),
        createdAt: _str(j['created_at']),
        productName: _str(j['product_name']),
      );

  final int id;
  final int productId;
  final String direction; // giris | cikis
  final int quantity;
  final String? reason;
  final String? createdAt;
  final String? productName;

  bool get isIn => direction == 'giris';
}

// ---------------------------------------------------------------------------
// Takvim — API-V2 §8
// ---------------------------------------------------------------------------

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.name,
    required this.category,
    this.month,
    this.day,
    this.endMonth,
    this.endDay,
    this.isFixed = true,
    this.note,
    this.resolvedDate,
    this.resolvedEndDate,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> j) {
    final resolved = j['resolved_date'];
    String? start;
    String? end;
    if (resolved is Map) {
      start = _str(resolved['start_date']);
      end = _str(resolved['end_date']);
    } else {
      start = _str(resolved);
      end = _str(j['resolved_end_date']);
    }
    return CalendarEvent(
      id: _int(j['id']),
      name: j['name']?.toString() ?? '',
      category: j['category']?.toString() ?? '',
      month: _intOrNull(j['month']),
      day: _intOrNull(j['day']),
      endMonth: _intOrNull(j['end_month']),
      endDay: _intOrNull(j['end_day']),
      isFixed: _bool(j['is_fixed'], true),
      note: _str(j['note']),
      resolvedDate: start,
      resolvedEndDate: end,
    );
  }

  final int id;
  final String name;
  final String category;
  final int? month;
  final int? day;
  final int? endMonth;
  final int? endDay;
  final bool isFixed;
  final String? note;
  final String? resolvedDate;
  final String? resolvedEndDate;

  /// Kategori kodu → ekran metni (E-47).
  static String categoryLabel(String category) {
    switch (category) {
      case 'milli_bayram':
        return 'Millî Bayram';
      case 'dini_bayram':
        return 'Dinî Bayram';
      case 'dini_gun':
        return 'Dinî Gün';
      case 'resmi_gun':
        return 'Resmî Gün';
      case 'onemli_gun':
        return 'Önemli Gün';
      case 'onemli_hafta':
        return 'Önemli Hafta';
      default:
        return category;
    }
  }

  /// Gruplama ayı — tarihi belirlenmemişse `null`.
  int? get groupMonth {
    if (month != null) return month;
    final d = DateTime.tryParse(resolvedDate ?? '');
    return d?.month;
  }

  bool get hasDate => groupMonth != null;
}

// ---------------------------------------------------------------------------
// İçerik blokları — API-V2 §10
// ---------------------------------------------------------------------------

class ContentBlock {
  const ContentBlock({
    required this.key,
    required this.title,
    required this.body,
    this.updatedAt,
    this.updatedByName,
  });

  factory ContentBlock.fromJson(Map<String, dynamic> j) => ContentBlock(
        key: j['key']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        updatedAt: _str(j['updated_at']),
        updatedByName: _str(j['updated_by_name']),
      );

  final String key;
  final String title;
  final String body;
  final String? updatedAt;
  final String? updatedByName;

  bool get isEmpty => body.trim().isEmpty;
}

// ---------------------------------------------------------------------------
// Kullanıcılar — API-V2 §11
// ---------------------------------------------------------------------------

class UserAccount {
  const UserAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.regionId,
    this.provinceId,
    this.regionName,
    this.provinceName,
  });

  factory UserAccount.fromJson(Map<String, dynamic> j) => UserAccount(
        id: _int(j['id']),
        name: j['name']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        role: j['role']?.toString() ?? 'saha',
        isActive: _bool(j['is_active'], true),
        regionId: _intOrNull(j['region_id']),
        provinceId: _intOrNull(j['province_id']),
        regionName: _str(j['region_name']),
        provinceName: _str(j['province_name']),
      );

  final int id;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final int? regionId;
  final int? provinceId;
  final String? regionName;
  final String? provinceName;

  bool get isAdmin => role == 'genel_merkez';
  String get roleLabel => isAdmin ? 'Genel Merkez' : 'Saha';
}

// ---------------------------------------------------------------------------
// Ekler — API-V2 §9
// ---------------------------------------------------------------------------

class Attachment {
  const Attachment({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.kind,
    required this.fileName,
    required this.mime,
    required this.size,
    this.uploadedBy,
    this.uploadedByName,
    this.downloadUrl,
    this.createdAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        id: _int(j['id']),
        entity: j['entity']?.toString() ?? '',
        entityId: _int(j['entity_id']),
        kind: j['kind']?.toString() ?? 'dokuman',
        fileName: j['file_name']?.toString() ?? '',
        mime: j['mime']?.toString() ?? '',
        size: _int(j['size']),
        uploadedBy: _intOrNull(j['uploaded_by']),
        uploadedByName: _str(j['uploaded_by_name']),
        downloadUrl: _str(j['download_url']),
        createdAt: _str(j['created_at']),
      );

  final int id;
  final String entity;
  final int entityId;
  final String kind;
  final String fileName;
  final String mime;
  final int size;
  final int? uploadedBy;
  final String? uploadedByName;
  final String? downloadUrl;
  final String? createdAt;

  bool get isImage => mime.startsWith('image/');
}

// ---------------------------------------------------------------------------
// Dashboard — API-V2 §12
// ---------------------------------------------------------------------------

class ActivityCounts {
  const ActivityCounts({
    this.count = 0,
    this.volunteers = 0,
    this.beneficiaries = 0,
    this.participants = 0,
    this.hours = 0,
  });

  factory ActivityCounts.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ActivityCounts();
    return ActivityCounts(
      count: _int(j['count']),
      volunteers: _int(j['volunteers']),
      beneficiaries: _int(j['beneficiaries']),
      participants: _int(j['participants']),
      hours: _double(j['hours']),
    );
  }

  final int count;
  final int volunteers;
  final int beneficiaries;
  final int participants;
  final double hours;
}

class DashboardSummary {
  const DashboardSummary({
    required this.orgUnits,
    required this.persons,
    required this.byRegion,
    required this.tasks,
    required this.trainings,
    required this.events,
    required this.meetings,
    required this.topTaskTypes,
    required this.requestsByStatus,
    required this.shipmentCount,
    required this.stockProducts,
    required this.stockTotal,
    required this.stockLow,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) {
    final org = (j['organization'] as Map?)?.cast<String, dynamic>() ?? const {};
    final act = (j['activity'] as Map?)?.cast<String, dynamic>() ?? const {};
    final log = (j['logistics'] as Map?)?.cast<String, dynamic>() ?? const {};
    final req = (log['requests'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ship = (log['shipments'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stock = (log['stock'] as Map?)?.cast<String, dynamic>() ?? const {};
    Map<String, int> counts(dynamic m) {
      final map = (m as Map?)?.cast<String, dynamic>() ?? const {};
      return {
        'aktif': _int(map['aktif']),
        'pasif': _int(map['pasif']),
        'teskilat_yok': _int(map['teskilat_yok']),
        'total': _int(map['total']),
      };
    }

    return DashboardSummary(
      orgUnits: counts(org['org_units']),
      persons: counts(org['persons']),
      byRegion:
          PagedRaw.of(org['by_region']).rows.map(StatusBreakdown.fromJson).toList(),
      tasks: ActivityCounts.fromJson(
          (act['tasks'] as Map?)?.cast<String, dynamic>()),
      trainings: ActivityCounts.fromJson(
          (act['trainings'] as Map?)?.cast<String, dynamic>()),
      events: ActivityCounts.fromJson(
          (act['events'] as Map?)?.cast<String, dynamic>()),
      meetings: ActivityCounts.fromJson(
          (act['meetings'] as Map?)?.cast<String, dynamic>()),
      topTaskTypes: PagedRaw.of(j['top_task_types'])
          .rows
          .map((e) => TopTaskType(
                id: _intOrNull(e['task_type_id']),
                name: e['name']?.toString() ?? '',
                count: _int(e['count']),
              ))
          .toList(),
      requestsByStatus: {
        for (final k in RequestStatusKeys.all) k: _int(req[k]),
      },
      shipmentCount: _int(ship['count']),
      stockProducts: _int(stock['products']),
      stockTotal: _int(stock['total_quantity']),
      stockLow: _int(stock['low_stock']),
    );
  }

  final Map<String, int> orgUnits;
  final Map<String, int> persons;
  final List<StatusBreakdown> byRegion;
  final ActivityCounts tasks;
  final ActivityCounts trainings;
  final ActivityCounts events;
  final ActivityCounts meetings;
  final List<TopTaskType> topTaskTypes;
  final Map<String, int> requestsByStatus;
  final int shipmentCount;
  final int stockProducts;
  final int stockTotal;
  final int stockLow;

  int get orgAktif => orgUnits['aktif'] ?? 0;
  int get orgPasif => orgUnits['pasif'] ?? 0;
  int get orgTeskilatYok => orgUnits['teskilat_yok'] ?? 0;
  int get orgTotal =>
      (orgUnits['total'] ?? 0) > 0
          ? orgUnits['total']!
          : orgAktif + orgPasif + orgTeskilatYok;

  /// Açık talep = `talep` + `onaylandi` (§5.4 Bölüm 5).
  int get openRequests =>
      (requestsByStatus['talep'] ?? 0) + (requestsByStatus['onaylandi'] ?? 0);
  int get deliveredRequests => requestsByStatus['teslim_edildi'] ?? 0;

  /// Gönüllü toplamı — faaliyet KPI'sı.
  int get totalVolunteers =>
      tasks.volunteers + trainings.volunteers + events.volunteers;
}

class RequestStatusKeys {
  const RequestStatusKeys._();
  static const all = [
    'talep',
    'onaylandi',
    'gonderildi',
    'teslim_edildi',
    'iptal',
  ];
}

class TopTaskType {
  const TopTaskType({required this.id, required this.name, required this.count});

  final int? id;
  final String name;
  final int count;
}

/// `GET /dashboard/timeseries` — aylık zaman serisi (API notu N-2).
///
/// Alan adları esnek okunur: `{month|period|label, count|value}`.
class TimeseriesPoint {
  const TimeseriesPoint({required this.label, required this.value});

  factory TimeseriesPoint.fromJson(Map<String, dynamic> j) => TimeseriesPoint(
        label: (j['period'] ?? j['month'] ?? j['label'] ?? '').toString(),
        value: _double(j['count'] ?? j['value'] ?? j['total']),
      );

  final String label; // 'YYYY-MM' (interval=month) veya 'YYYY' (interval=year)
  final double value;

  /// `2026-07` → `Tem`.
  String get shortMonthLabel {
    const names = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
    ];
    final parts = label.split('-');
    if (parts.length >= 2) {
      final m = int.tryParse(parts[1]);
      if (m != null && m >= 1 && m <= 12) return names[m - 1];
    }
    return label;
  }
}

/// `GET /dashboard/provinces` — il bazlı kırılım (81 satır).
///
/// Sunucu alan adları: `province_id`, `province_code`, `province_name`,
/// `region_id`, `org_active`, `org_passive`, `org_none`, `person_count`,
/// `activity_count`.
class ProvinceBreakdown {
  const ProvinceBreakdown({
    required this.provinceId,
    required this.provinceName,
    required this.code,
    required this.aktif,
    required this.pasif,
    required this.teskilatYok,
    this.regionId,
    this.regionName,
    this.personCount = 0,
    this.activityCount = 0,
  });

  factory ProvinceBreakdown.fromJson(Map<String, dynamic> j) =>
      ProvinceBreakdown(
        provinceId: _int(j['province_id'] ?? j['id']),
        provinceName: (j['province_name'] ?? j['name'] ?? '').toString(),
        code: _int(j['province_code'] ?? j['code'] ?? j['plate']),
        aktif: _int(j['org_active'] ?? j['aktif'] ?? j['org_units_aktif']),
        pasif: _int(j['org_passive'] ?? j['pasif'] ?? j['org_units_pasif']),
        teskilatYok:
            _int(j['org_none'] ?? j['teskilat_yok'] ?? j['org_units_teskilat_yok']),
        regionId: _intOrNull(j['region_id']),
        regionName: _str(j['region_name']),
        personCount: _int(j['person_count']),
        activityCount: _int(j['activity_count']),
      );

  final int provinceId;
  final String provinceName;
  final int code;
  final int aktif;
  final int pasif;
  final int teskilatYok;
  final int? regionId;
  final String? regionName;
  final int personCount;
  final int activityCount;

  int get total => aktif + pasif + teskilatYok;
}

// ---------------------------------------------------------------------------
// Kılavuz ve Dokümanlar — API-V2 §19 (SPEC-V2-M6)
// ---------------------------------------------------------------------------

/// Doküman kapsamı — `documents.scope` (API-V2 §19.3, CHECK ile zorlanır).
///
/// Bu liste **Tanımlar'dan gelmez**: sözleşme sabiti bir enum'dır, sunucu
/// listedekiler dışında bir değeri 400 ile reddeder. R4'ün "kodda sabit liste
/// yasağı" Tanımlar'dan yönetilen listeler içindir; kapsam onlardan biri değil.
class DocumentScope {
  const DocumentScope._();

  static const genel = 'genel';
  static const bolge = 'bolge';
  static const il = 'il';
  static const ilce = 'ilce';

  static const all = [genel, bolge, il, ilce];

  /// Filtre çipi / form seçeneği etiketi (SPEC-V2-M6 §5.3 kapsam rozetleri).
  static String label(String scope) {
    switch (scope) {
      case bolge:
        return S2.dokKapsamBolge;
      case il:
        return S2.dokKapsamIl;
      case ilce:
        return S2.dokKapsamIlce;
      default:
        return S2.dokKapsamGenel;
    }
  }
}

/// Doküman kaydı — API-V2 §19.2.
///
/// `scopeLabel`, `isExpired` ve `attachmentCount` **sunucuda** hesaplanır;
/// istemci bunları yeniden türetmez (§19.5).
class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.scope,
    required this.scopeLabel,
    required this.isExpired,
    required this.isActive,
    required this.downloadCount,
    required this.attachmentCount,
    this.description,
    this.categoryName,
    this.regionId,
    this.provinceId,
    this.districtId,
    this.regionName,
    this.provinceName,
    this.districtName,
    this.version,
    this.publishedAt,
    this.validUntil,
    this.createdByName,
    this.attachments = const [],
  });

  factory DocumentRecord.fromJson(Map<String, dynamic> j) => DocumentRecord(
        id: _int(j['id']),
        title: j['title']?.toString() ?? '',
        description: _str(j['description']),
        categoryId: _int(j['category_id']),
        categoryName: _str(j['category_name']),
        scope: j['scope']?.toString() ?? DocumentScope.genel,
        scopeLabel: j['scope_label']?.toString() ?? S2.dokKapsamGenel,
        regionId: _intOrNull(j['region_id']),
        provinceId: _intOrNull(j['province_id']),
        districtId: _intOrNull(j['district_id']),
        regionName: _str(j['region_name']),
        provinceName: _str(j['province_name']),
        districtName: _str(j['district_name']),
        version: _str(j['version']),
        publishedAt: _str(j['published_at']),
        validUntil: _str(j['valid_until']),
        isExpired: _bool(j['is_expired']),
        isActive: _bool(j['is_active'], true),
        downloadCount: _int(j['download_count']),
        attachmentCount: _int(j['attachment_count']),
        createdByName: _str(j['created_by_name']),
        attachments: (j['attachments'] as List?)
                ?.map((e) => Attachment.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  final int id;
  final String title;
  final String? description;
  final int categoryId;
  final String? categoryName;
  final String scope;

  /// Rozet metni: `Genel` / `<Bölge adı>` / `<İl adı>` / `<İlçe adı>`.
  final String scopeLabel;
  final int? regionId;
  final int? provinceId;
  final int? districtId;
  final String? regionName;
  final String? provinceName;
  final String? districtName;
  final String? version;
  final String? publishedAt;
  final String? validUntil;

  /// `valid_until` geçmiş → "Süresi doldu" rozeti (sunucuda `date('now')`).
  final bool isExpired;
  final bool isActive;
  final int downloadCount;
  final int attachmentCount;
  final String? createdByName;

  /// Yalnız `GET /documents/:id` gövdesinde dolu gelir.
  final List<Attachment> attachments;
}
