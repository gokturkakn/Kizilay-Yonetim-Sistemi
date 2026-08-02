// Rapor tanımları — TEK KAYNAK.
//
// Her rapor bir kez tanımlanır: filtreleri, sorgusu ve Türkçe sütun başlıkları.
// Hem Excel (.xlsx) hem PDF çıktısı aynı tanımı kullanır; böylece iki biçim
// birbirinden ayrışamaz (bir sütun eklendiğinde ikisinde birden görünür).
import { badRequest, validDate, toIntOrThrow } from './helpers.js';

const UNIT_TYPE_TR = {
  il_teskilati: 'İl Teşkilatı',
  ilce_teskilati: 'İlçe Teşkilatı',
  temsilcilik: 'Temsilcilik',
};
const PERSON_STATUS_TR = { aktif: 'Aktif', pasif: 'Pasif', teskilat_yok: 'Teşkilat Yok' };
const ASSIGNMENT_STATUS_TR = { atandi: 'Atandı', devam: 'Devam Ediyor', tamamlandi: 'Tamamlandı' };
const ORG_TYPE_TR = {
  koordinasyon_kurulu: 'Koordinasyon Kurulu',
  bolge_temsilciligi: 'Bölge Temsilciliği',
  komisyon: 'Komisyon',
  il_baskanligi: 'İl Kadın Başkanlığı',
  ilce_baskanligi: 'İlçe Kadın Başkanlığı',
  temsilcilik: 'Temsilcilik',
};

/** Ortak coğrafi + tarih filtrelerini WHERE parçalarına çevirir. */
function geoFilters(q, cols) {
  const where = [];
  const params = [];
  if (q.region_id && cols.region) {
    where.push(`${cols.region} = ?`); params.push(toIntOrThrow(q.region_id, 'region_id'));
  }
  if (q.province_id && cols.province) {
    where.push(`${cols.province} = ?`); params.push(toIntOrThrow(q.province_id, 'province_id'));
  }
  if (q.district_id && cols.district) {
    where.push(`${cols.district} = ?`); params.push(toIntOrThrow(q.district_id, 'district_id'));
  }
  if (q.from && cols.date) { where.push(`${cols.date} >= ?`); params.push(validDate(q.from, 'from')); }
  if (q.to && cols.date) { where.push(`${cols.date} <= ?`); params.push(validDate(q.to, 'to')); }
  return { where, params };
}

const sql = (base, where, orderBy) =>
  `${base} ${where.length ? `WHERE ${where.join(' AND ')}` : ''} ORDER BY ${orderBy}`;

/**
 * Rapor kayıtları. Anahtar = URL'deki dosya adı (ör. /export/persons.xlsx).
 * Her kayıt: { title, filename, columns, build(db, query) → rows }
 */
