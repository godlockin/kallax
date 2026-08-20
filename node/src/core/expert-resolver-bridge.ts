/**
 * EPIC-277: Bridge to scripts/expert-resolver.sh
 *
 * KALLAX Gate Reviewer
 * 5 levels gate review for PRs and task completion.
 *
 * v2.0.3 EPIC-056-A: 3 阶段治理协调器 (Conductor 全局 → 4+5 专家并行 → Master 仲裁 + 主公拍板)
 * 跟 5 levels 共存 — 5 levels 用于 PR 评审, 3 阶段用于 EPIC/expert 评审
 */
import { existsSync } from 'node:fs';
import * as path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { z } from 'zod';
import { logger } from '../utils/logger.js';

const execFileP = promisify(execFile);

export const ExpertRowSchema = z.object({
  role_id: z.string().min(1),
  name: z.string(),
  source: z.string(),
  path: z.string(),
  // 下面 7 字段 shell 端可能为空, 允许空串
  vibe: z.string().optional().default(''),
  tools: z.string().optional().default(''),
  priority: z.string().optional().default(''),
  use_when_zh: z.string().optional().default(''),
  use_when_en: z.string().optional().default(''),
  triggers: z.string().optional().default(''),
});
export type ExpertRow = z.infer<typeof ExpertRowSchema>;

const ListResponseSchema = z.array(ExpertRowSchema);
const PathResponseSchema = z.object({ path: z.string() });

const RESOLVER_DEFAULT_TIMEOUT_MS = 10_000;

export interface ExpertResolverOptions {
  /** repo root, 用于定位 scripts/expert-resolver.sh */
  repoRoot: string;
  /** 子进程超时, 默认 10s */
  timeoutMs?: number;
}

export class ExpertResolverBridge {
  private readonly resolverPath: string;
  private readonly timeoutMs: number;

  constructor(opts: ExpertResolverOptions) {
    this.resolverPath = `${opts.repoRoot}/scripts/expert-resolver.sh`;
    this.timeoutMs = opts.timeoutMs ?? RESOLVER_DEFAULT_TIMEOUT_MS;
    if (!existsSync(this.resolverPath)) {
      throw new Error(`expert-resolver.sh not found: ${this.resolverPath}`);
    }
  }

  /** 精确查: 派单主用. 返回 {path} 或 null (角色不存在 / 解析失败). */
  async path(roleId: string): Promise<{ path: string } | null> {
    try {
      const { stdout } = await execFileP(
        'bash',
        [this.resolverPath, 'path', roleId, '--json'],
        { cwd: path.dirname(this.resolverPath), timeout: this.timeoutMs },
      );
      const parsed = PathResponseSchema.safeParse(JSON.parse(stdout));
      if (!parsed.success) {
        logger.warn({ roleId, stdout, error: parsed.error.message }, 'path output invalid');
        return null;
      }
      return { path: parsed.data.path };
    } catch {
      // exit 非 0 (角色不存在) 走这里, 视为正常 null
      return null;
    }
  }

  /** 关键词搜: 子串匹配, 有边界缺陷, 仅作 fallback. */
  async find(query: string): Promise<ExpertRow[]> {
    try {
      const { stdout } = await execFileP(
        'bash',
        [this.resolverPath, 'find', query, '--json'],
        { cwd: path.dirname(this.resolverPath), timeout: this.timeoutMs },
      );
      const parsed = ListResponseSchema.safeParse(JSON.parse(stdout));
      if (!parsed.success) {
        logger.warn({ query, error: parsed.error.message }, 'find output invalid');
        return [];
      }
      return parsed.data;
    } catch {
      return [];
    }
  }

  /** 派单用: 先 path 精确查, 失败才用 find 兜底. 仍失败返回 null. */
  async resolve(roleIdOrQuery: string): Promise<{ roleId: string; path: string } | null> {
    const hit = await this.path(roleIdOrQuery);
    if (hit !== null) {
      return { roleId: roleIdOrQuery, path: hit.path };
    }
    // fallback: find
    const candidates = await this.find(roleIdOrQuery);
    const candidate = candidates[0];
    if (candidate !== undefined && candidates.length === 1) {
      // 唯一命中, 直接采信
      return { roleId: candidate.role_id, path: candidate.path };
    }
    if (candidates.length > 1) {
      // 多个匹配, 不消歧则放弃 (派单派错比不派更糟)
      logger.warn({ roleIdOrQuery, hits: candidates.length }, 'find returned multiple, refusing to dispatch');
      return null;
    }
    return null;
  }
}
