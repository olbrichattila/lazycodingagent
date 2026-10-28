# SQLite amalgamation (vendored)

Official amalgamation from [sqlite.org](https://www.sqlite.org/download.html). Version in `VERSION.txt`.

## Build flags (via `scripts/build-sqlite-static.sh` / `.ps1`)

- **Windows (default):** The app links **`winsqlite3.dll`** (shipped with Windows 10+) via [`uSqlite3Embed.pas`](../../packages/LazySqliteStatic/src/uSqlite3Embed.pas). MSVC **`sqlite3_embed.o` + FPC 3.2.x internal linker** still links with [`uSqliteWinEmbedBridge.pas`](../../packages/LazySqliteStatic/src/uSqliteWinEmbedBridge.pas) but **faults in `sqlite3_initialize` at runtime**; define **`LCA_SQLITE_EMBED_WIN`** on the project to try that experimental static path (CI embed build remains for future fixes / non-Windows parity).
- **Windows embed build:** `build-sqlite-static.ps1` compiles with **MSVC `cl.exe`** by default (COFF for FPC). Set **`SQLITE_CC=clang`** to use **LLVM Clang** with `-target x86_64-pc-windows-msvc` instead (no Build Tools required if Windows SDK + Clang are on PATH). **`cl` must use `/Gy-`** plus `/GS-`, `/guard:cf-`, and `/Zl` so FPC 3.2.x avoids COMDAT `.pdata`/`.xdata` errors; the script sets these for MSVC. After compile, **MinGW `objcopy -R .drectve`** strips MSVC linker directives. **Linking** uses FPC’s **internal linker** and the bridge unit (`public name` forwarders for Win32/CRT symbols from the embed object). MinGW **`gcc`** objects are not supported. **Linux/macOS:** GCC/Clang with `-Wno-discarded-qualifiers` (or `-Wno-ignored-qualifiers` on Darwin) — silences a known warning in the upstream amalgamation (`sqlite3ShadowTableName`); we do not patch vendored `sqlite3.c` for that.
- `SQLITE_ENABLE_FTS5` — keyword search for future workspace knowledge base
- `SQLITE_THREADSAFE=1`
- `SQLITE_ENABLE_JSON1`

Runtime: WAL mode is enabled in `uAppDatabase` when opening databases.

## Future: sqlite-vec (Phase B)

When profiling requires approximate nearest-neighbor search, extend the amalgamation build to compile **sqlite-vec** into the same static object (see `future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md` §7.2). Use `BUILD_SQLITE_VEC=1` when that hook is implemented.

## License

SQLite is in the public domain. See the blessing in `sqlite3.h`.
