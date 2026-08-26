//! M0 read-only runtime diagnostics foundation.
//!
//! This module gathers *read-only* environment and version information that
//! milestone M0 needs as a baseline: app/Tauri/WebKitGTK versions, the display
//! session and desktop environment, the configured data directory, and a
//! configuration-derived portal backend hint. It also provides the log
//! redaction rules used by future logging.
//!
//! Scope boundary: M0 only provides the read-only data source and redaction
//! primitives. The M5 milestone owns the full "copy / export diagnostics" UI
//! entry point and any live D-Bus portal probing. This module deliberately
//! does not perform network or privileged queries, and never mutates state.

#[cfg(target_os = "linux")]
use std::process::Command;

use serde::Serialize;

use crate::storage;

/// Read-only snapshot of the runtime environment and versions.
#[derive(Debug, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct RuntimeDiagnostics {
    pub app_version: String,
    pub tauri_version: String,
    /// WebKitGTK version (Linux only). `None` when it cannot be detected.
    pub webkitgtk_version: Option<String>,
    /// `XDG_SESSION_TYPE`, e.g. "wayland" or "x11".
    pub session_type: Option<String>,
    /// `XDG_SESSION_DESKTOP`, e.g. "plasma".
    pub session_desktop: Option<String>,
    /// `XDG_CURRENT_DESKTOP`, e.g. "KDE".
    pub current_desktop: Option<String>,
    /// `DISPLAY` (X11) when set.
    pub display: Option<String>,
    /// `WAYLAND_DISPLAY` (Wayland) when set.
    pub wayland_display: Option<String>,
    /// `GTK_USE_PORTAL` as configured; the Linux launcher sets it for KDE.
    pub gtk_use_portal: Option<String>,
    /// Configuration-derived portal backend hint: "kde", "gtk", or "unknown".
    /// This reflects which backend the launcher would use, not a live probe.
    pub portal_backend: Option<String>,
    pub data_dir: String,
    pub logs_dir: String,
}

/// Collects a read-only diagnostics snapshot.
pub fn collect() -> Result<RuntimeDiagnostics, String> {
    let dirs = storage::resolve_data_dirs()?;
    let session_type = env_option("XDG_SESSION_TYPE");
    let current_desktop = env_option("XDG_CURRENT_DESKTOP");
    let gtk_use_portal = env_option("GTK_USE_PORTAL");

    Ok(RuntimeDiagnostics {
        app_version: env!("CARGO_PKG_VERSION").to_string(),
        tauri_version: tauri::VERSION.to_string(),
        webkitgtk_version: webkitgtk_version(),
        session_type,
        session_desktop: env_option("XDG_SESSION_DESKTOP"),
        current_desktop: current_desktop.clone(),
        display: env_option("DISPLAY"),
        wayland_display: env_option("WAYLAND_DISPLAY"),
        gtk_use_portal: gtk_use_portal.clone(),
        portal_backend: portal_backend_hint(current_desktop.as_deref(), gtk_use_portal.as_deref()),
        data_dir: dirs.data_dir.display().to_string(),
        logs_dir: dirs.logs_dir.display().to_string(),
    })
}

/// Best-effort WebKitGTK version via `pkg-config` (read-only). Returns `None`
/// when the package or the tool is not available.
#[cfg(target_os = "linux")]
fn webkitgtk_version() -> Option<String> {
    for package in ["webkit2gtk-4.1", "webkit2gtk-4.0"] {
        let output = Command::new("pkg-config")
            .arg("--modversion")
            .arg(package)
            .output()
            .ok()?;
        if output.status.success() {
            let version = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !version.is_empty() {
                return Some(version);
            }
        }
    }
    None
}

#[cfg(not(target_os = "linux"))]
fn webkitgtk_version() -> Option<String> {
    None
}

/// Derives a portal backend hint from configuration only: KDE sessions prefer
/// the KDE portal backend, and only an explicitly enabled (`1`) GTK_USE_PORTAL
/// selects the GTK portal. Anything else is reported as unknown rather than
/// guessed.
fn portal_backend_hint(
    current_desktop: Option<&str>,
    gtk_use_portal: Option<&str>,
) -> Option<String> {
    let is_kde = current_desktop.is_some_and(|value| {
        value
            .split(':')
            .any(|entry| entry.eq_ignore_ascii_case("kde"))
    });
    if is_kde {
        Some("kde".to_string())
    } else if gtk_use_portal.is_some_and(|value| value.trim() == "1") {
        Some("gtk".to_string())
    } else {
        Some("unknown".to_string())
    }
}

fn env_option(name: &str) -> Option<String> {
    std::env::var(name)
        .ok()
        .filter(|value| !value.trim().is_empty())
}

/// Redacts sensitive values from a log line.
///
/// Applied rules, matching `docs/linux/log-redaction.md`:
/// - URL credentials (`scheme://user:pass@host`) are stripped to `***@host`.
/// - Sensitive query/fragment parameters are replaced with `[REDACTED]`.
/// - A home directory prefix is collapsed to `~` so full user paths are not
///   written to logs.
///
/// These redaction primitives are the M0 foundation for future logging; they
/// are not yet consumed by runtime code, hence the dead-code allowance until
/// the M5 logging/entry point wires them in.
#[cfg_attr(not(test), allow(dead_code))]
pub fn redact_for_log(input: &str) -> String {
    let home = std::env::var("HOME").ok().filter(|h| !h.is_empty());
    redact_for_log_with_home(input, home.as_deref())
}

/// Same as [`redact_for_log`] but with an explicit home directory, so tests
/// are deterministic regardless of the host's `HOME`.
pub fn redact_for_log_with_home(input: &str, home: Option<&str>) -> String {
    redact_url_credentials(redact_sensitive_params(redact_home(input, home)))
}

