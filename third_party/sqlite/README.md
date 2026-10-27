# SQLite amalgamation (vendored)

Official amalgamation from [sqlite.org](https://www.sqlite.org/download.html). Version in `VERSION.txt`.

## Build flags (via `scripts/build-sqlite-static.sh` / `.ps1`)

- `-Wno-discarded-qualifiers` — silences a known GCC warning in the upstream amalgamation (`sqlite3ShadowTableName`); we do not patch vendored `sqlite3.c` for that.
- `SQLITE_ENABLE_FTS5` — keyword search for future workspace knowledge base
- `SQLITE_THREADSAFE=1`
- `SQLITE_ENABLE_JSON1`

Runtime: WAL mode is enabled in `uAppDatabase` when opening databases.

## Future: sqlite-vec (Phase B)

When profiling requires approximate nearest-neighbor search, extend the amalgamation build to compile **sqlite-vec** into the same static object (see `future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md` §7.2). Use `BUILD_SQLITE_VEC=1` when that hook is implemented.

## License

SQLite is in the public domain. See the blessing in `sqlite3.h`.
