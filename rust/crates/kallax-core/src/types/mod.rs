//! Core types for KALLAX multi-agent orchestration
//!
//! 跟 v2.7.4 D4.3 联合, 跟 Rule 8 联合. Split into sub-modules:
//! - ticket: Ticket + TicketId + TicketStatus + Priority
//! - task: Task + TaskId + TaskType + TaskStatus
//! - performer: Performer + PerformerId + PerformerStatus
//! - event: Event + EventId + EventType
//!
//! Types follow these principles:
//! - Immutable by default (fields are private, accessed via methods)
//! - All state transitions are explicit
//! - Public API exposed via re-exports below

pub mod ticket;
pub mod task;
pub mod performer;
pub mod event;
pub mod instance;
pub mod trace;
pub mod dag;

// Re-export public API (跟 v2.7.4 单一 SoT 模式 一致, 跟 D4.3 联合)
pub use ticket::{Ticket, TicketId, TicketStatus, Priority};
pub use task::{Task, TaskId, TaskType, TaskStatus};
pub use performer::{Performer, PerformerId, PerformerStatus};
pub use event::{Event, EventId, EventType};
pub use instance::{Instance, InstanceRole};
pub use trace::{TraceSpan, SpanContext};
pub use dag::{DagRun, DagNodeState, DagStatus};
