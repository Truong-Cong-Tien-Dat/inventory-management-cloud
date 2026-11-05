# Lightweight production image (Option A): the Flutter Web bundle is built
# locally with `flutter build web --release` and committed at
# frontend/build/web, so this image only needs Node.js. See
# docs/DEPLOY_RENDER.md for the full deployment guide.

FROM node:20-alpine

ENV NODE_ENV=production \
    STATIC_DIR=/app/public

WORKDIR /app

# Install exact production dependencies first for better layer caching.
COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Express application code and the prebuilt web bundle.
COPY backend/src ./src
COPY frontend/build/web ./public

# Render injects PORT automatically (default 10000 for Docker runtimes).
EXPOSE 10000

CMD ["node", "src/server.js"]
