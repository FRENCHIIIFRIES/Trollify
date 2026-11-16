"""sysinfo 0.36.1 calls libc::proc_pidinfo in open_files(), which does not exist for iOS.
Replace that one function with a stub so the crate compiles for aarch64-apple-ios."""
import glob, os, re

files = glob.glob(os.path.expanduser("~/.cargo/registry/src/*/sysinfo-0.36.*/src/unix/apple/process.rs"))
assert files, "sysinfo source not found - run cargo fetch first"
for f in files:
    s = open(f).read()
    new, n = re.subn(r"pub\(crate\) fn open_files\(&self\) -> Option<usize> \{.*?\n    \}\n",
                     "pub(crate) fn open_files(&self) -> Option<usize> {\n        None\n    }\n", s, count=1, flags=re.S)
    print(f, "patched" if n else "NOT PATCHED (pattern missing)")
    assert n == 1 or "None\n    }" in s
    open(f, "w").write(new)
