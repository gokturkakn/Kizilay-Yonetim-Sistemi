// Rapor dışa aktarım uçları: /export/<rapor>.xlsx ve /export/<rapor>.pdf
//
// Rapor tanımları (sorgu + Türkçe sütunlar) src/reports.js içinde TEK yerde durur;
// iki biçim de aynı tanımı kullandığı için birbirinden ayrışamaz.
// Liste uçlarıyla aynı filtreler geçerlidir, sayfalama uygulanmaz.
import { Router } from 'express';
import ExcelJS from 'exceljs';
import { requireRole } from '../auth.js';
import { notFound } from '../helpers.js';
import { auditLog } from '../audit.js';
import { maskTcNo } from '../tc.js';
import { REPORTS, filterSummary } from '../reports.js';
import { sendPdfTable } from '../pdf.js';

async function sendWorkbook(res, filename, sheetName, columns, rows) {
  const wb = new ExcelJS.Workbook();
  wb.creator = 'Kızılay Kadın Teşkilat Yönetim Sistemi';
  const ws = wb.addWorksheet(sheetName);
  ws.columns = columns.map((c) => ({ header: c.header, key: c.key, width: c.width || 22 }));
  ws.getRow(1).font = { bold: true };
  for (const row of rows) ws.addRow(row);
  res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  await wb.xlsx.write(res);
  res.end();
}

/** `?unmasked=1` / `?unmasked=true` → maskesiz çıktı talebi. */
function wantsUnmasked(query) {
  const v = String(query.unmasked ?? '').trim().toLowerCase();
  return v === '1' || v === 'true';
}

export default function exportRoutes(db) {
  const r = Router();

  // SPEC 3. bölüm: raporlar genel merkez yetkisinde.
  r.use('/export', requireRole('genel_merkez'));

  r.get('/export/:report.:format(xlsx|pdf)', async (req, res, next) => {
    try {
      const spec = REPORTS[req.params.report];
      if (!spec) throw notFound(`Bilinmeyen rapor: ${req.params.report}`);

      let rows = spec.build(db, req.query);

      // ---------------------------------------------------------------- KVKK
      // Denetim Y-1: TC numaraları raporlara maskesiz iniyordu ve dosya cihazda
      // korumasız duruyordu. Artık VARSAYILAN maskelidir; maskesiz çıktı bilinçli
      // bir tercihtir (`?unmasked=1`), yalnız `genel_merkez` alabilir (bu yönlendirici
      // zaten yalnız ona açık) ve MUTLAKA denetim izine düşer — "kim, ne zaman, hangi
      // filtreyle kimlik verisi indirdi" sorusu cevaplanabilir olmalıdır.
      const unmasked = wantsUnmasked(req.query);
      if (spec.sensitiveFields?.length) {
        if (!unmasked) {
          rows = rows.map((row) => {
            const copy = { ...row };
            for (const f of spec.sensitiveFields) copy[f] = maskTcNo(copy[f]);
            return copy;
          });
        } else {
          const { unmasked: _drop, ...filters } = req.query;
          auditLog(db, {
            entity: 'exports',
            entityId: 0, // rapor bir satır değildir; entity_id NOT NULL olduğu için 0.
            action: 'export_unmasked',
            changedBy: req.user.id,
            changes: {
              report: req.params.report,
              format: req.params.format,
              fields: spec.sensitiveFields,
              row_count: rows.length,
              filters,
            },
          });
        }
      }

      if (req.params.format === 'pdf') {
        sendPdfTable(res, {
          filename: `${spec.filename}.pdf`,
          title: spec.title,
          subtitle: filterSummary(db, req.query),
          columns: spec.columns,
          rows,
        });
        return;
      }
      await sendWorkbook(res, `${spec.filename}.xlsx`, spec.title, spec.columns, rows);
    } catch (e) { next(e); }
  });

  return r;
}
