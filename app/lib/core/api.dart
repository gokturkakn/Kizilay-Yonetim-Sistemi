import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api_client.dart';

/// docs/API.md sözleşmesinin tipli sarmalayıcısı.
class Api {
  Api(this.client);

  final ApiClient client;

  // Liste cevapları hem düz dizi hem {data, total} biçiminde gelebilir.
  static List<Map<String, dynamic>> _rows(dynamic resp) {
    final list = resp is List ? resp : (resp is Map ? resp['data'] : null);
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  static int _total(dynamic resp, int fallback) {
    if (resp is Map && resp['total'] is num) {
      return (resp['total'] as num).toInt();
    }
    return fallback;
  }

  // ---- Auth ----

  Future<(String token, AppUser user)> login(
      String email, String password) async {
    final resp = await client
        .post('/auth/login', {'email': email, 'password': password});
    final map = (resp as Map).cast<String, dynamic>();
    return (
      map['token']?.toString() ?? '',
      AppUser.fromJson((map['user'] as Map).cast<String, dynamic>()),
    );
  }

  // ---- Referans veri ----

  Future<List<Province>> provinces() async {
    final resp = await client.get('/provinces', query: {'limit': '100'});
    return _rows(resp).map(Province.fromJson).toList();
  }

  Future<List<District>> districts(int provinceId) async {
    final resp = await client
        .get('/provinces/$provinceId/districts', query: {'limit': '1000'});
    return _rows(resp).map(District.fromJson).toList();
  }

  Future<List<TaskArea>> taskAreas() async {
    final resp = await client.get('/task-areas', query: {'limit': '500'});
    return _rows(resp).map(TaskArea.fromJson).toList();
  }

  Future<List<Body>> bodies() async {
    final resp = await client.get('/bodies', query: {'limit': '100'});
    return _rows(resp).map(Body.fromJson).toList();
  }

  // ---- Kişiler ----

  Future<Paged<Person>> persons({
    int? provinceId,
    int? districtId,
    String? unitType,
    bool? isActive,
    String? q,
    int page = 1,
    int limit = 50,
  }) async {
    final resp = await client.get('/persons', query: {
      if (provinceId != null) 'province_id': '$provinceId',
      if (districtId != null) 'district_id': '$districtId',
      'unit_type': ?unitType,
      if (isActive != null) 'is_active': '$isActive',
      if (q != null && q.isNotEmpty) 'q': q,
      'page': '$page',
      'limit': '$limit',
    });
    final rows = _rows(resp).map(Person.fromJson).toList();
    return Paged(data: rows, total: _total(resp, rows.length));
  }

  Future<Person> personById(int id) async {
    final resp = await client.get('/persons/$id');
    return Person.fromJson((resp as Map).cast<String, dynamic>());
  }

  Future<void> createPerson(Map<String, dynamic> body) =>
      client.post('/persons', body);

  Future<void> updatePerson(int id, Map<String, dynamic> body) =>
      client.put('/persons/$id', body);

  Future<void> setPersonActive(int id, bool isActive) =>
      client.patch('/persons/$id/active', {'is_active': isActive});

  // ---- Üyelikler ----

  Future<List<Membership>> bodyMembers(int bodyId, {bool? isActive}) async {
    final resp = await client.get('/bodies/$bodyId/members', query: {
      if (isActive != null) 'is_active': '$isActive',
      'limit': '500',
    });
    return _rows(resp).map(Membership.fromJson).toList();
  }

  Future<void> addMember(int bodyId, int personId, String? roleTitle) =>
      client.post('/bodies/$bodyId/members', {
        'person_id': personId,
        if (roleTitle != null && roleTitle.isNotEmpty)
          'role_title': roleTitle,
      });

  Future<void> deleteMembership(int membershipId) =>
      client.delete('/memberships/$membershipId');

  Future<void> setMembershipActive(int membershipId, bool isActive) =>
      client.patch(
          '/memberships/$membershipId/active', {'is_active': isActive});

  // ---- Saha faaliyetleri ----

  Future<Paged<FieldActivity>> fieldActivities({
    int? taskAreaId,
    int? provinceId,
    String? from,
    String? to,
    int page = 1,
    int limit = 50,
  }) async {
    final resp = await client.get('/field-activities', query: {
      if (taskAreaId != null) 'task_area_id': '$taskAreaId',
      if (provinceId != null) 'province_id': '$provinceId',
      'from': ?from,
      'to': ?to,
      'page': '$page',
      'limit': '$limit',
    });
    final rows = _rows(resp).map(FieldActivity.fromJson).toList();
    return Paged(data: rows, total: _total(resp, rows.length));
  }

  Future<void> createFieldActivity(Map<String, dynamic> body) =>
      client.post('/field-activities', body);

  Future<void> updateFieldActivity(int id, Map<String, dynamic> body) =>
      client.put('/field-activities/$id', body);

  Future<void> deleteFieldActivity(int id) =>
      client.delete('/field-activities/$id');

  // ---- Toplantılar ----

  Future<List<Meeting>> meetings({int? bodyId, String? from, String? to}) async {
    final resp = await client.get('/meetings', query: {
      if (bodyId != null) 'body_id': '$bodyId',
      'from': ?from,
      'to': ?to,
      'limit': '500',
    });
    return _rows(resp).map(Meeting.fromJson).toList();
  }

  Future<void> createMeeting(Map<String, dynamic> body) =>
      client.post('/meetings', body);

  Future<void> updateMeeting(int id, Map<String, dynamic> body) =>
      client.put('/meetings/$id', body);

  Future<void> deleteMeeting(int id) => client.delete('/meetings/$id');

  // ---- Görev atamaları ----

  Future<List<Assignment>> assignments({int? personId, String? status}) async {
    final resp = await client.get('/assignments', query: {
      if (personId != null) 'person_id': '$personId',
      'status': ?status,
      'limit': '500',
    });
    return _rows(resp).map(Assignment.fromJson).toList();
  }

  Future<void> createAssignment(Map<String, dynamic> body) =>
      client.post('/assignments', body);

  Future<void> updateAssignment(int id, Map<String, dynamic> body) =>
      client.put('/assignments/$id', body);

  // ---- Değişiklik günlüğü ----

  Future<Paged<AuditLog>> auditLogs({
    String? entity,
    String? from,
    String? to,
    int page = 1,
    int limit = 50,
  }) async {
    final resp = await client.get('/audit-logs', query: {
      'entity': ?entity,
      'from': ?from,
      'to': ?to,
      'page': '$page',
      'limit': '$limit',
    });
    final rows = _rows(resp).map(AuditLog.fromJson).toList();
    return Paged(data: rows, total: _total(resp, rows.length));
  }

  // ---- Excel dışa aktarım ----

  Future<Uint8List> exportXlsx(String name) =>
      client.getBytes('/export/$name.xlsx');
}
