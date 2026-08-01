// Excel (.xlsx) dışa aktarım uçları. Liste uçlarıyla aynı filtreleri uygular,
// sayfalama uygulamaz (rapor tüm eşleşen kayıtları içerir). Türkçe sütun başlıkları.
import { Router } from 'express';
import ExcelJS from 'exceljs';
import { requireRole } from '../auth.js';
import { badRequest, parseBoolFlag, validDate, toIntOrThrow } from '../helpers.js';

const UNIT_TYPES = ['il_teskilati', 'ilce_teskilati', 'temsilcilik'];
const UNIT_TYPE_TR = {
  il_teskilati: 'İl Teşkilatı',
  ilce_teskilati: 'İlçe Teşkilatı',
  temsilcilik: 'Temsilcilik',
};
const STATUS_TR = { atandi: 'Atandı', devam: 'Devam Ediyor', tamamlandi: 'Tamamlandı' };

async function sendWorkbook(res, filename, sheetName, columns, rows) {
  const wb = new ExcelJS.Workbook();
  wb.creator = 'Kızılay Kadın Teşkilat Yönetim Sistemi';
  const ws = wb.addWorksheet(sheetName);
  ws.columns = columns.map((c) => ({ header: c.header, key: c.key, width: c.width || 22 }));
  ws.getRow(1).font = { bold: true };
  for (const row of rows) ws.addRow(row);
  res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  await wb.xlsx.write(res);
  res.end();
}

