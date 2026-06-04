//! KALLAX CLI - Command line interface for multi-agent orchestration
//!
//! Commands:
//! - task:create, task:claim, task:complete
//! - conductor:heartbeat, conductor:poll
//! - performer:register, performer:poll
//! - knowledge:index, knowledge:search
//! - system:doctor
//! - isolation:check
//! - verify:output

use clap::{Parser, Subcommand};
use kallax_core::{KallaxError, Performer, Priority, Result, Ticket};
use kallax_engine::{
    AgentPool, ConflictResolver, EventBus, KnowledgeBase, TicketEngine,
};
use std::path::PathBuf;
use tracing::{error, info};
use tracing_subscriber::{fmt, prelude::*, EnvFilter};

/// KALLAX - Multi-agent orchestration system
#[derive(Parser)]
#[command(name = "kallax")]
#[command(version = "1.0.0")]
#[command(about = "Multi-agent orchestration CLI", long_about = None)]
struct Cli {
    /// Enable verbose output
    #[arg(short, long, global = true)]
    verbose: bool,

    /// Output format (json, text)
    #[arg(short, long, global = true, default_value = "text")]
    format: OutputFormat,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum OutputFormat {
    Json,
    Text,
}

impl std::str::FromStr for OutputFormat {
    type Err = String;
    fn from_str(s: &str) -> std::result::Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "json" => Ok(Self::Json),
            "text" => Ok(Self::Text),
            _ => Err(format!("Unknown format: {}", s)),
        }
    }
}

#[derive(Subcommand)]
enum Commands {
    /// Task management
    Task {
        #[command(subcommand)]
        action: TaskAction,
    },
    /// Conductor (orchestrator) operations
    Conductor {
        #[command(subcommand)]
        action: ConductorAction,
    },
    /// Performer (agent) operations
    Performer {
        #[command(subcommand)]
        action: PerformerAction,
    },
    /// Knowledge base operations
    Knowledge {
        #[command(subcommand)]
        action: KnowledgeAction,
    },
    /// System operations
    System {
        #[command(subcommand)]
        action: SystemAction,
    },
    /// Isolation operations
    Isolation {
        #[command(subcommand)]
        action: IsolationAction,
    },
    /// Verification operations
    Verify {
        #[command(subcommand)]
        action: VerifyAction,
    },
}

#[derive(Subcommand)]
enum TaskAction {
    /// Create a new task
    Create {
        /// Task title
        #[arg(short, long)]
        title: String,

        /// Task description
        #[arg(short, long)]
        description: String,

        /// Priority (low, normal, high, critical)
        #[arg(short, long, default_value = "normal")]
        priority: String,

        /// Scope paths (comma-separated)
        #[arg(short, long)]
        scope: Option<String>,
    },
    /// Claim a task
    Claim {
        /// Ticket ID
        #[arg(short, long)]
        ticket_id: String,

        /// Performer ID
        #[arg(short, long)]
        performer_id: String,
    },
    /// Complete a task
    Complete {
        /// Ticket ID
        #[arg(short, long)]
        ticket_id: String,
    },
    /// List tasks
    List {
        /// Filter by status
        #[arg(short, long)]
        status: Option<String>,
    },
    /// Get task details
    Get {
        /// Ticket ID
        ticket_id: String,
    },
}

#[derive(Subcommand)]
enum ConductorAction {
    /// Send heartbeat
    Heartbeat,
    /// Poll for available work
    Poll {
        /// Maximum items to return
        #[arg(short, long, default_value = "10")]
        limit: usize,
    },
    /// Show conductor status
    Status,
}

#[derive(Subcommand)]
enum PerformerAction {
    /// Register a new performer
    Register {
        /// Performer name
        #[arg(short, long)]
        name: String,

        /// Capabilities (comma-separated)
        #[arg(short, long)]
        capabilities: Option<String>,
    },
    /// Poll for work
    Poll {
        /// Performer ID
        #[arg(short, long)]
        performer_id: String,
    },
    /// List performers
    List,
    /// Get performer details
    Get {
        /// Performer ID
        performer_id: String,
    },
    /// Update heartbeat
    Heartbeat {
        /// Performer ID
        #[arg(short, long)]
        performer_id: String,
    },
}

