use std::{
    fs,
    path::PathBuf,
    sync::{Arc, Mutex},
    thread,
    time::{Duration, Instant},
};

use serde::{Deserialize, Serialize};
use tauri::{PhysicalPosition, PhysicalSize, Window};

use crate::storage;

#[derive(Clone, Default)]
pub struct WindowSaveDebouncer(Arc<Mutex<Option<Instant>>>);

impl WindowSaveDebouncer {
    pub fn request(&self, window: &Window) {
        let deadline = Instant::now() + Duration::from_millis(500);
        let should_start_worker = if let Ok(mut pending) = self.0.lock() {
            let should_start = pending.is_none();
            *pending = Some(deadline);
            should_start
        } else {
            return;
        };
        if !should_start_worker {
            return;
        }

        let pending = Arc::clone(&self.0);
        let window = window.clone();
        thread::spawn(move || loop {
            let wait = match pending.lock() {
                Ok(value) => match *value {
                    Some(deadline) => deadline.saturating_duration_since(Instant::now()),
                    None => return,
                },
                Err(_) => return,
            };
            if !wait.is_zero() {
                thread::sleep(wait);
                continue;
            }
            let should_save = pending
                .lock()
                .map(|mut value| {
                    if value.is_some_and(|current| current <= Instant::now()) {
                        *value = None;
                        true
                    } else {
                        false
                    }
                })
                .unwrap_or(false);
            if should_save {
                let _ = save_window(&window);
            }
            return;
        });
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SavedWindowState {
    pub x: i32,
    pub y: i32,
    pub width: u32,
    pub height: u32,
    pub maximized: bool,
}

fn state_path() -> Result<PathBuf, String> {
    Ok(storage::ensure_data_dirs()?
        .data_dir
        .join("window-state.json"))
}

pub fn restore(window: &tauri::WebviewWindow) -> Result<(), String> {
    let path = state_path()?;
    let Ok(bytes) = fs::read(&path) else {
        return Ok(());
    };
    let state: SavedWindowState = serde_json::from_slice(&bytes)
        .map_err(|error| format!("failed to read window state: {error}"))?;

    let on_screen = window
        .available_monitors()
        .map_err(|error| error.to_string())?
        .iter()
        .any(|monitor| intersects_monitor(&state, monitor.position(), monitor.size()));

    if on_screen {
        window
            .set_size(PhysicalSize::new(state.width, state.height))
            .map_err(|error| error.to_string())?;
        window
            .set_position(PhysicalPosition::new(state.x, state.y))
            .map_err(|error| error.to_string())?;
    }

    if state.maximized {
        window.maximize().map_err(|error| error.to_string())?;
    }
    Ok(())
}

pub fn save_window(window: &Window) -> Result<(), String> {
    save_values(
        window.outer_position().map_err(|error| error.to_string())?,
        window.outer_size().map_err(|error| error.to_string())?,
        window.is_maximized().map_err(|error| error.to_string())?,
    )
}

fn save_values(
    position: PhysicalPosition<i32>,
    size: PhysicalSize<u32>,
    maximized: bool,
) -> Result<(), String> {
    let state = SavedWindowState {
        x: position.x,
        y: position.y,
        width: size.width,
        height: size.height,
        maximized,
    };
    let path = state_path()?;
    let bytes = serde_json::to_vec_pretty(&state).map_err(|error| error.to_string())?;
    fs::write(path, bytes).map_err(|error| error.to_string())
}

fn intersects_monitor(
    state: &SavedWindowState,
    monitor_position: &PhysicalPosition<i32>,
    monitor_size: &PhysicalSize<u32>,
) -> bool {
    let right = state
        .x
        .saturating_add(state.width.min(i32::MAX as u32) as i32);
    let bottom = state
        .y
        .saturating_add(state.height.min(i32::MAX as u32) as i32);
    let monitor_right = monitor_position
        .x
        .saturating_add(monitor_size.width.min(i32::MAX as u32) as i32);
    let monitor_bottom = monitor_position
        .y
        .saturating_add(monitor_size.height.min(i32::MAX as u32) as i32);
    right > monitor_position.x
        && state.x < monitor_right
        && bottom > monitor_position.y
        && state.y < monitor_bottom
}

#[cfg(test)]
mod tests {
    use tauri::{PhysicalPosition, PhysicalSize};

    use super::{intersects_monitor, SavedWindowState};

    #[test]
    fn accepts_window_partially_visible_on_any_monitor() {
        let state = SavedWindowState {
            x: 1900,
            y: 100,
            width: 400,
            height: 300,
            maximized: false,
        };
        assert!(intersects_monitor(
            &state,
            &PhysicalPosition::new(1920, 0),
            &PhysicalSize::new(1920, 1080)
        ));
    }

    #[test]
    fn rejects_window_on_disconnected_monitor() {
        let state = SavedWindowState {
            x: -1800,
            y: 100,
            width: 1200,
            height: 800,
            maximized: false,
        };
        assert!(!intersects_monitor(
            &state,
            &PhysicalPosition::new(0, 0),
            &PhysicalSize::new(1920, 1080)
        ));
    }
}
