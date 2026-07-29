// 跟 v2.7.4 D4.5 联合, 跟 Rule 8 联合. Split from main.rs.
// Parsers and initialization: init_logging + parse helpers.

use kallax_core::error::{KallaxError, Result};
use kallax_core::types::Priority;
use std::path::PathBuf;

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
    match s.to_lowercase().as_str() {
        "low" => Ok(Priority::Low),
        "normal" => Ok(Priority::Normal),
        "high" => Ok(Priority::High),
        "critical" => Ok(Priority::Critical),
        other => Err(KallaxError::validation("priority", other.to_string())),
    }
}

pub fn parse_scope(s: &str) -> Vec<PathBuf> {
    s.split(',')
        .filter(|p| !p.is_empty())
        .map(PathBuf::from)
        .collect()
}
