//! TypeScript/JavaScript symbol extractor using regex
//!
//! Patterns: `function name`, `class Name`, `interface Name`, `method(`

use super::super::types::{Symbol, SymbolKind};
use regex::Regex;

/// Extract symbols from TypeScript/JavaScript source code
pub fn extract(content: &str) -> Vec<Symbol> {
    let func_re = Regex::new(r"(?:export\s+)?(?:async\s+)?function\s+(\w+)").unwrap();
    let class_re = Regex::new(r"(?:export\s+)?(?:abstract\s+)?class\s+(\w+)").unwrap();
    let iface_re = Regex::new(r"(?:export\s+)?interface\s+(\w+)").unwrap();

    let mut symbols = Vec::new();
    let mut in_block_comment = false;

    for (i, line) in content.lines().enumerate() {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        // Track multi-line comments
        if in_block_comment {
            if trimmed.contains("*/") {
                in_block_comment = false;
            }
            continue;
        }
        if trimmed.starts_with("/*") && !trimmed.contains("*/") {
            in_block_comment = true;
            continue;
        }

        // Skip single-line comments (detect // before pattern)
        if let Some(comment_pos) = trimmed.find("//") {
            let code = &trimmed[..comment_pos];
            if code.is_empty() {
                continue;
            }
            if let Some(sym) = try_match(code, &func_re, &class_re, &iface_re, i + 1) {
                symbols.push(sym);
            }
        } else {
            if let Some(sym) = try_match(trimmed, &func_re, &class_re, &iface_re, i + 1) {
                symbols.push(sym);
            }
        }
    }

    symbols
}

fn try_match(
    s: &str,
    func_re: &Regex,
    class_re: &Regex,
    iface_re: &Regex,
    line: usize,
) -> Option<Symbol> {
    if let Some(caps) = func_re.captures(s) {
        return Some(Symbol {
            name: caps.get(1).unwrap().as_str().to_string(),
            kind: SymbolKind::Function,
            line,
        });
    }
    if let Some(caps) = class_re.captures(s) {
        return Some(Symbol {
            name: caps.get(1).unwrap().as_str().to_string(),
            kind: SymbolKind::Class,
            line,
        });
    }
    if let Some(caps) = iface_re.captures(s) {
        return Some(Symbol {
            name: caps.get(1).unwrap().as_str().to_string(),
            kind: SymbolKind::Interface,
            line,
        });
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_functions() {
        let code = "function foo() {}\nfunction bar() {}";
        let syms = extract(code);
        assert_eq!(syms.len(), 2);
        assert_eq!(syms[0].name, "foo");
        assert_eq!(syms[1].name, "bar");
    }

    #[test]
    fn extract_classes() {
        let code = "class MyClass {}\nexport class PublicClass {}";
        let syms = extract(code);
        assert_eq!(syms.len(), 2);
        assert_eq!(syms[0].name, "MyClass");
        assert_eq!(syms[1].name, "PublicClass");
    }

    #[test]
    fn extract_interfaces() {
        let code = "interface User {}\nexport interface Config {}";
        let syms = extract(code);
        assert_eq!(syms.len(), 2);
    }

    #[test]
    fn skip_comments() {
        let code = "// function commented() {}\nfunction real() {}";
        let syms = extract(code);
        assert_eq!(syms.len(), 1);
        assert_eq!(syms[0].name, "real");
    }

    #[test]
    fn empty_content() {
        let syms = extract("");
        assert!(syms.is_empty());
    }
}
