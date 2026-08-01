/**
 * v2 referans verisi tohumlaması.
 *
 * Bu dosyadaki HER ŞEY referans veridir (demo değil): bölgeler, tanım listeleri,
 * teşkilat birimleri, etkinlik takvimi, içerik blokları. Üretimde de gereklidir.
 *
 * Tümü idempotenttir ve **yönetici düzenlemelerini ezmez**:
 *  - var olan bir tanım kalemi güncellenmez, yalnız eksik olan eklenir,
 *  - var olan bir org birimin durumu değiştirilmez,
 *  - var olan bir içerik bloğunun metni korunur.
 */
import { REGIONS, REGION_PROVINCE_CODES } from './seed-data/regions.js';
import { LOOKUP_CATEGORIES, LOOKUP_ITEMS, HIERARCHICAL_ITEMS } from './seed-data/lookups.js';
import { CALENDAR_EVENTS, MOVABLE_DATES } from './seed-data/calendar.js';
import { CONTENT_BLOCKS } from './seed-data/content.js';

// ---------------------------------------------------------------- bölgeler
function seedRegions(db) {
  const byCode = db.prepare('SELECT id FROM regions WHERE code = ?');
  const ins = db.prepare('INSERT INTO regions (code, name, sort_order) VALUES (?, ?, ?)');
  for (const r of REGIONS) {
    if (!byCode.get(r.code)) ins.run(r.code, r.name, r.sort_order);
  }

  // 81 ilin bölgeye eşlenmesi — plaka kodu üzerinden, her açılışta güvence altına alınır.
  const setRegion = db.prepare('UPDATE provinces SET region_id = ? WHERE code = ? AND (region_id IS NULL OR region_id <> ?)');
  for (const [regionCode, provinceCodes] of Object.entries(REGION_PROVINCE_CODES)) {
    const region = byCode.get(regionCode);
    if (!region) continue;
    for (const plaka of provinceCodes) setRegion.run(region.id, plaka, region.id);
  }
}

// --------------------------------------------------------------- tanımlar
function seedLookups(db) {
  const catByCode = db.prepare('SELECT id FROM lookup_categories WHERE code = ?');
  const insCat = db.prepare('INSERT INTO lookup_categories (code, name, is_system) VALUES (?, ?, 1)');
  for (const c of LOOKUP_CATEGORIES) {
    if (!catByCode.get(c.code)) insCat.run(c.code, c.name);
  }

  const itemByName = db.prepare(
    'SELECT id FROM lookup_items WHERE category_id = ? AND COALESCE(parent_id, 0) = ? AND name = ?'
  );
  const insItem = db.prepare(
    'INSERT INTO lookup_items (category_id, parent_id, name, sort_order) VALUES (?, ?, ?, ?)'
  );

  // Düz kategoriler
  for (const [code, names] of Object.entries(LOOKUP_ITEMS)) {
    const cat = catByCode.get(code);
    if (!cat) continue;
    names.forEach((name, i) => {
      if (!itemByName.get(cat.id, 0, name)) insItem.run(cat.id, null, name, i + 1);
    });
  }

  // Hiyerarşik kategoriler (Görev Türü → Alt Görev)
  for (const [code, def] of Object.entries(HIERARCHICAL_ITEMS)) {
    const cat = catByCode.get(code);
    const parentCat = catByCode.get(def.parentCategory);
    if (!cat || !parentCat) continue;
    for (const [parentName, children] of Object.entries(def.items)) {
      const parent = itemByName.get(parentCat.id, 0, parentName);
      if (!parent) continue;
      children.forEach((name, i) => {
        if (!itemByName.get(cat.id, parent.id, name)) insItem.run(cat.id, parent.id, name, i + 1);
      });
    }
  }
}

// ------------------------------------------------------- teşkilat birimleri
/**
 * SPEC-V2 K4. Birimler kişiden bağımsız olarak vardır.
 *
 * Durum kararı:
 *  - koordinasyon kurulu + komisyonlar → v1 `bodies.is_active` değerinden taşınır
 *    (bunlar gerçekten var olan, kurulmuş birimlerdir),
 *  - bölge temsilcilikleri, il ve ilçe başkanlıkları → **'teskilat_yok'**
 *    (SPEC-V2 K3: "Teşkilat Yok özellikle İl/İlçe Başkanlıkları ve Temsilcilikler için
 *     raporlanabilir olmalı"). Böylece teşkilatlanma boşluğu raporu ilk günden anlamlıdır.
 */
