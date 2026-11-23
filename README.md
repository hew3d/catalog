# Hew catalog

The catalog is the list of sources that Hew's "Browse the catalog" view
shows. A source is a place where someone publishes Library items (and,
later, plugins) with an index file, `hew.json`. The catalog holds links to
those sources and generated metadata about them. It holds no item files,
plugin packages or thumbnails; those stay on the publisher's host.

## Files

On `main`, edited by pull request:

- `library.json`: source references for Library items.
- `plugins.json`: source references for plugins. Hew reads the file for
  shape and shows nothing from it yet.
- `removed.json`: sources taken out of the catalog.

On the `data` branch, generated and never edited by hand:

- `catalog.json`: one entry per listed source (name, author, license,
  item counts, categories, whether the entry is stale) and the contents
  of `removed.json`.
- `sources/<slug>.json`: the source's index as the last build read it.

Hew reads `catalog.json` from
`https://raw.githubusercontent.com/hew3d/catalog/data/catalog.json`.

## How listing works

1. The publisher follows [PUBLISHING.md](PUBLISHING.md) and opens a pull
   request that adds one canonical source reference to `library.json` or
   `plugins.json`.
2. The `Check listing` workflow (`check.yml`) runs `hew-cli catalog
   check` on each reference the pull request adds. It finds them by a
   diff against the merge commit's first parent.
3. A maintainer reviews the pull request, confirms the list is still
   sorted with no duplicates, and merges it.
4. The build workflow runs on every push to `main` and every 6 hours. It
   runs `hew-cli catalog build` and commits the output to `data`.

Both workflows run a released `hew-cli`. Every Hew release from
v1.5.0-pre.4 on publishes it as archives of its own:
`hew-cli-v<version>-macos-universal.tar.gz`, `-linux-x86_64.tar.gz`,
`-linux-aarch64.tar.gz`, `-windows-x64.zip` and `-windows-arm64.zip`,
each with a `.sha256` file beside it that holds `<hex>  <filename>`. A
workflow downloads the Linux x86_64 archive for the version in
`HEW_CLI_VERSION`, now `1.5.0-pre.4`, and verifies the checksum before
it runs anything. The workflows start to pass when that release tag
exists. To move to a newer `hew-cli`, change `HEW_CLI_VERSION` in both
files.

A listed source whose build fails keeps its last good snapshot and is
marked `stale`. A source that fails with no earlier snapshot is left out
of that build.

Hew reads an item from the source's own current index, never from the
catalog's snapshot. The snapshot feeds the catalog view only, so a
publisher's new version does not wait for a catalog build.

## The checks

`hew-cli catalog check <reference>` reads one source the way the web app
does. It prints one line, `<code>: <message>`, for the first failure of
each kind, and exits 1 if anything failed. No output and exit status 0
is a pass.

| Code | Fails when |
|---|---|
| `reference` | The reference does not parse, or is not written in its canonical form. The message gives the canonical form. |
| `index_invalid` | `hew.json` does not parse, is over 4 MB, was written for a newer Hew, or breaks a rule of the format. |
| `license_missing` | The index states no license. |
| `license_format` | The index license, or an item's own license, is neither an SPDX expression (ids such as `CC-BY-4.0`, joined by `AND`, `OR` or `WITH`, with balanced parentheses) nor a `LicenseRef-<name>` backed by an `https` `licenseUrl` on the index. Only the form is checked, not whether an id exists. |
| `file_integrity` | An item does not match its listed SHA-256 and size, a thumbnail is not a PNG, or either answers with an HTTP error. A thumbnail has no hash in the index and is checked for its size limit and PNG signature only. |
| `item_mismatch` | An item does not load as a Hew file, or its id or category differs from its index entry. |
| `ids_unique` | Two entries share an id. |
| `public_https` | A URL, on any redirect hop, is not `https` or does not resolve to a public address. |
| `cors` | A response lacks `Access-Control-Allow-Origin: *` (the exact value `https://app.hew3d.com` also passes). This is checked on the resolve, index, item and thumbnail requests. Publishers should send `*`, because a self-hosted copy of the web app has another origin. |
| `rate_limited` | The host limited the requests. |
| `unreachable` | A request got no answer, or a git host's commit lookup returned no commit. |

For a git source the check resolves the reference to a commit first and
reads the index and every file at that commit. If `GITHUB_TOKEN` is set,
it is sent to `api.github.com`, and nowhere else, to raise GitHub's
request limit.

`catalog check` looks at one source and never at the list files. That a
list is a sorted JSON array without duplicates is checked by
the `check.yml` workflow (it fails the pull request with one error line per
problem before any source is read), by `test/run.sh`, and in review.

## Removal

A source is removed by a pull request that adds an entry to
`removed.json`:

```json
{
  "source": "github:owner/repo",
  "severity": "removed",
  "reason": "One sentence saying why.",
  "link": "https://example.org/optional-details"
}
```

`severity` is `removed` or `critical`. Hew treats both the same for now.
The entry matches the source whatever `@<ref>` the list gave. The build
no longer requests a removed source, and it does not appear in `sources`.
Items a person already has from a removed source stay in their Library;
adding and updating from it stop, and Hew shows the reason.

Removal comes from a maintainer decision, for example a license problem,
a source that no longer works, or a report of harmful content. A
publisher can ask for their own source to be removed by opening an issue.

## Checking locally

`test/run.sh` checks that the three lists are well formed, runs the
build on them without network access and, if `actionlint` is installed,
lints the workflows. It needs a `hew-cli` with the `catalog` commands:
set `HEW_CLI` to the binary, or `HEW_SOURCE_TREE` to a checkout of Hew
to build one from. No workflow runs the script.
