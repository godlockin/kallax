/**
 * KALLAX Plugin System — discover, load, unload community plugins.
 */
import { ok, err } from 'neverthrow';
import type { KallaxResult } from '../types/index.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';
import * as fs from 'node:fs';
import * as path from 'node:path';

export interface PluginManifest {
  name: string; version: string; description: string; author: string;
  type: 'hook' | 'expert' | 'template' | 'tool'; main: string; capabilities: string[]; dependencies?: string[];
}

export interface PluginRegistry {
  discover(directory: string): Promise<KallaxResult<PluginManifest[]>>;
  load(manifest: PluginManifest): Promise<KallaxResult<void>>;
  unload(pluginName: string): Promise<KallaxResult<void>>;
  list(): PluginManifest[];
  get(pluginName: string): PluginManifest | null;
  isLoaded(pluginName: string): boolean;
}

export function createPluginRegistry(basePath: string): PluginRegistry {
  const plugins = new Map<string, PluginManifest>();
  const loadedPlugins = new Set<string>();

  return {
    async discover(directory: string): Promise<KallaxResult<PluginManifest[]>> {
      try {
        const fullPath = path.resolve(basePath, directory);
        if (!fs.existsSync(fullPath)) return ok([]);
        const entries = fs.readdirSync(fullPath, { withFileTypes: true });
        const manifests: PluginManifest[] = [];
        for (const entry of entries) {
          if (!entry.isDirectory()) continue;
          const manifestPath = path.join(fullPath, entry.name, 'kallax-plugin.json');
          if (fs.existsSync(manifestPath)) {
            const raw = fs.readFileSync(manifestPath, 'utf-8');
            const manifest = JSON.parse(raw) as PluginManifest;
            manifests.push(manifest);
            plugins.set(manifest.name, manifest);
          }
        }
        logger.info({ directory, count: manifests.length }, 'plugins discovered');
        return ok(manifests);
      } catch (error: unknown) {
        return err(new KallaxError(KallaxErrorCode.INTERNAL_ERROR, 'Plugin discovery failed', { cause: error }));
      }
    },

    async load(manifest: PluginManifest): Promise<KallaxResult<void>> {
      if (loadedPlugins.has(manifest.name)) return ok(undefined);
      plugins.set(manifest.name, manifest);
      loadedPlugins.add(manifest.name);
      logger.info({ plugin: manifest.name, version: manifest.version }, 'plugin loaded');
      return ok(undefined);
    },

    async unload(pluginName: string): Promise<KallaxResult<void>> {
      loadedPlugins.delete(pluginName);
      logger.info({ plugin: pluginName }, 'plugin unloaded');
      return ok(undefined);
    },

    list(): PluginManifest[] {
      return Array.from(plugins.values());
    },

    get(pluginName: string): PluginManifest | null {
      return plugins.get(pluginName) ?? null;
    },

    isLoaded(pluginName: string): boolean {
      return loadedPlugins.has(pluginName);
    },
  };
}

let defaultRegistry: PluginRegistry | null = null;
export function getPluginRegistry(): PluginRegistry {
  return defaultRegistry ?? (defaultRegistry = createPluginRegistry('.kallax/plugins'));
}
