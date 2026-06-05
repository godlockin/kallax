/**
 * Plugin System E2E tests.
 * Tests the full lifecycle: create temp fixture -> discover -> load -> verify -> unload
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import * as os from 'node:os';
import { createPluginRegistry } from '../../src/core/plugin-system.js';
import type { PluginManifest } from '../../src/core/plugin-system.js';

// ============================================================================
// Helpers
// ============================================================================

const TEST_MANIFEST: PluginManifest = {
  name: 'test-analyzer',
  version: '1.0.0',
  description: 'A test analysis plugin',
  author: 'kallax-tester',
  type: 'hook',
  main: 'index.js',
  capabilities: ['analysis', 'reporting'],
  dependencies: ['logging-core'],
};

const SECOND_MANIFEST: PluginManifest = {
  name: 'test-formatter',
  version: '0.5.0',
  description: 'A test formatting plugin',
  author: 'kallax-tester',
  type: 'tool',
  main: 'dist/format.js',
  capabilities: ['formatting', 'lint'],
};

/**
 * Create a plugin directory with a valid kallax-plugin.json manifest file.
 * Returns the absolute path to the plugin directory.
 */
async function createPluginFixture(
  parentDir: string,
  manifest: PluginManifest,
): Promise<string> {
  const pluginDir = path.join(parentDir, manifest.name);
  await fs.mkdir(pluginDir, { recursive: true });

  const manifestPayload: Record<string, unknown> = {
    name: manifest.name,
    version: manifest.version,
    description: manifest.description,
    author: manifest.author,
    type: manifest.type,
    main: manifest.main,
    capabilities: [...manifest.capabilities],
  };
  if (manifest.dependencies && manifest.dependencies.length > 0) {
    manifestPayload.dependencies = [...manifest.dependencies];
  }

  await fs.writeFile(
    path.join(pluginDir, 'kallax-plugin.json'),
    JSON.stringify(manifestPayload, null, 2),
  );

  return pluginDir;
}

// ============================================================================
// Tests
// ============================================================================

