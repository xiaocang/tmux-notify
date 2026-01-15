mod db;
mod models;

use clap::{Parser, Subcommand};
use db::{get_default_db_path, Database};
use models::{ErrorResponse, QueryResponse};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "tmux-notify")]
#[command(about = "Notification storage for tmux", long_about = None)]
struct Cli {
    /// Custom database path (default: $XDG_DATA_HOME/tmux-notify/notifications.db)
    #[arg(long, global = true)]
    db_path: Option<PathBuf>,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Add or replace a notification for a pane
    Add {
        /// Notification title
        #[arg(short, long)]
        title: String,

        /// Notification message
        #[arg(short, long)]
        message: String,

        /// Pane ID (e.g., %5)
        #[arg(short, long)]
        pane: String,

        /// Retention hours for cleanup (default: 24)
        #[arg(long, default_value = "24")]
        retention: i64,
    },

    /// Query all notifications (JSON output)
    Query,

    /// Get unread notification count
    Count,

    /// Mark notification as read for a pane
    MarkRead {
        /// Pane ID to mark as read
        pane: String,
    },

    /// Dismiss (delete) notification for a pane
    Dismiss {
        /// Pane ID to dismiss
        pane: String,
    },

    /// Manually cleanup old notifications
    Cleanup {
        /// Retention hours (default: 24)
        #[arg(long, default_value = "24")]
        retention: i64,
    },

    /// Reset (delete) the entire notification database
    Reset,
}

fn main() {
    let cli = Cli::parse();

    match run(cli) {
        Ok(_) => {}
        Err(e) => {
            let resp = ErrorResponse {
                ok: false,
                error: e.to_string(),
            };
            println!("{}", serde_json::to_string(&resp).unwrap());
            std::process::exit(1);
        }
    }
}

fn run(cli: Cli) -> Result<(), Box<dyn std::error::Error>> {
    // Handle Reset separately since it doesn't need the DB connection
    if matches!(cli.command, Commands::Reset) {
        let db_path = cli.db_path.unwrap_or_else(get_default_db_path);
        if db_path.exists() {
            std::fs::remove_file(&db_path)?;
            println!("{{\"ok\":true,\"path\":\"{}\"}}", db_path.display());
        } else {
            println!("{{\"ok\":true,\"message\":\"database does not exist\"}}");
        }
        return Ok(());
    }

    let db = Database::open(cli.db_path)?;

    match cli.command {
        Commands::Add {
            title,
            message,
            pane,
            retention,
        } => {
            db.add(&pane, &title, &message)?;
            // Run cleanup on add
            db.cleanup(retention)?;
            println!("{{\"ok\":true}}");
        }

        Commands::Query => {
            let notifications = db.query()?;
            let resp = QueryResponse {
                ok: true,
                notifications,
            };
            println!("{}", serde_json::to_string(&resp)?);
        }

        Commands::Count => {
            let count = db.count_unread()?;
            println!("{}", count);
        }

        Commands::MarkRead { pane } => {
            db.mark_read(&pane)?;
            println!("{{\"ok\":true}}");
        }

        Commands::Dismiss { pane } => {
            db.dismiss(&pane)?;
            println!("{{\"ok\":true}}");
        }

        Commands::Cleanup { retention } => {
            let deleted = db.cleanup(retention)?;
            println!("{{\"ok\":true,\"deleted\":{}}}", deleted);
        }

        Commands::Reset => {
            // Handled above, this branch is unreachable
            unreachable!()
        }
    }

    Ok(())
}
