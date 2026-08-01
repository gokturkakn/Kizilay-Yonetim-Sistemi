/**
 * K6 — Etkinlik takvimi.
 *
 * Sabit tarihli günler (millî bayramlar, resmî günler, önemli gün/haftalar) `month`/`day`
 * ile tutulur; hafta olanlar için `end_month`/`end_day` de doludur.
 *
 * Dinî bayram ve kandiller hicri takvime bağlıdır: `is_fixed = 0`, `month`/`day` NULL ve
 * gerçek tarih yıl bazında `calendar_event_dates` içinden okunur.
 */
export const id = '007_calendar';

export function up(db) {
  db.exec(`
CREATE TABLE IF NOT EXISTS calendar_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL CHECK (category IN (
    'milli_bayram', 'dini_bayram', 'dini_gun', 'resmi_gun', 'onemli_gun', 'onemli_hafta'
  )),
  month INTEGER CHECK (month IS NULL OR (month BETWEEN 1 AND 12)),
  day INTEGER CHECK (day IS NULL OR (day BETWEEN 1 AND 31)),
  end_month INTEGER CHECK (end_month IS NULL OR (end_month BETWEEN 1 AND 12)),
  end_day INTEGER CHECK (end_day IS NULL OR (end_day BETWEEN 1 AND 31)),
  is_fixed INTEGER NOT NULL DEFAULT 1,
  note TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  -- Sabit tarihli bir kaydın ay/gün bilgisi zorunludur; hareketli olanınki olmamalıdır.
  CHECK ((is_fixed = 1 AND month IS NOT NULL AND day IS NOT NULL)
      OR (is_fixed = 0 AND month IS NULL AND day IS NULL))
);
CREATE INDEX IF NOT EXISTS idx_calendar_events_category ON calendar_events(category);
CREATE INDEX IF NOT EXISTS idx_calendar_events_month ON calendar_events(month);

CREATE TABLE IF NOT EXISTS calendar_event_dates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id INTEGER NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE,
  year INTEGER NOT NULL CHECK (year BETWEEN 2000 AND 2100),
  start_date TEXT NOT NULL,
  end_date TEXT,
  UNIQUE (event_id, year)
);
CREATE INDEX IF NOT EXISTS idx_calendar_event_dates_year ON calendar_event_dates(year);
  `);
}
