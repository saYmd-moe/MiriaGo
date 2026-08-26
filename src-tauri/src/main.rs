#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

mod commands;
#[cfg(test)]
mod csp;
mod desktop_db;
mod diagnostics;
mod storage;
mod window_state;

use tauri::{Emitter, Manager};

#[cfg(target_os = "linux")]
fn is_kde_desktop(desktops: &str) -> bool {
    desktops
        .split(':')
        .any(|desktop| desktop.eq_ignore_ascii_case("kde"))
}

#[cfg(target_os = "linux")]
fn configure_linux_desktop_environment() {
    if std::env::var_os("GTK_USE_PORTAL").is_some() {
        return;
    }

    let is_kde = std::env::var("XDG_CURRENT_DESKTOP")
        .ok()
        .is_some_and(|desktops| is_kde_desktop(&desktops));
    if is_kde {
        // GTK file choosers then use xdg-desktop-portal-kde instead of a
        // foreign-looking GTK dialog. Respect an explicit user override.
        std::env::set_var("GTK_USE_PORTAL", "1");
    }
}

fn main() {
    #[cfg(target_os = "linux")]
    configure_linux_desktop_environment();

    let pending_plan_files = commands::PendingPlanFiles::from_args(std::env::args());
    let window_save_debouncer = window_state::WindowSaveDebouncer::default();
    tauri::Builder::default()
        .manage(pending_plan_files)
        .manage(window_save_debouncer.clone())
        .plugin(tauri_plugin_single_instance::init(|app, args, _cwd| {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.unminimize();
                let _ = window.show();
                let _ = window.set_focus();
            }
            if let Some(pending) = app.try_state::<commands::PendingPlanFiles>() {
                let plan_files = args
                    .iter()
                    .filter(|path| std::path::Path::new(path.as_str()).is_file())
                    .filter(|path| {
                        std::path::Path::new(path.as_str())
                            .extension()
                            .and_then(|extension| extension.to_str())
                            .is_some_and(|extension| extension.eq_ignore_ascii_case("sjhplan"))
                    })
                    .cloned()
                    .collect::<Vec<_>>();
                pending.add_args(plan_files.iter().cloned());
                if !plan_files.is_empty() {
                    let _ = app.emit("miriago://open-plan-file", ());
                }
            }
        }))
        .plugin(tauri_plugin_notification::init())
        .setup(|app| {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window_state::restore(&window);
            }
            Ok(())
        })
        .on_window_event(move |window, event| match event {
            tauri::WindowEvent::Moved(_) | tauri::WindowEvent::Resized(_) => {
                window_save_debouncer.request(window);
            }
            tauri::WindowEvent::CloseRequested { .. } => {
                let _ = window_state::save_window(window);
            }
            _ => {}
        })
        .invoke_handler(tauri::generate_handler![
            commands::launcher_info,
            commands::ensure_data_dirs,
            commands::runtime_diagnostics,
            commands::prepare_export_destination,
            commands::write_export_file,
            commands::load_desktop_state,
            commands::save_desktop_state,
            commands::save_desktop_plan_bundle,
            commands::delete_desktop_plan,
            commands::set_desktop_active_plan,
            commands::save_desktop_settings,
            commands::save_desktop_visit_record,
            commands::delete_desktop_visit_record,
            commands::restore_import_assets,
            commands::write_asset,
            commands::read_asset,
            commands::reference_cache_stats,
            commands::clear_reference_cache,
            commands::fetch_anitabi_static_json,
            commands::open_external_url,
            commands::take_pending_plan_files,
            commands::desktop_diagnostics,
            commands::notify_desktop_task
        ])
        .run(tauri::generate_context!())
        .expect("failed to run MiriaGo desktop launcher");
}

#[cfg(all(test, target_os = "linux"))]
mod tests {
    use super::is_kde_desktop;

    #[test]
    fn kde_desktop_detection_is_case_insensitive_and_supports_lists() {
        for value in ["KDE", "kde", "KDE:GNOME", "Unity:KDE"] {
            assert!(is_kde_desktop(value), "{value} should be detected as KDE");
        }
        assert!(!is_kde_desktop("GNOME:Unity"));
    }
}
