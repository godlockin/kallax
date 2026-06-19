// 跟 v2.7.4 D4.5 联合, 跟 Rule 8 联合. Split from main.rs.
// Parsers and initialization: init_logging + parse helpers.

use crate::error::{KallaxError, Result};
use crate::types::Priority;
use std::path::PathBuf;
use std::str::FromStr;

pub fn init_logging(verbose: bool) {
    use tracing_subscriber::{fmt, EnvFilter};
    let filter = if verbose {
        EnvFilter::new("debug")
    } else {
        EnvFilter::new("info")
    };
    let _ = fmt().with_env_filter(filter).try_init();
}

pub fn parse_priority(s: &str) -> Result<Priority> {
    Priority::from_str(s).map_err(|_| KallaxError::validation("priority", s.to_string()))
}

pub fn parse_scope(s: &str) -> Vec<PathBuf> {
    s.split(',').filter(|p| !p.is_empty()).map(PathBuf::from).collect()
}

pub fn parse_capabilities(s: &str) -> Vec<String> {
    s.split(',').filter(|c| !c.is_empty()).map(String::from).collect()
}