function seedOrgUnits(db) {
  const find = db.prepare(`
    SELECT id, status FROM org_units
    WHERE type = ? AND COALESCE(province_id, 0) = ? AND COALESCE(district_id, 0) = ?`);
  const ins = db.prepare(`
    INSERT INTO org_units (type, name, code, region_id, province_id, district_id, parent_id, body_id, status)
    VALUES (@type, @name, @code, @region_id, @province_id, @district_id, @parent_id, @body_id, @status)`);

  const upsert = (u) => {
    const existing = find.get(u.type, u.province_id || 0, u.district_id || 0);
    if (existing) return existing.id;
    return Number(ins.run({
      code: null, region_id: null, province_id: null, district_id: null,
      parent_id: null, body_id: null, status: 'teskilat_yok', ...u,
    }).lastInsertRowid);
  };

  // 1) Koordinasyon Kurulu (v1 bodies satırından)
  const kurulBody = db.prepare("SELECT id, name, is_active FROM bodies WHERE type = 'koordinasyon_kurulu' LIMIT 1").get();
  let kurulId = null;
  if (kurulBody) {
    kurulId = upsert({
      type: 'koordinasyon_kurulu', name: kurulBody.name, code: 'KK',
      body_id: kurulBody.id, status: kurulBody.is_active ? 'aktif' : 'pasif',
    });
  }

  // 2) Komisyonlar (v1 bodies satırlarından taşınır)
  const komisyonlar = db.prepare("SELECT id, name, is_active FROM bodies WHERE type = 'komisyon' ORDER BY id").all();
  const findByName = db.prepare('SELECT id FROM org_units WHERE type = ? AND name = ?');
  for (const k of komisyonlar) {
    if (findByName.get('komisyon', k.name)) continue;
    ins.run({
      type: 'komisyon', name: k.name, code: null, region_id: null, province_id: null,
      district_id: null, parent_id: kurulId, body_id: k.id,
      status: k.is_active ? 'aktif' : 'pasif',
    });
  }

  // 3) Bölge temsilcilikleri (7)
  const regions = db.prepare('SELECT id, code, name FROM regions ORDER BY sort_order').all();
  const regionUnitId = {};
  for (const r of regions) {
    const name = `${r.name} Bölge Temsilciliği`;
    const existing = findByName.get('bolge_temsilciligi', name);
    regionUnitId[r.id] = existing
      ? existing.id
      : Number(ins.run({
        type: 'bolge_temsilciligi', name, code: `BT-${r.code}`, region_id: r.id,
        province_id: null, district_id: null, parent_id: kurulId, body_id: null,
        status: 'teskilat_yok',
      }).lastInsertRowid);
  }

  // 4) İl başkanlıkları (81)
  const provinces = db.prepare('SELECT id, code, name, region_id FROM provinces ORDER BY code').all();
  const provinceUnitId = {};
  for (const p of provinces) {
    const existing = find.get('il_baskanligi', p.id, 0);
    provinceUnitId[p.id] = existing
      ? existing.id
      : Number(ins.run({
        type: 'il_baskanligi',
        name: `${p.name} İl Kadın Başkanlığı`,
        code: `IL-${String(p.code).padStart(2, '0')}`,
        region_id: p.region_id,
        province_id: p.id,
        district_id: null,
        parent_id: p.region_id ? regionUnitId[p.region_id] : kurulId,
        body_id: null,
        status: 'teskilat_yok',
      }).lastInsertRowid);
  }

  // 5) İlçe başkanlıkları (973)
  const districts = db.prepare(`
    SELECT d.id, d.name, d.province_id, p.region_id
    FROM districts d JOIN provinces p ON p.id = d.province_id
    ORDER BY d.province_id, d.name`).all();
  for (const d of districts) {
    if (find.get('ilce_baskanligi', d.province_id, d.id)) continue;
    ins.run({
      type: 'ilce_baskanligi',
      name: `${d.name} İlçe Kadın Başkanlığı`,
      code: null,
      region_id: d.region_id,
      province_id: d.province_id,
      district_id: d.id,
      parent_id: provinceUnitId[d.province_id] ?? null,
      body_id: null,
      status: 'teskilat_yok',
    });
  }
}

