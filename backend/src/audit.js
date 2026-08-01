// Değişiklik günlüğü: persons, memberships, field_activities, meetings, assignments
// üzerindeki her create/update/delete/active-toggle işlemi bir satır yazar.

export function auditLog(db, { entity, entityId, action, changedBy, changes }) {
  db.prepare(
    'INSERT INTO audit_logs (entity, entity_id, action, changed_by, changes) VALUES (?, ?, ?, ?, ?)'
  ).run(entity, entityId, action, changedBy ?? null, changes ? JSON.stringify(changes) : null);
}

// Update işlemlerinde eski/yeni değer farkını üretir.
export function diffChanges(before, after, fields) {
  const diff = {};
  for (const f of fields) {
    const oldV = before[f] ?? null;
    const newV = after[f] ?? null;
    if (oldV !== newV) diff[f] = { old: oldV, new: newV };
  }
  return diff;
}
