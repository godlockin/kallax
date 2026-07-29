//! Knowledge base with full-text search
//!
//! In-memory knowledge storage with simple FTS.

use dashmap::DashMap;
use kallax_core::{KallaxError, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;

/// A knowledge entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KnowledgeEntry {
    pub id: String,
    pub title: String,
    pub content: String,
    pub tags: Vec<String>,
    pub source: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

impl KnowledgeEntry {
    pub fn new(
        id: impl Into<String>,
        title: impl Into<String>,
        content: impl Into<String>,
    ) -> Self {
        Self {
            id: id.into(),
            title: title.into(),
            content: content.into(),
            tags: Vec::new(),
            source: String::new(),
            created_at: chrono::Utc::now(),
        }
    }

    pub fn with_tags(mut self, tags: Vec<String>) -> Self {
        self.tags = tags;
        self
    }

    pub fn with_source(mut self, source: impl Into<String>) -> Self {
        self.source = source.into();
        self
    }
}

/// Knowledge base with full-text search
pub struct KnowledgeBase {
    entries: DashMap<String, KnowledgeEntry>,
    /// Inverted index: word -> entry IDs
    word_index: DashMap<String, HashSet<String>>,
    /// Tag index: tag -> entry IDs
    tag_index: DashMap<String, HashSet<String>>,
}

impl KnowledgeBase {
    pub fn new() -> Self {
        Self {
            entries: DashMap::new(),
            word_index: DashMap::new(),
            tag_index: DashMap::new(),
        }
    }

    /// Add an entry to the knowledge base
    pub fn add(&self, entry: KnowledgeEntry) -> Result<()> {
        let id = entry.id.clone();

        if self.entries.contains_key(&id) {
            return Err(KallaxError::AlreadyExists {
                entity_type: "knowledge_entry",
                entity_id: id,
            });
        }

        // Index words from title and content
        let words = self.tokenize(&format!("{} {}", entry.title, entry.content));
        for word in words {
            self.word_index.entry(word).or_default().insert(id.clone());
        }

        // Index tags
        for tag in &entry.tags {
            self.tag_index
                .entry(tag.to_lowercase())
                .or_default()
                .insert(id.clone());
        }

        self.entries.insert(id, entry);
        Ok(())
    }

    /// Get an entry by ID
    pub fn get(&self, id: &str) -> Option<KnowledgeEntry> {
        self.entries.get(id).map(|e| e.clone())
    }

    /// Search by query string (simple full-text search)
    pub fn search(&self, query: &str) -> Vec<KnowledgeEntry> {
        let query_words = self.tokenize(query);

        if query_words.is_empty() {
            return Vec::new();
        }

        // Find entries matching all query words (AND search)
        let mut matching_ids: Option<HashSet<String>> = None;

        for word in query_words {
            let word_matches: HashSet<String> = self
                .word_index
                .get(&word)
                .map(|ids| ids.clone())
                .unwrap_or_default();

            matching_ids = Some(match matching_ids {
                Some(ids) => ids.intersection(&word_matches).cloned().collect(),
                None => word_matches,
            });
        }

        matching_ids
            .unwrap_or_default()
            .iter()
            .filter_map(|id| self.entries.get(id).map(|e| e.clone()))
            .collect()
    }

    /// Search by tag
    pub fn search_by_tag(&self, tag: &str) -> Vec<KnowledgeEntry> {
        self.tag_index
            .get(&tag.to_lowercase())
            .map(|ids| {
                ids.iter()
                    .filter_map(|id| self.entries.get(id).map(|e| e.clone()))
                    .collect()
            })
            .unwrap_or_default()
    }

    /// Remove an entry
    pub fn remove(&self, id: &str) -> Option<KnowledgeEntry> {
        if let Some((_, entry)) = self.entries.remove(id) {
            // Remove from word index
            let words = self.tokenize(&format!("{} {}", entry.title, entry.content));
            for word in words {
                if let Some(mut ids) = self.word_index.get_mut(&word) {
                    ids.remove(id);
                }
            }

            // Remove from tag index
            for tag in &entry.tags {
                if let Some(mut ids) = self.tag_index.get_mut(&tag.to_lowercase()) {
                    ids.remove(id);
                }
            }

            return Some(entry);
        }
        None
    }

    /// Get all entries
    pub fn all(&self) -> Vec<KnowledgeEntry> {
        self.entries.iter().map(|e| e.clone()).collect()
    }

    /// Get entry count
    pub fn len(&self) -> usize {
        self.entries.len()
    }

    /// Check if empty
    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// Tokenize text into searchable words
    fn tokenize(&self, text: &str) -> Vec<String> {
        text.to_lowercase()
            .split(|c: char| !c.is_alphanumeric())
            .filter(|s| s.len() >= 2) // Skip single chars
            .map(String::from)
            .collect()
    }
}

impl Default for KnowledgeBase {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_and_search() {
        let kb = KnowledgeBase::new();

        let entry = KnowledgeEntry::new(
            "1",
            "Rust Programming",
            "Rust is a systems programming language",
        )
        .with_tags(vec!["rust".to_string(), "programming".to_string()]);

        kb.add(entry).unwrap();

        let results = kb.search("rust programming");
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].title, "Rust Programming");
    }

    #[test]
    fn search_by_tag() {
        let kb = KnowledgeBase::new();

        let entry1 = KnowledgeEntry::new("1", "Rust Basics", "Basic Rust concepts")
            .with_tags(vec!["rust".to_string()]);
        let entry2 = KnowledgeEntry::new("2", "Python Basics", "Basic Python concepts")
            .with_tags(vec!["python".to_string()]);

        kb.add(entry1).unwrap();
        kb.add(entry2).unwrap();

        let results = kb.search_by_tag("rust");
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].title, "Rust Basics");
    }

    #[test]
    fn and_search() {
        let kb = KnowledgeBase::new();

        let entry1 = KnowledgeEntry::new("1", "Rust Systems", "Systems programming");
        let entry2 = KnowledgeEntry::new("2", "Rust Web", "Web development");

        kb.add(entry1).unwrap();
        kb.add(entry2).unwrap();

        let results = kb.search("rust systems");
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].title, "Rust Systems");
    }
}
