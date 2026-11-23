# Publishing a source

A source is a folder of `.hew` Library items plus an index file named
`hew.json`. Any host that serves single files over HTTPS without a login
can hold it. The same steps, with more explanation, are at
<https://hew3d.com/learn/publishing-a-source>.

`hew-cli` comes with the Hew desktop app. Each Hew release from
v1.5.0-pre.4 on also has it as a download of its own, for macOS, Linux
and Windows, with a `.sha256` checksum file beside each archive.

## 1. Make the items

Save each item from Hew into your Library (Save to Library), then copy
the files into one folder. Every item carries an id that stays the same
when it is published and when someone adds it, so keep editing the same
items when you publish new versions.

## 2. Write the index

Put the items in the folder in any layout (names that start with a dot
are skipped), and run:

```
hew-cli library index ./parts --name "Shop Hardware" --license CC-BY-4.0
```

This writes `hew.json` with the SHA-256 and size of every item, and a
thumbnail for each item in `thumbnails/`. Use `--description`, `--author`
and `--homepage` to fill in the rest. A file that is not a Library item
stops the run, and nothing is written.

A listed source needs a license: an SPDX identifier such as `CC-BY-4.0`,
or `LicenseRef-<name>` together with `--license-url`. `hew-cli catalog check` refuses any other form.

After changing any item, run the command again. To see whether the index
is out of date without writing anything:

```
hew-cli library index ./parts --check
```

Commit or upload the folder, `hew.json` and `thumbnails/` included.

## 3. Host it

- GitHub, GitLab and Codeberg (or any Forgejo or Gitea host): push the
  folder to a public repository. The reference is `github:owner/repo`,
  `gitlab:group/project` or `codeberg:owner/repo`. Add `//<dir>` to name
  a folder inside the repository and `@<ref>` to name a branch or a
  tag. Both work on all of these hosts. The name after `@` cannot
  contain a `/`.
- Any other web host: upload the folder and give the address of
  `hew.json`, for example `web:https://example.org/parts/hew.json`.

The web app reads sources from the browser, so a plain web host must send
the header `Access-Control-Allow-Origin: *` on every file (`hew.json`,
the items and the thumbnails). GitHub, GitLab.com, Codeberg and
gitea.com already send it. Every address must be `https` and public;
redirects are allowed and must stay on `https`.

## 4. Check it

```
hew-cli catalog check github:owner/repo
```

Fix every line it prints. No output and exit status 0 means it passes.
The [README](README.md#the-checks) lists the codes.

## 5. Tell people, or ask to be listed

Listing is optional. Without it, anyone can add your source in Hew: in
the Library, **Add a source…**, then paste the reference. Hew tells them
the source is not in the catalog and has not been checked.

To be listed, open a pull request that adds one canonical reference line
to `library.json`, keeping the list sorted and without duplicates. The
pull request template has a short checklist. A maintainer runs the
checks above and reviews the request.

Listed or not, Hew reads items from your source as it is now, so a new
version reaches people when you publish it. Items are not signed: the
SHA-256 in the index catches a changed or damaged file and does not
prove who published it.
