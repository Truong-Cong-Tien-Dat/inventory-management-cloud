import { checkHealth } from '../services/health.service.js';

export async function getHealth(req, res) {
  const data = await checkHealth(req.app.locals.pool);
  res.json({ data });
}
