## Kit scope — read before running

**Not the default retrieval path.** This kit's default for "where is X defined / who calls it /
what type is this" is the LSP plugin + grep: compiler-accurate, always current, cheap. A graph
built last week is stale the moment code changes, and a stale graph is worse than none.

Graphify's real job here is **orientation**: the first hour in a large repo you have never
seen, cross-repo maps, or a non-code corpus (docs, papers, images, video). When you run it,
**state when the graph was built** in your answer so the reader can judge staleness.

Upstream: the version below is fetched from `Graphify-Labs/graphify` at install time (the CLI
installs with `pip install graphifyy` — note the double-y while the PyPI name is reclaimed).
