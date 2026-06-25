/**
 * Frontmatter extraction and parsing utilities for KALLAX persona .md files.
 *
 * The persona .md files use a YAML-like frontmatter block delimited by `---`
 * markers, followed by a markdown body. The block uses simple key:value
 * scalars, `|` multi-line blocks, and inline `[a, b, c]` arrays.
 *
 * js-yaml is intentionally NOT used here because the persona frontmatter is
 * a strict, well-known subset that we control, and we want zero new
 * dependencies on the schema surface.
 */

export interface ExtractedMarkdown {
  readonly fmBlock: string;
  readonly body: string;
}

const FRONTMATTER_DELIMITER = '---';

export const extractFrontmatter = (content: string): ExtractedMarkdown => {
  const lines = content.split('\n');
  let delimiters = 0;
  let fmEnd = -1;
  for (let i = 0; i < lines.length; i += 1) {
    if (lines[i] === FRONTMATTER_DELIMITER) {
      delimiters += 1;
      if (delimiters === 2) {
        fmEnd = i;
        break;
      }
    }
  }
  if (delimiters < 2 || fmEnd === -1) {
    return { fmBlock: '', body: content };
  }
  return {
    fmBlock: lines.slice(1, fmEnd).join('\n'),
    body: lines.slice(fmEnd + 1).join('\n'),
  };
};

export const parseFrontmatter = (fmBlock: string): Readonly<Record<string, unknown>> => {
  const out: Record<string, unknown> = {};
  const lines = fmBlock.split('\n');
  let currentKey: string | null = null;
  let buffer: string[] = [];
  let indent = -1;

  const flush = (): void => {
    if (currentKey !== null) {
      out[currentKey] = buffer.join('\n');
      currentKey = null;
      buffer = [];
      indent = -1;
    }
  };

  for (const raw of lines) {
    if (raw.trim() === '') continue;
    const match = /^([a-zA-Z_][a-zA-Z0-9_]*):\s*(.*)$/.exec(raw);
    if (match && match[1] !== undefined && match[2] !== undefined) {
      flush();
      const key = match[1];
      const value = match[2];
      if (value === '|') {
        currentKey = key;
        buffer = [];
        indent = -1;
      } else if (value.startsWith('[') && value.endsWith(']')) {
        const inner = value.slice(1, -1).trim();
        out[key] = inner.length === 0 ? [] : inner.split(',').map((s) => s.trim());
      } else if (/^-?\d+(\.\d+)?$/.test(value)) {
        out[key] = Number(value);
      } else {
        out[key] = value.replace(/^["']|["']$/g, '');
      }
      continue;
    }
    if (currentKey !== null) {
      const cur = raw.match(/^ */)?.[0].length ?? 0;
      if (indent === -1) indent = cur;
      if (cur >= indent) buffer.push(raw.slice(indent));
    }
  }
  flush();
  return out;
};

export interface SectionSlice {
  readonly name: string;
  readonly body: string;
}

export const sliceSection = (body: string, headerPattern: RegExp): string | null => {
  const lines = body.split('\n');
  let inSection = false;
  const out: string[] = [];
  for (const line of lines) {
    if (headerPattern.test(line)) {
      if (inSection) break;
      inSection = true;
      continue;
    }
    if (inSection && /^## [A-Z]/.test(line)) break;
    if (inSection) out.push(line);
  }
  return inSection ? out.join('\n') : null;
};