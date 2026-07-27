//! Registry for object storage and lookup
//!
//! Thread-safe registry for managing named objects.

use dashmap::DashMap;
use std::sync::Arc;

use crate::{KallaxError, Result};

/// Thread-safe registry for named objects
pub struct Registry<T> {
    store: DashMap<String, Arc<T>>,
    type_name: &'static str,
}

impl<T> Registry<T> {
    /// Create a new registry
    pub fn new(type_name: &'static str) -> Self {
        Self {
            store: DashMap::new(),
            type_name,
        }
    }

    /// Register an object with a name
    pub fn register(&self, name: impl Into<String>, obj: T) -> Result<()> {
        let name = name.into();
        if self.store.contains_key(&name) {
            return Err(KallaxError::AlreadyExists {
                entity_type: self.type_name,
                entity_id: name,
            });
        }
        self.store.insert(name, Arc::new(obj));
        Ok(())
    }

    /// Register or replace an object
    pub fn register_or_replace(&self, name: impl Into<String>, obj: T) -> Option<Arc<T>> {
        self.store.insert(name.into(), Arc::new(obj))
    }

    /// Get an object by name
    pub fn get(&self, name: &str) -> Option<Arc<T>> {
        self.store.get(name).map(|r| Arc::clone(&r))
    }

    /// Get an object or return NotFound error
    pub fn get_or_err(&self, name: &str) -> Result<Arc<T>> {
        self.get(name).ok_or_else(|| KallaxError::NotFound {
            entity_type: self.type_name,
            entity_id: name.to_string(),
        })
    }

    /// Remove an object by name
    pub fn unregister(&self, name: &str) -> Option<Arc<T>> {
        self.store.remove(name).map(|(_, v)| v)
    }

    /// Check if name exists
    pub fn contains(&self, name: &str) -> bool {
        self.store.contains_key(name)
    }

    /// Get all names
    pub fn names(&self) -> Vec<String> {
        self.store.iter().map(|r| r.key().clone()).collect()
    }

    /// Get count
    pub fn len(&self) -> usize {
        self.store.len()
    }

    /// Check if empty
    pub fn is_empty(&self) -> bool {
        self.store.is_empty()
    }

    /// Clear all entries
    pub fn clear(&self) {
        self.store.clear();
    }

    /// Iterate over all entries
    pub fn iter(&self) -> impl Iterator<Item = (String, Arc<T>)> + '_ {
        self.store
            .iter()
            .map(|r| (r.key().clone(), Arc::clone(r.value())))
    }
}

impl<T> Default for Registry<T> {
    fn default() -> Self {
        Self::new("unknown")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn basic_operations() {
        let registry: Registry<String> = Registry::new("test");

        registry.register("key1", "value1".to_string()).unwrap();
        assert_eq!(*registry.get("key1").unwrap(), "value1");

        // Duplicate registration should fail
        let result = registry.register("key1", "value2".to_string());
        assert!(result.is_err());
    }

    #[test]
    fn get_or_err() {
        let registry: Registry<i32> = Registry::new("number");

        registry.register("one", 1).unwrap();

        assert_eq!(*registry.get_or_err("one").unwrap(), 1);

        let result = registry.get_or_err("two");
        assert!(matches!(result, Err(KallaxError::NotFound { .. })));
    }

    #[test]
    fn register_or_replace() {
        let registry: Registry<i32> = Registry::new("number");

        registry.register_or_replace("key", 1);
        assert_eq!(*registry.get("key").unwrap(), 1);

        let old = registry.register_or_replace("key", 2);
        assert_eq!(*old.unwrap(), 1);
        assert_eq!(*registry.get("key").unwrap(), 2);
    }
}
