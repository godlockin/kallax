//! Language-specific symbol extractors
//!
//! Each sub-module implements regex-based extraction for one language.
//! The `extract_symbols` function dispatches to the correct extractor.

mod typescript;
mod python;
mod rust;

use super::types::{Language, Symbol};

use self::typescript as ts_ext;
use self::python as py_ext;
use self::rust as rs_ext;

/// Dispatch to language-specific extractor
pub fn extract_symbols(content: &str, language: Language) -> Vec<Symbol> {
    match language {
        Language::TypeScript => ts_ext::extract(content),
        Language::Python => py_ext::extract(content),
        Language::Rust => rs_ext::extract(content),
        Language::Unknown => Vec::new(),
    }
}

/// Count approximate lines of code (non-empty, non-comment lines)
pub fn count_loc(content: &str, language: Language) -> usize {
    content
        .lines()
        .filter(|line| {
            let t = line.trim();
            if t.is_empty() {
                return false;
            }
            match language {
                Language::TypeScript | Language::Rust => {
                    !t.starts_with("//") && !t.starts_with("/*") && !t.starts_with("///") && !t.starts_with("//!")
                }
                Language::Python => !t.starts_with('#'),
                Language::Unknown => true,
            }
        })
        .count()
}

// Re-export individual extractors for direct use
// Re-export individual extractors for direct use (suppress dead_code: available for library consumers)
#[allow(unused_imports)]
pub use self::typescript::extract as extract_ts;
#[allow(unused_imports)]
pub use self::python::extract as extract_py;
#[allow(unused_imports)]
pub use self::rust::extract as extract_rs;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dispatch_to_typescript() {
        let code = "function foo() {}";
        let syms = extract_symbols(code, Language::TypeScript);
        assert_eq!(syms.len(), 1);
        assert_eq!(syms[0].name, "foo");
    }

    #[test]
    fn dispatch_to_python() {
        let code = "def bar(): pass";
        let syms = extract_symbols(code, Language::Python);
        assert_eq!(syms.len(), 1);
        assert_eq!(syms[0].name, "bar");
    }

    #[test]
    fn dispatch_to_rust() {
        let code = "fn baz() {}";
        let syms = extract_symbols(code, Language::Rust);
        assert_eq!(syms.len(), 1);
        assert_eq!(syms[0].name, "baz");
    }

    #[test]
    fn dispatch_unknown_returns_empty() {
        let syms = extract_symbols("some text", Language::Unknown);
        assert!(syms.is_empty());
    }

    #[test]
    fn loc_counts_non_empty_lines() {
        let code = "fn a() {}\n\nfn b() {}\n// comment\nfn c() {}";
        let loc = count_loc(code, Language::Rust);
        // Lines: fn a() {} (1), empty (0), fn b() {} (1), // comment (0), fn c() {} (1) = 3
        assert_eq!(loc, 3);
    }

    #[test]
    fn loc_empty_content() {
        assert_eq!(count_loc("", Language::Rust), 0);
    }
}
