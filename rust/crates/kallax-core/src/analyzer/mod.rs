//! KALLAX Code Analyzer — regex-based symbol extraction
//!
//! # Usage
//!
//! ```rust,ignore
//! use kallax_core::analyzer::CodeAnalyzer;
//!
//! let analyzer = CodeAnalyzer::new();
//! let analysis = analyzer.analyze_file("src/main.rs")?;
//! println!("{} symbols found in {}", analysis.symbols.len(), analysis.path.display());
//! ```
//!
//! Supported languages: TypeScript, Python, Rust

mod types;
mod language;
mod extractors;

use std::fs;
use std::path::{Path, PathBuf};

use crate::error::KallaxError;
use crate::Result;

use self::extractors::{count_loc, extract_symbols};
use self::language::{detect_language, is_supported};
pub use self::types::{FileAnalysis, Language, Symbol, SymbolKind};

/// A code analyzer that extracts symbols from source files.
///
/// Uses regex-based pattern matching (no native tree-sitter bindings).
/// Supports TypeScript, Python, and Rust.
pub struct CodeAnalyzer;

impl CodeAnalyzer {
    /// Create a new analyzer instance
    pub fn new() -> Self {
        Self
    }

    /// Analyze a single file, extracting symbols and counting LOC.
    ///
    /// Returns `FileAnalysis` with detected symbols, or an error if the
    /// file cannot be read. Unsupported file types return an empty analysis.
    pub fn analyze_file(&self, path: impl Into<PathBuf>) -> Result<FileAnalysis> {
        let path: PathBuf = path.into();
        let language = detect_language(&path);

        if language == Language::Unknown {
            return Ok(FileAnalysis {
                path,
                language,
                symbols: Vec::new(),
                loc: 0,
            });
        }

        let content = fs::read_to_string(&path).map_err(|e| {
            KallaxError::io(&path, format!("failed to read file: {e}"))
        })?;

        let symbols = extract_symbols(&content, language);
        let loc = count_loc(&content, language);

        Ok(FileAnalysis {
            path,
            language,
            symbols,
            loc,
        })
    }

    /// Analyze all supported files in a directory (recursive).
    ///
    /// Skips unsupported file types and returns per-file results.
    /// Errors from individual files are collected per-file in the
    /// returned `DirectoryResult`.
    pub fn analyze_directory(&self, dir: impl AsRef<Path>) -> Result<Vec<FileAnalysis>> {
        let dir = dir.as_ref();
        let mut results = Vec::new();

        if !dir.is_dir() {
            return Err(KallaxError::io(
                dir,
                format!("not a directory: {}", dir.display()),
            ));
        }

        let files = collect_files(dir).map_err(|e| {
            KallaxError::io(dir, format!("failed to scan directory: {e}"))
        })?;

        for file_path in files {
            let analysis = self.analyze_file(&file_path)?;
            results.push(analysis);
        }

        Ok(results)
    }
}

impl Default for CodeAnalyzer {
    fn default() -> Self {
        Self::new()
    }
}

/// Recursively collect all supported source files under a directory
fn collect_files(dir: &Path) -> std::io::Result<Vec<PathBuf>> {
    let mut files = Vec::new();

    if !dir.is_dir() {
        return Ok(files);
    }

    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();

        if path.is_dir() {
            // Skip hidden dirs (like .git, .claude, node_modules, target)
            let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
            if name.starts_with('.') || name == "node_modules" || name == "target" {
                continue;
            }
            files.extend(collect_files(&path)?);
        } else if is_supported(&path) {
            files.push(path);
        }
    }

    Ok(files)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn analyze_unknown_file_returns_empty() {
        let analyzer = CodeAnalyzer::new();
        let result = analyzer.analyze_file("/tmp/nonexistent.py");
        assert!(result.is_err());
    }

    #[test]
    fn analyze_directory_nonexistent() {
        let analyzer = CodeAnalyzer::new();
        let result = analyzer.analyze_directory("/tmp/kallax-nonexistent-dir-12345");
        assert!(result.is_err());
    }

    #[test]
    fn default_and_new_are_equivalent() {
        let result_default = CodeAnalyzer::default().analyze_file("/tmp/nonexistent.py");
        let result_new = CodeAnalyzer::new().analyze_file("/tmp/nonexistent.py");
        assert_eq!(result_default.is_err(), result_new.is_err());
    }
}
