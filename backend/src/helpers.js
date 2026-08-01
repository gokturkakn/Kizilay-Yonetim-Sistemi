// Ortak yardımcılar: hata gövdesi, sayfalama, doğrulama.

export class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export const badRequest = (msg, code = 'VALIDATION_ERROR') => new ApiError(400, code, msg);
export const notFound = (msg = 'Kayıt bulunamadı') => new ApiError(404, 'NOT_FOUND', msg);
export const conflict = (msg) => new ApiError(409, 'CONFLICT', msg);

export function errorBody(code, message) {
  return { error: { code, message } };
}

// ?page=&limit= → {page, limit, offset}
export function pagination(query, defaultLimit = 50, maxLimit = 1000) {
  let page = parseInt(query.page, 10);
  let limit = parseInt(query.limit, 10);
  if (!Number.isFinite(page) || page < 1) page = 1;
  if (!Number.isFinite(limit) || limit < 1) limit = defaultLimit;
  if (limit > maxLimit) limit = maxLimit;
  return { page, limit, offset: (page - 1) * limit };
}

// Listeleme: where parçaları + parametrelerle {data, total} üretir.
export function listQuery(db, { select, from, where = [], params = [], orderBy, query }) {
  const whereSql = where.length ? ` WHERE ${where.join(' AND ')}` : '';
  const total = db.prepare(`SELECT COUNT(*) AS c FROM ${from}${whereSql}`).get(...params).c;
  const { limit, offset } = pagination(query);
  const rows = db
    .prepare(`SELECT ${select} FROM ${from}${whereSql}${orderBy ? ` ORDER BY ${orderBy}` : ''} LIMIT ? OFFSET ?`)
    .all(...params, limit, offset);
  return { data: rows, total };
}

export function parseBoolFlag(value) {
  // is_active filtreleri için: "1"/"0"/"true"/"false"
  if (value === undefined || value === null || value === '') return undefined;
  if (value === '1' || value === 'true' || value === true) return 1;
  if (value === '0' || value === 'false' || value === false) return 0;
  throw badRequest("is_active değeri 1/0 ya da true/false olmalı");
}

export function requireFields(body, fields) {
  for (const f of fields) {
    if (body[f] === undefined || body[f] === null || body[f] === '') {
      throw badRequest(`'${f}' alanı zorunludur`);
    }
  }
}

export const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
export const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export function validDate(value, field) {
  if (!DATE_RE.test(String(value)) || Number.isNaN(Date.parse(value))) {
    throw badRequest(`'${field}' YYYY-MM-DD biçiminde olmalı`);
  }
  return value;
}

export function toIntOrThrow(value, field) {
  const n = Number(value);
  if (!Number.isInteger(n)) throw badRequest(`'${field}' tam sayı olmalı`);
  return n;
}
