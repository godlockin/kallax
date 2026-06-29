// 跟 v2.7.4 D4.5 联合, 跟 Rule 8 联合. Split from main.rs.
// CLI entry: imports, main() function, handler sub-module declarations.

mod enums;
mod handlers;
mod output;
mod parsers;
mod sub_enums;

use clap::Parser;
use std::sync::Arc;

use enums::{Cli, Commands, OutputFormat};
use handlers::{
    handle_conductor_action, handle_isolation_action, handle_knowledge_action,
    handle_performer_action, handle_system_action, handle_task_action, handle_verify_action,
};
use output::output_result;
use parsers::init_logging;

use kallax_core::error::Result;
use kallax_engine::ticket_engine::TicketEngine;

#[tokio::main]
async fn main() -> std::result::Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    init_logging(cli.verbose);
    let format = cli.output;
    let engine = Arc::new(TicketEngine::new()?);

    let result = match cli.command {
        Commands::Task(action) => handle_task_action(action, &engine, format).await,
        Commands::Conductor(action) => handle_conductor_action(action, &engine, format).await,
        Commands::Performer(action) => handle_performer_action(action, &engine, format).await,
        Commands::Knowledge(action) => handle_knowledge_action(action, &engine, format).await,
        Commands::System(action) => handle_system_action(action, &engine, format).await,
        Commands::Isolation(action) => handle_isolation_action(action, &engine, format).await,
        Commands::Verify(action) => handle_verify_action(action, &engine, format).await,
    };

    if let Err(e) = result {
        eprintln!("Error: {}", e);
        output_result(
            format,
            "error",
            serde_json::json!({
                "error": e.to_string(),
            }),
        );
        std::process::exit(1);
    }

    Ok(())
}
