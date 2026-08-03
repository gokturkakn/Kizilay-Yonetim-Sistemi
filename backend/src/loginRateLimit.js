/**
 * Giriş denemesi hız sınırlama — denetim raporu Y-3.
 *
 * Ölçülen durum (REALITY-CHECK §4 PROBE-15): 25 ardışık hatalı giriş 1,84 saniyede
 * tamamlandı; ne 429, ne gecikme, ne kilitleme vardı. Şifreler herkese açık depoda
 * yayımlanmış ve tek bir admin hesabı olduğu için bu doğrudan sömürülebilir bir açıktı.
 *
 * İKİ AYRI SAYAÇ tutulur ve ikisi de bağımsız olarak kilitleyebilir:
 *
 *   1. HESAP  (`acct:<e-posta>`)  — dağıtık (botnet) parola denemesini durdurur:
 *      saldırgan IP değiştirse bile aynı hesaba deneme yapmaya devam edemez.
 *   2. IP     (`ip:<adres>`)      — hesap sayma (credential stuffing) saldırısını
 *      durdurur: saldırgan her denemede farklı e-posta kullansa bile IP'si sayılır.
 *
 * BAŞARILI giriş her iki sayacı da sıfırlar; meşru kullanıcı birkaç kez yanlış yazıp
 * sonra doğru girdiğinde ceza taşımaz.
 *
 * ⚠ TEK SÜREÇ SINIRI — BİLİNÇLİ KAPSAM KARARI
 * Sayaçlar süreç belleğindedir. Sonuçları:
 *   • Sunucu yeniden başlatıldığında tüm sayaçlar sıfırlanır.
 *   • Birden çok kopya (yatay ölçekleme / birden çok Render örneği) çalıştırılırsa
 *     her kopya kendi sayacını tutar; etkin sınır kopya sayısı kadar gevşer.
 * Bugünkü dağıtım tek örnektir, bu yüzden yeni bir bağımlılık (redis vb.) eklemek
 * yerine bellek içi çözüm seçilmiştir. Birden çok örneğe geçildiğinde bu modül
 * paylaşımlı bir sayaca (Redis INCR + EXPIRE) taşınmalıdır — arayüzü aynı kalır.
 */
import { ApiError } from './helpers.js';

const num = (value, fallback) => {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? n : fallback;
};

/** Ortam değişkenleriyle ayarlanabilir (testler kısa pencereler kullanır). */
export function rateLimitConfig(env = process.env) {
  return {
    // Sayma penceresi: bu süre içinde biriken başarısız denemeler toplanır.
    windowMs: num(env.KK_LOGIN_WINDOW_MS, 15 * 60 * 1000),
    // Kilit süresi: sınır aşıldığında girişin kapalı kalacağı süre.
    lockMs: num(env.KK_LOGIN_LOCK_MS, 15 * 60 * 1000),
    // Hesap başına izin verilen başarısız deneme.
    accountMax: num(env.KK_LOGIN_MAX_ATTEMPTS, 5),
    // IP başına izin verilen başarısız deneme (birden çok hesabı kapsar).
    ipMax: num(env.KK_LOGIN_IP_MAX_ATTEMPTS, 20),
  };
}

/**
 * İstemci IP'si.
 *
 * Render gibi platformlarda TLS bir vekil sunucuda sonlanır ve gerçek adres
 * `X-Forwarded-For` başlığındadır. Bu başlık İSTEMCİ TARAFINDAN UYDURULABİLİR;
 * bu yüzden yalnızca vekil arkasında çalıştığımızı bildiğimizde okunur
 * (`KK_TRUST_PROXY=1` ya da üretim benzeri ortam). Aksi halde soketin gerçek
 * adresi kullanılır — geliştirmede başlık göndererek kilit atlatılamaz.
 */
export function clientIp(req, { trustProxy }) {
  if (trustProxy) {
    const fwd = req.headers['x-forwarded-for'];
    if (typeof fwd === 'string' && fwd.length > 0) {
      const first = fwd.split(',')[0].trim();
      if (first) return first;
    }
  }
  return req.socket?.remoteAddress || req.ip || 'bilinmeyen';
}

export function createLoginRateLimiter(env = process.env, now = () => Date.now()) {
  const cfg = rateLimitConfig(env);
  const buckets = new Map();

  function prune(t) {
    // Tembel temizlik: sayaç haritası büyümediği sürece dolaşmaya gerek yok.
    if (buckets.size < 500) return;
    for (const [key, b] of buckets) {
      if (b.lockedUntil <= t && b.firstAt + cfg.windowMs <= t) buckets.delete(key);
    }
  }

  function get(key, t) {
    let b = buckets.get(key);
    if (!b) { b = { count: 0, firstAt: t, lockedUntil: 0 }; buckets.set(key, b); }
    // Kilit bitmişse ve pencere dolmuşsa sayaç sıfırdan başlar (kendiliğinden iyileşme).
    if (b.lockedUntil !== 0 && b.lockedUntil <= t) { b.count = 0; b.firstAt = t; b.lockedUntil = 0; }
    else if (b.lockedUntil === 0 && b.firstAt + cfg.windowMs <= t) { b.count = 0; b.firstAt = t; }
    return b;
  }

  function lockedSeconds(key, t) {
    const b = buckets.get(key);
    if (!b || b.lockedUntil <= t) return 0;
    return Math.ceil((b.lockedUntil - t) / 1000);
  }

  return {
    config: cfg,

    /**
     * Giriş denemesinden ÖNCE çağrılır. Kilitliyse 429 fırlatır.
     * @throws {ApiError} 429 TOO_MANY_ATTEMPTS
     */
    assertAllowed(ip, email) {
      const t = now();
      prune(t);
      const ipLock = lockedSeconds(`ip:${ip}`, t);
      if (ipLock > 0) {
        throw Object.assign(
          new ApiError(429, 'TOO_MANY_ATTEMPTS',
            `Bu ağ adresinden çok fazla giriş denemesi yapıldı. `
            + `Lütfen ${ipLock} saniye sonra tekrar deneyin.`),
          { retryAfter: ipLock }
        );
      }
      const acctLock = email ? lockedSeconds(`acct:${email}`, t) : 0;
      if (acctLock > 0) {
        throw Object.assign(
          new ApiError(429, 'TOO_MANY_ATTEMPTS',
            `Çok fazla başarısız giriş denemesi nedeniyle bu hesap geçici olarak kilitlendi. `
            + `Lütfen ${acctLock} saniye sonra tekrar deneyin.`),
          { retryAfter: acctLock }
        );
      }
    },

    /** Başarısız giriş — iki sayaç da artar, sınır aşılırsa kilitlenir. */
    registerFailure(ip, email) {
      const t = now();
      const bump = (key, max) => {
        const b = get(key, t);
        b.count += 1;
        if (b.count >= max) b.lockedUntil = t + cfg.lockMs;
      };
      bump(`ip:${ip}`, cfg.ipMax);
      if (email) bump(`acct:${email}`, cfg.accountMax);
    },

    /** Başarılı giriş — hem hesabın hem IP'nin sayacı temizlenir. */
    registerSuccess(ip, email) {
      buckets.delete(`ip:${ip}`);
      if (email) buckets.delete(`acct:${email}`);
    },

    /** Testler ve `/health` teşhisi için. */
    size() { return buckets.size; },
  };
}