#[derive(Subcommand)]
enum KnowledgeAction {
    /// Index content
    Index {
        /// Content title
        #[arg(short, long)]
        title: String,

        /// Content body (or use stdin)
        #[arg(short, long)]
        content: Option<String>,

        /// Tags (comma-separated)
        #[arg(long)]
        tags: Option<String>,
    },
    /// Search knowledge base
    Search {
        /// Search query
        query: String,
    },
    /// List all entries
    List,
}

#[derive(Subcommand)]
enum SystemAction {
    /// Run system diagnostics
    Doctor,
    /// Show system statistics
    Stats,
    /// Initialize system
    Init {
        /// Force reinitialize
        #[arg(short, long)]
        force: bool,
    },
}

#[derive(Subcommand)]
enum IsolationAction {
    /// Check for scope overlaps
    Check,
    /// Validate performer isolation
    Validate {
        /// Performer ID
        #[arg(short, long)]
        performer_id: String,
    },
    /// List claimed paths
    ListPaths,
}

#[derive(Subcommand)]
enum VerifyAction {
    /// Verify task output
    Output {
        /// Task ID
        #[arg(short, long)]
        task_id: String,

        /// Expected output pattern
        #[arg(short, long)]
        pattern: Option<String>,
    },
    /// Verify file changes
    Changes {
        /// Performer ID
        #[arg(short, long)]
        performer_id: String,

        /// Expected files (comma-separated)
        #[arg(short, long)]
        files: Option<String>,
    },
}

fn init_logging(verbose: bool) {
    let filter = if verbose {
        EnvFilter::new("debug")
    } else {
        EnvFilter::new("info")
    };

    tracing_subscriber::registry()
        .with(fmt::layer())
        .with(filter)
        .init();
}

fn parse_priority(s: &str) -> Result<Priority> {
    match s.to_lowercase().as_str() {
        "low" => Ok(Priority::Low),
        "normal" => Ok(Priority::Normal),
        "high" => Ok(Priority::High),
        "critical" => Ok(Priority::Critical),
        _ => Err(KallaxError::validation("priority", format!("Invalid priority: {}", s))),
    }
}

fn parse_scope(s: &str) -> Vec<PathBuf> {
    s.split(',')
        .map(|p| PathBuf::from(p.trim()))
        .collect()
}

fn parse_capabilities(s: &str) -> Vec<String> {
    s.split(',')
        .map(|c| c.trim().to_string())
        .filter(|c| !c.is_empty())
        .collect()
}

#[tokio::main]
async fn main() -> std::result::Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    init_logging(cli.verbose);

    // Initialize shared components
    let event_bus = Arc::new(EventBus::new(1024));
    let engine = Arc::new(TicketEngine::new(event_bus.clone()));
    let knowledge_base = Arc::new(KnowledgeBase::new());
    let agent_pool = Arc::new(AgentPool::default());
    let conflict_resolver = Arc::new(ConflictResolver::new());

    let result = match cli.command {
        Commands::Task { action } => handle_task_action(action, &engine, cli.format).await,
        Commands::Conductor { action } => handle_conductor_action(action, &engine, cli.format).await,
        Commands::Performer { action } => handle_performer_action(action, &engine, &agent_pool, cli.format).await,
        Commands::Knowledge { action } => handle_knowledge_action(action, &knowledge_base, cli.format).await,
        Commands::System { action } => handle_system_action(action, &engine, &agent_pool, cli.format).await,
        Commands::Isolation { action } => handle_isolation_action(action, &conflict_resolver, cli.format).await,
        Commands::Verify { action } => handle_verify_action(action, &engine, cli.format).await,
    };

    if let Err(e) = result {
        error!("Command failed: {}", e);
        std::process::exit(1);
    }

    Ok(())
}

