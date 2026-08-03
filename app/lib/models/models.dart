/// Veri modelleri — docs/API.md sözleşmesine göre.
///
/// Sunucu bazı listelerde ilişkili adları (province_name vb.) döndürebilir;
/// modeller bu alanları esnek biçimde ayrıştırır, yoksa null bırakır ve
/// UI referans veri önbelleğinden çözer.
library;

int _asInt(dynamic v) =>
    v is int ? v : (v is String ? int.tryParse(v) ?? 0 : (v as num).toInt());

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  return _asInt(v);
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return false;
}

String? _asStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.regionId,
    this.provinceId,
    this.districtId,
    this.mustChangePassword = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: _asInt(json['id']),
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
        phone: _asStringOrNull(json['phone']),
        regionId: _asIntOrNull(json['region_id']),
        provinceId: _asIntOrNull(json['province_id']),
        districtId: _asIntOrNull(json['district_id']),
        mustChangePassword: _asBool(json['must_change_password']),
      );

  final int id;
  final String name;
  final String email;
  final String role;

  /// Kendi profilinden düzenlenebilir (API-V2 `PATCH /auth/me`).
  final String? phone;

  /// Kullanıcının kapsamı — `POST /auth/login` gövdesinden gelir (API-V2 §11).
  ///
  /// v2.2'de üçü de sunucuda tutulur ve kullanıcı kendi profilinden
  /// değiştirebilir. Doküman kütüphanesi bu üçlüyü "bana uygulananlar"
  /// görünümünde kullanır (SPEC-V2-M6 §4).
  final int? regionId;
  final int? provinceId;
  final int? districtId;

  /// API-V2 §1.8 — açıkken uygulama yalnız şifre değiştirme ekranını gösterir.
  final bool mustChangePassword;

  bool get isAdmin => role == 'genel_merkez';

  /// `null` geçilen alanlar korunur; kapsam alanlarını **temizlemek** için
  /// [clearScope] kullanılır (aksi hâlde `null` "değiştirme" anlamına gelir).
  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    int? regionId,
    int? provinceId,
    int? districtId,
    bool? mustChangePassword,
    bool clearScope = false,
    bool clearPhone = false,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        role: role,
        phone: clearPhone ? null : (phone ?? this.phone),
        regionId: clearScope ? regionId : (regionId ?? this.regionId),
        provinceId: clearScope ? provinceId : (provinceId ?? this.provinceId),
        districtId: clearScope ? districtId : (districtId ?? this.districtId),
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'phone': phone,
        'region_id': regionId,
        'province_id': provinceId,
        'district_id': districtId,
        'must_change_password': mustChangePassword,
      };
}

class Province {
  const Province({
    required this.id,
    required this.code,
    required this.name,
    this.regionId,
  });

  factory Province.fromJson(Map<String, dynamic> json) => Province(
        id: _asInt(json['id']),
        code: _asInt(json['code']),
        name: json['name']?.toString() ?? '',
        regionId: _asIntOrNull(json['region_id']),
      );

  final int id;
  final int code;
  final String name;

  /// v2 eklemesi — API-V2 §3 (`GET /provinces` artık `region_id` döndürür).
  final int? regionId;
}

class District {
  const District(
      {required this.id, required this.name, required this.provinceId});

  factory District.fromJson(Map<String, dynamic> json) => District(
        id: _asInt(json['id']),
        name: json['name']?.toString() ?? '',
        provinceId: _asInt(json['province_id']),
      );

  final int id;
  final String name;
  final int provinceId;
}

class TaskArea {
  const TaskArea(
      {required this.id, required this.name, required this.isActive});

  factory TaskArea.fromJson(Map<String, dynamic> json) => TaskArea(
        id: _asInt(json['id']),
        name: json['name']?.toString() ?? '',
        isActive: json.containsKey('is_active')
            ? _asBool(json['is_active'])
            : true,
      );

  final int id;
  final String name;
  final bool isActive;
}

class Body {
  const Body({required this.id, required this.type, required this.name});

  factory Body.fromJson(Map<String, dynamic> json) => Body(
        id: _asInt(json['id']),
        type: json['type']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );

  final int id;
  final String type;
  final String name;

  bool get isKurul => type == 'koordinasyon_kurulu';
}

