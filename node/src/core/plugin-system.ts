/**
 * KALLAX Plugin System
 * Plugin discovery, loading, unloading, and registry management.
 * Follows strict TypeScript — no `any`, no `@ts-ignore`.
 */

import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import { err, ok } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';

// ============================================================================
// Types
// ============================================================================

export interface PluginManifest {
  readonly name: string;
  readonly version: string;
  readonly description: string;
  readonly author: string;
  readonly type: 'hook' | 'expert' | 'template' | 'tool';
  readonly main: string;
  readonly capabilities: readonly string[];
  readonly dependencies?: readonly string[];
}

export interface PluginRegistry {
  /** Scan a directory for plugin manifests (root-level manifest or subdirs) */
  discover(directory: string): Promise<KallaxResult<PluginManifest[]>>;
  /** Add a plugin to the active registry */
  load(manifest: PluginManifest): Promise<KallaxResult<void>>;
  /** Remove a plugin from the active registry */
  unload(pluginName: string): Promise<KallaxResult<void>>;
  /** Return all currently loaded plugins */
  list(): readonly PluginManifest[];
  /** Get a loaded plugin by name, or null */
  get(pluginName: string): PluginManifest | null;
  /** Check if a plugin is currently loaded */
  isLoaded(pluginName: string): boolean;
}

// ============================================================================
// Manifest Validation
// ============================================================================

const VALID_PLUGIN_TYPES = new Set(['hook', 'expert', 'template', 'tool']);

interface RawManifest {
  name?: unknown;
  version?: unknown;
  description?: unknown;
  author?: unknown;
  type?: unknown;
  main?: unknown;
  capabilities?: unknown;
  dependencies?: unknown;
}

function isValidManifest(
  raw: RawManifest,
): raw is Required<
  Pick<PluginManifest, 'name' | 'version' | 'description' | 'author' | 'type' | 'main' | 'capabilities'>
> & RawManifest {
  return (
    typeof raw.name === 'string' &&
    typeof raw.version === 'string' &&
    typeof raw.description === 'string' &&
    typeof raw.author === 'string' &&
    typeof raw.type === 'string' &&
    VALID_PLUGIN_TYPES.has(raw.type) &&
    typeof raw.main === 'string' &&
    Array.isArray(raw.capabilities)
  );
}

function normalizeManifest(raw: RawManifest): PluginManifest {
  return {
    name: raw.name as string,
    version: raw.version as string,
    description: raw.description as string,
    author: raw.author as string,
    type: raw.type as PluginManifest['type'],
    main: raw.main as string,
    capabilities: raw.capabilities as string[],
    dependencies: raw.dependencies != null ? (raw.dependencies as string[]) : undefined,
  };
}

// ============================================================================
// Internal State
// ============================================================================

interface PluginRegistryState {
  readonly loaded: Map<string, PluginManifest>;
  readonly basePath: string;
}

function createInternalState(basePath: string): PluginRegistryState {
  return { loaded: new Map(), basePath };
}

// ============================================================================
// Core Operations
// ============================================================================

/**
 * Scan `directory` for plugin manifests.
 *
 * Two modes:
 * 1. The directory itself is a plugin (has `kallax-plugin.json` at root)
 * 2. The directory contains plugin subdirectories (each with `kallax-plugin.json`)
 */
async function discoverFromDir(directory: string): Promise<KallaxResult<PluginManifest[]>> {
  try {
    await fs.access(directory);
  } catch {
    return ok([]);
  }

  try {
    const manifests: PluginManifest[] = [];

    // Mode 1: Check if the directory itself is a plugin
    const selfManifestPath = path.join(directory, 'kallax-plugin.json');
    try {
      const content = await fs.readFile(selfManifestPath, 'utf-8');
      const raw = JSON.parse(content) as RawManifest;
      if (isValidManifest(raw)) {
        manifests.push(normalizeManifest(raw));
        return ok(manifests);
      }
    } catch {
      // Not a self-contained plugin — fall through to subdir scan
    }

    // Mode 2: Scan subdirectories for plugins
    const entries = await fs.readdir(directory, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;

      const manifestPath = path.join(directory, entry.name, 'kallax-plugin.json');
      try {
        const content = await fs.readFile(manifestPath, 'utf-8');
        const raw = JSON.parse(content) as RawManifest;
        if (isValidManifest(raw)) {
          manifests.push(normalizeManifest(raw));
        } else {
          logger.warn({ pluginDir: entry.name }, 'invalid plugin manifest — skipping');
        }
      } catch {
        // No valid manifest in this subdirectory
      }
    }

    return ok(manifests);
  } catch (error: unknown) {
    return err(
      new KallaxError(KallaxErrorCode.INTERNAL_ERROR, `Failed to scan for plugins in ${directory}`, {
        cause: error,
      }),
    );
  }
}

function loadIntoRegistry(state: PluginRegistryState, manifest: PluginManifest): KallaxResult<void> {
  if (state.loaded.has(manifest.name)) {
    return err(
      new KallaxError(KallaxErrorCode.PLUGIN_ALREADY_LOADED, `Plugin "${manifest.name}" is already loaded`),
    );
  }

  state.loaded.set(manifest.name, manifest);
  logger.info({ plugin: manifest.name, type: manifest.type }, 'plugin loaded');
  return ok(undefined);
}

function unloadFromRegistry(state: PluginRegistryState, pluginName: string): KallaxResult<void> {
  if (!state.loaded.has(pluginName)) {
    return err(
      new KallaxError(KallaxErrorCode.PLUGIN_NOT_FOUND, `Plugin "${pluginName}" is not loaded`),
    );
  }

  state.loaded.delete(pluginName);
  logger.info({ plugin: pluginName }, 'plugin unloaded');
  return ok(undefined);
}

// ============================================================================
// Factory
// ============================================================================

export function createPluginRegistry(basePath: string): PluginRegistry {
  const state = createInternalState(basePath);

  return {
    discover(directory: string): Promise<KallaxResult<PluginManifest[]>> {
      return discoverFromDir(directory);
    },

    load(manifest: PluginManifest): Promise<KallaxResult<void>> {
      return Promise.resolve(loadIntoRegistry(state, manifest));
    },

    unload(pluginName: string): Promise<KallaxResult<void>> {
      return Promise.resolve(unloadFromRegistry(state, pluginName));
    },

    list(): readonly PluginManifest[] {
      return Array.from(state.loaded.values());
    },

    get(pluginName: string): PluginManifest | null {
      return state.loaded.get(pluginName) ?? null;
    },

    isLoaded(pluginName: string): boolean {
      return state.loaded.has(pluginName);
    },
  };
}
