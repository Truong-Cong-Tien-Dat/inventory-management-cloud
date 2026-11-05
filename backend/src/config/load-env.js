import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const defaultEnvPath = path.resolve(__dirname, '../../.env');

// Load backend/.env regardless of the current working directory. Existing
// process environment variables always take precedence over the file.
dotenv.config({
  path: process.env.DOTENV_CONFIG_PATH || defaultEnvPath,
  quiet: true,
});
