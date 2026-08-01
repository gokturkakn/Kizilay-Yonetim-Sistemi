/**
 * Saha Faaliyetleri (görevler, eğitimler, etkinlikler, toplantılar v2) + Lojistik.
 *
 * `meetings` yeniden inşa edilir çünkü v2'de:
 *   - `body_id` NULL olabilmelidir (Kamp / Çalıştay bir kurul veya komisyona bağlı değildir),
 *   - `decision` ("Alınan Kararlar") toplantı anında boş olabilmelidir.
 * Mevcut satırlar birebir taşınır; v1 istemcisi için hiçbir alan kaybolmaz.
 */
export const id = '009_field_modules';

export function up(db) {
  // --- A. Görevler ---------------------------------------------------------
  db.exec(`
CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_date TEXT NOT NULL,
  region_id INTEGER REFERENCES regions(id),
  province_id INTEGER REFERENCES provinces(id),
  district_id INTEGER REFERENCES districts(id),
  branch TEXT,
  org_unit_id INTEGER REFERENCES org_units(id),
  task_type_id INTEGER NOT NULL REFERENCES lookup_items(id),
  sub_task_id INTEGER REFERENCES lookup_items(id),
  volunteer_count INTEGER NOT NULL DEFAULT 0 CHECK (volunteer_count >= 0),
  beneficiary_count INTEGER NOT NULL DEFAULT 0 CHECK (beneficiary_count >= 0),
  duration_hours REAL CHECK (duration_hours IS NULL OR duration_hours >= 0),
  notes TEXT,
  created_by INTEGER NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_tasks_date ON tasks(task_date);
CREATE INDEX IF NOT EXISTS idx_tasks_type ON tasks(task_type_id);
CREATE INDEX IF NOT EXISTS idx_tasks_region ON tasks(region_id);
CREATE INDEX IF NOT EXISTS idx_tasks_province ON tasks(province_id);

CREATE TABLE IF NOT EXISTS trainings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  training_date TEXT NOT NULL,
  region_id INTEGER REFERENCES regions(id),
  province_id INTEGER REFERENCES provinces(id),
  district_id INTEGER REFERENCES districts(id),
  org_unit_id INTEGER REFERENCES org_units(id),
  trainer TEXT,
  topic_id INTEGER NOT NULL REFERENCES lookup_items(id),
  category_id INTEGER REFERENCES lookup_items(id),
  method_id INTEGER REFERENCES lookup_items(id),
  participant_count INTEGER NOT NULL DEFAULT 0 CHECK (participant_count >= 0),
  volunteer_count INTEGER NOT NULL DEFAULT 0 CHECK (volunteer_count >= 0),
  duration_hours REAL CHECK (duration_hours IS NULL OR duration_hours >= 0),
  notes TEXT,
  created_by INTEGER NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_trainings_date ON trainings(training_date);
CREATE INDEX IF NOT EXISTS idx_trainings_topic ON trainings(topic_id);
CREATE INDEX IF NOT EXISTS idx_trainings_region ON trainings(region_id);

CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_date TEXT NOT NULL,
  calendar_event_id INTEGER NOT NULL REFERENCES calendar_events(id),
  event_type_id INTEGER REFERENCES lookup_items(id),
  region_id INTEGER REFERENCES regions(id),
  province_id INTEGER REFERENCES provinces(id),
  district_id INTEGER REFERENCES districts(id),
  org_unit_id INTEGER REFERENCES org_units(id),
  participant_count INTEGER NOT NULL DEFAULT 0 CHECK (participant_count >= 0),
  volunteer_count INTEGER NOT NULL DEFAULT 0 CHECK (volunteer_count >= 0),
  beneficiary_count INTEGER NOT NULL DEFAULT 0 CHECK (beneficiary_count >= 0),
  notes TEXT,
  created_by INTEGER NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_events_date ON events(event_date);
CREATE INDEX IF NOT EXISTS idx_events_calendar ON events(calendar_event_id);
CREATE INDEX IF NOT EXISTS idx_events_region ON events(region_id);
  `);

  // --- B. Toplantılar v2 (tablo yeniden inşası) ----------------------------
  const meetingCols = db.prepare('PRAGMA table_info(meetings)').all().map((c) => c.name);
  if (!meetingCols.includes('meeting_type_id')) {
    db.exec(`
CREATE TABLE meetings_v2 (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  body_id INTEGER REFERENCES bodies(id),
  meeting_type_id INTEGER REFERENCES lookup_items(id),
  method_id INTEGER REFERENCES lookup_items(id),
  location TEXT,
  platform TEXT,
  org_unit_id INTEGER REFERENCES org_units(id),
  region_id INTEGER REFERENCES regions(id),
  province_id INTEGER REFERENCES provinces(id),
  meeting_date TEXT NOT NULL,
  participants TEXT,
  agenda TEXT,
  decision TEXT NOT NULL DEFAULT '',
  outcome TEXT,
  created_by INTEGER NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO meetings_v2 (id, body_id, meeting_date, decision, outcome, created_by, created_at)
SELECT id, body_id, meeting_date, decision, outcome, created_by, created_at FROM meetings;

DROP TABLE meetings;
ALTER TABLE meetings_v2 RENAME TO meetings;

CREATE INDEX IF NOT EXISTS idx_meetings_body ON meetings(body_id);
CREATE INDEX IF NOT EXISTS idx_meetings_date ON meetings(meeting_date);
CREATE INDEX IF NOT EXISTS idx_meetings_type ON meetings(meeting_type_id);
    `);
  }

  // --- C. Lojistik ---------------------------------------------------------
  db.exec(`
CREATE TABLE IF NOT EXISTS material_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  request_date TEXT NOT NULL,
  org_unit_id INTEGER REFERENCES org_units(id),
  region_id INTEGER REFERENCES regions(id),
  province_id INTEGER REFERENCES provinces(id),
  district_id INTEGER REFERENCES districts(id),
  product_id INTEGER NOT NULL REFERENCES lookup_items(id),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  status TEXT NOT NULL DEFAULT 'talep'
    CHECK (status IN ('talep', 'onaylandi', 'gonderildi', 'teslim_edildi', 'iptal')),
  requested_by_person_id INTEGER REFERENCES persons(id),
  notes TEXT,
  created_by INTEGER NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_material_requests_status ON material_requests(status);
CREATE INDEX IF NOT EXISTS idx_material_requests_product ON material_requests(product_id);
CREATE INDEX IF NOT EXISTS idx_material_requests_date ON material_requests(request_date);

CREATE TABLE IF NOT EXISTS shipments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  request_id INTEGER NOT NULL REFERENCES material_requests(id),
  shipment_date TEXT NOT NULL,
  shipping_method_id INTEGER REFERENCES lookup_items(id),
  tracking_no TEXT,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  received_by TEXT,
  received_date TEXT,
  notes TEXT,
  created_by INTEGER NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_shipments_request ON shipments(request_id);
CREATE INDEX IF NOT EXISTS idx_shipments_date ON shipments(shipment_date);

CREATE TABLE IF NOT EXISTS stock_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL UNIQUE REFERENCES lookup_items(id),
  quantity INTEGER NOT NULL DEFAULT 0,
  min_quantity INTEGER NOT NULL DEFAULT 0 CHECK (min_quantity >= 0),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS stock_movements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL REFERENCES lookup_items(id),
  direction TEXT NOT NULL CHECK (direction IN ('giris', 'cikis')),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  reason TEXT,
  ref_type TEXT,
  ref_id INTEGER,
  created_by INTEGER REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_created ON stock_movements(created_at);
  `);
}
