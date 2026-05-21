mod bing;
mod cli;
mod commands;
mod config;
mod cosmic;

fn main() -> anyhow::Result<()> {
    cli::Cli::run()
}
