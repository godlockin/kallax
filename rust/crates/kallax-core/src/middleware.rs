//! Middleware pipeline for request/response processing
//!
//! Composable middleware for intercepting and transforming operations.

use async_trait::async_trait;
use std::sync::Arc;

use crate::{Result, KallaxError};

/// Context passed through middleware pipeline
#[derive(Debug, Clone)]
pub struct Context {
    pub request_id: String,
    pub metadata: std::collections::HashMap<String, String>,
}

impl Context {
    pub fn new(request_id: impl Into<String>) -> Self {
        Self {
            request_id: request_id.into(),
            metadata: std::collections::HashMap::new(),
        }
    }

    pub fn with_metadata(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.metadata.insert(key.into(), value.into());
        self
    }
}

/// Middleware trait for processing requests
#[async_trait]
pub trait Middleware<Req, Res>: Send + Sync
where
    Req: Send + 'static,
    Res: Send + 'static,
{
    /// Process the request and optionally call next middleware
    async fn process(
        &self,
        ctx: &Context,
        request: Req,
        next: Next<'_, Req, Res>,
    ) -> Result<Res>;
}

/// Next middleware in the chain
pub struct Next<'a, Req, Res> {
    middlewares: &'a [Arc<dyn Middleware<Req, Res>>],
    handler: &'a dyn Handler<Req, Res>,
}

impl<'a, Req, Res> Next<'a, Req, Res>
where
    Req: Send + 'static,
    Res: Send + 'static,
{
    /// Run the next middleware or handler
    pub async fn run(self, ctx: &Context, request: Req) -> Result<Res> {
        if let Some((current, rest)) = self.middlewares.split_first() {
            let next = Next {
                middlewares: rest,
                handler: self.handler,
            };
            current.process(ctx, request, next).await
        } else {
            self.handler.handle(ctx, request).await
        }
    }
}

/// Handler trait for the final processing
#[async_trait]
pub trait Handler<Req, Res>: Send + Sync
where
    Req: Send + 'static,
    Res: Send + 'static,
{
    async fn handle(&self, ctx: &Context, request: Req) -> Result<Res>;
}

/// Middleware pipeline
pub struct MiddlewarePipeline<Req, Res>
where
    Req: Send + 'static,
    Res: Send + 'static,
{
    middlewares: Vec<Arc<dyn Middleware<Req, Res>>>,
}

impl<Req, Res> MiddlewarePipeline<Req, Res>
where
    Req: Send + 'static,
    Res: Send + 'static,
{
    pub fn new() -> Self {
        Self {
            middlewares: Vec::new(),
        }
    }

    /// Add middleware to the pipeline
    pub fn use_middleware<M>(mut self, middleware: M) -> Self
    where
        M: Middleware<Req, Res> + 'static,
    {
        self.middlewares.push(Arc::new(middleware));
        self
    }

    /// Execute the pipeline with a handler
    pub async fn execute<H>(&self, ctx: &Context, request: Req, handler: &H) -> Result<Res>
    where
        H: Handler<Req, Res>,
    {
        let next = Next {
            middlewares: &self.middlewares,
            handler,
        };
        next.run(ctx, request).await
    }
}

impl<Req, Res> Default for MiddlewarePipeline<Req, Res>
where
    Req: Send + 'static,
    Res: Send + 'static,
{
    fn default() -> Self {
        Self::new()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Built-in middlewares
// ─────────────────────────────────────────────────────────────────────────────

/// Logging middleware
pub struct LoggingMiddleware;

#[async_trait]
impl<Req, Res> Middleware<Req, Res> for LoggingMiddleware
where
    Req: Send + std::fmt::Debug + 'static,
    Res: Send + 'static,
{
    async fn process(
        &self,
        ctx: &Context,
        request: Req,
        next: Next<'_, Req, Res>,
    ) -> Result<Res> {
        tracing::info!(
            request_id = %ctx.request_id,
            "Processing request"
        );

        let start = std::time::Instant::now();
        let result = next.run(ctx, request).await;
        let duration = start.elapsed();

        match &result {
            Ok(_) => {
                tracing::info!(
                    request_id = %ctx.request_id,
                    duration_ms = duration.as_millis(),
                    "Request completed successfully"
                );
            }
            Err(e) => {
                tracing::error!(
                    request_id = %ctx.request_id,
                    duration_ms = duration.as_millis(),
                    error = %e,
                    "Request failed"
                );
            }
        }

        result
    }
}

/// Timeout middleware
pub struct TimeoutMiddleware {
    timeout_ms: u64,
}

impl TimeoutMiddleware {
    pub fn new(timeout_ms: u64) -> Self {
        Self { timeout_ms }
    }
}

#[async_trait]
impl<Req, Res> Middleware<Req, Res> for TimeoutMiddleware
where
    Req: Send + 'static,
    Res: Send + 'static,
{
    async fn process(
        &self,
        ctx: &Context,
        request: Req,
        next: Next<'_, Req, Res>,
    ) -> Result<Res> {
        let timeout = tokio::time::Duration::from_millis(self.timeout_ms);

        tokio::time::timeout(timeout, next.run(ctx, request))
            .await
            .map_err(|_| KallaxError::Timeout {
                operation: "middleware_pipeline",
                duration_ms: self.timeout_ms,
            })?
    }
}

/// Validation middleware that validates requests
pub struct ValidationMiddleware<V> {
    validator: V,
}

impl<V> ValidationMiddleware<V> {
    pub fn new(validator: V) -> Self {
        Self { validator }
    }
}

#[async_trait]
impl<Req, Res, V> Middleware<Req, Res> for ValidationMiddleware<V>
where
    Req: Send + 'static,
    Res: Send + 'static,
    V: Validator<Req> + Send + Sync,
{
    async fn process(
        &self,
        ctx: &Context,
        request: Req,
        next: Next<'_, Req, Res>,
    ) -> Result<Res> {
        self.validator.validate(&request)?;
        next.run(ctx, request).await
    }
}

/// Validator trait
pub trait Validator<T> {
    fn validate(&self, item: &T) -> Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;

    struct TestHandler;

    #[async_trait]
    impl Handler<String, String> for TestHandler {
        async fn handle(&self, _ctx: &Context, request: String) -> Result<String> {
            Ok(format!("handled: {}", request))
        }
    }

    struct UppercaseMiddleware;

    #[async_trait]
    impl Middleware<String, String> for UppercaseMiddleware {
        async fn process(
            &self,
            ctx: &Context,
            request: String,
            next: Next<'_, String, String>,
        ) -> Result<String> {
            let upper = request.to_uppercase();
            next.run(ctx, upper).await
        }
    }

    #[tokio::test]
    async fn middleware_transforms_request() {
        let pipeline = MiddlewarePipeline::<String, String>::new()
            .use_middleware(UppercaseMiddleware);

        let ctx = Context::new("test-req-1");
        let result = pipeline
            .execute(&ctx, "hello".to_string(), &TestHandler)
            .await;

        assert_eq!(result.unwrap(), "handled: HELLO");
    }
}
