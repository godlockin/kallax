/**
 * KALLAX Plugin Command Registration
 * CLI: kallax plugin list | install <path> | remove <name>
 */

import { Command } from 'commander';
import * as fsSync from 'node:fs';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import type { AppContext } from '../cli-context.js';
import { logger } from '../utils/logger.js';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { createPluginRegistry } from '../core/plugin-system.js';

function findProjectRoot(): string {
  let dir = process.cwd();
  while (dir !== '/') {
    const gitDir = path.join(dir, '.git');
    const identityDir = path.join(dir, '.kallax', 'IDENTITY.md');
    if (fsSync.existsSync(gitDir) || fsSync.existsSync(identityDir)) return dir;
    dir = path.dirname(dir);
  }
  return process.cwd();
}

function getPluginBasePath(): string {
  return path.join(findProjectRoot(), '.kallax', 'plugins');
}

export function registerPluginCommands(program: Command, _ctx: AppContext): void {
  const pluginCmd = program.command('plugin').description('Plugin management (list/install/remove)');

  // ---- list ----
  pluginCmd
    .command('list')
    .description('List all installed plugins')
    .action(async () => {
      try {
        const basePath = getPluginBasePath();
        await fs.mkdir(basePath, { recursive: true });

        const registry = createPluginRegistry(basePath);
        const discoverResult = await registry.discover(basePath);
        if (discoverResult.isErr()) {
          logger.kallaxError(discoverResult.error);
          process.exit(1);
        }

        const manifests = discoverResult.value;
        for (const m of manifests) {
          await registry.load(m);
        }

        const loaded = registry.list();
        const output = loaded.map((m) => ({
          name: m.name,
          version: m.version,
          type: m.type,
          author: m.author,
          description: m.description,
        }));

        process.stdout.write(JSON.stringify({ count: output.length, plugins: output }, null, 2) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  // ---- install ----
  pluginCmd
    .command('install <path>')
    .description('Install a plugin from a local directory')
    .action(async (pluginPath: string) => {
      try {
        const absPath = path.resolve(pluginPath);
        const basePath = getPluginBasePath();
        await fs.mkdir(basePath, { recursive: true });

        const registry = createPluginRegistry(basePath);
        const discoverResult = await registry.discover(absPath);
        if (discoverResult.isErr()) {
          logger.kallaxError(discoverResult.error);
          process.exit(1);
        }

        const manifests = discoverResult.value;
        if (manifests.length === 0) {
          process.stdout.write(
            JSON.stringify({ error: 'No valid plugins found', path: absPath }) + '\n',
          );
          process.exit(1);
        }

        const installed: string[] = [];
        for (const m of manifests) {
          // Determine source dir: if absPath itself is the plugin (has manifest at root),
          // copy the whole dir; otherwise look for a subdirectory matching plugin name
          const selfManifestPath = path.join(absPath, 'kallax-plugin.json');
          let sourceDir: string;
          try {
            await fs.access(selfManifestPath);
            sourceDir = absPath;
          } catch {
            sourceDir = path.join(absPath, m.name);
          }

          const targetDir = path.join(basePath, m.name);
          await fs.cp(sourceDir, targetDir, { recursive: true, force: true });

          const loadResult = await registry.load(m);
          if (loadResult.isErr()) {
            logger.kallaxError(loadResult.error);
            process.exit(1);
          }
          installed.push(m.name);
        }

        process.stdout.write(
          JSON.stringify({ installed: installed.length, plugins: installed }) + '\n',
        );
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });

  // ---- remove ----
  pluginCmd
    .command('remove <name>')
    .description('Remove an installed plugin')
    .action(async (name: string) => {
      try {
        const basePath = getPluginBasePath();
        const registry = createPluginRegistry(basePath);

        const unloadResult = await registry.unload(name);
        if (unloadResult.isErr()) {
          logger.kallaxError(unloadResult.error);
          process.exit(1);
        }

        // Remove plugin directory
        const pluginDir = path.join(basePath, name);
        try {
          await fs.rm(pluginDir, { recursive: true, force: true });
        } catch {
          // Directory may not exist on disk — state is already cleaned up
        }

        process.stdout.write(JSON.stringify({ removed: name }) + '\n');
      } catch (error: unknown) {
        logger.kallaxError(KallaxError.fromUnknown(error));
        process.exit(1);
      }
    });
}
