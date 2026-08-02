// v2 ortak yardımcıları: üç durumlu statü, tanım (lookup) doğrulaması, coğrafya türetme.
import { badRequest, notFound, toIntOrThrow, validDate } from './helpers.js';

export const STATUSES = ['aktif', 'pasif', 'teskilat_yok'];

export function validStatus(value, field = 'status') {
  if (!STATUSES.includes(value)) {
    throw badRequest(`'${field}' şunlardan biri olmalı: ${STATUSES.join(', ')}`);
  }
  return value;
}

/** v1 uyumu: is_active boolean'ı statüye çevirir. */
export function statusFromIsActive(flag) {
  return flag ? 'aktif' : 'pasif';
}

/** Bir tanım kaleminin var olduğunu ve doğru kategoride olduğunu doğrular. */
export function requireLookup(db, value, categoryCode, field) {
  const id = toIntOrThrow(value, field);
  const row = db.prepare(`
    SELECT li.id, li.parent_id, li.name, lc.code AS category_code
    FROM lookup_items li JOIN lookup_categories lc ON lc.id = li.category_id
    WHERE li.id = ?`).get(id);
  if (!row) throw badRequest(`'${field}' geçersiz (tanım kalemi bulunamadı)`);
  if (categoryCode && row.category_code !== categoryCode) {
    throw badRequest(`'${field}' '${categoryCode}' kategorisinden bir kalem olmalı`);
  }
  return row;
}

/** Opsiyonel tanım alanı: boşsa null döner. */
export function optionalLookup(db, value, categoryCode, field) {
  if (value === undefined || value === null || value === '') return null;
  return requireLookup(db, value, categoryCode, field).id;
}

export function optionalInt(value, field) {
  if (value === undefined || value === null || value === '') return null;
  return toIntOrThrow(value, field);
}

export function optionalDate(value, field) {
  if (value === undefined || value === null || value === '') return null;
  return validDate(value, field);
}

export function optionalText(value) {
  if (value === undefined || value === null) return null;
  const s = String(value).trim();
  return s === '' ? null : s;
}

export function nonNegativeInt(value, field, fallback = 0) {
  if (value === undefined || value === null || value === '') return fallback;
  const n = toIntOrThrow(value, field);
  if (n < 0) throw badRequest(`'${field}' negatif olamaz`);
  return n;
}

export function optionalHours(value, field) {
  if (value === undefined || value === null || value === '') return null;
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0) throw badRequest(`'${field}' 0 veya daha büyük bir sayı olmalı`);
  return n;
}

/**
 * il/ilçe tutarlılığını doğrular ve bölgeyi il üzerinden TÜRETİR.
 * İstemci `region_id` göndermek zorunda değildir — SPEC-V2'deki tüm formlar
 * Bölge/İl/İlçe üçlüsünü birlikte gösterir, ama tek doğru kaynak `provinces.region_id`'dir.
 */
export function resolveGeo(db, body, { requireProvince = false } = {}) {
  let provinceId = optionalInt(body.province_id, 'province_id');
  let districtId = optionalInt(body.district_id, 'district_id');
  let regionId = optionalInt(body.region_id, 'region_id');

  if (requireProvince && provinceId === null) throw badRequest("'province_id' alanı zorunludur");

  let province = null;
  if (provinceId !== null) {
    province = db.prepare('SELECT id, region_id FROM provinces WHERE id = ?').get(provinceId);
    if (!province) throw badRequest('province_id geçersiz');
  }
  if (districtId !== null) {
    const d = db.prepare('SELECT id, province_id FROM districts WHERE id = ?').get(districtId);
    if (!d) throw badRequest('district_id geçersiz');
    if (provinceId !== null && d.province_id !== provinceId) {
      throw badRequest('İlçe, seçilen ile ait değil');
    }
    if (provinceId === null) {
      provinceId = d.province_id;
      province = db.prepare('SELECT id, region_id FROM provinces WHERE id = ?').get(provinceId);
    }
  }
  if (regionId !== null && !db.prepare('SELECT id FROM regions WHERE id = ?').get(regionId)) {
    throw badRequest('region_id geçersiz');
  }
  if (regionId === null && province) regionId = province.region_id;

  return { region_id: regionId, province_id: provinceId, district_id: districtId };
}

export function optionalOrgUnit(db, value, field = 'org_unit_id') {
  if (value === undefined || value === null || value === '') return null;
  const id = toIntOrThrow(value, field);
  if (!db.prepare('SELECT id FROM org_units WHERE id = ?').get(id)) {
    throw badRequest(`'${field}' geçersiz`);
  }
  return id;
}

export function mustExist(db, table, id, message) {
  const row = db.prepare(`SELECT * FROM ${table} WHERE id = ?`).get(id);
  if (!row) throw notFound(message);
  return row;
}

/** Ek (attachment) sayısını tek sorguda getiren alt sorgu parçası. */
export const attachmentCountSql = (entity, alias = 't') =>
  `(SELECT COUNT(*) FROM attachments a WHERE a.entity = '${entity}' AND a.entity_id = ${alias}.id) AS attachment_count`;

/**
 * Türkçe küçük harf katlaması — arama kutuları için.
 *
 * SQLite'ın `LIKE` operatörü yalnız ASCII harflerde büyük/küçük harf duyarsızdır:
 * "KILAVUZ" ile "Kılavuz", "İZİN" ile "izin" eşleşmez. Türkçede ayrıca noktalı/noktasız
 * i ayrımı vardır (I→ı, İ→i), bu yüzden düz `toLowerCase()` de yetmez.
 * Bu fonksiyon `tr_lower` adıyla SQLite'a kaydedilir (bkz. src/db.js).
 */
export function trLower(value) {
  if (value === null || value === undefined) return null;
  return String(value).replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase();
}

/** Çoklu değer alabilen sorgu parametresi (?status=a&status=b). */
export function asArray(value) {
  if (value === undefined || value === null || value === '') return [];
  return Array.isArray(value) ? value : [value];
}
