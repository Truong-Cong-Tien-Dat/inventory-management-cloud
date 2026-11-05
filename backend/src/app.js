import fs from 'node:fs';
import path from 'node:path';

import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import morgan from 'morgan';
import { buildCorsOptions } from './config/cors.js';
import { env } from './config/env.js';
import { errorHandler } from './middleware/error-handler.js';
import { notFound } from './middleware/not-found.js';
import apiRouter from './routes/index.js';

function buildCspDirectives() {
  return {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'", "'unsafe-inline'"],
    styleSrc: ["'self'", "'unsafe-inline'"],
    imgSrc: ["'self'", 'data:', 'blob:'],
    fontSrc: ["'self'", 'data:'],
    connectSrc: ["'self'"],
    workerSrc: ["'self'", 'blob:'],
    objectSrc: ["'none'"],
    baseUri: ["'self'"],
    frameAncestors: ["'none'"],
    formAction: ["'self'"],
  };
}

export function createApp({ pool }) {
  if (!pool) {
    throw new Error('createApp requires a PostgreSQL pool');
  }

  const app = express();
  app.locals.pool = pool;

  app.disable('x-powered-by');
  app.set('trust proxy', env.trustProxy);

  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: buildCspDirectives(),
      },
      crossOriginEmbedderPolicy: false,
    }),
  );
  app.use(cors(buildCorsOptions(env)));
  app.use(compression());
  app.use(express.json({ limit: env.jsonBodyLimit }));

  if (env.requestLogging) {
    app.use(morgan(env.isProduction ? 'combined' : 'dev'));
  }

  app.use('/api', apiRouter);

  // Optional single-service deployment (Render): serve the prebuilt Flutter
  // Web bundle from STATIC_DIR and fall back to index.html for client-side
  // routes. API routes above keep priority; unset STATIC_DIR disables this.
  if (env.staticDir) {
    const indexFile = path.join(env.staticDir, 'index.html');
    if (!fs.existsSync(indexFile)) {
      throw new Error(
        `STATIC_DIR is configured but ${indexFile} does not exist. ` +
          'Build the frontend first (flutter build web --release).',
      );
    }

    const isImmutableAsset = (relativePath) =>
      relativePath.startsWith('assets/') ||
      relativePath.startsWith('canvaskit/') ||
      relativePath.startsWith('fonts/');

    app.use(
      express.static(env.staticDir, {
        index: false,
        setHeaders(res, filePath) {
          const relativePath = path.relative(env.staticDir, filePath);
          // Stable filenames change on every build: revalidate via ETag.
          res.setHeader('Cache-Control', 'no-cache');
          if (isImmutableAsset(relativePath)) {
            res.setHeader(
              'Cache-Control',
              'public, max-age=604800, immutable',
            );
          }
        },
      }),
    );

    // SPA fallback: any non-API GET/HEAD serves the Flutter shell so deep
    // links such as /products/12 and /inventory survive a hard refresh.
    app.use((req, res, next) => {
      if (req.method !== 'GET' && req.method !== 'HEAD') return next();
      if (req.path.startsWith('/api')) return next();
      res.sendFile(
        indexFile,
        { headers: { 'Cache-Control': 'no-cache' } },
        (error) => (error ? next(error) : undefined),
      );
    });
  }

  app.use(notFound);
  app.use(errorHandler);

  return app;
}