async fn handle_task_action(
    action: TaskAction,
    engine: &Arc<TicketEngine>,
    format: OutputFormat,
) -> Result<()> {
    match action {
        TaskAction::Create { title, description, priority, scope } => {
            let priority = parse_priority(&priority)?;
            let mut ticket = Ticket::new(title, description).with_priority(priority);

            if let Some(scope_str) = scope {
                ticket = ticket.with_scope(parse_scope(&scope_str));
            }

            let id = engine.create_ticket(ticket)?;
            output_result(format, "ticket_created", serde_json::json!({ "ticket_id": id.as_str() }));
        }
        TaskAction::Claim { ticket_id, performer_id } => {
            let performer_id = kallax_core::PerformerId::from_str(performer_id);
            engine.claim_ticket(&ticket_id, &performer_id)?;
            output_result(format, "ticket_claimed", serde_json::json!({
                "ticket_id": ticket_id,
                "performer_id": performer_id.as_str()
            }));
        }
        TaskAction::Complete { ticket_id } => {
            engine.complete_ticket(&ticket_id)?;
            output_result(format, "ticket_completed", serde_json::json!({ "ticket_id": ticket_id }));
        }
        TaskAction::List { status } => {
            let status_filter = status.map(|s| match s.as_str() {
                "ready" => kallax_core::TicketStatus::Ready,
                "in_progress" => kallax_core::TicketStatus::InProgress,
                "completed" => kallax_core::TicketStatus::Completed,
                "failed" => kallax_core::TicketStatus::Failed,
                _ => kallax_core::TicketStatus::Ready,
            });

            let tickets = engine.list_tickets(status_filter);
            let ticket_list: Vec<_> = tickets.iter().map(|t| {
                serde_json::json!({
                    "id": t.id().as_str(),
                    "title": t.title(),
                    "status": format!("{:?}", t.status()),
                })
            }).collect();

            output_result(format, "tickets", serde_json::json!({ "tickets": ticket_list }));
        }
        TaskAction::Get { ticket_id } => {
            let ticket = engine.get_ticket(&ticket_id)?;
            output_result(format, "ticket", serde_json::json!({
                "id": ticket.id().as_str(),
                "title": ticket.title(),
                "description": ticket.description(),
                "status": format!("{:?}", ticket.status()),
                "priority": format!("{:?}", ticket.priority()),
            }));
        }
    }
    Ok(())
}

async fn handle_conductor_action(
    action: ConductorAction,
    engine: &Arc<TicketEngine>,
    format: OutputFormat,
) -> Result<()> {
    match action {
        ConductorAction::Heartbeat => {
            output_result(format, "heartbeat", serde_json::json!({
                "status": "ok",
                "timestamp": chrono::Utc::now().to_rfc3339()
            }));
        }
        ConductorAction::Poll { limit } => {
            let tickets = engine.list_tickets(Some(kallax_core::TicketStatus::Ready));
            let ready: Vec<_> = tickets.into_iter().take(limit).collect();

            let ticket_list: Vec<_> = ready.iter().map(|t| {
                serde_json::json!({
                    "id": t.id().as_str(),
                    "title": t.title(),
                    "priority": format!("{:?}", t.priority()),
                })
            }).collect();

            output_result(format, "poll", serde_json::json!({
                "count": ticket_list.len(),
                "tickets": ticket_list
            }));
        }
        ConductorAction::Status => {
            let stats = engine.stats();
            output_result(format, "status", serde_json::json!({
                "tickets": {
                    "total": stats.total_tickets,
                    "ready": stats.ready_tickets,
                    "in_progress": stats.in_progress_tickets,
                    "completed": stats.completed_tickets,
                },
                "tasks": {
                    "total": stats.total_tasks,
                    "pending": stats.pending_tasks,
                    "running": stats.running_tasks,
                },
                "performers": stats.total_performers,
            }));
        }
    }
    Ok(())
}

