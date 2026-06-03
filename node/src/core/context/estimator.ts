/**
 * KALLAX Context Estimator — token counting for context window management.
 *
 * Strategy: character-based estimation with content-type-specific ratios.
 * Text: 4 chars/token, Code: 3.5 chars/token, JSON: 3 chars/token.
 */

import type { KallaxResult } from '../../types/index.js';
import { logger } from '../../utils/logger.js';

export interface TokenEstimate {
  readonly totalTokens: number;
  readonly textTokens: number;
  readonly codeTokens: number;
  readonly jsonTokens: number;
  readonly charCount: number;
  readonly breakdown: Array<{ source: string; tokens: number; chars: number }>;
}

export interface FileTokenInfo {
  readonly path: string;
  readonly tokens: number;
  readonly chars: number;
  readonly type: 'text' | 'code' | 'json';
}

export interface ContextEstimator {
  estimateText: (text: string) => number;
  estimateCode: (code: string) => number;
  estimateJson: (json: string) => number;
  estimateFile: (content: string, path: string) => FileTokenInfo;
  estimateTotal: (files: Array<{ content: string; path: string }>) => TokenEstimate;
  setRatios: (text: number, code: number, json: number) => void;
}

const DEFAULT_RATIOS = {
  text: 4.0,
  code: 3.5,
  json: 3.0,
};

function classifyFile(path: string): 'text' | 'code' | 'json' {
  const ext = path.split('.').pop()?.toLowerCase() ?? '';
  const codeExts = new Set([
    'ts', 'tsx', 'js', 'jsx', 'rs', 'go', 'py', 'java', 'c', 'cpp', 'h',
    'rb', 'swift', 'kt', 'scala', 'sh', 'bash', 'zsh', 'sql', 'graphql',
    'vue', 'svelte', 'css', 'scss', 'less', 'html', 'xml',
  ]);
  const jsonExts = new Set(['json', 'yaml', 'yml', 'toml']);

  if (jsonExts.has(ext)) return 'json';
  if (codeExts.has(ext)) return 'code';
  return 'text';
}

export function createContextEstimator(): ContextEstimator {
  let ratios = { ...DEFAULT_RATIOS };

  return {
    estimateText(text: string): number {
      return Math.ceil(text.length / ratios.text);
    },

    estimateCode(code: string): number {
      return Math.ceil(code.length / ratios.code);
    },

    estimateJson(json: string): number {
      return Math.ceil(json.length / ratios.json);
    },

    estimateFile(content: string, path: string): FileTokenInfo {
      const type = classifyFile(path);
      let tokens: number;
      switch (type) {
        case 'code':
          tokens = Math.ceil(content.length / ratios.code);
          break;
        case 'json':
          tokens = Math.ceil(content.length / ratios.json);
          break;
        default:
          tokens = Math.ceil(content.length / ratios.text);
      }
      return { path, tokens, chars: content.length, type };
    },

    estimateTotal(files: Array<{ content: string; path: string }>): TokenEstimate {
      let totalTokens = 0;
      let textTokens = 0;
      let codeTokens = 0;
      let jsonTokens = 0;
      let charCount = 0;
      const breakdown: Array<{ source: string; tokens: number; chars: number }> = [];

      for (const file of files) {
        const info = this.estimateFile(file.content, file.path);
        totalTokens += info.tokens;
        charCount += info.chars;
        switch (info.type) {
          case 'text': textTokens += info.tokens; break;
          case 'code': codeTokens += info.tokens; break;
          case 'json': jsonTokens += info.tokens; break;
        }
        breakdown.push({ source: info.path, tokens: info.tokens, chars: info.chars });
      }

      return { totalTokens, textTokens, codeTokens, jsonTokens, charCount, breakdown };
    },

    setRatios(text: number, code: number, json: number): void {
      ratios = { text, code, json };
      logger.info({ text, code, json }, 'token estimation ratios updated');
    },
  };
}

// Default singleton
let defaultEstimator: ContextEstimator | null = null;

export function getContextEstimator(): ContextEstimator {
  if (defaultEstimator === null) {
    defaultEstimator = createContextEstimator();
  }
  return defaultEstimator;
}
