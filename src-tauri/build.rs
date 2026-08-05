fn main() {
    const COMMANDS: &[&str] = &[
        "probe_environment",
        "load_runtime_schema",
        "inspect_extension_manifest",
        "load_config_graph",
        "open_config",
        "prepare_create_config_confirmation",
        "create_config",
        "stage_changes",
        "prepare_apply_changes_confirmation",
        "apply_changes",
        "list_snapshots",
        "prepare_restore_snapshot_confirmation",
        "restore_snapshot",
    ];

    tauri_build::try_build(
        tauri_build::Attributes::new()
            .app_manifest(tauri_build::AppManifest::new().commands(COMMANDS)),
    )
    .expect("failed to generate Tauri context");
}
