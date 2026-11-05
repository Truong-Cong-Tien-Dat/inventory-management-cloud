import { Router } from 'express';
import { getHealth } from '../controllers/health.controller.js';
import { asyncHandler } from '../middleware/async-handler.js';

const router = Router();

router.get('/health', asyncHandler(getHealth));

export default router;
