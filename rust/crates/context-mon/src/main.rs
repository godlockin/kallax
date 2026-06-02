//! Context Monitor - Tracks and manages agent context window usage
//!
//! Features:
//! - Token estimation
//! - Memory monitoring
//! - Context compression triggering
//! - Usage statistics

use kallax_core::{KallaxError, PerformerId, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use parking_lot::RwLock;
use tracing::{info, warn};

// ─────────────────────────────────────────────────────────────────────────────
// Token Estimator
// ─────────────────────────────────────────────────────────────────────────────

/// Token estimation methods
pub struct TokenEstimator {
    /// Average characters per token (varies by model)
    chars_per_token: f64,
}

impl TokenEstimator {
    /// Create estimator with default ratio (4 chars/token for English)
    pub fn new() -> Self {
        Self {
            chars_per_token: 4.0,
        }
    }

    /// Create estimator with custom ratio
    pub fn with_ratio(chars_per_token: f64) -> Self {
        Self { chars_per_token }
    }

    /// Estimate tokens from text
    pub fn estimate_text(&self, text: &str) -> u64 {
        let char_count = text.chars().count();
        (char_count as f64 / self.chars_per_token).ceil() as u64
    }

    /// Estimate tokens from code (typically more dense)
    pub fn estimate_code(&self, code: &str) -> u64 {
        // Code is typically denser, use 3.5 chars/token
        let char_count = code.chars().count();
        (char_count as f64 / 3.5).ceil() as u64
    }

    /// Estimate tokens from JSON
    pub fn estimate_json(&self, json: &str) -> u64 {
        // JSON has lots of punctuation, use 3.0 chars/token
        let char_count = json.chars().count();
        (char_count as f64 / 3.0).ceil() as u64
    }
}

impl Default for TokenEstimator {
    fn default() -> Self {
        Self::new()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Context Usage Tracking
// ─────────────────────────────────────────────────────────────────────────────

/// Context usage for a single performer
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContextUsage {
    pub performer_id: String,
    pub current_tokens: u64,
    pub max_tokens: u64,
    pub compression_threshold: f64,
    pub last_updated: DateTime<Utc>,
    pub compressions_triggered: u32,
}

impl ContextUsage {
    pub fn new(performer_id: &str, max_tokens: u64) -> Self {
        Self {
            performer_id: performer_id.to_string(),
            current_tokens: 0,
            max_tokens,
            compression_threshold: 0.8, // 80% by default
            last_updated: Utc::now(),
            compressions_triggered: 0,
        }
    }

    /// Get usage percentage
    pub fn usage_percent(&self) -> f64 {
        if self.max_tokens == 0 {
            return 0.0;
        }
        (self.current_tokens as f64 / self.max_tokens as f64) * 100.0
    }

    /// Check if compression should be triggered
    pub fn should_compress(&self) -> bool {
        let threshold = self.max_tokens as f64 * self.compression_threshold;
        self.current_tokens as f64 >= threshold
    }

    /// Remaining tokens
    pub fn remaining(&self) -> u64 {
        self.max_tokens.saturating_sub(self.current_tokens)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Context Monitor
// ─────────────────────────────────────────────────────────────────────────────

/// Context monitor configuration
#[derive(Debug, Clone)]
pub struct ContextMonitorConfig {
    /// Default max tokens per performer
    pub default_max_tokens: u64,
    /// Compression threshold (0.0 - 1.0)
    pub compression_threshold: f64,
    /// Enable automatic compression
    pub auto_compress: bool,
}

impl Default for ContextMonitorConfig {
    fn default() -> Self {
        Self {
            default_max_tokens: 128_000, // Claude's context window
            compression_threshold: 0.8,
            auto_compress: true,
        }
    }
}

/// Context monitor tracks token usage across performers
pub struct ContextMonitor {
    config: ContextMonitorConfig,
    usages: RwLock<HashMap<String, ContextUsage>>,
    estimator: TokenEstimator,
    total_compressions: AtomicU64,
}

impl ContextMonitor {
    /// Create a new context monitor
    pub fn new(config: ContextMonitorConfig) -> Self {
        Self {
            config,
            usages: RwLock::new(HashMap::new()),
            estimator: TokenEstimator::new(),
            total_compressions: AtomicU64::new(0),
        }
    }

    /// Register a performer for tracking
    pub fn register_performer(&self, performer_id: &PerformerId) -> Result<()> {
        let id = performer_id.as_str().to_string();

        let mut usages = self.usages.write();
        if usages.contains_key(&id) {
            return Err(KallaxError::AlreadyExists {
                entity_type: "context_usage",
                entity_id: id,
            });
        }

        let usage = ContextUsage {
            performer_id: id.clone(),
            current_tokens: 0,
            max_tokens: self.config.default_max_tokens,
            compression_threshold: self.config.compression_threshold,
            last_updated: Utc::now(),
            compressions_triggered: 0,
        };

        usages.insert(id, usage);
        Ok(())
    }

    /// Update token count for a performer
    pub fn update_tokens(&self, performer_id: &PerformerId, tokens: u64) -> Result<CompressionAction> {
        let id = performer_id.as_str();

        let mut usages = self.usages.write();
        let usage = usages.get_mut(id).ok_or_else(|| {
            KallaxError::not_found("context_usage", id)
        })?;

        usage.current_tokens = tokens;
        usage.last_updated = Utc::now();

        // Check if compression needed
        if usage.should_compress() && self.config.auto_compress {
            usage.compressions_triggered += 1;
            self.total_compressions.fetch_add(1, Ordering::SeqCst);

            warn!(
                performer_id = %performer_id,
                current = usage.current_tokens,
                max = usage.max_tokens,
                percent = usage.usage_percent(),
                "Context compression triggered"
            );

            return Ok(CompressionAction::Required {
                current_tokens: usage.current_tokens,
                target_tokens: (usage.max_tokens as f64 * 0.5) as u64, // Compress to 50%
            });
        }

        Ok(CompressionAction::NotNeeded)
    }

    /// Add tokens (incremental update)
    pub fn add_tokens(&self, performer_id: &PerformerId, additional_tokens: u64) -> Result<CompressionAction> {
        let current = self.get_usage(performer_id)?;
        let new_total = current.current_tokens.saturating_add(additional_tokens);
        self.update_tokens(performer_id, new_total)
    }

    /// Add text and estimate tokens
    pub fn add_text(&self, performer_id: &PerformerId, text: &str) -> Result<CompressionAction> {
        let tokens = self.estimator.estimate_text(text);
        self.add_tokens(performer_id, tokens)
    }

    /// Add code and estimate tokens
    pub fn add_code(&self, performer_id: &PerformerId, code: &str) -> Result<CompressionAction> {
        let tokens = self.estimator.estimate_code(code);
        self.add_tokens(performer_id, tokens)
    }

    /// Get usage for a performer
    pub fn get_usage(&self, performer_id: &PerformerId) -> Result<ContextUsage> {
        let usages = self.usages.read();
        usages.get(performer_id.as_str())
            .cloned()
            .ok_or_else(|| KallaxError::not_found("context_usage", performer_id.as_str()))
    }

    /// Reset usage for a performer (after compression)
    pub fn reset_usage(&self, performer_id: &PerformerId, new_tokens: u64) -> Result<()> {
        let mut usages = self.usages.write();
        let usage = usages.get_mut(performer_id.as_str()).ok_or_else(|| {
            KallaxError::not_found("context_usage", performer_id.as_str())
        })?;

        usage.current_tokens = new_tokens;
        usage.last_updated = Utc::now();

        info!(
            performer_id = %performer_id,
            new_tokens = new_tokens,
            "Context usage reset after compression"
        );

        Ok(())
    }

    /// Get all usages
    pub fn get_all_usages(&self) -> Vec<ContextUsage> {
        self.usages.read().values().cloned().collect()
    }

    /// Get monitor statistics
    pub fn stats(&self) -> MonitorStats {
        let usages = self.usages.read();

        let total_tokens: u64 = usages.values().map(|u| u.current_tokens).sum();
        let total_capacity: u64 = usages.values().map(|u| u.max_tokens).sum();
        let performers_near_limit = usages.values()
            .filter(|u| u.usage_percent() >= 70.0)
            .count();

        MonitorStats {
            tracked_performers: usages.len(),
            total_tokens,
            total_capacity,
            average_usage_percent: if usages.is_empty() {
                0.0
            } else {
                usages.values().map(|u| u.usage_percent()).sum::<f64>() / usages.len() as f64
            },
            performers_near_limit,
            total_compressions: self.total_compressions.load(Ordering::SeqCst),
        }
    }

    /// Unregister a performer
    pub fn unregister_performer(&self, performer_id: &PerformerId) {
        self.usages.write().remove(performer_id.as_str());
    }
}

impl Default for ContextMonitor {
    fn default() -> Self {
        Self::new(ContextMonitorConfig::default())
    }
}

/// Compression action result
#[derive(Debug, Clone)]
pub enum CompressionAction {
    NotNeeded,
    Required {
        current_tokens: u64,
        target_tokens: u64,
    },
}

/// Monitor statistics
#[derive(Debug, Clone, Serialize)]
pub struct MonitorStats {
    pub tracked_performers: usize,
    pub total_tokens: u64,
    pub total_capacity: u64,
    pub average_usage_percent: f64,
    pub performers_near_limit: usize,
    pub total_compressions: u64,
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "context-mon")]
#[command(version = "1.0.0")]
#[command(about = "Context window monitoring for KALLAX agents")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Estimate tokens for text
    Estimate {
        /// Input text (or use stdin)
        #[arg(short, long)]
        text: Option<String>,

        /// Treat input as code
        #[arg(short, long)]
        code: bool,

        /// Treat input as JSON
        #[arg(short, long)]
        json: bool,
    },
    /// Show monitor status
    Status,
    /// Start monitoring daemon
    Daemon {
        /// Monitoring interval in seconds
        #[arg(short, long, default_value = "5")]
        interval: u64,
    },
}

fn init_logging() {
    use tracing_subscriber::{fmt, prelude::*, EnvFilter};

    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("info"));

    tracing_subscriber::registry()
        .with(fmt::layer())
        .with(filter)
        .init();
}

#[tokio::main]
async fn main() -> std::result::Result<(), Box<dyn std::error::Error>> {
    init_logging();
    let cli = Cli::parse();

    let estimator = TokenEstimator::new();
    let monitor = ContextMonitor::default();

    match cli.command {
        Commands::Estimate { text, code, json } => {
            let input = text.unwrap_or_else(|| {
                use std::io::Read;
                let mut buffer = String::new();
                std::io::stdin().read_to_string(&mut buffer).unwrap_or_default();
                buffer
            });

            let tokens = if code {
                estimator.estimate_code(&input)
            } else if json {
                estimator.estimate_json(&input)
            } else {
                estimator.estimate_text(&input)
            };

            println!("Input length: {} chars", input.len());
            println!("Estimated tokens: {}", tokens);
        }
        Commands::Status => {
            let stats = monitor.stats();
            println!("Context Monitor Status");
            println!("─────────────────────");
            println!("Tracked performers: {}", stats.tracked_performers);
            println!("Total tokens: {}", stats.total_tokens);
            println!("Total capacity: {}", stats.total_capacity);
            println!("Average usage: {:.1}%", stats.average_usage_percent);
            println!("Near limit: {}", stats.performers_near_limit);
            println!("Compressions: {}", stats.total_compressions);
        }
        Commands::Daemon { interval } => {
            info!("Starting context monitor daemon (interval: {}s)", interval);

            loop {
                let stats = monitor.stats();

                if stats.performers_near_limit > 0 {
                    warn!(
                        near_limit = stats.performers_near_limit,
                        "Performers approaching context limit"
                    );
                }

                tokio::time::sleep(tokio::time::Duration::from_secs(interval)).await;
            }
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn token_estimation() {
        let estimator = TokenEstimator::new();

        // ~4 chars per token for English text
        let tokens = estimator.estimate_text("Hello, world!");
        assert!(tokens >= 3 && tokens <= 5);

        // Empty string
        assert_eq!(estimator.estimate_text(""), 0);
    }

    #[test]
    fn context_tracking() {
        let monitor = ContextMonitor::default();
        let performer_id = PerformerId::from_str("test-performer");

        monitor.register_performer(&performer_id).unwrap();

        let usage = monitor.get_usage(&performer_id).unwrap();
        assert_eq!(usage.current_tokens, 0);

        monitor.update_tokens(&performer_id, 1000).unwrap();

        let usage = monitor.get_usage(&performer_id).unwrap();
        assert_eq!(usage.current_tokens, 1000);
    }

    #[test]
    fn compression_trigger() {
        let config = ContextMonitorConfig {
            default_max_tokens: 1000,
            compression_threshold: 0.8,
            auto_compress: true,
        };

        let monitor = ContextMonitor::new(config);
        let performer_id = PerformerId::from_str("test-performer");

        monitor.register_performer(&performer_id).unwrap();

        // Below threshold - no compression
        let action = monitor.update_tokens(&performer_id, 700).unwrap();
        assert!(matches!(action, CompressionAction::NotNeeded));

        // Above threshold - compression needed
        let action = monitor.update_tokens(&performer_id, 850).unwrap();
        assert!(matches!(action, CompressionAction::Required { .. }));
    }
}
