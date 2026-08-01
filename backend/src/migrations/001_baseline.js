// v1 (MVP) şeması. Mevcut bir v1 veritabanında tüm tablolar zaten vardır → no-op.
// Sıfırdan kurulumda tüm v1 tablolarını oluşturur.
export const id = '001_baseline';

export function up(db) {
  db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('genel_merkez', 'saha')),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS provinces (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code INTEGER NOT NULL UNIQUE,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS districts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  province_id INTEGER NOT NULL REFERENCES provinces(id),
  name TEXT NOT NULL,
  UNIQUE (province_id, name)
);
CREATE INDEX IF NOT EXISTS idx_districts_province ON districts(province_id);

CREATE TABLE IF NOT EXISTS bodies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL CHECK (type IN ('koordinasyon_kurulu', 'komisyon')),
  name TEXT NOT NULL UNIQUE,
  is_active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS task_areas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  is_active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS persons (
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
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_persons_province ON persons(province_id);
CREATE INDEX IF NOT EXISTS idx_persons_district ON persons(district_id);

CREATE TABLE IF NOT EXISTS memberships (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  body_id INTEGER NOT NULL REFERENCES bodies(id),
  person_id INTEGER NOT NULL REFERENCES persons(id),
  role_title TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_memberships_body ON memberships(body_id);

CREATE TABLE IF NOT EXISTS field_activities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_area_id INTEGER NOT NULL REFERENCES task_areas(id),
  activity_date TEXT NOT NULL,
  volunteer_count INTEGER NOT NULL CHECK (volunteer_count >= 0),
  beneficiary_count INTEGER NOT NULL CHECK (beneficiary_count >= 0),
  province_id INTEGER REFERENCES provinces(id),
  district_id INTEGER REFERENCES districts(id),
  notes TEXT,
  created_by INTEGER NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_field_activities_date ON field_activities(activity_date);

CREATE TABLE IF NOT EXISTS meetings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  body_id INTEGER NOT NULL REFERENCES bodies(id),
  meeting_date TEXT NOT NULL,
  decision TEXT NOT NULL,
  outcome TEXT,
  created_by INTEGER NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_meetings_body ON meetings(body_id);

CREATE TABLE IF NOT EXISTS assignments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  person_id INTEGER NOT NULL REFERENCES persons(id),
  title TEXT NOT NULL,
  description TEXT,
  assigned_date TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'atandi' CHECK (status IN ('atandi', 'devam', 'tamamlandi')),
  created_by INTEGER NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_assignments_person ON assignments(person_id);

CREATE TABLE IF NOT EXISTS audit_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity TEXT NOT NULL,
  entity_id INTEGER NOT NULL,
  action TEXT NOT NULL,
  changed_by INTEGER REFERENCES users(id),
  changes TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_logs(entity);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at);
  `);
}