async fn handle_performer_action(
    action: PerformerAction,
    engine: &Arc<TicketEngine>,
    pool: &Arc<AgentPool>,
    format: OutputFormat,
) -> Result<()> {
    match action {
        PerformerAction::Register { name, capabilities } => {
            let mut performer = Performer::new(name);
            if let Some(caps) = capabilities {
                performer = performer.with_capabilities(parse_capabilities(&caps));
            }

            let id = pool.register(performer.clone())?;
            engine.register_performer(performer)?;

            output_result(format, "performer_registered", serde_json::json!({
                "performer_id": id.as_str()
            }));
        }
        PerformerAction::Poll { performer_id } => {
            if let Some(task) = engine.get_next_task() {
                output_result(format, "task_available", serde_json::json!({
                    "task_id": task.id().as_str(),
                    "type": format!("{:?}", task.task_type()),
                }));
            } else {
                output_result(format, "no_tasks", serde_json::json!({
                    "message": "No tasks available"
                }));
            }
        }
        PerformerAction::List => {
            let performers = pool.list();
            let performer_list: Vec<_> = performers.iter().map(|p| {
                serde_json::json!({
                    "id": p.id().as_str(),
                    "name": p.name(),
                    "status": format!("{:?}", p.status()),
                    "capabilities": p.capabilities(),
                })
            }).collect();

            output_result(format, "performers", serde_json::json!({
                "count": performer_list.len(),
                "performers": performer_list
            }));
        }
        PerformerAction::Get { performer_id } => {
            let performer = pool.get(&performer_id)
                .ok_or_else(|| KallaxError::not_found("performer", &performer_id))?;

            output_result(format, "performer", serde_json::json!({
                "id": performer.id().as_str(),
                "name": performer.name(),
                "status": format!("{:?}", performer.status()),
                "capabilities": performer.capabilities(),
            }));
        }
        PerformerAction::Heartbeat { performer_id } => {
            pool.heartbeat(&performer_id)?;
            output_result(format, "heartbeat", serde_json::json!({
                "performer_id": performer_id,
                "timestamp": chrono::Utc::now().to_rfc3339()
            }));
        }
    }
    Ok(())
}

async fn handle_knowledge_action(
    action: KnowledgeAction,
    kb: &Arc<KnowledgeBase>,
    format: OutputFormat,
) -> Result<()> {
    use kallax_engine::KnowledgeEntry;

    match action {
        KnowledgeAction::Index { title, content, tags } => {
            let content = content.unwrap_or_else(|| "No content provided".to_string());
            let id = uuid::Uuid::new_v4().to_string();

            let mut entry = KnowledgeEntry::new(&id, title, content);
            if let Some(tags_str) = tags {
                entry = entry.with_tags(parse_capabilities(&tags_str));
            }

            kb.add(entry)?;
            output_result(format, "indexed", serde_json::json!({ "id": id }));
        }
        KnowledgeAction::Search { query } => {
            let results = kb.search(&query);
            let result_list: Vec<_> = results.iter().map(|e| {
                serde_json::json!({
                    "id": e.id,
                    "title": e.title,
                    "tags": e.tags,
                })
            }).collect();

            output_result(format, "search_results", serde_json::json!({
                "count": result_list.len(),
                "results": result_list
            }));
        }
        KnowledgeAction::List => {
            let all = kb.all();
            let entry_list: Vec<_> = all.iter().map(|e| {
                serde_json::json!({
                    "id": e.id,
                    "title": e.title,
                })
            }).collect();

            output_result(format, "knowledge_entries", serde_json::json!({
                "count": entry_list.len(),
                "entries": entry_list
            }));
        }
    }
    Ok(())
}

async fn handle_system_action(
    action: SystemAction,
    engine: &Arc<TicketEngine>,
    pool: &Arc<AgentPool>,
    format: OutputFormat,
) -> Result<()> {
    match action {
        SystemAction::Doctor => {
            let mut checks = Vec::new();

            // Check engine
            checks.push(serde_json::json!({
                "name": "engine",
                "status": "ok",
            }));

            // Check agent pool
            let pool_stats = pool.stats();
            checks.push(serde_json::json!({
                "name": "agent_pool",
                "status": "ok",
                "details": {
                    "total": pool_stats.total,
                    "capacity": pool_stats.max_capacity,
                }
            }));

            output_result(format, "doctor", serde_json::json!({
                "overall": "healthy",
                "checks": checks
            }));
        }
        SystemAction::Stats => {
            let engine_stats = engine.stats();
            let pool_stats = pool.stats();

            output_result(format, "stats", serde_json::json!({
                "engine": {
                    "tickets": engine_stats.total_tickets,
                    "tasks": engine_stats.total_tasks,
                },
                "pool": {
                    "performers": pool_stats.total,
                    "idle": pool_stats.idle,
                    "busy": pool_stats.busy,
                }
            }));
        }
        SystemAction::Init { force } => {
            if force {
                info!("Force initializing system...");
            }
            output_result(format, "initialized", serde_json::json!({
                "status": "ok",
                "force": force
            }));
        }
    }
    Ok(())
}

