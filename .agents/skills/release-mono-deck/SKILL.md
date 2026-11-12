---
name: release-mono-deck
description: Prepare a local MonoDeck release commit and annotated tag. Runs only when explicitly invoked as $release-mono-deck.
---

# Release MonoDeck

From the MonoDeck repository root, review `Version.xcconfig` and `.github/workflows/release.yml`. A full local release request authorizes staging and committing only `Version.xcconfig` and `CHANGELOG.md` and creating the local annotated tag. Push or publish only with separate explicit authorization.

## 1. Check the working tree and resume state

- Confirm the release branch and that no merge, rebase, or similar operation is in progress. For a new release, record the branch and starting HEAD and require `git status --porcelain=v1 --untracked-files=all` to be empty. List any changes and stop if it is nonempty.
- On failure, preserve state and report the branch, starting HEAD, any selected baseline and version, and completed and pending work. On resume, verify the original state and intended changes against prior results and Git history. Stop on unrelated changes or if the original state or ownership is uncertain.
  - **Uncommitted edits.** Verify the starting HEAD, unused tag, and expected edits in the working tree and index. Keep completed edits, including any verified build increment, and continue with pending edits, validation, and commit.
  - **Committed, awaiting tag.** Verify the release commit as described below and confirm the tree is clean. Finish pending validation and tag the commit.
  - **Tagged.** Verify the release commit, clean tree, and annotated tag as described below, then report the result.

## 2. Choose the version

- For a new release, use the highest local stable `vX.Y.Z` tag by semantic version. If it is outside the starting HEAD's ancestry, wait for the user to choose the baseline. For a first release, tell the user and use all history through the starting HEAD. On resume, reuse the verified baseline and any selected version. Review the commits and relevant diffs in that range.
- Accept three nonnegative integers without leading zeros in `X.Y.Z` format, with an optional `v` prefix. Require a version above the baseline and at least `MARKETING_VERSION` at the starting HEAD. Require an unused tag for a new release.
- If the user gives no version, recommend a patch for compatible fixes, a minor for compatible features, or a major for breaking changes. Ask once, with the recommendation first and a brief explanation of the valid choices. Use chat if the choice UI is unavailable. Offer to defer if only one version fits and the UI requires another option. Wait for and validate the user's explicit choice before editing.
- Before editing, recheck the branch, starting HEAD, working tree, and index. Change only `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Version.xcconfig`. Set the build number to the value at the starting HEAD plus one. Ask how to proceed if the original build number is not an integer.

## 3. Update the changelog

- Add `## [X.Y.Z] - YYYY-MM-DD` with the user's local date and existing English category headings. Place it after Unreleased, if present, and before older releases. Move this release's entries from Unreleased and verify the origin of any existing section for the target version before editing it. Start a missing `CHANGELOG.md` with `# Changelog`.
- Write concise English notes on completed changes users will notice. Merge duplicates and cover installation, upgrades, compatibility, and any required migration or recovery steps. Use one short maintenance note for a release with only internal changes.
- Set `tag` to the selected `vX.Y.Z` and run `python3 script/release_notes.py "$tag"`. Review the notes and resolve validation failures before committing.

## 4. Commit and tag

- Preview the version, build number change, changelog summary, and tag. Run `git diff --check` and review the full release diff, including staged edits or a new `CHANGELOG.md`. Before testing, staging, and committing, verify the release branch, starting HEAD, and unused tag. Check that the working tree and index contain only the reviewed changes to the two release files.
- Run `task test TEST_FILTER=MonoDeckTests/VersionTests`. Continue once tests pass and `run_tests.py` confirms test environment exit and cleanup.
- After tests and the pre-staging checks, stage with `git add -- Version.xcconfig CHANGELOG.md`. Before committing, run `git diff --cached --check` and require the reviewed diff to be fully staged with no unstaged or untracked changes.
- Commit using Conventional Commits in the predominant language of the five latest commits, for example `chore(release): vX.Y.Z`. Verify the release commit is HEAD on the intended branch, has the starting HEAD as its parent, and changes only the two release files with the expected version, build number, and changelog.
- With `tag` set to the release tag and `release_commit` to the verified SHA, run `git tag -a "$tag" -m "$tag" "$release_commit"`. Verify `git cat-file -t "refs/tags/$tag"` returns `tag`, `git rev-parse "refs/tags/$tag^{commit}"` resolves to the release commit, and the tree is clean.
- Report the version, build number, commit SHA, local tag, and verification results.
