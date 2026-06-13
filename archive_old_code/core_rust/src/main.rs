mod cli;
mod core;

use clap::Parser;
use cli::{Cli, Commands};
use tracing_subscriber;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    tracing_subscriber::fmt::init();

    match cli.command {
        Some(Commands::Read { protocol, target, slave_id, func, addr, count }) => {
            core::master::run_master(protocol, target, slave_id, format!("read_{}", func), addr, count).await?;
        }
        Some(Commands::Write { protocol, target, slave_id, func, addr, value }) => {
            core::master::run_master(protocol, target, slave_id, format!("write_{}", func), addr, value).await?;
        }
        Some(Commands::Scan { protocol, target, from, to }) => {
            println!("Scanning {} target {} from {} to {}", protocol, target, from, to);
            // Scan logic implementation
            for id in from..=to {
                let res = core::master::run_master(protocol.clone(), target.clone(), id, "read_holding".to_string(), 0, 1).await;
                if res.is_ok() {
                    println!("Found active slave at ID {}", id);
                }
            }
        }
        None => {
            println!("Please provide a command. Use --help for more information.");
        }
    }

    Ok(())
}
