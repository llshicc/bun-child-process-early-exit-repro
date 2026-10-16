# bun-child-process-early-exit-repro

Under `bun test` on a loaded macOS machine, `node:child_process` sometimes emits `'exit'` and `'close'` for a child that exits at once **before `spawn()` returns**. A listener attached right after `spawn()` never fires, so anything waiting on `'exit'`/`'close'` (including `exec`/`execFile` callbacks) hangs.

```sh
./run.sh                 # node:child_process spawn(), 5 rounds x 60 files
./run.sh bun control     # Bun.spawn() on the same child
./run.sh bun execfile    # promisify(execFile)
./run.sh /path/to/bun    # another Bun build
```

Each probe is one spawn per test file. `run.sh` copies it into 60 files, starts 2 × CPU-count `yes` loops, and runs `bun test --parallel=4` five times. A failing file prints a `LOST` line.

macOS 14 (Darwin 23.4.0), arm64, 5 rounds × 60 files:

| Bun | `repro` | `control` |
|---|---|---|
| 1.3.14+0d9b296af | 71/300 | 0/300 |
| 1.4.3+c6da4a4d3 | 17/300 | 0/300 |
| 1.4.4-canary.1+5f5799ed1 | 29/300 | 0/300 |

Not tested on Linux.
