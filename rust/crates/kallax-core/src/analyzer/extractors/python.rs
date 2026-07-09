//! Python symbol extractor using regex
//!
//! Patterns: `def name`, `class Name`

use super::super::types::{Symbol, SymbolKind};
use regex::Regex;
use std::sync::OnceLock;

// EPIC-091 P1-5: OnceLock compile regex once
fn func_re() -> &'static Regex {
    static R: OnceLock<Regex> = OnceLock::new();
    R.get_or_init(|| Regex::new(r"(?:async\s+)?def\s+(\w+)").expect("valid regex"))
}
fn class_re() -> &'static Regex {
    static R: OnceLock<Regex> = OnceLock::new();
    R.get_or_init(|| Regex::new(r"class\s+(\w+)").expect("valid regex"))
}

/// Extract symbols from Python source code
pub fn extract(content: &str) -> Vec<Symbol> {
    let func_re = func_re();
    let class_re = class_re();

    let mut symbols = Vec::new();

    for (i, line) in content.lines().enumerate() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }

        if let Some(caps) = func_re.captures(trimmed) {
            symbols.push(Symbol {
                name: caps.get(1).unwrap().as_str().to_string(),
                kind: SymbolKind::Function,
                line: i + 1,
            });
        } else if let Some(caps) = class_re.captures(trimmed) {
            symbols.push(Symbol {
                name: caps.get(1).unwrap().as_str().to_string(),
                kind: SymbolKind::Class,
                line: i + 1,
            });
        }
    }

    symbols
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_functions() {
        let code = "def foo():\n    pass\ndef bar():\n    pass";
        let syms = extract(code);
        assert_eq!(syms.len(), 2);
        assert_eq!(syms[0].name, "foo");
        assert_eq!(syms[1].name, "bar");
    }

    #[test]
    fn extract_async_functions() {
        let code = "async def fetch_data():\n    pass";
        let syms = extract(code);
        assert_eq!(syms.len(), 1);
        assert_eq!(syms[0].name, "fetch_data");
    }

    #[test]
    fn extract_classes() {
        let code = "class MyClass:\n    pass";
        let syms = extract(code);
        assert_eq!(syms.len(), 1);
        assert_eq!(syms[0].kind, SymbolKind::Class);
    }

    #[test]
    fn skip_comments() {
        let code = "# def commented():\n# class Hidden:\ndef real():\n    pass";
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
