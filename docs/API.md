# API Contract — Teşkilat Yönetim Sistemi (v1)

Base URL: `http://localhost:4141/api/v1` · JSON · JWT bearer auth (except /auth/login).
Errors: `{ "error": { "code": string, "message": string } }` with proper HTTP status.
All list endpoints support `?page=1&limit=50` and return `{ "data": [...], "total": n }`.

## Auth
- `POST /auth/login` `{email, password}` → `{token, user: {id, name, email, role}}`
  - Seed user: `admin@kizilay.org.tr` / `Admin!2026` role `genel_merkez`
  - Seed user: `saha@kizilay.org.tr` / `Saha!2026` role `saha`

## Reference data (seeded)
- `GET /provinces` → 81 il `[{id, code, name}]` (code = plaka 1–81)
- `GET /provinces/:id/districts` → `[{id, name, province_id}]`
- `GET /commissions` → `[{id, name, is_active}]` (6 seeded) · `POST /commissions` (genel_merkez)
- `GET /task-areas` → `[{id, name, is_active}]` (seeded, extensible) · `POST /task-areas` (genel_merkez)

## Persons (kişiler)
`{id, first_name, last_name, tc_no, birth_date(YYYY-MM-DD), phone, email, profession,
  unit_type: "il_teskilati"|"ilce_teskilati"|"temsilcilik",
  province_id, district_id|null, is_active, created_at, updated_at}`
- `GET /persons?province_id=&district_id=&unit_type=&is_active=&q=` (q searches name)
- `POST /persons` · `GET /persons/:id` · `PUT /persons/:id` · `PATCH /persons/:id/active {is_active}`
- Validation: tc_no 11 digits + standard TC checksum, unique; email format; phone required.
- `POST /persons/import` — multipart xlsx stub for future bulk import (returns 501 with message in MVP is NOT ok; implement basic parse: columns ad,soyad,tc,... best-effort; on failure per-row errors).

## Memberships (kurul & komisyon üyelikleri)
- `GET /bodies` → `[{id, type: "koordinasyon_kurulu"|"komisyon", name}]` (1 kurul + 6 komisyon seeded; commissions map 1:1 to bodies)
- `GET /bodies/:id/members?is_active=` → `[{membership_id, person: {...}, role_title, is_active}]`
- `POST /bodies/:id/members {person_id, role_title}` · `DELETE /memberships/:id` · `PATCH /memberships/:id/active {is_active}`

## Field activities (saha görev formu)
`{id, task_area_id, activity_date, volunteer_count, beneficiary_count,
  province_id|null, district_id|null, notes|null, created_by, created_at}`
- `GET /field-activities?task_area_id=&province_id=&from=&to=` · `POST /field-activities` · `PUT /field-activities/:id` · `DELETE` (genel_merkez)

## Meetings (yönetsel faaliyetler)
`{id, body_id, meeting_date, decision, outcome, created_by, created_at}`
- `GET /meetings?body_id=&from=&to=` · `POST /meetings` · `PUT /meetings/:id` · `DELETE` (genel_merkez)

## Assignments (genel merkez görev atamaları)
`{id, person_id, title, description|null, assigned_date, status: "atandi"|"devam"|"tamamlandi", created_by}`
- `GET /assignments?person_id=&status=` (all authenticated roles can read)
- `POST /assignments` · `PUT /assignments/:id` (genel_merkez only)

## Audit log
- Every create/update/delete/active-toggle on persons, memberships, activities, meetings, assignments writes
  `{id, entity, entity_id, action, changed_by, changes(json), created_at}`
- `GET /audit-logs?entity=&from=&to=` (genel_merkez)

## Excel export (returns .xlsx attachment)
- `GET /export/persons.xlsx?{same filters as /persons}`
- `GET /export/field-activities.xlsx` · `GET /export/meetings.xlsx` · `GET /export/assignments.xlsx`
- Turkish column headers.

## Health
- `GET /health` → `{status:"ok", db:"ok", seeded:{provinces:81, districts:n>900, commissions:6}}`

## Backend notes (implementation clarifications, v0.1)
- **List envelope everywhere:** per the "All list endpoints" rule above, reference endpoints
  (`/provinces`, `/provinces/:id/districts`, `/commissions`, `/task-areas`, `/bodies`,
  `/bodies/:id/members`) also return `{data, total}` (not bare arrays as the inline examples
  suggest). Default `limit` is 50 (max 1000) — pass e.g. `?limit=100` to fetch all 81 provinces at once.
- **`POST /persons/import`** is implemented (not a 501 stub): multipart `file` (.xlsx), header row
  maps flexible Turkish columns (`ad, soyad, tc, dogum_tarihi, telefon, eposta, meslek, birim_turu,
  il_kodu|il, ilce`). Response: `{imported: n, errors: [{row, message}]}`.
- **Excel exports require `genel_merkez`** (API.md is silent; SPEC §3 assigns reports to genel_merkez).
- `DELETE` endpoints return `204 No Content`. `PATCH .../active` accepts `true/false/1/0`.
- Audit log `changes` is returned as parsed JSON; update actions store `{field: {old, new}}` diffs.
