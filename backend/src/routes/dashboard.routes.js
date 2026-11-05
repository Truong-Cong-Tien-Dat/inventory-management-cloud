import { Router } from 'express';
import { getSummary } from '../controllers/dashboard.controller.js';
import { asyncHandler } from '../middleware/async-handler.js';

const router = Router();

router.get('/dashboard/summary', asyncHandler(getSummary));

export default router;
