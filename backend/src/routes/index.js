import { Router } from 'express';
import categoryRoutes from './category.routes.js';
import dashboardRoutes from './dashboard.routes.js';
import healthRoutes from './health.routes.js';
import inventoryRoutes from './inventory.routes.js';
import productRoutes from './product.routes.js';

const router = Router();

router.use(healthRoutes);
router.use(categoryRoutes);
router.use(productRoutes);
router.use(inventoryRoutes);
router.use(dashboardRoutes);

export default router;
