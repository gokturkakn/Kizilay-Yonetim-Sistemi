/**
 * v2 modüllerinin DEMO kayıtları — yalnızca `KK_SEED_DEMO=1` / `--demo` ile yüklenir.
 * Üretimde ASLA çalışmaz. Gerçek veri sahadan girilecek / Excel'den aktarılacaktır.
 */

export function seedV2Demo(db, { adminId, sahaId, personIds }) {
  const lookupId = (categoryCode, name) => {
    const row = db.prepare(`
      SELECT li.id FROM lookup_items li
      JOIN lookup_categories lc ON lc.id = li.category_id
      WHERE lc.code = ? AND li.name = ?`).get(categoryCode, name);
    return row ? row.id : null;
  };
  const orgUnitId = (type, name) =>
    db.prepare('SELECT id FROM org_units WHERE type = ? AND name = ?').get(type, name)?.id ?? null;
  const provinceId = (name) => db.prepare('SELECT id FROM provinces WHERE name = ?').get(name)?.id ?? null;
  const regionOf = (pid) => db.prepare('SELECT region_id FROM provinces WHERE id = ?').get(pid)?.region_id ?? null;
  const calendarId = (name) => db.prepare('SELECT id FROM calendar_events WHERE name = ?').get(name)?.id ?? null;

  db.transaction(() => {
    const ankara = provinceId('Ankara');
    const istanbul = provinceId('İstanbul');
    const izmir = provinceId('İzmir');
    const cankaya = db.prepare('SELECT id FROM districts WHERE province_id = ? AND name = ?').get(ankara, 'Çankaya')?.id ?? null;

    // --- Görevlendirmeler: birkaç birimi "aktif" hale getirir -------------
    const insAssign = db.prepare(`
      INSERT INTO org_assignments (org_unit_id, person_id, role_id, role_title, start_date, status)
      VALUES (?, ?, ?, ?, ?, 'aktif')`);
    const activate = db.prepare("UPDATE org_units SET status = 'aktif', updated_at = datetime('now') WHERE id = ?");
    const pairs = [
      ['il_baskanligi', 'Ankara İl Kadın Başkanlığı', personIds[0], 'İl Başkanı'],
      ['il_baskanligi', 'İstanbul İl Kadın Başkanlığı', personIds[2], 'İl Başkanı'],
      ['ilce_baskanligi', 'Çankaya İlçe Kadın Başkanlığı', personIds[1], 'İlçe Başkanı'],
    ];
    for (const [type, name, personId, title] of pairs) {
      const unitId = orgUnitId(type, name);
      if (!unitId || !personId) continue;
      insAssign.run(unitId, personId, lookupId('gorev_unvani', title), title, '2026-01-15');
      activate.run(unitId);
    }

    // --- Görevler ---------------------------------------------------------
    const insTask = db.prepare(`
      INSERT INTO tasks (task_date, region_id, province_id, district_id, branch, org_unit_id,
        task_type_id, sub_task_id, volunteer_count, beneficiary_count, duration_hours, notes, created_by)
      VALUES (@task_date, @region_id, @province_id, @district_id, @branch, @org_unit_id,
        @task_type_id, @sub_task_id, @volunteer_count, @beneficiary_count, @duration_hours, @notes, @created_by)`);
    const task = (o) => insTask.run({
      district_id: null, branch: null, org_unit_id: null, sub_task_id: null,
      duration_hours: null, notes: null, ...o,
    });
    task({
      task_date: '2026-07-05', region_id: regionOf(ankara), province_id: ankara, district_id: cankaya,
      branch: 'Çankaya Şubesi', org_unit_id: orgUnitId('il_baskanligi', 'Ankara İl Kadın Başkanlığı'),
      task_type_id: lookupId('gorev_turu', 'Kan Hizmetleri'),
      sub_task_id: lookupId('alt_gorev', 'Kan Bağışı Organizasyonu'),
      volunteer_count: 12, beneficiary_count: 240, duration_hours: 6,
      notes: 'Kızılay Meydanı kan bağışı standı', created_by: sahaId,
    });
    task({
      task_date: '2026-07-12', region_id: regionOf(istanbul), province_id: istanbul,
      branch: 'Üsküdar Şubesi', org_unit_id: orgUnitId('il_baskanligi', 'İstanbul İl Kadın Başkanlığı'),
      task_type_id: lookupId('gorev_turu', 'Gıda Kolisi'),
      sub_task_id: lookupId('alt_gorev', 'Koli Dağıtımı'),
      volunteer_count: 8, beneficiary_count: 65, duration_hours: 4,
      notes: 'Gıda kolisi dağıtımı', created_by: sahaId,
    });
    task({
      task_date: '2026-07-26', region_id: regionOf(ankara), province_id: ankara,
      task_type_id: lookupId('gorev_turu', 'Gönüllü Kazanımı'),
      sub_task_id: lookupId('alt_gorev', 'Üniversite Tanıtım Standı'),
      volunteer_count: 15, beneficiary_count: 90, duration_hours: 5,
      notes: 'Üniversite gönüllü tanıtım günü', created_by: adminId,
    });

    // --- Eğitimler --------------------------------------------------------
    const insTraining = db.prepare(`
      INSERT INTO trainings (training_date, region_id, province_id, org_unit_id, trainer,
        topic_id, category_id, method_id, participant_count, volunteer_count, duration_hours, notes, created_by)
      VALUES (@training_date, @region_id, @province_id, @org_unit_id, @trainer,
        @topic_id, @category_id, @method_id, @participant_count, @volunteer_count, @duration_hours, @notes, @created_by)`);
    insTraining.run({
      training_date: '2026-07-18', region_id: regionOf(izmir), province_id: izmir,
      org_unit_id: orgUnitId('il_baskanligi', 'İzmir İl Kadın Başkanlığı'), trainer: 'Dr. Merve Şahin',
      topic_id: lookupId('egitim_konusu', 'İlk Yardım'),
      category_id: lookupId('egitim_kategorisi', 'Halka Açık'),
      method_id: lookupId('egitim_yontemi', 'Yüz Yüze'),
      participant_count: 40, volunteer_count: 5, duration_hours: 3,
      notes: 'İlk yardım farkındalık eğitimi', created_by: sahaId,
    });
    insTraining.run({
      training_date: '2026-07-22', region_id: regionOf(ankara), province_id: ankara,
      org_unit_id: orgUnitId('komisyon', 'Eğitim Komisyonu'), trainer: 'Fatma Demir',
      topic_id: lookupId('egitim_konusu', 'Gönüllülük ve Gönüllü Yönetimi'),
      category_id: lookupId('egitim_kategorisi', 'Gönüllü'),
      method_id: lookupId('egitim_yontemi', 'Çevrim İçi'),
      participant_count: 30, volunteer_count: 4, duration_hours: 2,
      notes: 'Gönüllü oryantasyon programı', created_by: adminId,
    });

    // --- Etkinlikler ------------------------------------------------------
    const insEvent = db.prepare(`
      INSERT INTO events (event_date, calendar_event_id, event_type_id, region_id, province_id,
        org_unit_id, participant_count, volunteer_count, beneficiary_count, notes, created_by)
      VALUES (@event_date, @calendar_event_id, @event_type_id, @region_id, @province_id,
        @org_unit_id, @participant_count, @volunteer_count, @beneficiary_count, @notes, @created_by)`);
    const cumhuriyet = calendarId('Cumhuriyet Bayramı');
    if (cumhuriyet) {
      insEvent.run({
        event_date: '2026-10-29', calendar_event_id: cumhuriyet,
        event_type_id: lookupId('etkinlik_turu', 'Millî Bayram'),
        region_id: regionOf(istanbul), province_id: istanbul,
        org_unit_id: orgUnitId('il_baskanligi', 'İstanbul İl Kadın Başkanlığı'),
        participant_count: 120, volunteer_count: 15, beneficiary_count: 300,
        notes: 'Cumhuriyet Bayramı kutlama programı', created_by: sahaId,
      });
    }

    // --- Toplantı (v2 alanlarıyla) ---------------------------------------
    db.prepare(`
      INSERT INTO meetings (body_id, meeting_type_id, method_id, location, org_unit_id,
        meeting_date, participants, agenda, decision, outcome, created_by)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
      null,
      lookupId('toplanti_turu', 'Çalıştay'),
      lookupId('toplanti_yontemi', 'Yüz Yüze'),
      'Genel Merkez Konferans Salonu',
      orgUnitId('koordinasyon_kurulu', 'Koordinasyon Kurulu'),
      '2026-07-28',
      '35 bölge ve il temsilcisi',
      '2027 teşkilatlanma hedefleri',
      'İl başkanlığı boş olan illerde öncelikli teşkilatlanma kararı alındı',
      'Yol haritası eylül ayında yayımlanacak',
      adminId
    );

    // --- Lojistik: talep → gönderi → stok --------------------------------
    const yelek = lookupId('lojistik_urun', 'Yelek');
    const brosur = lookupId('lojistik_urun', 'Broşür');
    const insReq = db.prepare(`
      INSERT INTO material_requests (request_date, org_unit_id, region_id, province_id,
        product_id, quantity, status, requested_by_person_id, notes, created_by)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);

    // Stok girişi (genel merkez deposu)
    const insMove = db.prepare(`
      INSERT INTO stock_movements (product_id, direction, quantity, reason, ref_type, ref_id, created_by)
      VALUES (?, ?, ?, ?, ?, ?, ?)`);
    const bumpStock = db.prepare(
      "UPDATE stock_items SET quantity = quantity + ?, updated_at = datetime('now') WHERE product_id = ?"
    );
    for (const [pid, qty] of [[yelek, 500], [brosur, 2000]]) {
      if (!pid) continue;
      insMove.run(pid, 'giris', qty, 'Başlangıç stok girişi', null, null, adminId);
      bumpStock.run(qty, pid);
    }

    if (yelek) {
      const reqId = Number(insReq.run(
        '2026-07-01', orgUnitId('il_baskanligi', 'Ankara İl Kadın Başkanlığı'),
        regionOf(ankara), ankara, yelek, 50, 'gonderildi', personIds[0],
        'Saha faaliyetleri için gönüllü yeleği', adminId
      ).lastInsertRowid);

      db.prepare(`
        INSERT INTO shipments (request_id, shipment_date, shipping_method_id, tracking_no,
          quantity, received_by, received_date, notes, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
        reqId, '2026-07-03', lookupId('gonderim_sekli', 'Kargo'), 'TR123456789',
        50, 'Ayşe Yılmaz', '2026-07-05', null, adminId
      );
      insMove.run(yelek, 'cikis', 50, 'Gönderi #1', 'shipments', 1, adminId);
      bumpStock.run(-50, yelek);
      db.prepare("UPDATE material_requests SET status = 'teslim_edildi' WHERE id = ?").run(reqId);
    }

    if (brosur) {
      insReq.run('2026-07-20', orgUnitId('il_baskanligi', 'İzmir İl Kadın Başkanlığı'),
        regionOf(izmir), izmir, brosur, 300, 'talep', personIds[4] ?? null,
        'Eğitim tanıtım broşürü', sahaId);
    }

    // --- Dokümanlar (SPEC-V2-M6) -----------------------------------------
    // Dört kategoriden birer örnek + dört kapsamdan örnekler; biri bilinçli olarak
    // yayından kaldırılmış (saha görünürlüğünün doğrulanabilmesi için), biri süresi
    // dolmuş bir izin belgesi ("Süresi doldu" rozeti gerçek veriyle görünsün).
    const insDoc = db.prepare(`
      INSERT INTO documents (title, description, category_id, scope, region_id, province_id,
        district_id, version, published_at, valid_until, is_active, created_by)
      VALUES (@title, @description, @category_id, @scope, @region_id, @province_id,
        @district_id, @version, @published_at, @valid_until, @is_active, @created_by)`);
    const doc = (o) => {
      if (!o.category_id) return;
      insDoc.run({
        description: null, region_id: null, province_id: null, district_id: null,
        version: null, published_at: null, valid_until: null, is_active: 1,
        created_by: adminId, ...o,
      });
    };
    doc({
      title: 'Gönüllü El Kitabı',
      description: 'Kızılay Kadın gönüllülerinin görev, sorumluluk ve süreçlerini anlatan temel rehber.',
      category_id: lookupId('dokuman_kategorisi', 'Kılavuzlar'),
      scope: 'genel', version: 'v2.1', published_at: '2026-01-15',
    });
    doc({
      title: 'Etkinlik İzin Belgesi Şablonu',
      description: 'Saha etkinlikleri için doldurulacak matbu izin belgesi.',
      category_id: lookupId('dokuman_kategorisi', 'Formlar ve Matbu Belgeler'),
      scope: 'il', region_id: regionOf(ankara), province_id: ankara,
      version: '2026 Revizyon', published_at: '2026-02-01', valid_until: '2026-06-30',
    });
    doc({
      title: 'Aile Yılı Proje Bilgi Notu',
      description: 'Aile Yılı kapsamında ilçe teşkilatlarının yürüteceği faaliyetlerin bilgi notu.',
      category_id: lookupId('dokuman_kategorisi', 'Proje Dokümanları'),
      scope: 'ilce', region_id: regionOf(ankara), province_id: ankara, district_id: cankaya,
      version: 'v1.0', published_at: '2026-03-10',
    });
    doc({
      title: '2025 Teşkilatlanma Yönergesi',
      description: 'Yerini 2026 yönergesine bırakmıştır; arşiv amaçlı saklanmaktadır.',
      category_id: lookupId('dokuman_kategorisi', 'Yönetsel Dokümanlar'),
      scope: 'genel', version: '2025', published_at: '2025-01-05', is_active: 0,
    });
  })();
}
