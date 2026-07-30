//! Event bus for pub/sub communication
//!
//! Uses tokio broadcast for event distribution.

use kallax_core::{Event, EventType, Result};
use parking_lot::RwLock;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::broadcast;

/// Event subscriber type
type Subscriber = broadcast::Sender<Event>;

/// Event bus for publishing and subscribing to events
pub struct EventBus {
    /// Global channel for all events
    global_tx: broadcast::Sender<Event>,
    /// Per-type channels for filtered subscriptions
    typed_channels: RwLock<HashMap<EventType, Subscriber>>,
    /// Buffer size for channels
    buffer_size: usize,
}

impl EventBus {
    /// Create a new event bus with specified buffer size
    pub fn new(buffer_size: usize) -> Self {
        let (global_tx, _) = broadcast::channel(buffer_size);
        Self {
            global_tx,
            typed_channels: RwLock::new(HashMap::new()),
            buffer_size,
        }
    }

    /// Publish an event to all subscribers
    pub fn publish(&self, event: Event) -> Result<usize> {
        let event_type = event.event_type;

        // Send to global channel
        let global_count = self.global_tx.send(event.clone()).unwrap_or(0);

        // Send to type-specific channel if exists
        let typed_count = {
            let channels = self.typed_channels.read();
            if let Some(tx) = channels.get(&event_type) {
                tx.send(event).unwrap_or(0)
            } else {
                0
            }
        };

        Ok(global_count + typed_count)
    }

    /// Subscribe to all events
    pub fn subscribe_all(&self) -> broadcast::Receiver<Event> {
        self.global_tx.subscribe()
    }

    /// Subscribe to specific event types
    pub fn subscribe(&self, event_type: EventType) -> broadcast::Receiver<Event> {
        let mut channels = self.typed_channels.write();

        if let Some(tx) = channels.get(&event_type) {
            tx.subscribe()
        } else {
            let (tx, rx) = broadcast::channel(self.buffer_size);
            channels.insert(event_type, tx);
            rx
        }
    }

    /// Get number of global subscribers
    pub fn subscriber_count(&self) -> usize {
        self.global_tx.receiver_count()
    }
}

impl Default for EventBus {
    fn default() -> Self {
        Self::new(1024)
    }
}

/// Event bus handle for shared access
pub type EventBusHandle = Arc<EventBus>;

/// Create a new event bus handle
pub fn create_event_bus(buffer_size: usize) -> EventBusHandle {
    Arc::new(EventBus::new(buffer_size))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[tokio::test]
    async fn publish_and_subscribe() {
        let bus = EventBus::new(16);
        let mut rx = bus.subscribe_all();

        let event = Event::new(EventType::TicketCreated, json!({"ticket_id": "TEST-001"}));
        bus.publish(event).unwrap();

        let received = rx.recv().await.unwrap();
        assert_eq!(received.event_type, EventType::TicketCreated);
    }

    #[tokio::test]
    async fn typed_subscription() {
        let bus = EventBus::new(16);
        let mut ticket_rx = bus.subscribe(EventType::TicketCreated);
        let mut task_rx = bus.subscribe(EventType::TaskStarted);

        // Publish ticket event
        let event = Event::new(EventType::TicketCreated, json!({}));
        bus.publish(event).unwrap();

        // Only ticket subscriber should receive
        let received = ticket_rx.recv().await.unwrap();
        assert_eq!(received.event_type, EventType::TicketCreated);

        // Task subscriber should timeout (no message)
        let result =
            tokio::time::timeout(std::time::Duration::from_millis(10), task_rx.recv()).await;
        assert!(result.is_err());
    }
}
