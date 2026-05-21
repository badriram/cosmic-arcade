use clap::{Parser, Subcommand};

use crate::commands;

const LONG_ABOUT: &str = "\
Cosmic Arcade configuration tool.

Examples:
  arcade-cli background set bing true    # rotate Bing's daily image as wallpaper
  arcade-cli background set bing false   # stop rotating
  arcade-cli background get              # show the active source
  arcade-cli background refresh          # fetch + apply now (also runs on a timer)";

#[derive(Parser)]
#[command(
    name = "arcade-cli",
    version,
    about = "Cosmic Arcade configuration tool",
    long_about = LONG_ABOUT,
    arg_required_else_help = true,
    subcommand_required = true,
)]
pub struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
#[command(arg_required_else_help = true)]
enum Command {
    /// Manage the desktop background
    Background {
        #[command(subcommand)]
        action: BackgroundAction,
    },
}

#[derive(Subcommand)]
#[command(arg_required_else_help = true)]
pub enum BackgroundAction {
    /// Show the active background source
    Get,
    /// Enable or disable a background source (currently: bing)
    Set {
        /// Background source — one of: bing
        source: String,
        /// true/false, on/off, yes/no, 1/0
        #[arg(value_parser = clap::builder::BoolishValueParser::new())]
        value: bool,
    },
    /// Fetch and apply the latest image for the active source
    Refresh,
}

impl Cli {
    pub fn run() -> anyhow::Result<()> {
        let cli = <Self as Parser>::parse();
        match cli.command {
            Command::Background { action } => commands::background::run(action),
        }
    }
}
