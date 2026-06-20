// rust/crates/kallax-bridge/src/error.rs — typed error (no unwrap/expect/panic)
//
// 跟 AGENTS.md Rule 3 (no skip tests) + Rule 8 (no copy-paste) 联合:
//   - thiserror typed enum (无 stringly-typed 错误)
//   - 上下文保留 (context: &'static str, source 链)
//   - 0 magic numbers, 0 console, 0 silent catch

use thiserror::Error;

#[derive(Debug, Error)]
pub enum BridgeError {
    #[error("io error in {context}: {source}")]
    Io {
        context: &'static str,
        #[source]
        source: std::io::Error,
    },

    #[error("regex error in {context}: {source}")]
    Regex {
        context: &'static str,
        #[source]
        source: regex::Error,
    },

    #[error("invalid input in {context}: {message}")]
    InvalidInput {
        context: &'static str,
        message: String,
    },

    #[error("file too large: {size} bytes > {limit} bytes")]
    FileTooLarge { size: u64, limit: u64 },
}

impl BridgeError {
    pub fn io(context: &'static str, source: std::io::Error) -> Self {
        Self::Io { context, source }
    }

    pub fn regex(context: &'static str, source: regex::Error) -> Self {
        Self::Regex { context, source }
    }

    pub fn invalid_input(context: &'static str, message: impl Into<String>) -> Self {
        Self::InvalidInput {
            context,
            message: message.into(),
        }
    }
}