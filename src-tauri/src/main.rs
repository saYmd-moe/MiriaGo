#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

mod commands;
#[cfg(test)]
mod csp;
mod desktop_db;
mod storage;

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

    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            commands::launcher_info,
            commands::ensure_data_dirs,
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
            commands::fetch_anitabi_static_json,
            commands::open_external_url
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
