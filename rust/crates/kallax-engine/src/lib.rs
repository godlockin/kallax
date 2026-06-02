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

pub mod event_bus;
pub mod ticket_engine;
pub mod dag;
pub mod knowledge_base;
pub mod agent_pool;
pub mod mailbox;
pub mod conflict_resolver;
pub mod worktree_manager;

pub use event_bus::EventBus;
pub use ticket_engine::TicketEngine;
pub use dag::DagScheduler;
pub use knowledge_base::{KnowledgeBase, KnowledgeEntry};
pub use agent_pool::AgentPool;
pub use mailbox::Mailbox;
pub use conflict_resolver::ConflictResolver;
pub use worktree_manager::WorktreeManager;