#[cfg_attr(not(test), allow(dead_code))]
const SENSITIVE_PARAMS: &[&str] = &[
    "token",
    "access_token",
    "refresh_token",
    "api_key",
    "apikey",
    "key",
    "password",
    "passwd",
    "pwd",
    "secret",
    "authorization",
    "signature",
    "sig",
    "client_secret",
];

#[cfg_attr(not(test), allow(dead_code))]
fn redact_home(input: &str, home: Option<&str>) -> String {
    match home {
        Some(home) if !home.is_empty() => input.replace(home, "~"),
        _ => input.to_string(),
    }
}

#[cfg_attr(not(test), allow(dead_code))]
fn redact_url_credentials(input: String) -> String {
    // `scheme://user:pass@host` -> `scheme://***@host`
    let mut result = input;
    let schemes = ["https://", "http://", "ftp://"];
    for scheme in schemes {
        let mut search_from = 0;
        while let Some(relative_from) = result[search_from..].find(scheme) {
            let start = search_from + relative_from + scheme.len();
            if let Some(abs_at) = find_userinfo_at(&result, start) {
                let prefix = &result[..start];
                let suffix = &result[abs_at + 1..]; // drop trailing '@'
                result = format!("{prefix}***@{suffix}");
                search_from = start;
            } else {
                search_from = start;
            }
        }
    }
    result
}

/// Returns the absolute index of the `@` for a `user:pass@host` userinfo
/// segment starting at `start`, or `None` when there is no credential.
#[cfg_attr(not(test), allow(dead_code))]
fn find_userinfo_at(text: &str, start: usize) -> Option<usize> {
    let end = text[start..]
        .find(|c: char| c == '/' || c == '?' || c == '#' || c.is_whitespace())
        .map(|i| start + i)
        .unwrap_or(text.len());
    let segment = &text[start..end];
    let at = segment.find('@')?;
    if !segment[..at].contains(':') {
        return None;
    }
    Some(start + at)
}

#[cfg_attr(not(test), allow(dead_code))]
fn redact_sensitive_params(input: String) -> String {
    use regex::Regex;

    // A sensitive key followed by `=` and a non-empty value running until the
    // next query/argument delimiter. The Rust `regex` crate has no look-around,
    // so we match `key=value` directly; over-redaction is safe, under-redaction
    // is not.
    let mut result = input;
    for key in SENSITIVE_PARAMS {
        let re = format!(r"(?i)({key}\s*=\s*)[^&;\s]+");
        if let Ok(regex) = Regex::new(&re) {
            result = regex.replace_all(&result, "${1}[REDACTED]").into_owned();
        }
    }
    result
}

#[cfg(test)]
mod tests {
    use super::{collect, portal_backend_hint, redact_for_log, redact_for_log_with_home};

    #[test]
    fn collect_reports_versions_and_paths_without_initializing_storage() {
        let report = collect().expect("diagnostics should resolve on the test host");
        assert!(!report.app_version.is_empty());
        assert!(!report.tauri_version.is_empty());
        assert!(!report.data_dir.is_empty());
        assert!(!report.logs_dir.is_empty());
    }

    #[test]
    fn portal_backend_prefers_kde() {
        assert_eq!(
            portal_backend_hint(Some("KDE"), Some("1")),
            Some("kde".to_string())
        );
        assert_eq!(
            portal_backend_hint(Some("GNOME"), Some("1")),
            Some("gtk".to_string())
        );
        assert_eq!(
            portal_backend_hint(Some("GNOME"), None),
            Some("unknown".to_string())
        );
        assert_eq!(portal_backend_hint(None, None), Some("unknown".to_string()));
    }

    #[test]
    fn portal_backend_requires_explicit_gtk_enablement() {
        assert_eq!(
            portal_backend_hint(Some("GNOME"), Some("0")),
            Some("unknown".to_string())
        );
        assert_eq!(
            portal_backend_hint(Some("GNOME"), Some("")),
            Some("unknown".to_string())
        );
        assert_eq!(
            portal_backend_hint(Some("GNOME"), Some(" 0 ")),
            Some("unknown".to_string())
        );
    }

    #[test]
    fn redact_strips_url_credentials() {
        let out = redact_for_log("fetching https://user:s3cr3t@cdn.example.com/image.png");
        assert!(!out.contains("s3cr3t"), "output leaked password: {out}");
        assert!(
            out.contains("***@cdn.example.com"),
            "credential not replaced: {out}"
        );
    }

    #[test]
    fn redact_replaces_sensitive_query_params() {
        let out = redact_for_log("GET https://host/api?token=abc123&x=1");
        assert!(!out.contains("abc123"), "output leaked token: {out}");
        assert!(
            out.contains("token=[REDACTED]"),
            "token not redacted: {out}"
        );
        assert!(
            out.contains("x=1"),
            "non-sensitive param should remain: {out}"
        );
    }

    #[test]
    fn redact_handles_api_key_and_password_params() {
        let out = redact_for_log("url?api_key=deadbeef password=hunter2");
        assert!(!out.contains("deadbeef"));
        assert!(!out.contains("hunter2"));
        assert!(out.contains("api_key=[REDACTED]"));
        assert!(out.contains("password=[REDACTED]"));
    }

    #[test]
    fn redact_collapses_home_path_when_home_is_given() {
        // Deterministic regardless of the host's HOME.
        let out = redact_for_log_with_home(
            "/home/example/.local/share/MiriaGo/miriago.sqlite",
            Some("/home/example"),
        );
        assert_eq!(out, "~/.local/share/MiriaGo/miriago.sqlite");

        // When no home is known, the path is left untouched.
        let out = redact_for_log_with_home("/home/example/x", None);
        assert_eq!(out, "/home/example/x");
    }
}
