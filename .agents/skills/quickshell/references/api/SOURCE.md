# Source of this reference

Generated on 2026-10-05 from the Quickshell source at tag **v0.3.1** (https://github.com/quickshell-mirror/quickshell, LGPL-3.0) using the project's own `typegen` tool from https://github.com/quickshell-mirror/quickshell-docs, then converted to Markdown.

The text of each entry comes from the doc comments in the Quickshell source. To regenerate for a newer release:

```sh
git clone --depth 1 --branch vX.Y.Z https://github.com/quickshell-mirror/quickshell qs
git clone --depth 1 https://github.com/quickshell-mirror/quickshell-docs qsdocs
cd qsdocs/typegen && cargo build && cd ..
mkdir -p data/modules build/types/types content/docs/types
./typegen/target/debug/typegen fulltypegen ../qs/src build/types/types data/modules content/docs/types types
python3 qs2md.py data/modules <skill>/references/api   # qs2md.py ships in this skill's scripts/
```
