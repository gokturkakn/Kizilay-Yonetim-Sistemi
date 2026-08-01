// K4 — Teşkilat birimi modeli. Birim, kişiden bağımsız bir varlıktır:
// bir il başkanlığı "Teşkilat Yok" durumunda da kayıtlıdır. Boşluk raporunun temeli budur.
export const id = '005_org_units';

export function up(db) {
  db.exec(`
CREATE TABLE IF NOT EXISTS org_units (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL CHECK (type IN (
    'koordinasyon_kurulu', 'bolge_temsilciligi', 'komisyon',
    'il_baskanligi', 'ilce_baskanligi', 'temsilcilik'
  )),
  name TEXT NOT NULL,
  code TEXT,
  region_id INTEGER REFERENCES regions(id),
  province_id INTEGER REFERENCES provinces(id),
  district_id INTEGER REFERENCES districts(id),
  parent_id INTEGER REFERENCES org_units(id),
  body_id INTEGER REFERENCES bodies(id),
  status TEXT NOT NULL DEFAULT 'teskilat_yok'
    CHECK (status IN ('aktif', 'pasif', 'teskilat_yok')),
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_org_units_type ON org_units(type);
CREATE INDEX IF NOT EXISTS idx_org_units_status ON org_units(status);
CREATE INDEX IF NOT EXISTS idx_org_units_region ON org_units(region_id);
CREATE INDEX IF NOT EXISTS idx_org_units_province ON org_units(province_id);
CREATE INDEX IF NOT EXISTS idx_org_units_parent ON org_units(parent_id);

-- Bir il için iki "il başkanlığı", bir ilçe için iki "ilçe başkanlığı" olamaz.
CREATE UNIQUE INDEX IF NOT EXISTS ux_org_units_scope
  ON org_units(type, COALESCE(province_id, 0), COALESCE(district_id, 0), name);

CREATE TABLE IF NOT EXISTS org_assignments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  org_unit_id INTEGER NOT NULL REFERENCES org_units(id),
  person_id INTEGER NOT NULL REFERENCES persons(id),
  role_id INTEGER REFERENCES lookup_items(id),
  role_title TEXT,
  start_date TEXT,
  end_date TEXT,
  status TEXT NOT NULL DEFAULT 'aktif'
    CHECK (status IN ('aktif', 'pasif', 'teskilat_yok')),
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_org_assignments_unit ON org_assignments(org_unit_id);
CREATE INDEX IF NOT EXISTS idx_org_assignments_person ON org_assignments(person_id);
CREATE INDEX IF NOT EXISTS idx_org_assignments_status ON org_assignments(status);
  `);
}
