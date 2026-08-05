#[cfg(target_os = "linux")]
use std::path::{Path, PathBuf};

#[cfg(target_os = "linux")]
fn private_gio_module_dir(appdir: &Path, path_exists: impl Fn(&Path) -> bool) -> PathBuf {
    let architecture_dir = match std::env::consts::ARCH {
        "x86_64" => Some("x86_64-linux-gnu"),
        "aarch64" => Some("aarch64-linux-gnu"),
        _ => None,
    };
    if let Some(architecture_dir) = architecture_dir {
        let candidate = appdir
            .join("usr/lib")
            .join(architecture_dir)
            .join("gio/modules");
        if path_exists(&candidate) {
            return candidate;
        }
    }

    // A private, possibly empty directory prevents the bundled GLib from
    // loading ABI-incompatible GVFS modules from the host.
    appdir.join("usr/lib/gio/modules")
}

pub fn prepare() {
    #[cfg(target_os = "linux")]
    if let Some(appdir) = std::env::var_os("APPDIR") {
        let module_dir = private_gio_module_dir(Path::new(&appdir), Path::exists);
        std::env::set_var("GIO_MODULE_DIR", module_dir);
        std::env::remove_var("GIO_EXTRA_MODULES");
    }
}

#[cfg(all(test, target_os = "linux"))]
mod tests {
    use super::*;

    #[test]
    fn selects_bundled_multiarch_modules_when_present() {
        let appdir = Path::new("/tmp/appdir");
        let expected = appdir.join("usr/lib/x86_64-linux-gnu/gio/modules");
        assert_eq!(
            private_gio_module_dir(appdir, |candidate| candidate == expected),
            expected
        );
    }

    #[test]
    fn falls_back_to_an_appdir_private_module_directory() {
        let appdir = Path::new("/tmp/appdir");
        assert_eq!(
            private_gio_module_dir(appdir, |_| false),
            appdir.join("usr/lib/gio/modules")
        );
    }
}
