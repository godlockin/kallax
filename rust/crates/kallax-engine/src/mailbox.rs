//! Mailbox for inter-agent messaging
//!
//! Asynchronous message passing between performers.

use kallax_core::{KallaxError, PerformerId, Result};
use chrono::{DateTime, Utc};
use dashmap::DashMap;
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use parking_lot::Mutex;
use uuid::Uuid;

/// A message between performers
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub id: String,
    pub from: PerformerId,
    pub to: PerformerId,
    pub message_type: MessageType,
    pub payload: serde_json::Value,
    pub timestamp: DateTime<Utc>,
    pub read: bool,
}

impl Message {
    pub fn new(
        from: PerformerId,
        to: PerformerId,
        message_type: MessageType,
        payload: serde_json::Value,
    ) -> Self {
        Self {
            id: format!("MSG-{}", &Uuid::new_v4().to_string()[..8].to_uppercase()),
            from,
            to,
            message_type,
            payload,
            timestamp: Utc::now(),
            read: false,
        }
    }
}

/// Message types
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MessageType {
    /// Request for information or action
    Request,
    /// Response to a request
    Response,
    /// Notification (no response expected)
    Notification,
    /// Conflict alert
    ConflictAlert,
    /// Task handoff
    TaskHandoff,
}

/// Mailbox for a single performer
struct PerformerMailbox {
    messages: Mutex<VecDeque<Message>>,
    max_size: usize,
}

impl PerformerMailbox {
    fn new(max_size: usize) -> Self {
        Self {
            messages: Mutex::new(VecDeque::new()),
            max_size,
        }
    }

    fn push(&self, message: Message) -> Result<()> {
        let mut messages = self.messages.lock();
        if messages.len() >= self.max_size {
            return Err(KallaxError::ResourceExhausted {
                resource: "mailbox_capacity",
                limit: self.max_size as u64,
                requested: 1,
            });
        }
        messages.push_back(message);
        Ok(())
    }

    fn pop(&self) -> Option<Message> {
        self.messages.lock().pop_front()
    }

    fn peek(&self) -> Option<Message> {
        self.messages.lock().front().cloned()
    }

    fn len(&self) -> usize {
        self.messages.lock().len()
    }

    fn drain(&self) -> Vec<Message> {
        self.messages.lock().drain(..).collect()
    }
}

/// Mailbox system for inter-agent communication
pub struct Mailbox {
    mailboxes: DashMap<String, PerformerMailbox>,
    max_mailbox_size: usize,
}

impl Mailbox {
    /// Create a new mailbox system
    pub fn new(max_mailbox_size: usize) -> Self {
        Self {
            mailboxes: DashMap::new(),
            max_mailbox_size,
        }
    }

    /// Send a message to a performer
    pub fn send(&self, message: Message) -> Result<()> {
        let to_id = message.to.as_str().to_string();

        // Get or create mailbox
        let mailbox = self.mailboxes
            .entry(to_id)
            .or_insert_with(|| PerformerMailbox::new(self.max_mailbox_size));

        mailbox.push(message)
    }

    /// Receive next message for a performer
    pub fn receive(&self, performer_id: &PerformerId) -> Option<Message> {
        self.mailboxes
            .get(performer_id.as_str())
            .and_then(|mb| mb.pop())
    }

    /// Peek at next message without removing it
    pub fn peek(&self, performer_id: &PerformerId) -> Option<Message> {
        self.mailboxes
            .get(performer_id.as_str())
            .and_then(|mb| mb.peek())
    }

    /// Get message count for a performer
    pub fn message_count(&self, performer_id: &PerformerId) -> usize {
        self.mailboxes
            .get(performer_id.as_str())
            .map(|mb| mb.len())
            .unwrap_or(0)
    }

    /// Drain all messages for a performer
    pub fn drain(&self, performer_id: &PerformerId) -> Vec<Message> {
        self.mailboxes
            .get(performer_id.as_str())
            .map(|mb| mb.drain())
            .unwrap_or_default()
    }

    /// Send a conflict alert
    pub fn send_conflict_alert(
        &self,
        from: PerformerId,
        to: PerformerId,
        conflict_details: serde_json::Value,
    ) -> Result<()> {
        let message = Message::new(from, to, MessageType::ConflictAlert, conflict_details);
        self.send(message)
    }

    /// Send a task handoff
    pub fn send_task_handoff(
        &self,
        from: PerformerId,
        to: PerformerId,
        task_details: serde_json::Value,
    ) -> Result<()> {
        let message = Message::new(from, to, MessageType::TaskHandoff, task_details);
        self.send(message)
    }
}

impl Default for Mailbox {
    fn default() -> Self {
        Self::new(1000)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn send_and_receive() {
        let mailbox = Mailbox::default();

        let from = PerformerId::from_str("perf-1");
        let to = PerformerId::from_str("perf-2");

        let msg = Message::new(
            from.clone(),
            to.clone(),
            MessageType::Request,
            serde_json::json!({"action": "help"}),
        );

        mailbox.send(msg).unwrap();

        let received = mailbox.receive(&to).unwrap();
        assert_eq!(received.from.as_str(), "perf-1");
        assert_eq!(received.message_type, MessageType::Request);
    }

    #[test]
    fn mailbox_capacity() {
        let mailbox = Mailbox::new(2); // Small capacity for testing

        let from = PerformerId::from_str("perf-1");
        let to = PerformerId::from_str("perf-2");

        // Fill mailbox
        for _ in 0..2 {
            let msg = Message::new(from.clone(), to.clone(), MessageType::Notification, serde_json::json!({}));
            mailbox.send(msg).unwrap();
        }

        // Should fail when full
        let msg = Message::new(from, to, MessageType::Notification, serde_json::json!({}));
        let result = mailbox.send(msg);
        assert!(matches!(result, Err(KallaxError::ResourceExhausted { .. })));
    }

    #[test]
    fn fifo_ordering() {
        let mailbox = Mailbox::default();

        let from = PerformerId::from_str("perf-1");
        let to = PerformerId::from_str("perf-2");

        for i in 0..3 {
            let msg = Message::new(
                from.clone(),
                to.clone(),
                MessageType::Notification,
                serde_json::json!({"order": i}),
            );
            mailbox.send(msg).unwrap();
        }

        // Should receive in order
        for i in 0..3 {
            let msg = mailbox.receive(&to).unwrap();
            assert_eq!(msg.payload["order"], i);
        }
    }
}
