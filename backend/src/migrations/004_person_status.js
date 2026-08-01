/**
 * K3 — Üç durumlu statü (BREAKING, yalnız veritabanı sütununda).
 *
 *   persons.is_active INTEGER  →  persons.status TEXT CHECK(aktif|pasif|teskilat_yok)
 *
 * SQLite'ta bir sütunu kaldırıp yerine CHECK'li bir sütun koymanın güvenli yolu
 * resmî "12 adımlı" tablo yeniden inşasıdır. Göç çalıştırıcısı `foreign_keys`i
 * kapalı tutar ve göçlerin sonunda `foreign_key_check` ile bütünlüğü doğrular.
 *
 * Veri eşlemesi:  is_active = 1 → 'aktif'   ·   is_active = 0 → 'pasif'
 * ('teskilat_yok' yalnızca v2'de elle atanabilen bir durumdur; hiçbir v1 satırı bu
 *  duruma taşınmaz, çünkü v1'de böyle bir bilgi yoktu.)
 *
 * API `is_active`'i `status`'tan türeterek döndürmeye devam eder (geriye dönük uyum).
 */
export const id = '004_person_status';

export function up(db) {
  const cols = db.prepare('PRAGMA table_info(persons)').all().map((c) => c.name);
  if (cols.includes('status')) return; // zaten uygulanmış

  db.exec(`
CREATE TABLE persons_v2 (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  tc_no TEXT NOT NULL UNIQUE,
  birth_date TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  profession TEXT,
  unit_type TEXT NOT NULL CHECK (unit_type IN ('il_teskilati', 'ilce_teskilati', 'temsilcilik')),
  province_id INTEGER NOT NULL REFERENCES provinces(id),
  district_id INTEGER REFERENCES districts(id),
  status TEXT NOT NULL DEFAULT 'aktif' CHECK (status IN ('aktif', 'pasif', 'teskilat_yok')),
  photo_attachment_id INTEGER,
  start_date TEXT,
  end_date TEXT,
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO persons_v2 (id, first_name, last_name, tc_no, birth_date, phone, email,
                        profession, unit_type, province_id, district_id, status,
                        created_at, updated_at)
SELECT id, first_name, last_name, tc_no, birth_date, phone, email,
       profession, unit_type, province_id, district_id,
       CASE WHEN is_active = 1 THEN 'aktif' ELSE 'pasif' END,
       created_at, updated_at
FROM persons;

DROP TABLE persons;
ALTER TABLE persons_v2 RENAME TO persons;

CREATE INDEX IF NOT EXISTS idx_persons_province ON persons(province_id);
CREATE INDEX IF NOT EXISTS idx_persons_district ON persons(district_id);
CREATE INDEX IF NOT EXISTS idx_persons_status ON persons(status);
  `);
}
