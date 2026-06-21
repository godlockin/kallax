//! Integration tests for `kallax_bridge::event_bus`.
//!
//! Moved out of `src/event_bus.rs` to keep the production file under the
//! 500-line-per-file Rule 8 limit (跟 v2.4.1 Hard Rule 联合).

use kallax_bridge::{
    build_envelope, EventBusCore, EventBusCoreError, MessagePriority,
};
use serde_json::json;

const TEST_CHANNEL: &str = "test.channel.publish_subscribe";

#[tokio::test]
async fn publish_fanout_to_multiple_subscribers() {
    let bus = EventBusCore::new();
    let mut sub_a = bus.subscribe(TEST_CHANNEL).unwrap();
    let mut sub_b = bus.subscribe(TEST_CHANNEL).unwrap();

    let envelope = build_envelope("TicketCreated", json!({"id": "T-1"}), MessagePriority::Normal);
    let delivered = bus.publish(TEST_CHANNEL, envelope.clone()).unwrap();
    assert_eq!(delivered, 2, "both subscribers receive");

    let got_a = sub_a.recv().await.unwrap();
    let got_b = sub_b.recv().await.unwrap();
    assert_eq!(got_a.event_id, envelope.event_id);
    assert_eq!(got_b.event_id, envelope.event_id);

    let stats = bus.stats();
    assert_eq!(stats.events_published, 1);
    assert!(stats.subscriber_count >= 2);
}

#[tokio::test]
async fn publish_to_empty_channel_returns_zero() {
    let bus = EventBusCore::new();
    let envelope = build_envelope("NobodyListening", json!({}), MessagePriority::Low);
    let delivered = bus.publish("nobody.subscribed", envelope).unwrap();
    assert_eq!(delivered, 0);
}

#[tokio::test]
async fn unsubscribe_drops_channel() {
    let bus = EventBusCore::new();
    let _sub = bus.subscribe("ephemeral").unwrap();
    let dropped = bus.unsubscribe("ephemeral").unwrap();
    assert_eq!(dropped, 1, "one subscriber removed");
    let dropped_again = bus.unsubscribe("ephemeral").unwrap();
    assert_eq!(dropped_again, 0, "idempotent unsubscribe");
}

#[tokio::test]
async fn invalid_channel_rejected() {
    let bus = EventBusCore::new();
    let envelope = build_envelope("X", json!({}), MessagePriority::Normal);
    assert!(matches!(
        bus.publish("", envelope.clone()),
        Err(EventBusCoreError::InvalidChannelName)
    ));
    assert!(matches!(
        bus.subscribe("nul\0channel"),
        Err(EventBusCoreError::InvalidChannelName)
    ));
}

#[tokio::test]
async fn capacity_guard_rejects_overflow() {
    let bus = EventBusCore::with_capacity(64, 2);
    let _a = bus.subscribe("capped").unwrap();
    let _b = bus.subscribe("capped").unwrap();
    let c = bus.subscribe("capped");
    assert!(matches!(
        c,
        Err(EventBusCoreError::ChannelAtCapacity { max: 2, .. })
    ));
}

#[test]
fn generate_event_id_is_unique() {
    let a = kallax_bridge::generate_event_id();
    let b = kallax_bridge::generate_event_id();
    assert_ne!(a, b);
    assert!(a.starts_with("evt_"));
}

#[tokio::test]
async fn try_recv_drains_buffer() {
    let bus = EventBusCore::new();
    let mut sub = bus.subscribe("drain").unwrap();

    let env = build_envelope("Drained", json!({"i": 1}), MessagePriority::High);
    bus.publish("drain", env.clone()).unwrap();
    let got = sub.try_recv().expect("buffer should have envelope");
    assert_eq!(got.event_id, env.event_id);
    assert!(sub.try_recv().is_none(), "buffer empty after one drain");
}