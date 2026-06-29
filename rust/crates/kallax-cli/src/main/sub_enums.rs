// 跟 v2.7.4 D4.5 联合, 跟 Rule 8 联合. Split from main.rs.
// Subcommand enums: 7 action enums for the CLI.

use clap::Subcommand;

#[derive(Debug, Subcommand)]
pub enum TaskAction {
    /// Create a new task
    Create {
        #[arg(short, long)]
        title: String,
        #[arg(short, long)]
        description: String,
        #[arg(short, long, default_value = "normal")]
        priority: String,
        #[arg(short, long)]
        scope: Option<String>,
    },
    /// Claim a task
    Claim {
        #[arg(short, long)]
        ticket_id: String,
        #[arg(short, long)]
        performer_id: String,
    },
    /// Complete a task
    Complete {
        #[arg(short, long)]
        ticket_id: String,
    },
    /// List tasks
    List {
        #[arg(short, long)]
        status: Option<String>,
    },
    /// Get task details
    Get {
        ticket_id: String,
    },
}

#[derive(Debug, Subcommand)]
pub enum ConductorAction {
    /// Show conductor status
    Status,
    /// List registered performers
    List,
    /// Dispatch a task to a performer
    Dispatch {
        #[arg(short, long)]
        ticket_id: String,
    },
    /// Heartbeat from conductor
    Heartbeat {
        #[arg(short, long)]
        conductor_id: String,
    },
}

#[derive(Debug, Subcommand)]
pub enum PerformerAction {
    /// Register a performer
    Register {
        #[arg(short, long)]
        name: String,
    },
    /// Performer heartbeat
    Heartbeat {
        #[arg(short, long)]
        performer_id: String,
    },
    /// Show performer status
    Status,
}

#[derive(Debug, Subcommand)]
pub enum KnowledgeAction {
    /// Add a knowledge entry
    Add {
        #[arg(short, long)]
        key: String,
        #[arg(short, long)]
        value: String,
    },
    /// Query knowledge base
    Query {
        #[arg(short, long)]
        key: String,
    },
    /// List all knowledge entries
    List,
}

#[derive(Debug, Subcommand)]
pub enum SystemAction {
    /// System health check
    Health,
    /// Show version
    Version,
    /// Show configuration
    Config,
}

#[derive(Debug, Subcommand)]
pub enum IsolationAction {
    /// Check scope violation
    Check {
        #[arg(short, long)]
        performer_id: String,
    },
}

#[derive(Debug, Subcommand)]
pub enum VerifyAction {
    /// Run 5-Level Fact-Forcing verification
    Run {
        #[arg(short, long)]
        ticket_id: String,
    },
    /// Check KPI precision
    Kpi {
        #[arg(short, long)]
        ticket_id: String,
    },
}
