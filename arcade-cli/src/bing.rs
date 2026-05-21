use std::fs;
use std::path::{Path, PathBuf};
use std::time::Duration;

use anyhow::{anyhow, Context, Result};
use serde::Deserialize;

const ARCHIVE_URL: &str =
    "https://www.bing.com/HPImageArchive.aspx?format=js&n=1&mkt=en-US";

#[derive(Debug, Deserialize)]
struct Archive {
    images: Vec<Image>,
}

#[derive(Debug, Deserialize)]
struct Image {
    /// Relative path like "/th?id=OHR.Foo_EN-US123_1920x1080.jpg&..."
    url: String,
    /// "YYYYMMDD"
    startdate: String,
}

fn client() -> Result<reqwest::blocking::Client> {
    Ok(reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(30))
        .user_agent("arcade-cli")
        .build()?)
}

/// Download today's Bing image into `cache_dir`. Returns the file path.
/// Skips download if the dated file already exists.
pub fn fetch_today(cache_dir: &Path) -> Result<PathBuf> {
    fs::create_dir_all(cache_dir)?;
    let http = client()?;

    let archive: Archive = http
        .get(ARCHIVE_URL)
        .send()
        .context("fetching Bing archive")?
        .error_for_status()?
        .json()
        .context("parsing Bing archive JSON")?;

    let image = archive
        .images
        .into_iter()
        .next()
        .ok_or_else(|| anyhow!("Bing archive returned no images"))?;

    let dest = cache_dir.join(format!("bing-{}.jpg", image.startdate));
    if dest.exists() {
        return Ok(dest);
    }

    let full_url = if image.url.starts_with("http") {
        image.url.clone()
    } else {
        format!("https://www.bing.com{}", image.url)
    };

    let bytes = http
        .get(&full_url)
        .send()
        .with_context(|| format!("downloading {full_url}"))?
        .error_for_status()?
        .bytes()?;

    fs::write(&dest, &bytes)
        .with_context(|| format!("writing {}", dest.display()))?;

    Ok(dest)
}

pub fn cache_dir() -> Result<PathBuf> {
    let dirs = directories::ProjectDirs::from("", "", "arcade-cli")
        .context("no cache dir")?;
    Ok(dirs.cache_dir().join("bing"))
}
