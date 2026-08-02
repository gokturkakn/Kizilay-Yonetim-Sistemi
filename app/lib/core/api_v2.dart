import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/models_v2.dart';
import 'api_client.dart';

/// docs/API-V2.md sözleşmesinin tipli sarmalayıcısı.
///
/// v1 [Api] sınıfı **yerinde durur**; bu sınıf onun yanında çalışır ve aynı
/// [ApiClient] örneğini paylaşır.
class ApiV2 {
  ApiV2(this.client);

  final ApiClient client;

  static Map<String, String> _q(Map<String, Object?> raw) {
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      out[k] = v.toString();
    });
    return out;
  }

  // ---- Tanımlar (§2) ----

  Future<List<LookupCategory>> lookupCategories() async {
    final resp = await client.get('/lookup-categories', query: {'limit': '200'});
    return PagedRaw.of(resp).rows.map(LookupCategory.fromJson).toList();
  }

  Future<LookupCategory> createLookupCategory(String code, String name) async {
    final resp =
        await client.post('/lookup-categories', {'code': code, 'name': name});
    return LookupCategory.fromJson((resp as Map).cast<String, dynamic>());
  }

  /// `GET /lookups/:categoryCode` — kategori yoksa 404 `NOT_FOUND`.
  Future<List<LookupItem>> lookups(
    String categoryCode, {
    int? parentId,
    bool? isActive,
    String? q,
  }) async {
    final resp = await client.get('/lookups/$categoryCode',
        query: _q({
          'parent_id': parentId,
          'is_active': isActive == null ? null : (isActive ? '1' : '0'),
          'q': q,
          'limit': '1000',
        }));
    return PagedRaw.of(resp).rows.map(LookupItem.fromJson).toList();
  }

  Future<List<LookupItem>> lookupItems({
    String? categoryCode,
    int? categoryId,
    int? parentId,
    bool? isActive,
    String? q,
  }) async {
    final resp = await client.get('/lookup-items',
        query: _q({
          'category_code': categoryCode,
          'category_id': categoryId,
          'parent_id': parentId,
          'is_active': isActive == null ? null : (isActive ? '1' : '0'),
          'q': q,
          'limit': '1000',
        }));
    return PagedRaw.of(resp).rows.map(LookupItem.fromJson).toList();
  }

  Future<void> createLookupItem(Map<String, dynamic> body) =>
      client.post('/lookup-items', body);

  Future<void> updateLookupItem(int id, Map<String, dynamic> body) =>
      client.put('/lookup-items/$id', body);

  Future<void> setLookupItemActive(int id, bool isActive) =>
      client.patch('/lookup-items/$id/active', {'is_active': isActive});

  Future<void> deleteLookupItem(int id) => client.delete('/lookup-items/$id');

  // ---- Bölgeler (§3) ----

  Future<List<Region>> regions() async {
    final resp = await client.get('/regions', query: {'limit': '50'});
    return PagedRaw.of(resp).rows.map(Region.fromJson).toList();
  }

  Future<List<Province>> provinces({int? regionId}) async {
    final resp = await client.get('/provinces',
        query: _q({'region_id': regionId, 'limit': '100'}));
    return PagedRaw.of(resp).rows.map(Province.fromJson).toList();
  }

  Future<List<District>> districts(int provinceId) async {
    final resp = await client
        .get('/provinces/$provinceId/districts', query: {'limit': '1000'});
    return PagedRaw.of(resp).rows.map(District.fromJson).toList();
  }

  // ---- Teşkilat birimleri (§4) ----

  Future<Paged2<OrgUnit>> orgUnits({
    String? type,
    List<String>? statuses,
    int? regionId,
    int? provinceId,
    int? districtId,
    int? parentId,
    String? q,
    int page = 1,
    int limit = 200,
  }) async {
    final query = _q({
      'type': type,
      'region_id': regionId,
      'province_id': provinceId,
      'district_id': districtId,
      'parent_id': parentId,
      'q': q,
      'page': page,
      'limit': limit,
    });
    if (statuses != null && statuses.length == 1) {
      query['status'] = statuses.first;
    }
    final resp = await client.get('/org-units', query: query);
    final raw = PagedRaw.of(resp);
    return Paged2(
      data: raw.rows.map(OrgUnit.fromJson).toList(),
      total: raw.total,
    );
  }

  Future<OrgUnit> orgUnit(int id) async {
    final resp = await client.get('/org-units/$id');
    return OrgUnit.fromJson((resp as Map).cast<String, dynamic>());
  }

  Future<OrgUnit> createOrgUnit(Map<String, dynamic> body) async {
    final resp = await client.post('/org-units', body);
    return OrgUnit.fromJson((resp as Map).cast<String, dynamic>());
  }

  Future<void> updateOrgUnit(int id, Map<String, dynamic> body) =>
      client.put('/org-units/$id', body);

  Future<void> setOrgUnitStatus(int id, String status) =>
      client.patch('/org-units/$id/status', {'status': status});

  Future<OrgUnitSummary> orgUnitSummary({String? type, int? regionId}) async {
    final resp = await client.get('/org-units/summary',
        query: _q({'type': type, 'region_id': regionId}));
    return OrgUnitSummary.fromJson((resp as Map).cast<String, dynamic>());
  }

  // ---- Görevlendirmeler (§5) ----

  Future<List<OrgAssignment>> orgAssignments({
    int? orgUnitId,
    int? personId,
    String? status,
    int? roleId,
  }) async {
    final resp = await client.get('/org-assignments',
        query: _q({
          'org_unit_id': orgUnitId,
          'person_id': personId,
          'status': status,
          'role_id': roleId,
          'limit': '500',
        }));
    return PagedRaw.of(resp).rows.map(OrgAssignment.fromJson).toList();
  }

  Future<void> createOrgAssignment(Map<String, dynamic> body) =>
      client.post('/org-assignments', body);

  Future<void> updateOrgAssignment(int id, Map<String, dynamic> body) =>
      client.put('/org-assignments/$id', body);

  Future<void> setOrgAssignmentStatus(int id, String status) =>
      client.patch('/org-assignments/$id/status', {'status': status});

  Future<void> deleteOrgAssignment(int id) =>
      client.delete('/org-assignments/$id');

  // ---- Görevler (§6.1) ----

  Future<Paged2<TaskRecord>> tasks({
    int? taskTypeId,
    int? subTaskId,
    int? regionId,
    int? provinceId,
    int? districtId,
    int? orgUnitId,
    String? from,
    String? to,
    String? q,
    int page = 1,
    int limit = 50,
  }) async {
    final resp = await client.get('/tasks',
        query: _q({
          'task_type_id': taskTypeId,
          'sub_task_id': subTaskId,
          'region_id': regionId,
          'province_id': provinceId,
          'district_id': districtId,
          'org_unit_id': orgUnitId,
          'from': from,
          'to': to,
          'q': q,
          'page': page,
          'limit': limit,
        }));
    final raw = PagedRaw.of(resp);
    return Paged2(
        data: raw.rows.map(TaskRecord.fromJson).toList(), total: raw.total);
  }

  Future<int> createTask(Map<String, dynamic> body) async =>
      _idOf(await client.post('/tasks', body));

  Future<void> updateTask(int id, Map<String, dynamic> body) =>
      client.put('/tasks/$id', body);

  Future<void> deleteTask(int id) => client.delete('/tasks/$id');

  // ---- Eğitimler (§6.2) ----

  Future<Paged2<TrainingRecord>> trainings({
    int? topicId,
    int? categoryId,
    int? methodId,
    int? regionId,
    int? provinceId,
    int? orgUnitId,
    String? from,
    String? to,
    int page = 1,
    int limit = 50,
  }) async {
    final resp = await client.get('/trainings',
        query: _q({
          'topic_id': topicId,
          'category_id': categoryId,
          'method_id': methodId,
          'region_id': regionId,
          'province_id': provinceId,
          'org_unit_id': orgUnitId,
          'from': from,
          'to': to,
          'page': page,
          'limit': limit,
        }));
    final raw = PagedRaw.of(resp);
    return Paged2(
        data: raw.rows.map(TrainingRecord.fromJson).toList(), total: raw.total);
  }

  Future<int> createTraining(Map<String, dynamic> body) async =>
      _idOf(await client.post('/trainings', body));

  Future<void> updateTraining(int id, Map<String, dynamic> body) =>
      client.put('/trainings/$id', body);

  Future<void> deleteTraining(int id) => client.delete('/trainings/$id');

  // ---- Etkinlikler (§6.3) ----

  Future<Paged2<EventRecord>> events({
    int? calendarEventId,
    int? eventTypeId,
    int? regionId,
    int? provinceId,
    int? orgUnitId,
    String? from,
    String? to,
    int page = 1,
    int limit = 50,
  }) async {
    final resp = await client.get('/events',
        query: _q({
          'calendar_event_id': calendarEventId,
          'event_type_id': eventTypeId,
          'region_id': regionId,
          'province_id': provinceId,
          'org_unit_id': orgUnitId,
          'from': from,
          'to': to,
          'page': page,
          'limit': limit,
        }));
    final raw = PagedRaw.of(resp);
    return Paged2(
        data: raw.rows.map(EventRecord.fromJson).toList(), total: raw.total);
  }

  Future<int> createEvent(Map<String, dynamic> body) async =>
      _idOf(await client.post('/events', body));

  Future<void> updateEvent(int id, Map<String, dynamic> body) =>
      client.put('/events/$id', body);

  Future<void> deleteEvent(int id) => client.delete('/events/$id');

  // ---- Toplantılar (§6.4) ----

  Future<Paged2<MeetingV2>> meetings({
    int? bodyId,
    int? meetingTypeId,
    int? methodId,
    int? orgUnitId,
    int? regionId,
    int? provinceId,
    String? from,
    String? to,
    int page = 1,
    int limit = 50,
  }) async {
    final resp = await client.get('/meetings',
        query: _q({
          'body_id': bodyId,
          'meeting_type_id': meetingTypeId,
          'method_id': methodId,
          'org_unit_id': orgUnitId,
          'region_id': regionId,
          'province_id': provinceId,
          'from': from,
          'to': to,
          'page': page,
          'limit': limit,
        }));
    final raw = PagedRaw.of(resp);
    return Paged2(
        data: raw.rows.map(MeetingV2.fromJson).toList(), total: raw.total);
  }

  Future<int> createMeeting(Map<String, dynamic> body) async =>
      _idOf(await client.post('/meetings', body));

  Future<void> updateMeeting(int id, Map<String, dynamic> body) =>
      client.put('/meetings/$id', body);

  Future<void> deleteMeeting(int id) => client.delete('/meetings/$id');

  // ---- Lojistik (§7) ----

  Future<Paged2<MaterialRequest>> materialRequests({
    String? status,
    int? productId,
    int? orgUnitId,
    int? regionId,
    int? provinceId,
    String? from,
    String? to,
    int page = 1,
    int limit = 100,
  }) async {
    final resp = await client.get('/material-requests',
        query: _q({
          'status': status,
          'product_id': productId,
          'org_unit_id': orgUnitId,
          'region_id': regionId,
          'province_id': provinceId,
          'from': from,
          'to': to,
          'page': page,
          'limit': limit,
        }));
    final raw = PagedRaw.of(resp);
    return Paged2(
        data: raw.rows.map(MaterialRequest.fromJson).toList(), total: raw.total);
  }

  Future<int> createMaterialRequest(Map<String, dynamic> body) async =>
      _idOf(await client.post('/material-requests', body));

  Future<void> updateMaterialRequest(int id, Map<String, dynamic> body) =>
      client.put('/material-requests/$id', body);

  Future<void> setMaterialRequestStatus(int id, String status) =>
      client.patch('/material-requests/$id/status', {'status': status});

  Future<void> deleteMaterialRequest(int id) =>
      client.delete('/material-requests/$id');

  Future<Paged2<Shipment>> shipments({
    int? requestId,
    int? shippingMethodId,
    int? productId,
    String? from,
    String? to,
    int page = 1,
    int limit = 100,
  }) async {
    final resp = await client.get('/shipments',
        query: _q({
          'request_id': requestId,
          'shipping_method_id': shippingMethodId,
          'product_id': productId,
          'from': from,
          'to': to,
          'page': page,
          'limit': limit,
        }));
    final raw = PagedRaw.of(resp);
    return Paged2(
        data: raw.rows.map(Shipment.fromJson).toList(), total: raw.total);
  }

  Future<int> createShipment(Map<String, dynamic> body) async =>
      _idOf(await client.post('/shipments', body));

  Future<void> updateShipment(int id, Map<String, dynamic> body) =>
      client.put('/shipments/$id', body);

  Future<void> deleteShipment(int id) => client.delete('/shipments/$id');

  Future<List<StockItem>> stockItems({int? productId, bool lowOnly = false}) async {
    final resp = await client.get('/stock-items',
        query: _q({
          'product_id': productId,
          'low_only': lowOnly ? '1' : null,
          'limit': '500',
        }));
    return PagedRaw.of(resp).rows.map(StockItem.fromJson).toList();
  }

  Future<void> setStockMinQuantity(int productId, int minQuantity) =>
      client.put('/stock-items/$productId', {'min_quantity': minQuantity});

  Future<List<StockMovement>> stockMovements({
    int? productId,
    String? direction,
    String? from,
    String? to,
  }) async {
    final resp = await client.get('/stock-movements',
        query: _q({
          'product_id': productId,
          'direction': direction,
          'from': from,
          'to': to,
          'limit': '500',
        }));
    return PagedRaw.of(resp).rows.map(StockMovement.fromJson).toList();
  }

  Future<void> createStockMovement(Map<String, dynamic> body) =>
      client.post('/stock-movements', body);

  // ---- Takvim (§8) ----

  Future<List<CalendarEvent>> calendarEvents({
    String? category,
    int? month,
    int? year,
    String? q,
  }) async {
    final resp = await client.get('/calendar-events',
        query: _q({
          'category': category,
          'month': month,
          'year': year,
          'q': q,
          'limit': '500',
        }));
    return PagedRaw.of(resp).rows.map(CalendarEvent.fromJson).toList();
  }

  Future<CalendarEvent> calendarEvent(int id) async {
    final resp = await client.get('/calendar-events/$id');
    return CalendarEvent.fromJson((resp as Map).cast<String, dynamic>());
  }

  // ---- Ekler (§9) ----

  Future<List<Attachment>> attachments({
    required String entity,
    required int entityId,
    String? kind,
  }) async {
    final resp = await client.get('/attachments',
        query: _q({
          'entity': entity,
          'entity_id': entityId,
          'kind': kind,
          'limit': '200',
        }));
    return PagedRaw.of(resp).rows.map(Attachment.fromJson).toList();
  }

  Future<Attachment> uploadAttachment({
    required String entity,
    required int entityId,
    required String kind,
    required String fileName,
    required List<int> bytes,
  }) async {
    final resp = await client.postMultipart('/attachments',
        bytes: bytes,
        fileName: fileName,
        fields: {
          'entity': entity,
          'entity_id': '$entityId',
          'kind': kind,
        });
    return Attachment.fromJson((resp as Map).cast<String, dynamic>());
  }

  Future<void> deleteAttachment(int id) => client.delete('/attachments/$id');

  Future<Uint8List> downloadAttachment(int id) =>
      client.getBytes('/attachments/$id/download');

  // ---- İçerik blokları (§10) ----

  Future<List<ContentBlock>> contentBlocks() async {
    final resp = await client.get('/content-blocks', query: {'limit': '100'});
    return PagedRaw.of(resp).rows.map(ContentBlock.fromJson).toList();
  }

  Future<ContentBlock> contentBlock(String key) async {
    final resp = await client.get('/content-blocks/$key');
    return ContentBlock.fromJson((resp as Map).cast<String, dynamic>());
  }

  Future<void> saveContentBlock(String key, String title, String body) =>
      client.put('/content-blocks/$key', {'title': title, 'body': body});

  // ---- Kullanıcılar (§11) ----

  Future<List<UserAccount>> users({String? role, bool? isActive, String? q}) async {
    final resp = await client.get('/users',
        query: _q({
          'role': role,
          'is_active': isActive == null ? null : (isActive ? '1' : '0'),
          'q': q,
          'limit': '500',
        }));
    return PagedRaw.of(resp).rows.map(UserAccount.fromJson).toList();
  }

  Future<void> createUser(Map<String, dynamic> body) =>
      client.post('/users', body);

  Future<void> updateUser(int id, Map<String, dynamic> body) =>
      client.put('/users/$id', body);

  Future<void> setUserActive(int id, bool isActive) =>
      client.patch('/users/$id/active', {'is_active': isActive});

  Future<void> setUserPassword(int id, String password) =>
      client.put('/users/$id/password', {'password': password});

  Future<void> changeOwnPassword(String current, String next) =>
      client.post('/auth/change-password',
          {'current_password': current, 'new_password': next});

  // ---- Kişiler (§13) ----

  Future<void> setPersonStatus(int id, String status) =>
      client.patch('/persons/$id/status', {'status': status});

  // ---- Dashboard (§12) ----

  /// `activityType`: `gorev | egitim | etkinlik | toplanti` (geçersiz → 400).
  Future<DashboardSummary> dashboardSummary({
    int? regionId,
    int? provinceId,
    int? districtId,
    String? activityType,
    String? from,
    String? to,
  }) async {
    final resp = await client.get('/dashboard/summary',
        query: _q({
          'region_id': regionId,
          'province_id': provinceId,
          'district_id': districtId,
          'activity_type': activityType,
          'from': from,
          'to': to,
        }));
    return DashboardSummary.fromJson((resp as Map).cast<String, dynamic>());
  }

  Future<List<StatusBreakdown>> dashboardByRegion({
    String? from,
    String? to,
  }) async {
    final resp = await client.get('/dashboard/by-region',
        query: _q({'from': from, 'to': to}));
    return PagedRaw.of(resp).rows.map(StatusBreakdown.fromJson).toList();
  }

  /// `GET /dashboard/timeseries?metric=&interval=` →
  /// `{metric, interval, data:[{period:"2026-01", count:n}]}`.
  /// Boş dönemler sıfırla doldurulmuş ve kronolojik sıradadır.
  ///
  /// Uç bulunamazsa (404) `null` döner → trend kartı hiç render edilmez
  /// (§11 N-2 geri düşüşü).
  Future<List<TimeseriesPoint>?> dashboardTimeseries({
    String metric = 'gorev',
    String interval = 'month',
    String? from,
    String? to,
    int? regionId,
    int? provinceId,
  }) async {
    try {
      final resp = await client.get('/dashboard/timeseries',
          query: _q({
            'metric': metric,
            'interval': interval,
            'from': from,
            'to': to,
            'region_id': regionId,
            'province_id': provinceId,
          }));
      return PagedRaw.of(resp).rows.map(TimeseriesPoint.fromJson).toList();
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// `GET /dashboard/provinces` → 81 satır. 404 ise `null` (§11 N-1:
  /// istemci tarafı sayıma düşülür).
  Future<List<ProvinceBreakdown>?> dashboardProvinces({
    int? regionId,
    String? from,
    String? to,
  }) async {
    try {
      final resp = await client.get('/dashboard/provinces',
          query: _q({'region_id': regionId, 'from': from, 'to': to}));
      return PagedRaw.of(resp).rows.map(ProvinceBreakdown.fromJson).toList();
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  // ---- Dışa aktarım ----

  Future<Uint8List> exportXlsx(String name, Map<String, Object?> filters) =>
      client.getBytes('/export/$name.xlsx', query: _q(filters));

  /// PDF ucu tanımlı değilse (404) `null` döner — §11 N-8: buton gizlenir.
  Future<Uint8List?> exportPdf(String name, Map<String, Object?> filters) async {
    try {
      return await client.getBytes('/export/$name.pdf', query: _q(filters));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  static int _idOf(dynamic resp) {
    if (resp is Map && resp['id'] != null) {
      final v = resp['id'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }
    return 0;
  }
}

/// API hata kodu → Türkçe metin — docs/UX-V2.md §11.2.
String v2ErrorMessage(Object error, {String fallback = 'Bir şeyler ters gitti.'}) {
  if (error is! ApiException) return fallback;
  if (error.isNetwork) return 'Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.';
  switch (error.code) {
    case 'VALIDATION_ERROR':
      return error.message.isNotEmpty
          ? error.message
          : 'Girdiğiniz bilgilerde hata var. Lütfen kontrol edin.';
    case 'INVALID_JSON':
    case 'INTERNAL':
      return 'Bir şeyler ters gitti.';
    case 'INVALID_TC_NO':
      return 'Geçersiz TC kimlik numarası.';
    case 'UNSUPPORTED_FILE_TYPE':
      return 'Yalnızca JPG, PNG, WEBP, GIF, PDF, Word (.docx) ve Excel (.xlsx) '
          'dosyaları yükleyebilirsiniz.';
    case 'FILE_TOO_LARGE':
      return 'Dosya boyutu en fazla 10 MB olabilir.';
    case 'WEAK_PASSWORD':
      return 'Şifre en az 8 karakter olmalıdır.';
    case 'UNAUTHORIZED':
      return 'Oturum süreniz doldu. Lütfen tekrar giriş yapın.';
    case 'ACCOUNT_DISABLED':
      return 'Hesabınız pasif durumda. Genel merkez ile iletişime geçin.';
    case 'FORBIDDEN':
      return 'Bu işlem için yetkiniz yok.';
    case 'NOT_FOUND':
      return 'Kayıt bulunamadı. Silinmiş olabilir.';
    case 'LAST_ADMIN':
      return 'Sistemdeki son genel merkez hesabı pasif yapılamaz.';
    default:
      return error.message.isNotEmpty ? error.message : fallback;
  }
}
