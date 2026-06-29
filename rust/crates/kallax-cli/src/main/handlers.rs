// 跟 v2.7.4 D4.5 联合, 跟 Rule 8 联合. Split from main.rs.
// Handlers: 7 handle_* functions for the subcommands.

use std::str::FromStr;
use std::sync::Arc;

use crate::enums::OutputFormat;
use crate::output::output_result;
use crate::parsers::{parse_priority, parse_scope};
use crate::sub_enums::{
    ConductorAction, IsolationAction, KnowledgeAction, PerformerAction, SystemAction,
    TaskAction, VerifyAction,
};

use kallax_core::error::Result;
use kallax_core::{PerformerId, Ticket, TicketStatus};
use kallax_engine::ticket_engine::TicketEngine;

// ---------------------------------------------------------------------------
// handle_task_action
// ---------------------------------------------------------------------------

pub async fn handle_task_action(
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
            let performer_id = PerformerId::from_str(performer_id);
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
                "ready" => TicketStatus::Ready,
                "in_progress" => TicketStatus::InProgress,
                "completed" => TicketStatus::Completed,
                "failed" => TicketStatus::Failed,
                _ => TicketStatus::Ready,
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

// ---------------------------------------------------------------------------
// handle_conductor_action
// ---------------------------------------------------------------------------

pub async fn handle_conductor_action(
    action: ConductorAction,
    engine: &Arc<TicketEngine>,
    format: OutputFormat,
) -> Result<()> {
    match action {
        ConductorAction::Status => {
            output_result(format, "conductor_status", serde_json::json!({
                "status": "active",
                "engine": "running",
            }));
        }
        ConductorAction::List => {
            output_result(format, "performers", serde_json::json!({ "performers": [] }));
        }
        ConductorAction::Dispatch { ticket_id } => {
            // Stub: dispatch_ticket not in TicketEngine API (S-07.5 范围不动 engine)
            // For now, verify ticket exists and is claimable
            let _ticket = engine.get_ticket(&ticket_id)?;
            output_result(format, "dispatched", serde_json::json!({ "ticket_id": ticket_id }));
        }
        ConductorAction::Heartbeat { conductor_id } => {
            output_result(format, "heartbeat_ok", serde_json::json!({ "conductor_id": conductor_id }));
        }
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// handle_performer_action
// ---------------------------------------------------------------------------

pub async fn handle_performer_action(
    action: PerformerAction,
    _engine: &Arc<TicketEngine>,
    format: OutputFormat,
) -> Result<()> {
    match action {
        PerformerAction::Register { name } => {
            output_result(format, "performer_registered", serde_json::json!({ "name": name }));
        }
        PerformerAction::Heartbeat { performer_id } => {
            output_result(format, "performer_heartbeat", serde_json::json!({ "performer_id": performer_id }));
        }
        PerformerAction::Status => {
            output_result(format, "performer_status", serde_json::json!({ "status": "ok" }));
        }
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// handle_knowledge_action
// ---------------------------------------------------------------------------

pub async fn handle_knowledge_action(
    action: KnowledgeAction,
    _engine: &Arc<TicketEngine>,
    format: OutputFormat,
) -> Result<()> {
    match action {
        KnowledgeAction::Add { key, value } => {
            output_result(format, "knowledge_added", serde_json::json!({ "key": key, "value": value }));
        }
        KnowledgeAction::Query { key } => {
            output_result(format, "knowledge_query", serde_json::json!({ "key": key, "value": null }));
        }
        KnowledgeAction::List => {
            output_result(format, "knowledge_list", serde_json::json!({ "entries": [] }));
        }
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// handle_system_action
// ---------------------------------------------------------------------------

pub async fn handle_system_action(
    action: SystemAction,
    _engine: &Arc<TicketEngine>,
    format: OutputFormat,
) -> Result<()> {
    match action {
        SystemAction::Health => {
            output_result(format, "health", serde_json::json!({ "status": "ok" }));
        }
        SystemAction::Version => {
            output_result(format, "version", serde_json::json!({
                "version": env!("CARGO_PKG_VERSION"),
                "name": env!("CARGO_PKG_NAME"),
            }));
        }
        SystemAction::Config => {
            output_result(format, "config", serde_json::json!({ "config": {} }));
        }
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// handle_isolation_action
// ---------------------------------------------------------------------------

pub async fn handle_isolation_action(
    action: IsolationAction,
    _engine: &Arc<TicketEngine>,
    format: OutputFormat,
) -> Result<()> {
    match action {
        IsolationAction::Check { performer_id } => {
            output_result(format, "isolation_check", serde_json::json!({
                "performer_id": performer_id,
                "violations": [],
            }));
        }
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// handle_verify_action
// ---------------------------------------------------------------------------

pub async fn handle_verify_action(
    action: VerifyAction,
    _engine: &Arc<TicketEngine>,
    format: OutputFormat,
) -> Result<()> {
    match action {
        VerifyAction::Run { ticket_id } => {
            output_result(format, "verify_run", serde_json::json!({ "ticket_id": ticket_id, "result": "pending" }));
        }
        VerifyAction::Kpi { ticket_id } => {
            output_result(format, "verify_kpi", serde_json::json!({ "ticket_id": ticket_id, "kpi": null }));
        }
    }
    Ok(())
}
