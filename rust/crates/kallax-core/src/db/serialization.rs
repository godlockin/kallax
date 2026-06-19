//! Serialization helpers for the SQLite persistence layer.
//! 跟 v2.7.4 D4.4 联合, 跟 Rule 8 联合. Extracted from db/mod.rs to modularize.

use crate::error::{KallaxError, Result};
use chrono::{DateTime, Utc};
use std::collections::HashMap;
use std::path::PathBuf;

pub(crate) fn ser_scope(scope: &[PathBuf]) -> String {
    serde_json::to_string(scope).unwrap_or_else(|_| "[]".to_string())
}

pub(crate) fn de_scope(s: &str) -> Vec<PathBuf> {
    serde_json::from_str(s).unwrap_or_default()
}

pub(crate) fn ser_strs(v: &[String]) -> String {
    serde_json::to_string(v).unwrap_or_else(|_| "[]".to_string())
}

pub(crate) fn de_strs(s: &str) -> Vec<String> {
    serde_json::from_str(s).unwrap_or_default()
}

pub(crate) fn ser_meta(m: &HashMap<String, serde_json::Value>) -> String {
    serde_json::to_string(m).unwrap_or_else(|_| "{}".to_string())
}

pub(crate) fn de_meta(s: &str) -> HashMap<String, serde_json::Value> {
    serde_json::from_str(s).unwrap_or_default()
}

pub(crate) fn ts_to_str(dt: &DateTime<Utc>) -> String {
    dt.to_rfc3339()
}

pub(crate) fn str_to_ts(s: &str) -> Result<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(s)
        .map(|dt| dt.with_timezone(&Utc))
        .map_err(|e| KallaxError::database("parse_datetime", e))
}
