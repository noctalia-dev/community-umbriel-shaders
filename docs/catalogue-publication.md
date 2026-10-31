# Catalogue publication and review

Contributors can keep experiments in this repository and submit them through
ordinary pull requests. Set this flag in an effect's `metadata.toml`, or inside
a `[families.<id>]` table in root `families.toml`:

```toml
publish = false
```

Missing flags mean `false`. Maintainers review and test an entry before approving
`publish = true`. Descriptive tags never override this decision. Published
effects require published dependencies; published families require published
members. To withdraw an entry, set it back to `false` and update any published
dependants or families in the same change.

The initial migration marked 136 catalogue effects and ten families as eligible.
Fifteen additional effects bring the catalogue to 151, with updated family
memberships and defaults. Publication does not claim new visual testing;
per-effect READMEs record their validation.

## Contributor checks

The read-only **Catalogue checks / Validate catalogue** workflow runs contract
tests and generates a registry from the checked-out commit. It does not deploy,
push commits, or grant a PR permission to publish. Its checks cover metadata and
packaging, not GPU compilation or visual behaviour.

Locally, run:

```sh
python3 -m unittest discover -s tools -p test_catalogue.py
python3 tools/catalogue.py --draft --output /tmp/catalogue.json
python3 tools/catalogue.py --draft --include-unpublished --output /tmp/catalogue-development.json
```

The last command validates experiments as well. Both files are development
snapshots. Production generation accepts only a full committed source revision
and rejects `--include-unpublished`. The plugin's configured local-checkout mode
deliberately includes experiments; its future online consumer must reject draft
snapshots.

## Repository review settings

A contributor can propose `publish = true`; the field is not authorization.
Publication is enabled before branch protection is configured, by maintainer
decision. Until protection is added, any account with write access can change
what reaches the catalogue; `publish = true` alone does not enforce review.
The follow-up repository settings are:

1. Assign the actual maintainer accounts/team as code owners for shader content,
   metadata, families, notices, catalogue tools and `.github/` (including the
   ownership file itself). Reviewing only the flags is insufficient: editing
   an already-published shader also changes what users download.
2. Require pull requests and code-owner approval on the source branch. Dismiss
   stale approvals after new changes, and restrict bypasses to the intended
   maintainers. Require the **Validate catalogue** status check.
3. Limit writes to the generated `catalogue` branch to the publishing workflow
   and intended maintainers. Never publish PR builds or unreviewed PR artifacts.

GitHub documents [code-owner review enforcement](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
and [required reviews on protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).
These are remote repository settings; adding the generator and validation
workflow does not enable them. No remote review rules are changed by the publisher.

## Online delivery

The catalogue is served directly from raw GitHub, without GitHub Pages or an API
server:

```text
https://raw.githubusercontent.com/noctalia-dev/community-umbriel-shaders/catalogue/catalogue.json
```

The **Publish catalogue** workflow runs on pushes to upstream `main` and can also
be started from **Actions → Publish catalogue → Run workflow**, selecting `main`.
It does not run on pull requests, other branches or forks. A read-only job runs
contract and publication tests and validates the exact source commit. Only after
that succeeds does a separate job receive `contents: write`, regenerate from
that immutable commit and push the JSON to the `catalogue` branch.

The publishing helper creates a tree containing only `catalogue.json`. It never
checks out the generated branch, edits shaders or changes the source branch.
Subsequent publications are ordinary fast-forward commits. Identical output is
a no-op. Serialised runs, a current-main check and a source-ancestry check prevent
stale reruns or source rollbacks from replacing a newer catalogue. A concurrent
push is rejected rather than force-overwritten; rerun publication after checking
the competing change. Generation failures leave the previous catalogue intact.

The plugin will fetch the latest JSON and resolve shaders and previews against
its immutable `source.revision`, checking downloaded byte lengths and hashes.
That revision identifies the source commit, not the generated-JSON commit.
Remote plugin downloads are separate work; publishing does not install or change
the plugin automatically.

## Manual publication and recovery

For an initial publication or workflow recovery, maintainers can run the same
helper from a trusted checkout with full source history and upstream Git write
credentials:

```sh
git fetch upstream
python3 -m unittest discover -s tools -p 'test*catalogue.py'
python3 tools/publish_catalogue.py --remote upstream --revision FULL_UPSTREAM_MAIN_SHA
```

Use the full SHA returned by `git rev-parse upstream/main`. The remote must fetch
from and push to `noctalia-dev/community-umbriel-shaders`. The helper rejects a
fork remote because the generator records upstream's repository identity. It
skips a revision that is no longer remote `main`. Do not use `--draft` output for
publication or manually substitute another source revision in generated JSON.

After publication, check that the public JSON has `draft: false`, the expected
source SHA and effect/family counts. Confirm a pinned shader or preview download
matches its recorded size and SHA-256. If the workflow cannot push, check the
repository's Actions policy and generated-branch rules; do not force-push around
a rejection. When branch protection is introduced, allow the intended publisher
to update `catalogue` while protecting `main` through maintainer review.
