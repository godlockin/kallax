// 跟 v2.7.4 D4.5 联合, 跟 Rule 8 联合. Split from main.rs.

use clap::Parser;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

use crate::types::{Priority, Scope};

// ---------------------------------------------------------------------------
// OutputFormat
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum OutputFormat {
    Text,
    Json,
    Yaml,
}

impl std::str::FromStr for OutputFormat {
    type Err = String;
    fn from_str(s: &str) -> std::result::Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "text" => Ok(Self::Text),
            "json" => Ok(Self::Json),
            "yaml" => Ok(Self::Yaml),
            other => Err(format!("unknown output format: {}", other)),
        }
    }
}

// ---------------------------------------------------------------------------
// Top-level Commands enum
// ---------------------------------------------------------------------------

#[derive(Debug, Parser)]
#[command(name = "kallax", version, about = "KALLAX multi-agent orchestrator")]
pub struct Cli {
    #[arg(long, default_value = "text")]
    pub output: OutputFormat,
    #[arg(long, short = 'v')]
    pub verbose: bool,
    #[arg(subcommand)]
    pub command: Commands,
}

#[derive(Debug, clap::Subcommand)]
pub enum Commands {
    /// Task management subcommands
    Task(TaskAction),
    /// Conductor subcommands
    Conductor(ConductorAction),
    /// Performer subcommands
    Performer(PerformerAction),
    /// Knowledge base subcommands
    Knowledge(KnowledgeAction),
    /// System subcommands
    System(SystemAction),
    /// Isolation checking subcommands
    Isolation(IsolationAction),
    /// Verification subcommands (5-Level Fact-Forcing)
    Verify(VerifyAction),
}
