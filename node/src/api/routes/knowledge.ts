/**
 * KALLAX Knowledge Routes
 * Knowledge base search, indexing, and statistics
 */

import { Router } from 'express';
import type { Request, Response } from 'express';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { KallaxError } from '../../types/index.js';
import { logger } from '../../utils/logger.js';
import {
  createSuccessResponse,
  createErrorResponse,
} from '../types.js';

const execFileAsync = promisify(execFile);

const DEFAULT_KNOWLEDGE_PATH = path.join(
  process.env['HOME'] ?? '/tmp',
  '.claude',
  'knowledge'
);

export interface KnowledgeRouteDependencies {
  readonly knowledgeBasePath?: string;
}

interface KnowledgeSearchResult {
  readonly file: string;
  readonly line: number;
  readonly content: string;
  readonly matchCount: number;
}

interface KnowledgeStats {
  readonly totalFiles: number;
  readonly totalSizeBytes: number;
  readonly topDirectories: readonly string[];
  readonly lastIndexed: number | null;
}

/**
 * Create knowledge routes with injected dependencies
 */
export function createKnowledgeRoutes(deps: KnowledgeRouteDependencies): Router {
  const knowledgePath = deps.knowledgeBasePath ?? DEFAULT_KNOWLEDGE_PATH;
  const router = Router();

  /**
   * Get all markdown files in the knowledge base
   */
  async function getKnowledgeFiles(dir: string): Promise<string[]> {
    const files: string[] = [];
    try {
      const entries = await fs.readdir(dir, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          const subFiles = await getKnowledgeFiles(fullPath);
          files.push(...subFiles);
        } else if (entry.isFile() && entry.name.endsWith('.md')) {
          files.push(fullPath);
        }
      }
    } catch {
      // Directory may not exist
    }
    return files;
  }

  // GET /api/knowledge/search?q= — search knowledge base
  router.get('/search', (req: Request, res: Response): void => {
    void (async (): Promise<void> => {
      try {
        const query = req.query['q'] as string | undefined;

        if (query === undefined || query.trim().length === 0) {
          res.status(400).json({
            success: false,
            error: { code: 'VALIDATION_ERROR', message: 'Search query q is required' },
            timestamp: Date.now(),
          });
          return;
        }

        // Check if knowledge directory exists
        let dirExists = false;
        try {
          await fs.access(knowledgePath);
          dirExists = true;
        } catch {
          // Directory doesn't exist
        }

        if (!dirExists) {
          res.json(createSuccessResponse({
            query,
            results: [],
            totalResults: 0,
            message: 'Knowledge base not found at ' + knowledgePath,
          }));
          return;
        }

        // Execute grep search
        const args = [
          '-r',
          '-n',
          '-i',
          '--include=*.md',
          '-l',
          query,
          knowledgePath,
        ];

        try {
          const { stdout } = await execFileAsync('grep', args);
          const matchedFiles = stdout.trim().split('\n').filter((f: string) => f.length > 0);

          // Get detailed results for first 20 files
          const results: KnowledgeSearchResult[] = [];
          const maxFiles = Math.min(matchedFiles.length, 20);

          for (let i = 0; i < maxFiles; i++) {
            const filePath = matchedFiles[i];
            if (filePath === undefined) continue;

            const countArgs = ['-c', '-i', query, filePath];
            const countResult = await execFileAsync('grep', countArgs);
            const countStr = countResult.stdout.trim();
            const matchCount = parseInt(countStr, 10) || 1;

            // Get first matching line
            const lineArgs = ['-n', '-i', '-m', '1', query, filePath];
            const lineResult = await execFileAsync('grep', lineArgs);
            const lineMatch = lineResult.stdout.trim();
            const colonIndex = lineMatch.indexOf(':');
            const lineNum = colonIndex > 0 ? parseInt(lineMatch.slice(0, colonIndex), 10) || 1 : 1;
            const content = colonIndex > 0 ? lineMatch.slice(colonIndex + 1) : lineMatch;

            const relativePath = path.relative(knowledgePath, filePath);

            results.push({
              file: relativePath,
              line: lineNum,
              content: content.slice(0, 200),
              matchCount,
            });
          }

          res.json(createSuccessResponse({
            query,
            results,
            totalResults: matchedFiles.length,
          }));
        } catch (grepError: unknown) {
          // grep returns exit code 1 when no matches
          const grepResult = grepError as { code?: number };
          if (grepResult.code === 1) {
            res.json(createSuccessResponse({
              query,
              results: [],
              totalResults: 0,
            }));
            return;
          }
          throw grepError;
        }
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'knowledge search failed');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // POST /api/knowledge/index — index a file/directory
  router.post('/index', (req: Request, res: Response): void => {
    void (async (): Promise<void> => {
      try {
        const body = req.body as Record<string, unknown>;
        const targetPath = body['path'] as string | undefined;

        if (targetPath === undefined || typeof targetPath !== 'string') {
          res.status(400).json({
            success: false,
            error: { code: 'VALIDATION_ERROR', message: 'path is required' },
            timestamp: Date.now(),
          });
          return;
        }

        // Resolve the path
        const resolvedPath = path.resolve(targetPath);

        // Verify it exists
        let stat;
        try {
          stat = await fs.stat(resolvedPath);
        } catch {
          res.status(404).json({
            success: false,
            error: { code: 'FILE_NOT_FOUND', message: `Path not found: ${resolvedPath}` },
            timestamp: Date.now(),
          });
          return;
        }

        let filesIndexed = 0;
        let totalSize = 0;

        if (stat.isDirectory()) {
          // Index all markdown files in directory
          const files = await getKnowledgeFiles(resolvedPath);
          filesIndexed = files.length;

          for (const file of files) {
            const fileStat = await fs.stat(file);
            totalSize += fileStat.size;
          }
        } else if (stat.isFile()) {
          filesIndexed = 1;
          totalSize = stat.size;
        }

        logger.info(
          { path: resolvedPath, filesIndexed, totalSize },
          'knowledge index completed'
        );

        res.json(createSuccessResponse({
          path: resolvedPath,
          filesIndexed,
          totalSizeBytes: totalSize,
          indexedAt: Date.now(),
        }));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'knowledge indexing failed');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  // GET /api/knowledge/stats — knowledge base stats
  router.get('/stats', (_req: Request, res: Response): void => {
    void (async (): Promise<void> => {
      try {
        let dirExists = false;
        try {
          await fs.access(knowledgePath);
          dirExists = true;
        } catch {
          // Directory doesn't exist
        }

        if (!dirExists) {
          res.json(createSuccessResponse({
            totalFiles: 0,
            totalSizeBytes: 0,
            topDirectories: [],
            lastIndexed: null,
          }));
          return;
        }

        const files = await getKnowledgeFiles(knowledgePath);
        let totalSize = 0;

        for (const file of files) {
          try {
            const stat = await fs.stat(file);
            totalSize += stat.size;
          } catch {
            // Skip files that can't be read
          }
        }

        // Get top-level directories
        const dirSet = new Set<string>();
        for (const file of files) {
          const relPath = path.relative(knowledgePath, file);
          const firstDir = relPath.split(path.sep)[0];
          if (firstDir !== undefined) {
            dirSet.add(firstDir);
          }
        }

        const stats: KnowledgeStats = {
          totalFiles: files.length,
          totalSizeBytes: totalSize,
          topDirectories: Array.from(dirSet).sort(),
          lastIndexed: Date.now(),
        };

        res.json(createSuccessResponse(stats));
      } catch (error: unknown) {
        const kallaxError = KallaxError.fromUnknown(error);
        logger.error({ error: kallaxError.message }, 'failed to get knowledge stats');
        res.status(500).json(createErrorResponse(kallaxError));
      }
    })();
  });

  return router;
}