// ---------------------------------------------------------------- takvim
function seedCalendar(db) {
  const byName = db.prepare('SELECT id FROM calendar_events WHERE name = ?');
  const ins = db.prepare(`
    INSERT INTO calendar_events (name, category, month, day, end_month, end_day, is_fixed, note)
    VALUES (@name, @category, @month, @day, @end_month, @end_day, @is_fixed, @note)`);
  for (const e of CALENDAR_EVENTS) {
    if (byName.get(e.name)) continue;
    const isFixed = e.is_fixed === 0 ? 0 : 1;
    ins.run({
      name: e.name,
      category: e.category,
      month: isFixed ? e.month : null,
      day: isFixed ? e.day : null,
      end_month: isFixed ? (e.end_month ?? null) : null,
      end_day: isFixed ? (e.end_day ?? null) : null,
      is_fixed: isFixed,
      note: e.note ?? null,
    });
  }

  const dateExists = db.prepare('SELECT id FROM calendar_event_dates WHERE event_id = ? AND year = ?');
  const insDate = db.prepare(
    'INSERT INTO calendar_event_dates (event_id, year, start_date, end_date) VALUES (?, ?, ?, ?)'
  );
  for (const d of MOVABLE_DATES) {
    const ev = byName.get(d.name);
    if (!ev || dateExists.get(ev.id, d.year)) continue;
    insDate.run(ev.id, d.year, d.start_date, d.end_date ?? null);
  }
}

// -------------------------------------------------------- içerik blokları
function seedContentBlocks(db) {
  const byKey = db.prepare('SELECT id FROM content_blocks WHERE key = ?');
  const ins = db.prepare('INSERT INTO content_blocks (key, title, body) VALUES (?, ?, ?)');
  for (const b of CONTENT_BLOCKS) {
    if (!byKey.get(b.key)) ins.run(b.key, b.title, b.body);
  }
}

// ------------------------------------------------------------------ stok
function seedStockItems(db) {
  const cat = db.prepare("SELECT id FROM lookup_categories WHERE code = 'lojistik_urun'").get();
  if (!cat) return;
  const products = db.prepare('SELECT id FROM lookup_items WHERE category_id = ?').all(cat.id);
  const exists = db.prepare('SELECT id FROM stock_items WHERE product_id = ?');
  const ins = db.prepare('INSERT INTO stock_items (product_id, quantity, min_quantity) VALUES (?, 0, 0)');
  for (const p of products) {
    if (!exists.get(p.id)) ins.run(p.id);
  }
}

/** Tüm v2 referans verisini tohumlar. Tek transaction — yarım kalmaz. */
export function seedV2(db) {
  db.transaction(() => {
    seedRegions(db);
    seedLookups(db);
    seedOrgUnits(db);
    seedCalendar(db);
    seedContentBlocks(db);
    seedStockItems(db);
    // 010 göçünde '' varsayılanıyla eklenen updated_at alanını anlamlı değere çek.
    db.prepare("UPDATE users SET updated_at = created_at WHERE updated_at IS NULL OR updated_at = ''").run();
  })();

  const one = (sql, ...p) => db.prepare(sql).get(...p).c;
  return {
    regions: one('SELECT COUNT(*) AS c FROM regions'),
    provinces_mapped: one('SELECT COUNT(*) AS c FROM provinces WHERE region_id IS NOT NULL'),
    lookup_categories: one('SELECT COUNT(*) AS c FROM lookup_categories'),
    lookup_items: one('SELECT COUNT(*) AS c FROM lookup_items'),
    org_units: one('SELECT COUNT(*) AS c FROM org_units'),
    calendar_events: one('SELECT COUNT(*) AS c FROM calendar_events'),
    calendar_event_dates: one('SELECT COUNT(*) AS c FROM calendar_event_dates'),
    content_blocks: one('SELECT COUNT(*) AS c FROM content_blocks'),
    stock_items: one('SELECT COUNT(*) AS c FROM stock_items'),
  };
}
