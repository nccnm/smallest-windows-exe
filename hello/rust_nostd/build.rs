fn main() {
    // No CRT: our own entry point, no default libraries, compact image.
    for a in ["/NODEFAULTLIB", "/ENTRY:start", "/SUBSYSTEM:CONSOLE", "/DYNAMICBASE:NO", "/FIXED",
              "/MANIFEST:NO", "/EMITTOOLVERSIONINFO:NO", "/MERGE:.rdata=.text",
              "/MERGE:.pdata=.text", "/ALIGN:16", "/FILEALIGN:16", "/SECTION:.text,ERW"] {
        println!("cargo:rustc-link-arg-bins={a}");
    }
}
