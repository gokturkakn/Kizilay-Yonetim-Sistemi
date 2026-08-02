// Rapor dışa aktarım uçları: /export/<rapor>.xlsx ve /export/<rapor>.pdf
//
// Rapor tanımları (sorgu + Türkçe sütunlar) src/reports.js içinde TEK yerde durur;
// iki biçim de aynı tanımı kullandığı için birbirinden ayrışamaz.
// Liste uçlarıyla aynı filtreler geçerlidir, sayfalama uygulanmaz.
import { Router } from 'express';
import ExcelJS from 'exceljs';
import { requireRole } from '../auth.js';
import { notFound } from '../helpers.js';
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

export default function exportRoutes(db) {
  const r = Router();

  // SPEC 3. bölüm: raporlar genel merkez yetkisinde.
  r.use('/export', requireRole('genel_merkez'));

  r.get('/export/:report.:format(xlsx|pdf)', async (req, res, next) => {
    try {
      const spec = REPORTS[req.params.report];
      if (!spec) throw notFound(`Bilinmeyen rapor: ${req.params.report}`);

      const rows = spec.build(db, req.query);

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
