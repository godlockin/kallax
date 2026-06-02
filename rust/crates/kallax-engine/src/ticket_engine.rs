//! Ticket engine - core orchestration logic
//!
//! Manages ticket lifecycle, task creation, and performer assignment.

use kallax_core::{
    Event, EventType, KallaxError, Performer, PerformerId, Result, Task, TaskId, TaskStatus,
    TaskType, Ticket, TicketId, TicketStatus,
};
use dashmap::DashMap;
use std::sync::Arc;
use tracing::{info, warn};

use crate::EventBus;

/// Ticket engine manages the orchestration lifecycle
pub struct TicketEngine {
    tickets: DashMap<String, Ticket>,
    tasks: DashMap<String, Task>,
    performers: DashMap<String, Performer>,
    event_bus: Arc<EventBus>,
}

impl TicketEngine {
    /// Create a new ticket engine
    pub fn new(event_bus: Arc<EventBus>) -> Self {
        Self {
            tickets: DashMap::new(),
            tasks: DashMap::new(),
            performers: DashMap::new(),
            event_bus,
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Ticket operations
    // ─────────────────────────────────────────────────────────────────────────

    /// Create a new ticket
    pub fn create_ticket(&self, ticket: Ticket) -> Result<TicketId> {
        let id = ticket.id().clone();
        let id_str = id.as_str().to_string();

        if self.tickets.contains_key(&id_str) {
            return Err(KallaxError::AlreadyExists {
                entity_type: "ticket",
                entity_id: id_str,
            });
        }

        self.tickets.insert(id_str.clone(), ticket);

        // Emit event
        let event = Event::new(
            EventType::TicketCreated,
            serde_json::json!({ "ticket_id": id_str }),
        );
        let _ = self.event_bus.publish(event);

        info!(ticket_id = %id_str, "Ticket created");
        Ok(id)
    }

    /// Get a ticket by ID
    pub fn get_ticket(&self, ticket_id: &str) -> Result<Ticket> {
        self.tickets
            .get(ticket_id)
            .map(|t| t.clone())
            .ok_or_else(|| KallaxError::not_found("ticket", ticket_id))
    }

    /// List all tickets with optional status filter
    pub fn list_tickets(&self, status: Option<TicketStatus>) -> Vec<Ticket> {
        self.tickets
            .iter()
            .filter(|t| status.map_or(true, |s| t.status() == s))
            .map(|t| t.clone())
            .collect()
    }

    /// Claim a ticket for a performer
    pub fn claim_ticket(&self, ticket_id: &str, performer_id: &PerformerId) -> Result<()> {
        let mut ticket = self.tickets
            .get_mut(ticket_id)
            .ok_or_else(|| KallaxError::not_found("ticket", ticket_id))?;

        // Validate performer exists and is idle
        let performer = self.performers
            .get(performer_id.as_str())
            .ok_or_else(|| KallaxError::not_found("performer", performer_id.as_str()))?;

        if performer.status() != kallax_core::PerformerStatus::Idle {
            return Err(KallaxError::invalid_state(
                "performer",
                performer_id.as_str(),
                "idle",
                performer.status().as_str(),
            ));
        }

        // Assign ticket
        ticket.assign(performer_id.clone())?;

        // Emit event
        let event = Event::new(
            EventType::TicketAssigned,
            serde_json::json!({
                "ticket_id": ticket_id,
                "performer_id": performer_id.as_str()
            }),
        );
        let _ = self.event_bus.publish(event);

        info!(
            ticket_id = %ticket_id,
            performer_id = %performer_id,
            "Ticket claimed"
        );
        Ok(())
    }

    /// Complete a ticket
    pub fn complete_ticket(&self, ticket_id: &str) -> Result<()> {
        let mut ticket = self.tickets
            .get_mut(ticket_id)
            .ok_or_else(|| KallaxError::not_found("ticket", ticket_id))?;

        ticket.complete()?;

        // Emit event
        let event = Event::new(
            EventType::TicketCompleted,
            serde_json::json!({ "ticket_id": ticket_id }),
        );
        let _ = self.event_bus.publish(event);

        info!(ticket_id = %ticket_id, "Ticket completed");
        Ok(())
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Task operations
    // ─────────────────────────────────────────────────────────────────────────

    /// Create a task for a ticket
    pub fn create_task(
        &self,
        ticket_id: &TicketId,
        task_type: TaskType,
        input: serde_json::Value,
    ) -> Result<TaskId> {
        // Validate ticket exists
        if !self.tickets.contains_key(ticket_id.as_str()) {
            return Err(KallaxError::not_found("ticket", ticket_id.as_str()));
        }

        let task = Task::new(ticket_id.clone(), task_type, input);
        let id = task.id().clone();
        let id_str = id.as_str().to_string();

        self.tasks.insert(id_str.clone(), task);

        info!(task_id = %id_str, ticket_id = %ticket_id, "Task created");
        Ok(id)
    }

    /// Get a task by ID
    pub fn get_task(&self, task_id: &str) -> Result<Task> {
        self.tasks
            .get(task_id)
            .map(|t| t.clone())
            .ok_or_else(|| KallaxError::not_found("task", task_id))
    }

    /// Get all tasks for a ticket
    pub fn get_tasks_for_ticket(&self, ticket_id: &str) -> Vec<Task> {
        self.tasks
            .iter()
            .filter(|t| t.ticket_id().as_str() == ticket_id)
            .map(|t| t.clone())
            .collect()
    }

    /// Start a task
    pub fn start_task(&self, task_id: &str) -> Result<()> {
        let mut task = self.tasks
            .get_mut(task_id)
            .ok_or_else(|| KallaxError::not_found("task", task_id))?;

        task.start()?;

        let event = Event::new(
            EventType::TaskStarted,
            serde_json::json!({ "task_id": task_id }),
        );
        let _ = self.event_bus.publish(event);

        info!(task_id = %task_id, "Task started");
        Ok(())
    }

    /// Complete a task with output
    pub fn complete_task(&self, task_id: &str, output: serde_json::Value) -> Result<()> {
        let mut task = self.tasks
            .get_mut(task_id)
            .ok_or_else(|| KallaxError::not_found("task", task_id))?;

        task.complete_with_output(output)?;

        let event = Event::new(
            EventType::TaskCompleted,
            serde_json::json!({ "task_id": task_id }),
        );
        let _ = self.event_bus.publish(event);

        info!(task_id = %task_id, "Task completed");
        Ok(())
    }

    /// Get next available task (pending with satisfied dependencies)
    pub fn get_next_task(&self) -> Option<Task> {
        self.tasks
            .iter()
            .filter(|t| t.status() == TaskStatus::Pending)
            .filter(|t| {
                // Check all dependencies are completed
                t.dependencies().iter().all(|dep_id| {
                    self.tasks
                        .get(dep_id.as_str())
                        .map(|dep| dep.status() == TaskStatus::Completed)
                        .unwrap_or(false)
                })
            })
            .map(|t| t.clone())
            .next()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Performer operations
    // ─────────────────────────────────────────────────────────────────────────

    /// Register a performer
    pub fn register_performer(&self, performer: Performer) -> Result<PerformerId> {
        let id = performer.id().clone();
        let id_str = id.as_str().to_string();

        if self.performers.contains_key(&id_str) {
            return Err(KallaxError::AlreadyExists {
                entity_type: "performer",
                entity_id: id_str,
            });
        }

        self.performers.insert(id_str.clone(), performer);

        let event = Event::new(
            EventType::PerformerRegistered,
            serde_json::json!({ "performer_id": id_str }),
        );
        let _ = self.event_bus.publish(event);

        info!(performer_id = %id_str, "Performer registered");
        Ok(id)
    }

    /// Get a performer by ID
    pub fn get_performer(&self, performer_id: &str) -> Result<Performer> {
        self.performers
            .get(performer_id)
            .map(|p| p.clone())
            .ok_or_else(|| KallaxError::not_found("performer", performer_id))
    }

    /// List all performers
    pub fn list_performers(&self) -> Vec<Performer> {
        self.performers.iter().map(|p| p.clone()).collect()
    }

    /// Update performer heartbeat
    pub fn heartbeat(&self, performer_id: &str) -> Result<()> {
        let mut performer = self.performers
            .get_mut(performer_id)
            .ok_or_else(|| KallaxError::not_found("performer", performer_id))?;

        performer.heartbeat();

        let event = Event::new(
            EventType::PerformerHeartbeat,
            serde_json::json!({ "performer_id": performer_id }),
        );
        let _ = self.event_bus.publish(event);

        Ok(())
    }

    /// Get statistics
    pub fn stats(&self) -> EngineStats {
        EngineStats {
            total_tickets: self.tickets.len(),
            ready_tickets: self.tickets.iter().filter(|t| t.status() == TicketStatus::Ready).count(),
            in_progress_tickets: self.tickets.iter().filter(|t| t.status() == TicketStatus::InProgress).count(),
            completed_tickets: self.tickets.iter().filter(|t| t.status() == TicketStatus::Completed).count(),
            total_tasks: self.tasks.len(),
            pending_tasks: self.tasks.iter().filter(|t| t.status() == TaskStatus::Pending).count(),
            running_tasks: self.tasks.iter().filter(|t| t.status() == TaskStatus::Running).count(),
            total_performers: self.performers.len(),
        }
    }
}

/// Engine statistics
#[derive(Debug, Clone)]
pub struct EngineStats {
    pub total_tickets: usize,
    pub ready_tickets: usize,
    pub in_progress_tickets: usize,
    pub completed_tickets: usize,
    pub total_tasks: usize,
    pub pending_tasks: usize,
    pub running_tasks: usize,
    pub total_performers: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_engine() -> TicketEngine {
        let event_bus = Arc::new(EventBus::new(16));
        TicketEngine::new(event_bus)
    }

    #[test]
    fn ticket_lifecycle() {
        let engine = create_engine();

        // Create ticket
        let ticket = Ticket::new("Test", "Description");
        let ticket_id = engine.create_ticket(ticket).unwrap();

        // Register performer
        let performer = Performer::new("Agent-1");
        let performer_id = engine.register_performer(performer).unwrap();

        // Claim ticket
        engine.claim_ticket(ticket_id.as_str(), &performer_id).unwrap();

        let ticket = engine.get_ticket(ticket_id.as_str()).unwrap();
        assert_eq!(ticket.status(), TicketStatus::InProgress);

        // Complete ticket
        engine.complete_ticket(ticket_id.as_str()).unwrap();

        let ticket = engine.get_ticket(ticket_id.as_str()).unwrap();
        assert_eq!(ticket.status(), TicketStatus::Completed);
    }

    #[test]
    fn task_creation_requires_ticket() {
        let engine = create_engine();

        let result = engine.create_task(
            &TicketId::from_str("NONEXISTENT"),
            TaskType::Analyze,
            serde_json::json!({}),
        );

        assert!(matches!(result, Err(KallaxError::NotFound { .. })));
    }
}
