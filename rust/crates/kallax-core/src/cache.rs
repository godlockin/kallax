//! Cache implementation with TTL support
//!
//! Thread-safe cache using DashMap for concurrent access.

use dashmap::DashMap;
use std::hash::Hash;
use std::time::{Duration, Instant};

/// Cache entry with value and expiration
struct CacheEntry<V> {
    value: V,
    expires_at: Instant,
}

/// Thread-safe cache with TTL support
pub struct Cache<K, V>
where
    K: Eq + Hash + Clone,
    V: Clone,
{
    store: DashMap<K, CacheEntry<V>>,
    default_ttl: Duration,
}

impl<K, V> Cache<K, V>
where
    K: Eq + Hash + Clone,
    V: Clone,
{
    /// Create a new cache with default TTL
    pub fn new(default_ttl: Duration) -> Self {
        Self {
            store: DashMap::new(),
            default_ttl,
        }
    }

    /// Get a value from cache if it exists and hasn't expired
    pub fn get(&self, key: &K) -> Option<V> {
        let entry = self.store.get(key)?;
        if entry.expires_at > Instant::now() {
            Some(entry.value.clone())
        } else {
            // Entry expired, remove it
            drop(entry); // Release read lock before write
            self.store.remove(key);
            None
        }
    }

    /// Insert a value with default TTL
    pub fn insert(&self, key: K, value: V) {
        self.insert_with_ttl(key, value, self.default_ttl);
    }

    /// Insert a value with custom TTL
    pub fn insert_with_ttl(&self, key: K, value: V, ttl: Duration) {
        let entry = CacheEntry {
            value,
            expires_at: Instant::now() + ttl,
        };
        self.store.insert(key, entry);
    }

    /// Remove a value from cache
    pub fn remove(&self, key: &K) -> Option<V> {
        self.store.remove(key).map(|(_, e)| e.value)
    }

    /// Check if key exists and is not expired
    pub fn contains(&self, key: &K) -> bool {
        match self.store.get(key) {
            Some(entry) => entry.expires_at > Instant::now(),
            None => false,
        }
    }

    /// Get number of entries (including expired ones)
    pub fn len(&self) -> usize {
        self.store.len()
    }

    /// Check if cache is empty
    pub fn is_empty(&self) -> bool {
        self.store.is_empty()
    }

    /// Clear all entries
    pub fn clear(&self) {
        self.store.clear();
    }

    /// Remove expired entries (garbage collection)
    pub fn gc(&self) -> usize {
        let now = Instant::now();
        let mut removed = 0;

        // Collect keys to remove
        let expired_keys: Vec<K> = self
            .store
            .iter()
            .filter(|entry| entry.expires_at <= now)
            .map(|entry| entry.key().clone())
            .collect();

        // Remove expired entries
        for key in expired_keys {
            self.store.remove(&key);
            removed += 1;
        }

        removed
    }

    /// Get or insert a value using a fallback function
    pub fn get_or_insert_with<F>(&self, key: K, f: F) -> V
    where
        F: FnOnce() -> V,
    {
        if let Some(value) = self.get(&key) {
            return value;
        }

        let value = f();
        self.insert(key, value.clone());
        value
    }

    /// Get or insert a value using a fallible fallback function
    pub fn get_or_try_insert_with<F, E>(&self, key: K, f: F) -> Result<V, E>
    where
        F: FnOnce() -> Result<V, E>,
    {
        if let Some(value) = self.get(&key) {
            return Ok(value);
        }

        let value = f()?;
        self.insert(key, value.clone());
        Ok(value)
    }
}

impl<K, V> Default for Cache<K, V>
where
    K: Eq + Hash + Clone,
    V: Clone,
{
    fn default() -> Self {
        // Default 5 minute TTL
        Self::new(Duration::from_secs(300))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread::sleep;

    #[test]
    fn basic_operations() {
        let cache: Cache<String, i32> = Cache::new(Duration::from_secs(60));

        cache.insert("key1".to_string(), 42);
        assert_eq!(cache.get(&"key1".to_string()), Some(42));
        assert_eq!(cache.get(&"key2".to_string()), None);
    }

    #[test]
    fn expiration() {
        let cache: Cache<String, i32> = Cache::new(Duration::from_millis(50));

        cache.insert("key1".to_string(), 42);
        assert_eq!(cache.get(&"key1".to_string()), Some(42));

        sleep(Duration::from_millis(100));
        assert_eq!(cache.get(&"key1".to_string()), None);
    }

    #[test]
    fn get_or_insert() {
        let cache: Cache<String, i32> = Cache::new(Duration::from_secs(60));

        let value = cache.get_or_insert_with("key1".to_string(), || 42);
        assert_eq!(value, 42);

        // Should return cached value, not call function again
        let value = cache.get_or_insert_with("key1".to_string(), || 100);
        assert_eq!(value, 42);
    }
}
