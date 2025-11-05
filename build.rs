use std::fs;
use std::path::Path;

fn main() {
    let out_dir = std::env::var("OUT_DIR").unwrap();
    let target_dir = Path::new(&out_dir).parent().unwrap().parent().unwrap().parent().unwrap();

    // Copy jcd_function.sh to target/release (or target/debug)
    let src_sh = "src/jcd_function.sh";
    let dst_sh = target_dir.join("jcd_function.sh");

    if let Err(e) = fs::copy(src_sh, &dst_sh) {
        println!("cargo:warning=Failed to copy {}: {}", src_sh, e);
    } else {
        println!("cargo:warning=Copied {} to {}", src_sh, dst_sh.display());
    }

    // Copy jcd_function.ps1 to target/release (or target/debug)
    let src_ps1 = "src/jcd_function.ps1";
    let dst_ps1 = target_dir.join("jcd_function.ps1");

    if let Err(e) = fs::copy(src_ps1, &dst_ps1) {
        println!("cargo:warning=Failed to copy {}: {}", src_ps1, e);
    } else {
        println!("cargo:warning=Copied {} to {}", src_ps1, dst_ps1.display());
    }

    // Tell cargo to rerun this script if either function file changes
    println!("cargo:rerun-if-changed=src/jcd_function.sh");
    println!("cargo:rerun-if-changed=src/jcd_function.ps1");
}