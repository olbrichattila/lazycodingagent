# SQLite amalgamation (vendored)

Official amalgamation from [sqlite.org](https://www.sqlite.org/download.html). Version in `VERSION.txt`.

## Build flags (via `scripts/build-sqlite-static.sh` / `.ps1`)

- **Windows:** `build-sqlite-static.ps1` uses **MSVC `cl.exe`** (COFF object). **`cl` must use `/Gy-`** (no function-level COMDATs) plus `/GS-`, `/guard:cf-`, and `/Zl` so FPC 3.2.x does not fail on associative `.pdata`/`.xdata` at link time; the script sets these automatically. After compile, **MinGW `objcopy -R .drectve`** strips MSVC linker directives so **`-Xe` (link.exe)** can consume the embed object. CI passes Windows/MSVC import libs via `scripts/ci-lazbuild.ps1` when linking `lazycodingagent.lpi`. MinGW `gcc` objects are not supported on Win64. **Linux/macOS:** GCC/Clang with `-Wno-discarded-qualifiers` (or `-Wno-ignored-qualifiers` on Darwin) — silences a known warning in the upstream amalgamation (`sqlite3ShadowTableName`); we do not patch vendored `sqlite3.c` for that.
- `SQLITE_ENABLE_FTS5` — keyword search for future workspace knowledge base
- `SQLITE_THREADSAFE=1`
- `SQLITE_ENABLE_JSON1`

Runtime: WAL mode is enabled in `uAppDatabase` when opening databases.

## Future: sqlite-vec (Phase B)

When profiling requires approximate nearest-neighbor search, extend the amalgamation build to compile **sqlite-vec** into the same static object (see `future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md` §7.2). Use `BUILD_SQLITE_VEC=1` when that hook is implemented.

## License

SQLite is in the public domain. See the blessing in `sqlite3.h`.
