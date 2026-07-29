// 跟 v2.7.4 D4.5 联合, 跟 Rule 8 联合. Split from main.rs.

use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};

use crate::sub_enums::{
    ConductorAction, IsolationAction, KnowledgeAction, PerformerAction, SystemAction, TaskAction,
    VerifyAction,
};

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
// Top-level Cli (flat subcommand structure for clap 4 nested support)
// ---------------------------------------------------------------------------

#[derive(Debug, Parser)]
#[command(name = "kallax", version, about = "KALLAX multi-agent orchestrator")]
pub struct Cli {
    #[arg(long, default_value = "text")]
    pub output: OutputFormat,
    #[arg(long, short = 'v')]
    pub verbose: bool,
    #[command(subcommand)]
    pub command: Commands,
}

// Manual Args impl: clap 4.6.1 Subcommand derive only impls Subcommand trait,
// not Args. For nested subcommand variants, the inner type must also impl Args.
// We provide a manual impl that delegates to Subcommand.
impl clap::Args for TaskAction {
    fn augment_args<'b>(__clap_app: clap::Command) -> clap::Command {
        <Self as clap::Subcommand>::augment_subcommands(__clap_app)
    }
    fn augment_args_for_update<'b>(__clap_app: clap::Command) -> clap::Command {
        <Self as clap::Subcommand>::augment_subcommands_for_update(__clap_app)
    }
}
impl clap::Args for ConductorAction {
    fn augment_args<'b>(__clap_app: clap::Command) -> clap::Command {
        <Self as clap::Subcommand>::augment_subcommands(__clap_app)
    }
    fn augment_args_for_update<'b>(__clap_app: clap::Command) -> clap::Command {
        <Self as clap::Subcommand>::augment_subcommands_for_update(__clap_app)
    }
}
impl clap::Args for PerformerAction {
    fn augment_args<'b>(__clap_app: clap::Command) -> clap::Command {
        <Self as clap::Subcommand>::augment_subcommands(__clap_app)
    }
    fn augment_args_for_update<'b>(__clap_app: clap::Command) -> clap::Command {
        <Self as clap::Subcommand>::augment_subcommands_for_update(__clap_app)
    }
}
impl clap::Args for KnowledgeAction {
    fn augment_args<'b>(__clap_app: clap::Command) -> clap::Command {
        <Self as clap::Subcommand>::augment_subcommands(__clap_app)
    }
    fn augment_args_for_update<'b>(__clap_app: clap::Command) -> clap::Command {
        <Self as clap::Subcommand>::augment_subcommands_for_update(__clap_app)
    }
}
impl clap::Args for SystemAction {
    fn augment_args<'b>(__clap_app: clap::Command) -> clap::Command {
        <Self as clap::Subcommand>::augment_subcommands(__clap_app)
    }
    fn augment_args_for_update<'b>(__clap_app: clap::Command) -> clap::Command {
        <Self as clap::Subcommand>::augment_subcommands_for_update(__clap_app)
    }
}
impl clap::Args for IsolationAction {
    fn augment_args<'b>(__clap_app: clap::Command) -> clap::Command {
        <Self as clap::Subcommand>::augment_subcommands(__clap_app)
    }
    fn augment_args_for_update<'b>(__clap_app: clap::Command) -> clap::Command {
        <Self as clap::Subcommand>::augment_subcommands_for_update(__clap_app)
    }
}
impl clap::Args for VerifyAction {
    fn augment_args<'b>(__clap_app: clap::Command) -> clap::Command {
        <Self as clap::Subcommand>::augment_subcommands(__clap_app)
    }
    fn augment_args_for_update<'b>(__clap_app: clap::Command) -> clap::Command {
        <Self as clap::Subcommand>::augment_subcommands_for_update(__clap_app)
    }
}

#[derive(Debug, Subcommand)]
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