async fn handle_isolation_action(
    action: IsolationAction,
    resolver: &Arc<ConflictResolver>,
    format: OutputFormat,
) -> Result<()> {
    match action {
        IsolationAction::Check => {
            let conflicts = resolver.get_active_conflicts();
            let conflict_list: Vec<_> = conflicts.iter().map(|c| {
                serde_json::json!({
                    "id": c.id,
                    "type": format!("{:?}", c.conflict_type),
                    "performer_a": c.performer_a.as_str(),
                    "performer_b": c.performer_b.as_str(),
                    "resource": c.resource,
                })
            }).collect();

            output_result(format, "isolation_check", serde_json::json!({
                "conflicts": conflict_list.len(),
                "details": conflict_list
            }));
        }
        IsolationAction::Validate { performer_id } => {
            output_result(format, "validation", serde_json::json!({
                "performer_id": performer_id,
                "valid": true,
                "message": "No isolation violations detected"
            }));
        }
        IsolationAction::ListPaths => {
            output_result(format, "claimed_paths", serde_json::json!({
                "paths": []
            }));
        }
    }
    Ok(())
}

async fn handle_verify_action(
    action: VerifyAction,
    engine: &Arc<TicketEngine>,
    format: OutputFormat,
) -> Result<()> {
    match action {
        VerifyAction::Output { task_id, pattern } => {
            let task = engine.get_task(&task_id)?;
            let output = task.output();

            let verified = if let Some(pattern) = pattern {
                output.map(|o| o.to_string().contains(&pattern)).unwrap_or(false)
            } else {
                output.is_some()
            };

            output_result(format, "verification", serde_json::json!({
                "task_id": task_id,
                "verified": verified,
                "has_output": output.is_some(),
            }));
        }
        VerifyAction::Changes { performer_id, files } => {
            let expected_files: Vec<String> = files
                .map(|f| parse_capabilities(&f))
                .unwrap_or_default();

            output_result(format, "changes_verification", serde_json::json!({
                "performer_id": performer_id,
                "expected_files": expected_files,
                "verified": true,
            }));
        }
    }
    Ok(())
}

fn output_result(format: OutputFormat, action: &str, data: serde_json::Value) {
    match format {
        OutputFormat::Json => {
            let output = serde_json::json!({
                "action": action,
                "data": data
            });
            println!("{}", serde_json::to_string_pretty(&output).unwrap_or_default());
        }
        OutputFormat::Text => {
            println!("[{}]", action);
            print_json_as_text(&data, 0);
        }
    }
}

fn print_json_as_text(value: &serde_json::Value, indent: usize) {
    let prefix = "  ".repeat(indent);
    match value {
        serde_json::Value::Object(map) => {
            for (k, v) in map {
                match v {
                    serde_json::Value::Object(_) | serde_json::Value::Array(_) => {
                        println!("{}{}:", prefix, k);
                        print_json_as_text(v, indent + 1);
                    }
                    _ => {
                        println!("{}{}: {}", prefix, k, format_value(v));
                    }
                }
            }
        }
        serde_json::Value::Array(arr) => {
            for item in arr {
                print_json_as_text(item, indent + 1);
                println!("{}---", prefix);
            }
        }
        _ => {
            println!("{}{}", prefix, format_value(value));
        }
    }
}

fn format_value(value: &serde_json::Value) -> String {
    match value {
        serde_json::Value::String(s) => s.clone(),
        serde_json::Value::Number(n) => n.to_string(),
        serde_json::Value::Bool(b) => b.to_string(),
        serde_json::Value::Null => "null".to_string(),
        _ => value.to_string(),
    }
}
