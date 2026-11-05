import { getDashboardSummary } from '../services/dashboard.service.js';

export async function getSummary(req, res) {
  const data = await getDashboardSummary(req.app.locals.pool);
  res.json({ data });
}
