use std::fs;
use std::path::PathBuf;

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ArcadeConfig {
    #[serde(default)]
    pub background: BackgroundConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackgroundConfig {
    /// Active source — "none" or "bing".
    pub source: String,
}

impl Default for BackgroundConfig {
    fn default() -> Self {
        Self { source: "none".into() }
    }
}

impl ArcadeConfig {
    pub fn path() -> Result<PathBuf> {
        let dirs = directories::ProjectDirs::from("", "", "arcade-cli")
            .context("could not resolve XDG config dir")?;
        Ok(dirs.config_dir().join("config.toml"))
    }

    pub fn load() -> Result<Self> {
        let path = Self::path()?;
        if !path.exists() {
            return Ok(Self::default());
        }
        let text = fs::read_to_string(&path)
            .with_context(|| format!("reading {}", path.display()))?;
        Ok(toml::from_str(&text)?)
    }

    pub fn save(&self) -> Result<()> {
        let path = Self::path()?;
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(&path, toml::to_string_pretty(self)?)?;
        Ok(())
    }
}