class Person {
  const Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.tcNo,
    required this.birthDate,
    required this.phone,
    this.email,
    this.profession,
    required this.unitType,
    required this.provinceId,
    this.districtId,
    required this.isActive,
    this.createdAt,
    this.provinceName,
    this.districtName,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    final province = json['province'];
    final district = json['district'];
    return Person(
      id: _asInt(json['id']),
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      tcNo: json['tc_no']?.toString() ?? '',
      birthDate: json['birth_date']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: _asStringOrNull(json['email']),
      profession: _asStringOrNull(json['profession']),
      unitType: json['unit_type']?.toString() ?? '',
      provinceId: _asInt(json['province_id']),
      districtId: _asIntOrNull(json['district_id']),
      isActive: _asBool(json['is_active']),
      createdAt: _asStringOrNull(json['created_at']),
      provinceName: _asStringOrNull(json['province_name']) ??
          (province is Map<String, dynamic>
              ? _asStringOrNull(province['name'])
              : null),
      districtName: _asStringOrNull(json['district_name']) ??
          (district is Map<String, dynamic>
              ? _asStringOrNull(district['name'])
              : null),
    );
  }

  final int id;
  final String firstName;
  final String lastName;
  final String tcNo;
  final String birthDate; // YYYY-MM-DD
  final String phone;
  final String? email;
  final String? profession;
  final String unitType; // il_teskilati | ilce_teskilati | temsilcilik
  final int provinceId;
  final int? districtId;
  final bool isActive;
  final String? createdAt;
  final String? provinceName;
  final String? districtName;

  String get fullName => '$firstName $lastName'.trim();
}

class Membership {
  const Membership({
    required this.membershipId,
    required this.person,
    this.roleTitle,
    required this.isActive,
  });

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        membershipId:
            _asInt(json['membership_id'] ?? json['id']),
        person: Person.fromJson(
            (json['person'] as Map).cast<String, dynamic>()),
        roleTitle: _asStringOrNull(json['role_title']),
        isActive: _asBool(json['is_active']),
      );

  final int membershipId;
  final Person person;
  final String? roleTitle;
  final bool isActive;
}

class FieldActivity {
  const FieldActivity({
    required this.id,
    required this.taskAreaId,
    required this.activityDate,
    required this.volunteerCount,
    required this.beneficiaryCount,
    this.provinceId,
    this.districtId,
    this.notes,
    this.taskAreaName,
    this.provinceName,
    this.districtName,
  });

  factory FieldActivity.fromJson(Map<String, dynamic> json) => FieldActivity(
        id: _asInt(json['id']),
        taskAreaId: _asInt(json['task_area_id']),
        activityDate: json['activity_date']?.toString() ?? '',
        volunteerCount: _asInt(json['volunteer_count']),
        beneficiaryCount: _asInt(json['beneficiary_count']),
        provinceId: _asIntOrNull(json['province_id']),
        districtId: _asIntOrNull(json['district_id']),
        notes: _asStringOrNull(json['notes']),
        taskAreaName: _asStringOrNull(json['task_area_name']),
        provinceName: _asStringOrNull(json['province_name']),
        districtName: _asStringOrNull(json['district_name']),
      );

  final int id;
  final int taskAreaId;
  final String activityDate; // YYYY-MM-DD
  final int volunteerCount;
  final int beneficiaryCount;
  final int? provinceId;
  final int? districtId;
  final String? notes;
  final String? taskAreaName;
  final String? provinceName;
  final String? districtName;
}

class Meeting {
  const Meeting({
    required this.id,
    required this.bodyId,
    required this.meetingDate,
    required this.decision,
    required this.outcome,
    this.bodyName,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
        id: _asInt(json['id']),
        bodyId: _asInt(json['body_id']),
        meetingDate: json['meeting_date']?.toString() ?? '',
        decision: json['decision']?.toString() ?? '',
        outcome: json['outcome']?.toString() ?? '',
        bodyName: _asStringOrNull(json['body_name']),
      );

  final int id;
  final int bodyId;
  final String meetingDate; // YYYY-MM-DD
  final String decision;
  final String outcome;
  final String? bodyName;
}

class Assignment {
  const Assignment({
    required this.id,
    required this.personId,
    required this.title,
    this.description,
    required this.assignedDate,
    required this.status,
    this.personName,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    final person = json['person'];
    return Assignment(
      id: _asInt(json['id']),
      personId: _asInt(json['person_id']),
      title: json['title']?.toString() ?? '',
      description: _asStringOrNull(json['description']),
      assignedDate: json['assigned_date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'atandi',
      personName: _asStringOrNull(json['person_name']) ??
          (person is Map<String, dynamic>
              ? '${person['first_name'] ?? ''} ${person['last_name'] ?? ''}'
                  .trim()
              : null),
    );
  }

  final int id;
  final int personId;
  final String title;
  final String? description;
  final String assignedDate; // YYYY-MM-DD
  final String status; // atandi | devam | tamamlandi
  final String? personName;
}

class AuditLog {
  const AuditLog({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.action,
    required this.changedBy,
    this.changes,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
        id: _asInt(json['id']),
        entity: json['entity']?.toString() ?? '',
        entityId: _asIntOrNull(json['entity_id']) ?? 0,
        action: json['action']?.toString() ?? '',
        changedBy: _asStringOrNull(json['changed_by_name']) ??
            json['changed_by']?.toString() ??
            '',
        changes: json['changes'],
        createdAt: json['created_at']?.toString() ?? '',
      );

  final int id;
  final String entity;
  final int entityId;
  final String action; // create | update | delete | active-toggle
  final String changedBy;
  final dynamic changes; // json map or string
  final String createdAt;
}

class Paged<T> {
  const Paged({required this.data, required this.total});

  final List<T> data;
  final int total;
}
