/**
 * 013 — `users.district_id` + `users.must_change_password`
 *
 * 1) `district_id`: kullanıcı kapsamının en dar kırılımı. Bu sütun olmadan giriş yapmış
 *    bir kullanıcının ifade edebildiği en dar kapsam ildi; dolayısıyla dokümanlardaki
 *    `?applicable_to=district:<id>` görünümü gerçek bir oturumdan hiç ulaşılamıyordu.
 *
 * 2) `must_change_password`: tohumlanmış ya da yönetici tarafından açılmış hesaplar bu
 *    bayrakla gelir. Bayrak açıkken API `GET /auth/me` ve `POST /auth/change-password`
 *    dışındaki her isteği 403 `PASSWORD_CHANGE_REQUIRED` ile reddeder. Böylece bir
 *    hesabın ilk şifresiyle kalıcı olarak kullanılması mümkün olmaz.
 *
 * Var olan hesaplar `0` ile gelir: yükseltmede kimse kilitlenmez (geriye dönük uyum).
 */
export const id = '013_users_district_password';

export function up(db) {
  const cols = db.prepare('PRAGMA table_info(users)').all().map((c) => c.name);
  const add = (sql) => db.exec(`ALTER TABLE users ADD COLUMN ${sql}`);

  if (!cols.includes('district_id')) add('district_id INTEGER REFERENCES districts(id)');
  if (!cols.includes('must_change_password')) {
    add('must_change_password INTEGER NOT NULL DEFAULT 0');
  }

  db.exec('CREATE INDEX IF NOT EXISTS idx_users_district ON users(district_id)');
}