describe('PluginSystem E2E', () => {
  let tmpDir: string;

  beforeAll(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'kallax-plugin-e2e-'));
  });

  afterAll(async () => {
    await fs.rm(tmpDir, { recursive: true, force: true });
  });

  // --------------------------------------------------------------------------
  // Discover
  // --------------------------------------------------------------------------

  it('discovers plugins from a directory with subdirectory structure', async () => {
    const parent = path.join(tmpDir, 'discover-subdirs');
    await fs.mkdir(parent, { recursive: true });
    await createPluginFixture(parent, TEST_MANIFEST);

    const registry = createPluginRegistry(parent);
    const result = await registry.discover(parent);

    expect(result.isOk()).toBe(true);
    expect(result.value.length).toBe(1);
    expect(result.value[0]!.name).toBe(TEST_MANIFEST.name);
    expect(result.value[0]!.version).toBe(TEST_MANIFEST.version);
    expect(result.value[0]!.type).toBe(TEST_MANIFEST.type);
  });

  it('discovers multiple plugins in the same parent directory', async () => {
    const parent = path.join(tmpDir, 'discover-multiple');
    await fs.mkdir(parent, { recursive: true });
    await createPluginFixture(parent, TEST_MANIFEST);
    await createPluginFixture(parent, SECOND_MANIFEST);

    const registry = createPluginRegistry(parent);
    const result = await registry.discover(parent);

    expect(result.isOk()).toBe(true);
    expect(result.value.length).toBe(2);

    const names = result.value.map((m) => m.name).sort();
    expect(names).toEqual([TEST_MANIFEST.name, SECOND_MANIFEST.name].sort());
  });

  it('discovers a single plugin when the directory itself contains the manifest', async () => {
    const parent = path.join(tmpDir, 'discover-self');
    await fs.mkdir(parent, { recursive: true });

    // Write manifest directly in parent (not in a subdir)
    const manifestPayload = {
      name: TEST_MANIFEST.name,
      version: TEST_MANIFEST.version,
      description: TEST_MANIFEST.description,
      author: TEST_MANIFEST.author,
      type: TEST_MANIFEST.type,
      main: TEST_MANIFEST.main,
      capabilities: [...TEST_MANIFEST.capabilities],
    };
    await fs.writeFile(
      path.join(parent, 'kallax-plugin.json'),
      JSON.stringify(manifestPayload, null, 2),
    );

    const registry = createPluginRegistry(parent);
    const result = await registry.discover(parent);

    expect(result.isOk()).toBe(true);
    expect(result.value.length).toBe(1);
    expect(result.value[0]!.name).toBe(TEST_MANIFEST.name);
  });

  it('returns empty array for a directory without plugins', async () => {
    const emptyDir = path.join(tmpDir, 'empty-dir');
    await fs.mkdir(emptyDir, { recursive: true });

    const registry = createPluginRegistry(emptyDir);
    const result = await registry.discover(emptyDir);

    expect(result.isOk()).toBe(true);
    expect(result.value.length).toBe(0);
  });

  it('returns empty array for a non-existent directory', async () => {
    const nonexistent = path.join(tmpDir, 'does-not-exist');
    const registry = createPluginRegistry(nonexistent);
    const result = await registry.discover(nonexistent);

    expect(result.isOk()).toBe(true);
    expect(result.value.length).toBe(0);
  });

  it('skips subdirectories without valid manifests', async () => {
    const parent = path.join(tmpDir, 'skip-invalid');
    await fs.mkdir(parent, { recursive: true });

    await createPluginFixture(parent, TEST_MANIFEST);

    // Add a subdirectory without a manifest
    await fs.mkdir(path.join(parent, 'no-manifest-dir'), { recursive: true });
    await fs.writeFile(path.join(parent, 'no-manifest-dir', 'random.txt'), 'not a plugin');

    const registry = createPluginRegistry(parent);
    const result = await registry.discover(parent);

    expect(result.isOk()).toBe(true);
    expect(result.value.length).toBe(1);
    expect(result.value[0]!.name).toBe(TEST_MANIFEST.name);
  });

  // --------------------------------------------------------------------------
  // Load
  // --------------------------------------------------------------------------

  it('loads a discovered plugin into the registry', async () => {
    const registry = createPluginRegistry(tmpDir);
    const result = await registry.load(TEST_MANIFEST);

    expect(result.isOk()).toBe(true);
    expect(registry.isLoaded(TEST_MANIFEST.name)).toBe(true);
  });

  it('rejects loading a duplicate plugin', async () => {
    const registry = createPluginRegistry(tmpDir);
    await registry.load(TEST_MANIFEST);
    const result = await registry.load(TEST_MANIFEST);

    expect(result.isErr()).toBe(true);
  });

  // --------------------------------------------------------------------------
  // List & Get
  // --------------------------------------------------------------------------

  it('returns loaded plugins from list()', async () => {
    const registry = createPluginRegistry(tmpDir);
    await registry.load(TEST_MANIFEST);
    await registry.load(SECOND_MANIFEST);

    const loaded = registry.list();
    expect(loaded.length).toBe(2);

    const names = loaded.map((m) => m.name).sort();
    expect(names).toEqual([TEST_MANIFEST.name, SECOND_MANIFEST.name].sort());
  });

  it('returns empty list when no plugins are loaded', async () => {
    const registry = createPluginRegistry(tmpDir);
    expect(registry.list().length).toBe(0);
  });

  it('gets a specific loaded plugin by name', async () => {
    const registry = createPluginRegistry(tmpDir);
    await registry.load(TEST_MANIFEST);

    const plugin = registry.get(TEST_MANIFEST.name);
    expect(plugin).not.toBeNull();
    expect(plugin!.name).toBe(TEST_MANIFEST.name);
    expect(plugin!.version).toBe(TEST_MANIFEST.version);
    expect(plugin!.type).toBe(TEST_MANIFEST.type);

    // Non-existent
    expect(registry.get('nonexistent-plugin')).toBeNull();
  });

  // --------------------------------------------------------------------------
  // Unload
  // --------------------------------------------------------------------------

  it('unloads a previously loaded plugin', async () => {
    const registry = createPluginRegistry(tmpDir);
    await registry.load(TEST_MANIFEST);
    expect(registry.isLoaded(TEST_MANIFEST.name)).toBe(true);

    const result = await registry.unload(TEST_MANIFEST.name);
    expect(result.isOk()).toBe(true);
    expect(registry.isLoaded(TEST_MANIFEST.name)).toBe(false);
  });

  it('rejects unloading a non-existent plugin', async () => {
    const registry = createPluginRegistry(tmpDir);
    const result = await registry.unload('never-loaded');

    expect(result.isErr()).toBe(true);
  });

  // --------------------------------------------------------------------------
  // Full Lifecycle
  // --------------------------------------------------------------------------

  it('completes the full lifecycle: discover -> load -> verify -> unload', async () => {
    const parent = path.join(tmpDir, 'full-lifecycle');
    await fs.mkdir(parent, { recursive: true });
    await createPluginFixture(parent, TEST_MANIFEST);

    const registry = createPluginRegistry(parent);

    // 1. Discover
    const discoverResult = await registry.discover(parent);
    expect(discoverResult.isOk()).toBe(true);
    expect(discoverResult.value.length).toBe(1);

    const manifest = discoverResult.value[0]!;

    // 2. Load
    const loadResult = await registry.load(manifest);
    expect(loadResult.isOk()).toBe(true);
    expect(registry.isLoaded(manifest.name)).toBe(true);

    // 3. Verify (list + get)
    const loaded = registry.list();
    expect(loaded.length).toBe(1);
    expect(loaded[0]!.name).toBe(manifest.name);

    const byGet = registry.get(manifest.name);
    expect(byGet).not.toBeNull();
    expect(byGet!.version).toBe(manifest.version);

    // 4. Unload
    const unloadResult = await registry.unload(manifest.name);
    expect(unloadResult.isOk()).toBe(true);
    expect(registry.isLoaded(manifest.name)).toBe(false);
    expect(registry.list().length).toBe(0);
  });
});
