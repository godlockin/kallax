//! Language detection — maps file extensions to Language enum
//!
//! Supported languages: TypeScript (.ts, .tsx, .js, .jsx),
//! Python (.py), Rust (.rs)

use super::types::Language;
use std::path::Path;

/// Detect language from file path based on extension.
/// Returns `Language::Unknown` for unsupported extensions.
pub fn detect_language(path: &Path) -> Language {
    match path.extension().and_then(|e| e.to_str()) {
        Some("ts") | Some("tsx") | Some("js") | Some("jsx") => Language::TypeScript,
        Some("py") => Language::Python,
        Some("rs") => Language::Rust,
        _ => Language::Unknown,
    }
}

/// Returns true if the file extension is supported by the analyzer
pub fn is_supported(path: &Path) -> bool {
    detect_language(path) != Language::Unknown
}

/// Returns the file extensions associated with each language
#[allow(dead_code)]
pub fn language_extensions(language: Language) -> &'static [&'static str] {
    match language {
        Language::TypeScript => &["ts", "tsx", "js", "jsx"],
        Language::Python => &["py"],
        Language::Rust => &["rs"],
        Language::Unknown => &[],
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn detect_typescript() {
        assert_eq!(
            detect_language(&PathBuf::from("main.ts")),
            Language::TypeScript
        );
        assert_eq!(
            detect_language(&PathBuf::from("component.tsx")),
            Language::TypeScript
        );
        assert_eq!(
            detect_language(&PathBuf::from("util.js")),
            Language::TypeScript
        );
    }

    #[test]
    fn detect_python() {
        assert_eq!(detect_language(&PathBuf::from("main.py")), Language::Python);
        assert_eq!(
            detect_language(&PathBuf::from("tests/test_foo.py")),
            Language::Python
        );
    }

    #[test]
    fn detect_rust() {
        assert_eq!(detect_language(&PathBuf::from("lib.rs")), Language::Rust);
        assert_eq!(
            detect_language(&PathBuf::from("src/main.rs")),
            Language::Rust
        );
    }

    #[test]
    fn detect_unknown() {
        assert_eq!(
            detect_language(&PathBuf::from("readme.md")),
            Language::Unknown
        );
        assert_eq!(
            detect_language(&PathBuf::from("Makefile")),
            Language::Unknown
        );
        assert_eq!(
            detect_language(&PathBuf::from("data.json")),
            Language::Unknown
        );
    }

    #[test]
    fn is_supported_returns_true_for_known() {
        assert!(is_supported(&PathBuf::from("main.rs")));
        assert!(is_supported(&PathBuf::from("main.py")));
        assert!(is_supported(&PathBuf::from("main.ts")));
    }

    #[test]
    fn is_supported_returns_false_for_unknown() {
        assert!(!is_supported(&PathBuf::from("readme.md")));
        assert!(!is_supported(&PathBuf::from("data.csv")));
    }
}
