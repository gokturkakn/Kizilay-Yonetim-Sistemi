import { Router } from 'express';
import multer from 'multer';
import ExcelJS from 'exceljs';
import { requireRole } from '../auth.js';
import { auditLog, diffChanges } from '../audit.js';
import { isValidTcNo } from '../tc.js';
import {
  badRequest, conflict, notFound, listQuery, parseBoolFlag,
  requireFields, EMAIL_RE, validDate, toIntOrThrow,
} from '../helpers.js';

const UNIT_TYPES = ['il_teskilati', 'ilce_teskilati', 'temsilcilik'];
const PERSON_FIELDS = [
  'first_name', 'last_name', 'tc_no', 'birth_date', 'phone', 'email',
  'profession', 'unit_type', 'province_id', 'district_id',
];
const SELECT_PERSON = `id, first_name, last_name, tc_no, birth_date, phone, email, profession,
  unit_type, province_id, district_id, is_active, created_at, updated_at`;

export function validatePersonPayload(db, body, opts = {}) {
  const { existingId = null } = opts;
  requireFields(body, ['first_name', 'last_name', 'tc_no', 'birth_date', 'phone', 'unit_type', 'province_id']);

  const tc = String(body.tc_no).trim();
  if (!isValidTcNo(tc)) {
    throw badRequest('TC kimlik no geçersiz (11 hane ve sağlama kuralına uygun olmalı)', 'INVALID_TC_NO');
  }
  const dupe = db.prepare('SELECT id FROM persons WHERE tc_no = ?').get(tc);
  if (dupe && dupe.id !== existingId) {
    throw conflict('Bu TC kimlik no ile kayıtlı kişi zaten var');
  }

  validDate(body.birth_date, 'birth_date');

  if (body.email !== undefined && body.email !== null && body.email !== '' && !EMAIL_RE.test(String(body.email))) {
    throw badRequest('E-posta biçimi geçersiz');
  }

  if (!UNIT_TYPES.includes(body.unit_type)) {
    throw badRequest(`unit_type şunlardan biri olmalı: ${UNIT_TYPES.join(', ')}`);
  }

  const provinceId = toIntOrThrow(body.province_id, 'province_id');
  if (!db.prepare('SELECT id FROM provinces WHERE id = ?').get(provinceId)) {
    throw badRequest('province_id geçersiz');
  }

  let districtId = null;
  if (body.district_id !== undefined && body.district_id !== null && body.district_id !== '') {
    districtId = toIntOrThrow(body.district_id, 'district_id');
    const dist = db.prepare('SELECT id, province_id FROM districts WHERE id = ?').get(districtId);
    if (!dist) throw badRequest('district_id geçersiz');
    if (dist.province_id !== provinceId) throw badRequest('İlçe, seçilen ile ait değil');
  }
  if (body.unit_type === 'ilce_teskilati' && districtId === null) {
    throw badRequest("unit_type 'ilce_teskilati' için district_id zorunludur");
  }

  return {
    first_name: String(body.first_name).trim(),
    last_name: String(body.last_name).trim(),
    tc_no: tc,
    birth_date: body.birth_date,
    phone: String(body.phone).trim(),
    email: body.email ? String(body.email).trim() : null,
    profession: body.profession ? String(body.profession).trim() : null,
    unit_type: body.unit_type,
    province_id: provinceId,
    district_id: districtId,
    // Formdaki aktif/pasif tiki. Gönderilmezse kayıt aktif kabul edilir (yeni kayıt)
    // veya mevcut değer korunur (güncelleme).
    is_active: parseBoolFlag(body.is_active) ?? (opts.currentActive ?? 1),
  };
}

