//! KALLAX Engine - Execution engine for multi-agent orchestration
//!
//! Components:
//! - EventBus: Pub/sub for system events
//! - TicketEngine: Core orchestration logic
//! - DAG Scheduler: Task dependency management
//! - KnowledgeBase: Full-text search
//! - AgentPool: Performer management
//! - Mailbox: Inter-agent messaging
//! - ConflictResolver: Handle concurrent modifications
//! - WorktreeManager: Git worktree isolation

pub mod agent_pool;
pub mod conflict_resolver;
pub mod dag;
pub mod event_bus;
pub mod knowledge_base;
pub mod mailbox;
pub mod ticket_engine;
pub mod worktree_manager;

pub use agent_pool::AgentPool;
pub use conflict_resolver::ConflictResolver;
pub use dag::DagScheduler;
pub use event_bus::EventBus;
pub use knowledge_base::{KnowledgeBase, KnowledgeEntry};
pub use mailbox::Mailbox;
pub use ticket_engine::TicketEngine;
pub use worktree_manager::WorktreeManager;
