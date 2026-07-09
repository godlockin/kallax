//! Rust symbol extractor using regex
//!
//! Patterns: `fn name`, `struct Name`, `impl Name`, `trait Name`

use super::super::types::{Symbol, SymbolKind};
use regex::Regex;
use std::sync::OnceLock;

// EPIC-091 P1-5: OnceLock compile regex once
fn fn_re() -> &'static Regex {
    static R: OnceLock<Regex> = OnceLock::new();
    R.get_or_init(|| Regex::new(r"(?:pub\s+)?(?:unsafe\s+)?fn\s+(\w+)").expect("valid regex"))
}
fn struct_re() -> &'static Regex {
    static R: OnceLock<Regex> = OnceLock::new();
    R.get_or_init(|| Regex::new(r"(?:pub\s+)?struct\s+(\w+)").expect("valid regex"))
}
fn impl_re() -> &'static Regex {
    static R: OnceLock<Regex> = OnceLock::new();
    R.get_or_init(|| Regex::new(r"(?:pub\s+)?(?:unsafe\s+)?impl\s+(\w+)").expect("valid regex"))
}
fn trait_re() -> &'static Regex {
    static R: OnceLock<Regex> = OnceLock::new();
    R.get_or_init(|| Regex::new(r"(?:pub\s+)?(?:unsafe\s+)?trait\s+(\w+)").expect("valid regex"))
}
fn enum_re() -> &'static Regex {
    static R: OnceLock<Regex> = OnceLock::new();
    R.get_or_init(|| Regex::new(r"(?:pub\s+)?enum\s+(\w+)").expect("valid regex"))
}

/// Extract symbols from Rust source code
pub fn extract(content: &str) -> Vec<Symbol> {
    let fn_re = fn_re();
    let struct_re = struct_re();
    let impl_re = impl_re();
    let trait_re = trait_re();
    let enum_re = enum_re();

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

        // Skip doc comments and line comments
        if trimmed.starts_with("///") || trimmed.starts_with("//!") || trimmed.starts_with("//") {
            continue;
        }

        // Try each pattern in priority order
        // EPIC-091 P1-5: unwrap 改 if let (regex 捕获 group 1 一定存在, 但 .unwrap 仍 panic 风险)
        let kind = if let Some(caps) = fn_re.captures(trimmed) {
            caps.get(1).map(|m| (m.as_str().to_string(), SymbolKind::Function))
        } else if let Some(caps) = struct_re.captures(trimmed) {
            caps.get(1).map(|m| (m.as_str().to_string(), SymbolKind::Class))
        } else if let Some(caps) = impl_re.captures(trimmed) {
            caps.get(1).map(|m| (m.as_str().to_string(), SymbolKind::Method))
        } else if let Some(caps) = trait_re.captures(trimmed) {
            caps.get(1).map(|m| (m.as_str().to_string(), SymbolKind::Interface))
        } else if let Some(caps) = enum_re.captures(trimmed) {
            caps.get(1).map(|m| (m.as_str().to_string(), SymbolKind::Class))
        } else {
            None
        };

        if let Some((name, kind)) = kind {
            symbols.push(Symbol { name, kind, line: i + 1 });
        }
    }

    symbols
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_functions() {
        let code = "fn foo() {}\npub fn bar() {}";
        let syms = extract(code);
        assert_eq!(syms.len(), 2);
        assert_eq!(syms[0].name, "foo");
        assert_eq!(syms[1].name, "bar");
    }

    #[test]
    fn extract_structs() {
        let code = "struct Point { x: i32, y: i32 }\npub struct Config {}";
        let syms = extract(code);
        assert_eq!(syms.len(), 2);
        assert_eq!(syms[0].kind, SymbolKind::Class);
    }

    #[test]
    fn extract_impl() {
        let code = "impl MyStruct {}\npub unsafe impl Send for MyStruct {}";
        let syms = extract(code);
        assert_eq!(syms.len(), 2);
        assert_eq!(syms[0].kind, SymbolKind::Method);
    }

    #[test]
    fn extract_traits() {
        let code = "trait Runnable {}\npub trait Serialize {}";
        let syms = extract(code);
        assert_eq!(syms.len(), 2);
        assert_eq!(syms[0].kind, SymbolKind::Interface);
    }

    #[test]
    fn extract_enums() {
        let code = "enum Color { Red, Green, Blue }";
        let syms = extract(code);
        assert_eq!(syms.len(), 1);
        assert_eq!(syms[0].name, "Color");
    }

    #[test]
    fn skip_comments() {
        let code = "// fn hidden() {}\n/// doc comment\nfn visible() {}";
        let syms = extract(code);
        assert_eq!(syms.len(), 1);
        assert_eq!(syms[0].name, "visible");
    }

    #[test]
    fn skip_block_comments() {
        let code = "/*\nfn hidden() {}\n*/\nfn visible() {}";
        let syms = extract(code);
        assert_eq!(syms.len(), 1);
        assert_eq!(syms[0].name, "visible");
    }

    #[test]
    fn empty_content() {
        let syms = extract("");
        assert!(syms.is_empty());
    }
}
