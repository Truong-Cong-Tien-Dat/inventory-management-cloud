import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createTestContext } from './helpers.js';

/**
 * Regression tests for the Content-Security-Policy shipped by Helmet.
 *
 * The CSP must keep allowing the Flutter Web CanvasKit renderer
 * (www.gstatic.com scripts/wasm, fonts.gstatic.com fonts, wasm-unsafe-eval
 * compilation) while staying locked down for everything else. These checks
 * protect against both regressions (origins removed again) and over-permissive
 * changes (broad eval / wildcard hosts).
 */

function directiveOf(csp, name) {
  return csp
    .split(';')
    .map((part) => part.trim())
    .find((directive) => directive.startsWith(`${name} `));
}

describe('security headers (Content-Security-Policy)', () => {
  let ctx;

  beforeAll(() => {
    ctx = createTestContext();
  });

  afterAll(async () => {
    await ctx.pool.end();
  });

  it('GET /api/health ships a CSP header with the required directives', async () => {
    const response = await ctx.request.get('/api/health').expect(200);

    const csp = response.headers['content-security-policy'];
    expect(csp, 'helmet CSP must be present on API responses').toBeTruthy();
    expect(csp).toContain("default-src 'self'");
    expect(csp).toContain('wasm-unsafe-eval');
    expect(csp).toContain('https://www.gstatic.com');
    expect(csp).toContain('https://fonts.gstatic.com');
  });

  it('script-src allows WebAssembly compilation but not broad eval()', async () => {
    const response = await ctx.request.get('/api/health').expect(200);
    const scriptSrc = directiveOf(
      response.headers['content-security-policy'],
      'script-src',
    );

    expect(scriptSrc).toContain("'wasm-unsafe-eval'");
    expect(scriptSrc).not.toContain("'unsafe-eval'");
    expect(scriptSrc).toContain('https://www.gstatic.com');
  });

  it('connect-src and font-src allow only the required gstatic origins', async () => {
    const response = await ctx.request.get('/api/health').expect(200);
    const csp = response.headers['content-security-policy'];

    const expected = {
      'connect-src': [
        'https://www.gstatic.com',
        'https://fonts.gstatic.com',
      ],
      'font-src': ['https://fonts.gstatic.com'],
    };

    for (const [name, requiredOrigins] of Object.entries(expected)) {
      const external = directiveOf(csp, name)
        .split(' ')
        .slice(1)
        .filter((token) => token.startsWith('http'));
      expect(external, `${name} external origins`).toEqual(requiredOrigins);
      // No wildcard or insecure hosts may sneak in.
      expect(external.every((token) => token.startsWith('https://'))).toBe(
        true,
      );
    }
  });

  it('keeps the hardening directives for framing, objects, and forms', async () => {
    const response = await ctx.request.get('/api/health').expect(200);
    const csp = response.headers['content-security-policy'];

    expect(csp).toContain("frame-ancestors 'none'");
    expect(csp).toContain("object-src 'none'");
    expect(csp).toContain("base-uri 'self'");
    expect(csp).toContain("form-action 'self'");
  });

  it('still serves JSON 404 envelopes with CSP on unknown API routes', async () => {
    const response = await ctx.request.get('/api/definitely-not-here').expect(404);

    expect(response.body.error.code).toBe('ROUTE_NOT_FOUND');
    expect(response.headers['content-security-policy']).toBeTruthy();
  });
});