export const REPORTS = {
  persons: {
    title: 'Kişiler',
    filename: 'kisiler',
    columns: [
      { header: 'Ad', key: 'first_name', width: 18 },
      { header: 'Soyad', key: 'last_name', width: 18 },
      { header: 'TC Kimlik No', key: 'tc_no', width: 16 },
      { header: 'Doğum Tarihi', key: 'birth_date', width: 14 },
      { header: 'Telefon', key: 'phone', width: 16 },
      { header: 'E-posta', key: 'email', width: 30 },
      { header: 'Meslek', key: 'profession', width: 20 },
      { header: 'Birim Türü', key: 'unit_type_tr', width: 16 },
      { header: 'Bölge', key: 'region_name', width: 20 },
      { header: 'İl', key: 'province_name', width: 16 },
      { header: 'İlçe', key: 'district_name', width: 16 },
      { header: 'Durum', key: 'status_tr', width: 14 },
    ],
    build(db, q) {
      const { where, params } = geoFilters(q, {
        region: 'pr.region_id', province: 'p.province_id', district: 'p.district_id',
      });
      if (q.unit_type) {
        if (!Object.keys(UNIT_TYPE_TR).includes(q.unit_type)) throw badRequest('unit_type filtresi geçersiz');
        where.push('p.unit_type = ?'); params.push(q.unit_type);
      }
      if (q.status) {
        if (!Object.keys(PERSON_STATUS_TR).includes(q.status)) throw badRequest('status filtresi geçersiz');
        where.push('p.status = ?'); params.push(q.status);
      }
      if (q.is_active === '1') where.push("p.status = 'aktif'");
      if (q.is_active === '0') where.push("p.status <> 'aktif'");
      if (q.q) {
        where.push("(p.first_name LIKE ? OR p.last_name LIKE ? OR (p.first_name || ' ' || p.last_name) LIKE ?)");
        const like = `%${q.q}%`;
        params.push(like, like, like);
      }
      return db.prepare(sql(`
        SELECT p.*, pr.name AS province_name, d.name AS district_name, rg.name AS region_name
        FROM persons p
        JOIN provinces pr ON pr.id = p.province_id
        LEFT JOIN regions rg ON rg.id = pr.region_id
        LEFT JOIN districts d ON d.id = p.district_id`, where, 'p.last_name, p.first_name'))
        .all(...params)
        .map((p) => ({
          ...p,
          unit_type_tr: UNIT_TYPE_TR[p.unit_type] || p.unit_type,
          status_tr: PERSON_STATUS_TR[p.status] || p.status,
        }));
    },
  },

  'org-units': {
    title: 'Teşkilatlanma Durumu',
    filename: 'teskilatlanma',
    columns: [
      { header: 'Teşkilat Birimi', key: 'name', width: 34 },
      { header: 'Tür', key: 'type_tr', width: 22 },
      { header: 'Bölge', key: 'region_name', width: 20 },
      { header: 'İl', key: 'province_name', width: 16 },
      { header: 'İlçe', key: 'district_name', width: 16 },
      { header: 'Durum', key: 'status_tr', width: 16 },
      { header: 'Görevli Sayısı', key: 'assignment_count', width: 14 },
    ],
    build(db, q) {
      const { where, params } = geoFilters(q, {
        region: 'o.region_id', province: 'o.province_id', district: 'o.district_id',
      });
      if (q.status) {
        if (!Object.keys(PERSON_STATUS_TR).includes(q.status)) throw badRequest('status filtresi geçersiz');
        where.push('o.status = ?'); params.push(q.status);
      }
      if (q.type) {
        if (!Object.keys(ORG_TYPE_TR).includes(q.type)) throw badRequest('type filtresi geçersiz');
        where.push('o.type = ?'); params.push(q.type);
      }
      return db.prepare(sql(`
        SELECT o.*, rg.name AS region_name, pr.name AS province_name, d.name AS district_name,
               (SELECT COUNT(*) FROM org_assignments oa
                 WHERE oa.org_unit_id = o.id AND oa.status = 'aktif') AS assignment_count
        FROM org_units o
        LEFT JOIN regions rg ON rg.id = o.region_id
        LEFT JOIN provinces pr ON pr.id = o.province_id
        LEFT JOIN districts d ON d.id = o.district_id`, where, 'o.type, pr.code, d.name, o.name'))
        .all(...params)
        .map((o) => ({
          ...o,
          type_tr: ORG_TYPE_TR[o.type] || o.type,
          status_tr: PERSON_STATUS_TR[o.status] || o.status,
        }));
    },
  },

  tasks: {
    title: 'Saha Görevleri',
    filename: 'saha-gorevleri',
    columns: [
      { header: 'Tarih', key: 'task_date', width: 14 },
      { header: 'Görev Türü', key: 'task_type_name', width: 26 },
      { header: 'Alt Görev', key: 'sub_task_name', width: 26 },
      { header: 'Bölge', key: 'region_name', width: 18 },
      { header: 'İl', key: 'province_name', width: 16 },
      { header: 'İlçe', key: 'district_name', width: 16 },
      { header: 'Şube', key: 'branch', width: 20 },
      { header: 'Gönüllü', key: 'volunteer_count', width: 10 },
      { header: 'Yararlanıcı', key: 'beneficiary_count', width: 12 },
      { header: 'Süre (saat)', key: 'duration_hours', width: 12 },
      { header: 'Açıklama', key: 'notes', width: 40 },
    ],
    build(db, q) {
      const { where, params } = geoFilters(q, {
        region: 't.region_id', province: 't.province_id', district: 't.district_id', date: 't.task_date',
      });
      if (q.task_type_id) {
        where.push('t.task_type_id = ?'); params.push(toIntOrThrow(q.task_type_id, 'task_type_id'));
      }
      return db.prepare(sql(`
        SELECT t.*, tt.name AS task_type_name, st.name AS sub_task_name,
               rg.name AS region_name, pr.name AS province_name, d.name AS district_name
        FROM tasks t
        LEFT JOIN lookup_items tt ON tt.id = t.task_type_id
        LEFT JOIN lookup_items st ON st.id = t.sub_task_id
        LEFT JOIN regions rg ON rg.id = t.region_id
        LEFT JOIN provinces pr ON pr.id = t.province_id
        LEFT JOIN districts d ON d.id = t.district_id`, where, 't.task_date DESC'))
        .all(...params);
    },
  },

  trainings: {
    title: 'Eğitimler',
    filename: 'egitimler',
    columns: [
      { header: 'Tarih', key: 'training_date', width: 14 },
      { header: 'Konu', key: 'topic_name', width: 30 },
      { header: 'Kategori', key: 'category_name', width: 22 },
      { header: 'Yöntem', key: 'method_name', width: 16 },
      { header: 'Bölge', key: 'region_name', width: 18 },
      { header: 'İl', key: 'province_name', width: 16 },
      { header: 'Eğitmen', key: 'trainer', width: 24 },
      { header: 'Katılımcı', key: 'participant_count', width: 12 },
      { header: 'Gönüllü', key: 'volunteer_count', width: 10 },
      { header: 'Süre (saat)', key: 'duration_hours', width: 12 },
    ],
    build(db, q) {
      const { where, params } = geoFilters(q, {
        region: 'tr.region_id', province: 'tr.province_id', date: 'tr.training_date',
      });
      if (q.topic_id) { where.push('tr.topic_id = ?'); params.push(toIntOrThrow(q.topic_id, 'topic_id')); }
      return db.prepare(sql(`
        SELECT tr.*, tp.name AS topic_name, ct.name AS category_name, mt.name AS method_name,
               rg.name AS region_name, pr.name AS province_name
        FROM trainings tr
        LEFT JOIN lookup_items tp ON tp.id = tr.topic_id
        LEFT JOIN lookup_items ct ON ct.id = tr.category_id
        LEFT JOIN lookup_items mt ON mt.id = tr.method_id
        LEFT JOIN regions rg ON rg.id = tr.region_id
        LEFT JOIN provinces pr ON pr.id = tr.province_id`, where, 'tr.training_date DESC'))
        .all(...params);
    },
  },

  events: {
    title: 'Etkinlikler',
    filename: 'etkinlikler',
    columns: [
      { header: 'Tarih', key: 'event_date', width: 14 },
      { header: 'Etkinlik', key: 'event_name', width: 40 },
      { header: 'Bölge', key: 'region_name', width: 18 },
      { header: 'İl', key: 'province_name', width: 16 },
      { header: 'Katılımcı', key: 'participant_count', width: 12 },
      { header: 'Gönüllü', key: 'volunteer_count', width: 10 },
      { header: 'Yararlanıcı', key: 'beneficiary_count', width: 12 },
      { header: 'Açıklama', key: 'notes', width: 40 },
    ],
    build(db, q) {
      const { where, params } = geoFilters(q, {
        region: 'e.region_id', province: 'e.province_id', date: 'e.event_date',
      });
      return db.prepare(sql(`
        SELECT e.*, COALESCE(ce.name, li.name) AS event_name,
               rg.name AS region_name, pr.name AS province_name
        FROM events e
        LEFT JOIN calendar_events ce ON ce.id = e.calendar_event_id
        LEFT JOIN lookup_items li ON li.id = e.event_type_id
        LEFT JOIN regions rg ON rg.id = e.region_id
        LEFT JOIN provinces pr ON pr.id = e.province_id`, where, 'e.event_date DESC'))
        .all(...params);
    },
  },

  meetings: {
    title: 'Toplantılar',
    filename: 'toplantilar',
    columns: [
      { header: 'Tarih', key: 'meeting_date', width: 14 },
      { header: 'Toplantı Türü', key: 'meeting_type_name', width: 26 },
      { header: 'Kurul/Komisyon', key: 'body_name', width: 30 },
      { header: 'Yöntem', key: 'method_name', width: 14 },
      { header: 'Yer / Platform', key: 'venue', width: 24 },
      { header: 'Katılımcı Sayısı', key: 'participant_count', width: 14 },
      { header: 'Gündem', key: 'agenda', width: 40 },
      { header: 'Alınan Kararlar', key: 'decision', width: 40 },
      { header: 'Sonuç', key: 'outcome', width: 30 },
    ],
    build(db, q) {
      const where = [];
      const params = [];
      if (q.body_id) { where.push('m.body_id = ?'); params.push(toIntOrThrow(q.body_id, 'body_id')); }
      if (q.meeting_type_id) {
        where.push('m.meeting_type_id = ?'); params.push(toIntOrThrow(q.meeting_type_id, 'meeting_type_id'));
      }
      if (q.from) { where.push('m.meeting_date >= ?'); params.push(validDate(q.from, 'from')); }
      if (q.to) { where.push('m.meeting_date <= ?'); params.push(validDate(q.to, 'to')); }
      return db.prepare(sql(`
        SELECT m.*, b.name AS body_name, mt.name AS meeting_type_name, mm.name AS method_name
        FROM meetings m
        LEFT JOIN bodies b ON b.id = m.body_id
        LEFT JOIN lookup_items mt ON mt.id = m.meeting_type_id
        LEFT JOIN lookup_items mm ON mm.id = m.method_id`, where, 'm.meeting_date DESC'))
        .all(...params)
        .map((m) => ({ ...m, venue: m.location || m.platform || '' }));
    },
  },

  assignments: {
    title: 'Görev Atamaları',
    filename: 'gorev-atamalari',
    columns: [
      { header: 'Kişi', key: 'person_name', width: 28 },
      { header: 'Görev Başlığı', key: 'title', width: 40 },
      { header: 'Açıklama', key: 'description', width: 40 },
      { header: 'Atama Tarihi', key: 'assigned_date', width: 14 },
      { header: 'Durum', key: 'status_tr', width: 16 },
      { header: 'Atayan', key: 'created_by_name', width: 24 },
    ],
    build(db, q) {
      const where = [];
      const params = [];
      if (q.person_id) { where.push('a.person_id = ?'); params.push(toIntOrThrow(q.person_id, 'person_id')); }
      if (q.status) {
        if (!Object.keys(ASSIGNMENT_STATUS_TR).includes(q.status)) throw badRequest('status filtresi geçersiz');
        where.push('a.status = ?'); params.push(q.status);
      }
      return db.prepare(sql(`
        SELECT a.*, p.first_name || ' ' || p.last_name AS person_name, u.name AS created_by_name
        FROM assignments a
        JOIN persons p ON p.id = a.person_id
        LEFT JOIN users u ON u.id = a.created_by`, where, 'a.assigned_date DESC'))
        .all(...params)
        .map((a) => ({ ...a, status_tr: ASSIGNMENT_STATUS_TR[a.status] || a.status }));
    },
  },

  // v1 uyumu: eski ad korunur (istemciler /export/field-activities.xlsx çağırıyor).
  'field-activities': {
    title: 'Saha Faaliyetleri',
    filename: 'saha-faaliyetleri',
    columns: [
      { header: 'Görev Alanı', key: 'task_area_name', width: 32 },
      { header: 'Tarih', key: 'activity_date', width: 14 },
      { header: 'Gönüllü Sayısı', key: 'volunteer_count', width: 14 },
      { header: 'Yararlanıcı Sayısı', key: 'beneficiary_count', width: 16 },
      { header: 'İl', key: 'province_name', width: 16 },
      { header: 'İlçe', key: 'district_name', width: 16 },
      { header: 'Açıklama', key: 'notes', width: 40 },
      { header: 'Kaydı Giren', key: 'created_by_name', width: 24 },
    ],
    build(db, q) {
      const { where, params } = geoFilters(q, {
        province: 'f.province_id', district: 'f.district_id', date: 'f.activity_date',
      });
      if (q.task_area_id) {
        where.push('f.task_area_id = ?'); params.push(toIntOrThrow(q.task_area_id, 'task_area_id'));
      }
      return db.prepare(sql(`
        SELECT f.*, t.name AS task_area_name, pr.name AS province_name, d.name AS district_name,
               u.name AS created_by_name
        FROM field_activities f
        JOIN task_areas t ON t.id = f.task_area_id
        LEFT JOIN provinces pr ON pr.id = f.province_id
        LEFT JOIN districts d ON d.id = f.district_id
        LEFT JOIN users u ON u.id = f.created_by`, where, 'f.activity_date DESC'))
        .all(...params);
    },
  },
};

/** Rapor başlığının altına yazılacak, uygulanan filtreleri özetleyen satır. */
export function filterSummary(db, q) {
  const parts = [];
  const name = (table, id) =>
    db.prepare(`SELECT name FROM ${table} WHERE id = ?`).get(id)?.name;
  if (q.region_id) parts.push(`Bölge: ${name('regions', q.region_id) || q.region_id}`);
  if (q.province_id) parts.push(`İl: ${name('provinces', q.province_id) || q.province_id}`);
  if (q.district_id) parts.push(`İlçe: ${name('districts', q.district_id) || q.district_id}`);
  if (q.from || q.to) parts.push(`Tarih: ${q.from || '…'} — ${q.to || '…'}`);
  if (q.status) parts.push(`Durum: ${PERSON_STATUS_TR[q.status] || ASSIGNMENT_STATUS_TR[q.status] || q.status}`);
  if (q.type) parts.push(`Tür: ${ORG_TYPE_TR[q.type] || q.type}`);
  if (q.q) parts.push(`Arama: ${q.q}`);
  return parts.length ? parts.join(' · ') : 'Filtre uygulanmadı (tüm kayıtlar)';
}