export default function personRoutes(db) {
  const r = Router();
  const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

  const getPerson = (id) => db.prepare(`SELECT ${SELECT_PERSON} FROM persons WHERE id = ?`).get(id);

  r.get('/persons', (req, res, next) => {
    try {
      const where = [];
      const params = [];
      const { province_id, district_id, unit_type, q } = req.query;
      if (province_id) { where.push('province_id = ?'); params.push(toIntOrThrow(province_id, 'province_id')); }
      if (district_id) { where.push('district_id = ?'); params.push(toIntOrThrow(district_id, 'district_id')); }
      if (unit_type) {
        if (!UNIT_TYPES.includes(unit_type)) throw badRequest('unit_type filtresi geçersiz');
        where.push('unit_type = ?'); params.push(unit_type);
      }
      const active = parseBoolFlag(req.query.is_active);
      if (active !== undefined) { where.push('is_active = ?'); params.push(active); }
      if (q) {
        where.push("(first_name LIKE ? OR last_name LIKE ? OR (first_name || ' ' || last_name) LIKE ?)");
        const like = `%${q}%`;
        params.push(like, like, like);
      }
      res.json(listQuery(db, {
        select: SELECT_PERSON,
        from: 'persons',
        where, params,
        orderBy: 'last_name, first_name',
        query: req.query,
      }));
    } catch (e) { next(e); }
  });

  r.get('/persons/:id', (req, res, next) => {
    try {
      const row = getPerson(req.params.id);
      if (!row) throw notFound('Kişi bulunamadı');
      res.json(row);
    } catch (e) { next(e); }
  });

  r.post('/persons', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const p = validatePersonPayload(db, req.body || {});
      const { lastInsertRowid } = db.prepare(`
        INSERT INTO persons (first_name, last_name, tc_no, birth_date, phone, email, profession,
                             unit_type, province_id, district_id, is_active)
        VALUES (@first_name, @last_name, @tc_no, @birth_date, @phone, @email, @profession,
                @unit_type, @province_id, @district_id, @is_active)`).run(p);
      const row = getPerson(lastInsertRowid);
      auditLog(db, { entity: 'persons', entityId: row.id, action: 'create', changedBy: req.user.id, changes: p });
      res.status(201).json(row);
    } catch (e) { next(e); }
  });

  r.put('/persons/:id', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const before = getPerson(req.params.id);
      if (!before) throw notFound('Kişi bulunamadı');
      const p = validatePersonPayload(db, req.body || {}, {
        existingId: before.id,
        currentActive: before.is_active,
      });
      db.prepare(`
        UPDATE persons SET first_name=@first_name, last_name=@last_name, tc_no=@tc_no,
          birth_date=@birth_date, phone=@phone, email=@email, profession=@profession,
          unit_type=@unit_type, province_id=@province_id, district_id=@district_id,
          is_active=@is_active, updated_at=datetime('now')
        WHERE id=@id`).run({ ...p, id: before.id });
      const after = getPerson(before.id);
      auditLog(db, {
        entity: 'persons', entityId: before.id, action: 'update', changedBy: req.user.id,
        changes: diffChanges(before, after, PERSON_FIELDS),
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  r.patch('/persons/:id/active', requireRole('genel_merkez'), (req, res, next) => {
    try {
      const before = getPerson(req.params.id);
      if (!before) throw notFound('Kişi bulunamadı');
      const flag = parseBoolFlag((req.body || {}).is_active);
      if (flag === undefined) throw badRequest("'is_active' alanı zorunludur");
      db.prepare("UPDATE persons SET is_active = ?, updated_at = datetime('now') WHERE id = ?").run(flag, before.id);
      const after = getPerson(before.id);
      auditLog(db, {
        entity: 'persons', entityId: before.id, action: 'active_toggle', changedBy: req.user.id,
        changes: { is_active: { old: before.is_active, new: flag } },
      });
      res.json(after);
    } catch (e) { next(e); }
  });

  // Excel'den toplu içe aktarma (temel sürüm): sütunlar başlık satırından eşlenir.
  // Beklenen başlıklar (esnek): ad, soyad, tc, dogum_tarihi, telefon, eposta, meslek,
  // birim_turu, il_kodu/il, ilce
  r.post('/persons/import', requireRole('genel_merkez'), upload.single('file'), async (req, res, next) => {
    try {
      if (!req.file || !req.file.buffer) {
        throw badRequest("Dosya gerekli: multipart 'file' alanında .xlsx yükleyin");
      }
      const wb = new ExcelJS.Workbook();
      try {
        await wb.xlsx.load(req.file.buffer);
      } catch {
        throw badRequest('Dosya .xlsx olarak okunamadı');
      }
      const ws = wb.worksheets[0];
      if (!ws) throw badRequest('Çalışma sayfası bulunamadı');

      const norm = (s) => String(s ?? '').trim().toLowerCase()
        .replace(/ı/g, 'i').replace(/ş/g, 's').replace(/ğ/g, 'g')
        .replace(/ü/g, 'u').replace(/ö/g, 'o').replace(/ç/g, 'c')
        .replace(/[^a-z0-9_]/g, '_');
      const headerMap = {}; // normalized header -> column index
      ws.getRow(1).eachCell((cell, col) => { headerMap[norm(cell.value)] = col; });
      const pick = (row, ...names) => {
        for (const n of names) {
          if (headerMap[n]) {
            const v = row.getCell(headerMap[n]).value;
            if (v !== null && v !== undefined && v !== '') {
              return typeof v === 'object' && v.text ? v.text : v;
            }
          }
        }
        return null;
      };

      const errors = [];
      let imported = 0;
      for (let i = 2; i <= ws.rowCount; i += 1) {
        const row = ws.getRow(i);
        if (row.actualCellCount === 0) continue;
        try {
          const provinceRaw = pick(row, 'il_kodu', 'plaka', 'il');
          let province = null;
          if (provinceRaw !== null) {
            province = Number.isInteger(Number(provinceRaw))
              ? db.prepare('SELECT id FROM provinces WHERE code = ?').get(Number(provinceRaw))
              : db.prepare('SELECT id FROM provinces WHERE name = ?').get(String(provinceRaw).trim());
          }
          if (!province) throw new Error('İl bulunamadı (il_kodu/il sütunu)');

          const districtRaw = pick(row, 'ilce');
          let districtId = null;
          if (districtRaw) {
            const d = db.prepare('SELECT id FROM districts WHERE province_id = ? AND name = ?')
              .get(province.id, String(districtRaw).trim());
            if (!d) throw new Error(`İlçe bulunamadı: ${districtRaw}`);
            districtId = d.id;
          }

          let birth = pick(row, 'dogum_tarihi', 'dogum');
          if (birth instanceof Date) birth = birth.toISOString().slice(0, 10);

          const payload = validatePersonPayload(db, {
            first_name: pick(row, 'ad', 'first_name'),
            last_name: pick(row, 'soyad', 'last_name'),
            tc_no: pick(row, 'tc', 'tc_no', 'tc_kimlik_no'),
            birth_date: birth,
            phone: pick(row, 'telefon', 'phone'),
            email: pick(row, 'eposta', 'e_posta', 'email'),
            profession: pick(row, 'meslek', 'profession'),
            unit_type: pick(row, 'birim_turu', 'unit_type') || (districtId ? 'ilce_teskilati' : 'il_teskilati'),
            province_id: province.id,
            district_id: districtId,
          });
          const { lastInsertRowid } = db.prepare(`
            INSERT INTO persons (first_name, last_name, tc_no, birth_date, phone, email, profession,
                                 unit_type, province_id, district_id, is_active)
            VALUES (@first_name, @last_name, @tc_no, @birth_date, @phone, @email, @profession,
                    @unit_type, @province_id, @district_id, 1)`).run(payload);
          auditLog(db, {
            entity: 'persons', entityId: Number(lastInsertRowid), action: 'create',
            changedBy: req.user.id, changes: { ...payload, source: 'import' },
          });
          imported += 1;
        } catch (rowErr) {
          errors.push({ row: i, message: rowErr.message });
        }
      }
      res.json({ imported, errors });
    } catch (e) { next(e); }
  });

  return r;
}
