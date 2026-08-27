#[cfg(test)]
mod tests {
    fn policy() -> String {
        let path = concat!(env!("CARGO_MANIFEST_DIR"), "/tauri.conf.json");
        let text = std::fs::read_to_string(path).expect("tauri.conf.json should exist");
        let config: serde_json::Value =
            serde_json::from_str(&text).expect("tauri.conf.json should be valid JSON");
        config["app"]["security"]["csp"]
            .as_str()
            .expect("app.security.csp must be a non-null string")
            .to_owned()
    }

    fn sources<'a>(csp: &'a str, name: &str) -> Vec<&'a str> {
        csp.split(';')
            .filter_map(|part| {
                let (directive, values) = part.trim().split_once(' ')?;
                (directive == name).then_some(values.split_whitespace())
            })
            .flatten()
            .collect()
    }

    #[test]
    fn desktop_build_uses_the_local_flutter_web_resource_helper() {
        let path = concat!(env!("CARGO_MANIFEST_DIR"), "/tauri.conf.json");
        let text = std::fs::read_to_string(path).expect("tauri.conf.json should exist");
        let config: serde_json::Value =
            serde_json::from_str(&text).expect("tauri.conf.json should be valid JSON");
        assert_eq!(
            config["build"]["beforeBuildCommand"],
            "bash scripts/build-flutter-web.sh --release"
        );
        assert_eq!(
            config["build"]["beforeDevCommand"],
            "bash scripts/build-flutter-web.sh --debug"
        );
    }

    #[test]
    fn csp_is_non_null_and_restricts_script_surfaces() {
        let csp = policy();
        assert!(!csp.trim().is_empty());
        let scripts = sources(&csp, "script-src");
        assert!(scripts.contains(&"'self'"));
        assert!(scripts.contains(&"'wasm-unsafe-eval'"));
        assert!(!scripts.contains(&"'unsafe-inline'"));
        assert!(!scripts.contains(&"'unsafe-eval'"));
        assert_eq!(sources(&csp, "object-src"), ["'none'"]);
        assert_eq!(sources(&csp, "base-uri"), ["'self'"]);
        assert_eq!(
            sources(&csp, "script-src"),
            ["'self'", "'wasm-unsafe-eval'"]
        );
        assert_eq!(sources(&csp, "style-src"), ["'self'", "'unsafe-inline'"]);
        assert!(!csp.contains("unpkg.com"));
    }

    #[test]
    fn tauri_csp_manifest_is_unchanged() {
        assert_eq!(
            policy(),
            "default-src 'self'; base-uri 'self'; object-src 'none'; frame-src 'self'; worker-src 'self' blob:; font-src 'self'; img-src 'self' data: blob: https://image.anitabi.cn https://img-tc.anitabi.cn https:; style-src 'self' 'unsafe-inline'; script-src 'self' 'wasm-unsafe-eval'; connect-src 'self' https:;"
        );
    }

    #[test]
    fn csp_allows_default_remote_resources_without_plain_http() {
        let csp = policy();
        let connects = sources(&csp, "connect-src");
        assert!(connects.contains(&"'self'"));
        assert!(connects.contains(&"https:"));
        assert!(!connects.contains(&"http:"));

        let images = sources(&csp, "img-src");
        for source in [
            "https://image.anitabi.cn",
            "https://img-tc.anitabi.cn",
            "data:",
            "blob:",
        ] {
            assert!(images.contains(&source), "img-src must allow {source}");
        }
    }

    #[test]
    fn csp_remains_valid_when_m3_removes_the_map_cdn() {
        let csp = policy();
        for directive in [
            "default-src",
            "style-src",
            "script-src",
            "img-src",
            "connect-src",
        ] {
            assert!(!sources(&csp, directive).is_empty());
        }
        assert!(csp.contains("'self'"));
    }
}
