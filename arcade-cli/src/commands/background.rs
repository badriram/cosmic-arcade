use std::process::Command;

use anyhow::{bail, Context, Result};

use crate::bing;
use crate::cli::BackgroundAction;
use crate::config::ArcadeConfig;
use crate::cosmic;

const TIMER_UNIT: &str = "arcade-background.timer";

pub fn run(action: BackgroundAction) -> Result<()> {
    match action {
        BackgroundAction::Get => get(),
        BackgroundAction::Set { source, value } => set(&source, value),
        BackgroundAction::Refresh => refresh(),
    }
}

fn get() -> Result<()> {
    let cfg = ArcadeConfig::load()?;
    println!("source = {}", cfg.background.source);
    Ok(())
}

fn set(source: &str, value: bool) -> Result<()> {
    match source {
        "bing" => set_bing(value),
        other => bail!("unknown background source: {other} (known: bing)"),
    }
}

fn set_bing(enable: bool) -> Result<()> {
    let mut cfg = ArcadeConfig::load()?;
    if enable {
        cfg.background.source = "bing".into();
        cfg.save()?;
        systemctl_user(&["enable", "--now", TIMER_UNIT]).ok();
        refresh()?;
        println!("Bing background enabled.");
    } else {
        if cfg.background.source == "bing" {
            cfg.background.source = "none".into();
            cfg.save()?;
        }
        systemctl_user(&["disable", "--now", TIMER_UNIT]).ok();
        println!("Bing background disabled.");
    }
    Ok(())
}

fn refresh() -> Result<()> {
    let cfg = ArcadeConfig::load()?;
    match cfg.background.source.as_str() {
        "none" => {
            eprintln!("no background source active; nothing to refresh");
            Ok(())
        }
        "bing" => {
            if !cosmic::is_supported() {
                bail!("cosmic-bg config schema looks unfamiliar (v1/ missing or shadowed); aborting");
            }
            let cache = bing::cache_dir()?;
            let image = bing::fetch_today(&cache)
                .context("fetching today's Bing image")?;
            cosmic::apply_image(&image)?;
            println!("applied {}", image.display());
            Ok(())
        }
        other => bail!("unknown source in config: {other}"),
    }
}

fn systemctl_user(args: &[&str]) -> Result<()> {
    let status = Command::new("systemctl")
        .arg("--user")
        .args(args)
        .status()
        .context("invoking systemctl --user")?;
    if !status.success() {
        bail!("systemctl --user {:?} exited with {status}", args);
    }
    Ok(())
}
