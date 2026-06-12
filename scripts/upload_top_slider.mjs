#!/usr/bin/env node
/**
 * @deprecated Use generate_top_slider_variants.mjs --upload instead.
 */
import { spawnSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const script = path.join(path.dirname(fileURLToPath(import.meta.url)), 'generate_top_slider_variants.mjs');
const result = spawnSync(process.execPath, [script, '--upload'], { stdio: 'inherit' });
process.exit(result.status ?? 1);
