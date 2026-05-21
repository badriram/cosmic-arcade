//! Direct writer for cosmic-bg's on-disk config.
//!
//! cosmic-bg watches `~/.config/cosmic/com.system76.CosmicBackground/v1/`
//! via inotify (ConfigWatchSource) and re-applies wallpapers on any change.
//! We write the same RON files cosmic-settings would, so no daemon ping
//! is needed.
//!
//! Schema mirrors `pop-os/cosmic-bg/config/src/lib.rs` (verified against
//! upstream master, 2026-05). If a future version bumps to v2, the writes
//! become no-ops — detect with `is_supported()`.
//!
//! Constants from upstream:
//!   NAME              = "com.system76.CosmicBackground"
//!   BACKGROUNDS       = "backgrounds"        (Vec<String> of output names)
//!   DEFAULT_BACKGROUND = "all"               (Entry filename for same-on-all)
//!   SAME_ON_ALL       = "same-on-all"        (bool)
//! Per-output entries live under filename "output.<name>".

use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

const CONFIG_NAME: &str = "com.system76.CosmicBackground";
const CONFIG_VERSION: u32 = 1;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Source {
    Path(PathBuf),
    Color(Color),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Color {
    Single([f32; 3]),
    Gradient(Gradient),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Gradient {
    pub colors: Vec<[f32; 3]>,
    pub radius: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FilterMethod {
    Nearest,
    Linear,
    Lanczos,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ScalingMode {
    Fit([f32; 3]),
    Stretch,
    Zoom,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SamplingMethod {
    Alphanumeric,
    Random,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Entry {
    pub output: String,
    pub source: Source,
    pub filter_by_theme: bool,
    pub rotation_frequency: u64,
    pub filter_method: FilterMethod,
    pub scaling_mode: ScalingMode,
    pub sampling_method: SamplingMethod,
}

fn config_dir() -> Result<PathBuf> {
    let base = directories::BaseDirs::new().context("no HOME")?;
    Ok(base
        .config_dir()
        .join("cosmic")
        .join(CONFIG_NAME)
        .join(format!("v{CONFIG_VERSION}")))
}

/// Check the v1 directory exists or can be created — bail early if the
/// schema has moved (e.g. a v2/ alongside it that we don't understand).
pub fn is_supported() -> bool {
    if let Ok(dir) = config_dir() {
        let parent = dir.parent().map(Path::to_path_buf);
        match parent {
            Some(p) if p.exists() => {
                let has_other = fs::read_dir(&p)
                    .ok()
                    .into_iter()
                    .flatten()
                    .filter_map(|e| e.ok())
                    .any(|e| {
                        let name = e.file_name();
                        let n = name.to_string_lossy();
                        n.starts_with('v') && n != format!("v{CONFIG_VERSION}")
                    });
                !has_other
            }
            _ => true,
        }
    } else {
        false
    }
}

fn write_key<T: Serialize>(key: &str, value: &T) -> Result<()> {
    let dir = config_dir()?;
    fs::create_dir_all(&dir)?;
    let path = dir.join(key);
    let text = ron::ser::to_string(value)
        .with_context(|| format!("serializing {key}"))?;
    fs::write(&path, text).with_context(|| format!("writing {}", path.display()))?;
    Ok(())
}

/// Point every output at `image`, same-on-all.
pub fn apply_image(image: &Path) -> Result<()> {
    let entry = Entry {
        output: "all".into(),
        source: Source::Path(image.to_path_buf()),
        filter_by_theme: false,
        rotation_frequency: 0,
        filter_method: FilterMethod::Lanczos,
        scaling_mode: ScalingMode::Zoom,
        sampling_method: SamplingMethod::Alphanumeric,
    };
    write_key("backgrounds", &vec!["all".to_string()])?;
    write_key("same-on-all", &true)?;
    write_key("all", &entry)?;
    Ok(())
}
