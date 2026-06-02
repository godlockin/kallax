/**
 * KALLAX Role Selector
 * Determine instance role (Conductor vs Performer)
 */

import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import { err, ok } from 'neverthrow';
import { z } from 'zod';
import type { KallaxResult, InstanceRole } from '../types/index.js';
import { KallaxError, KallaxErrorCode, InstanceRole as InstanceRoleEnum } from '../types/index.js';
import { logger } from '../utils/logger.js';

export interface RoleConfig {
  readonly role: InstanceRole;
  readonly configuredAt: number;
  readonly configSource: 'file' | 'env' | 'auto';
}

const InstanceConfigSchema = z.object({
  role: z.nativeEnum(InstanceRoleEnum),
  configuredAt: z.number().optional(),
});

type InstanceConfig = z.infer<typeof InstanceConfigSchema>;

export interface RoleSelector {
  detectRole: (projectRoot: string) => Promise<KallaxResult<RoleConfig>>;
  setRole: (projectRoot: string, role: InstanceRole) => Promise<KallaxResult<void>>;
  getRoleFromEnv: () => KallaxResult<InstanceRole | null>;
  getRoleFromFile: (projectRoot: string) => Promise<KallaxResult<InstanceRole | null>>;
}

export function createRoleSelector(): RoleSelector {
  const CONFIG_FILE = '.kallax/state/instance_config.yml';

  async function readYamlConfig(filePath: string): Promise<KallaxResult<InstanceConfig | null>> {
    try {
      const content = await fs.readFile(filePath, 'utf-8');

      // Simple YAML parsing for our limited use case
      const lines = content.split('\n');
      const config: Record<string, unknown> = {};

      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.length === 0 || trimmed.startsWith('#')) continue;

        const colonIndex = trimmed.indexOf(':');
        if (colonIndex === -1) continue;

        const key = trimmed.slice(0, colonIndex).trim();
        let value: unknown = trimmed.slice(colonIndex + 1).trim();

        // Parse value
        if (value === 'true') value = true;
        else if (value === 'false') value = false;
        else if (/^\d+$/.test(value as string)) value = parseInt(value as string, 10);

        config[key] = value;
      }

      const result = InstanceConfigSchema.safeParse(config);
      if (!result.success) {
        return ok(null);
      }

      return ok(result.data);
    } catch (error: unknown) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
        return ok(null);
      }
      return err(
        new KallaxError(KallaxErrorCode.FILE_NOT_FOUND, 'Failed to read config file', { cause: error })
      );
    }
  }

  async function writeYamlConfig(filePath: string, config: InstanceConfig): Promise<KallaxResult<void>> {
    const dir = path.dirname(filePath);

    try {
      await fs.mkdir(dir, { recursive: true });

      const content = [
        '# KALLAX Instance Configuration',
        `# Generated at: ${new Date().toISOString()}`,
        '',
        `role: ${config.role}`,
        `configuredAt: ${config.configuredAt ?? Date.now()}`,
      ].join('\n');

      await fs.writeFile(filePath, content, 'utf-8');
      return ok(undefined);
    } catch (error: unknown) {
      return err(
        new KallaxError(KallaxErrorCode.INTERNAL_ERROR, 'Failed to write config file', { cause: error })
      );
    }
  }

  return {
    async detectRole(projectRoot): Promise<KallaxResult<RoleConfig>> {
      // 1. Check environment variable first
      const envResult = this.getRoleFromEnv();
      if (envResult.isOk() && envResult.value !== null) {
        logger.info({ role: envResult.value, source: 'env' }, 'role detected from environment');
        return ok({
          role: envResult.value,
          configuredAt: Date.now(),
          configSource: 'env',
        });
      }

      // 2. Check config file
      const fileResult = await this.getRoleFromFile(projectRoot);
      if (fileResult.isOk() && fileResult.value !== null) {
        logger.info({ role: fileResult.value, source: 'file' }, 'role detected from config file');
        return ok({
          role: fileResult.value,
          configuredAt: Date.now(),
          configSource: 'file',
        });
      }

      // 3. Auto-detect based on presence of other instances
      // For now, default to performer if no other indicators
      logger.info({ role: InstanceRoleEnum.PERFORMER, source: 'auto' }, 'role auto-detected');
      return ok({
        role: InstanceRoleEnum.PERFORMER,
        configuredAt: Date.now(),
        configSource: 'auto',
      });
    },

    async setRole(projectRoot, role): Promise<KallaxResult<void>> {
      const configPath = path.join(projectRoot, CONFIG_FILE);
      const config: InstanceConfig = {
        role,
        configuredAt: Date.now(),
      };

      const result = await writeYamlConfig(configPath, config);
      if (result.isOk()) {
        logger.info({ role, configPath }, 'role configured');
      }
      return result;
    },

    getRoleFromEnv(): KallaxResult<InstanceRole | null> {
      const envRole = process.env['KALLAX_ROLE'];
      if (envRole === undefined || envRole === '') {
        return ok(null);
      }

      const normalized = envRole.toLowerCase();
      if (normalized === 'conductor') {
        return ok(InstanceRoleEnum.CONDUCTOR);
      }
      if (normalized === 'performer') {
        return ok(InstanceRoleEnum.PERFORMER);
      }

      return err(
        new KallaxError(KallaxErrorCode.CONFIG_INVALID, `Invalid KALLAX_ROLE: ${envRole}`, {
          metadata: { validRoles: ['conductor', 'performer'] },
        })
      );
    },

    async getRoleFromFile(projectRoot): Promise<KallaxResult<InstanceRole | null>> {
      const configPath = path.join(projectRoot, CONFIG_FILE);
      const configResult = await readYamlConfig(configPath);

      if (configResult.isErr()) {
        return err(configResult.error);
      }

      if (configResult.value === null) {
        return ok(null);
      }

      return ok(configResult.value.role);
    },
  };
}