export default function exportRoutes(db) {
  const r = Router();

  // SPEC 3. bölüm: raporlar genel merkez yetkisinde.
  r.use('/export', requireRole('genel_merkez'));

  r.get('/export/persons.xlsx', async (req, res, next) => {
    try {
      const where = [];
      const params = [];
      const { province_id, district_id, unit_type, q } = req.query;
      if (province_id) { where.push('p.province_id = ?'); params.push(toIntOrThrow(province_id, 'province_id')); }
      if (district_id) { where.push('p.district_id = ?'); params.push(toIntOrThrow(district_id, 'district_id')); }
      if (unit_type) {
        if (!UNIT_TYPES.includes(unit_type)) throw badRequest('unit_type filtresi geçersiz');
        where.push('p.unit_type = ?'); params.push(unit_type);
      }
      // v1 uyumu: is_active=1 → 'aktif'; is_active=0 → aktif olmayan (pasif + teşkilat yok).
      const active = parseBoolFlag(req.query.is_active);
      if (active === 1) where.push("p.status = 'aktif'");
      if (active === 0) where.push("p.status <> 'aktif'");
      if (req.query.status) { where.push('p.status = ?'); params.push(String(req.query.status)); }
      if (req.query.region_id) { where.push('pr.region_id = ?'); params.push(toIntOrThrow(req.query.region_id, 'region_id')); }
      if (q) {
        where.push("(p.first_name LIKE ? OR p.last_name LIKE ? OR (p.first_name || ' ' || p.last_name) LIKE ?)");
        const like = `%${q}%`;
        params.push(like, like, like);
      }
      const rows = db.prepare(`
        SELECT p.*, pr.name AS province_name, d.name AS district_name, rg.name AS region_name
        FROM persons p
        JOIN provinces pr ON pr.id = p.province_id
        LEFT JOIN regions rg ON rg.id = pr.region_id
        LEFT JOIN districts d ON d.id = p.district_id
        ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
        ORDER BY p.last_name, p.first_name`).all(...params);

      await sendWorkbook(res, 'kisiler.xlsx', 'Kişiler', [
        { header: 'Ad', key: 'first_name' },
        { header: 'Soyad', key: 'last_name' },
        { header: 'TC Kimlik No', key: 'tc_no' },
        { header: 'Doğum Tarihi', key: 'birth_date' },
        { header: 'Telefon', key: 'phone' },
        { header: 'E-posta', key: 'email', width: 30 },
        { header: 'Meslek', key: 'profession' },
        { header: 'Birim Türü', key: 'unit_type_tr' },
        { header: 'Bölge', key: 'region_name' },
        { header: 'İl', key: 'province_name' },
        { header: 'İlçe', key: 'district_name' },
        { header: 'Durum', key: 'status_tr' },
        { header: 'Kayıt Tarihi', key: 'created_at' },
      ], rows.map((p) => ({
        ...p,
        unit_type_tr: UNIT_TYPE_TR[p.unit_type] || p.unit_type,
        status_tr: { aktif: 'Aktif', pasif: 'Pasif', teskilat_yok: 'Teşkilat Yok' }[p.status] || p.status,
      })));
    } catch (e) { next(e); }
  });

  r.get('/export/field-activities.xlsx', async (req, res, next) => {
    try {
      const where = [];
      const params = [];
      const { task_area_id, province_id, from, to } = req.query;
      if (task_area_id) { where.push('f.task_area_id = ?'); params.push(toIntOrThrow(task_area_id, 'task_area_id')); }
      if (province_id) { where.push('f.province_id = ?'); params.push(toIntOrThrow(province_id, 'province_id')); }
      if (from) { where.push('f.activity_date >= ?'); params.push(validDate(from, 'from')); }
      if (to) { where.push('f.activity_date <= ?'); params.push(validDate(to, 'to')); }
      const rows = db.prepare(`
        SELECT f.*, t.name AS task_area_name, pr.name AS province_name, d.name AS district_name,
               u.name AS created_by_name
        FROM field_activities f
        JOIN task_areas t ON t.id = f.task_area_id
        LEFT JOIN provinces pr ON pr.id = f.province_id
        LEFT JOIN districts d ON d.id = f.district_id
        LEFT JOIN users u ON u.id = f.created_by
        ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
        ORDER BY f.activity_date DESC`).all(...params);

      await sendWorkbook(res, 'saha-faaliyetleri.xlsx', 'Saha Faaliyetleri', [
        { header: 'Görev Alanı', key: 'task_area_name', width: 32 },
        { header: 'Tarih', key: 'activity_date' },
        { header: 'Gönüllü Sayısı', key: 'volunteer_count' },
        { header: 'Yararlanıcı Sayısı', key: 'beneficiary_count' },
        { header: 'İl', key: 'province_name' },
        { header: 'İlçe', key: 'district_name' },
        { header: 'Açıklama', key: 'notes', width: 40 },
        { header: 'Kaydı Giren', key: 'created_by_name' },
        { header: 'Kayıt Tarihi', key: 'created_at' },
      ], rows);
    } catch (e) { next(e); }
  });

  r.get('/export/meetings.xlsx', async (req, res, next) => {
    try {
      const where = [];
      const params = [];
      const { body_id, from, to } = req.query;
      if (body_id) { where.push('m.body_id = ?'); params.push(toIntOrThrow(body_id, 'body_id')); }
      if (from) { where.push('m.meeting_date >= ?'); params.push(validDate(from, 'from')); }
      if (to) { where.push('m.meeting_date <= ?'); params.push(validDate(to, 'to')); }
      const rows = db.prepare(`
        SELECT m.*, b.name AS body_name, u.name AS created_by_name
        FROM meetings m
        JOIN bodies b ON b.id = m.body_id
        LEFT JOIN users u ON u.id = m.created_by
        ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
        ORDER BY m.meeting_date DESC`).all(...params);

      await sendWorkbook(res, 'yonetsel-faaliyetler.xlsx', 'Yönetsel Faaliyetler', [
        { header: 'Kurul/Komisyon', key: 'body_name', width: 40 },
        { header: 'Toplantı Tarihi', key: 'meeting_date' },
        { header: 'Karar/Konu', key: 'decision', width: 50 },
        { header: 'Sonuç', key: 'outcome', width: 40 },
        { header: 'Kaydı Giren', key: 'created_by_name' },
        { header: 'Kayıt Tarihi', key: 'created_at' },
      ], rows);
    } catch (e) { next(e); }
  });

  r.get('/export/assignments.xlsx', async (req, res, next) => {
    try {
      const where = [];
      const params = [];
      const { person_id, status } = req.query;
      if (person_id) { where.push('a.person_id = ?'); params.push(toIntOrThrow(person_id, 'person_id')); }
      if (status) {
        if (!Object.keys(STATUS_TR).includes(status)) throw badRequest('status filtresi geçersiz');
        where.push('a.status = ?'); params.push(status);
      }
      const rows = db.prepare(`
        SELECT a.*, p.first_name || ' ' || p.last_name AS person_name, u.name AS created_by_name
        FROM assignments a
        JOIN persons p ON p.id = a.person_id
        LEFT JOIN users u ON u.id = a.created_by
        ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
        ORDER BY a.assigned_date DESC`).all(...params);

      await sendWorkbook(res, 'gorev-atamalari.xlsx', 'Görev Atamaları', [
        { header: 'Kişi', key: 'person_name', width: 30 },
        { header: 'Görev Başlığı', key: 'title', width: 45 },
        { header: 'Açıklama', key: 'description', width: 45 },
        { header: 'Atama Tarihi', key: 'assigned_date' },
        { header: 'Durum', key: 'status_tr' },
        { header: 'Atayan', key: 'created_by_name' },
      ], rows.map((a) => ({ ...a, status_tr: STATUS_TR[a.status] || a.status })));
    } catch (e) { next(e); }
  });

  return r;
}
