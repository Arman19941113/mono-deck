---
name: mono-deck-workflow
description: Inspect existing MonoDeck workspaces and manage their repositories, worktree groups, and member worktrees with the mono-deck CLI.
---

# MonoDeck workspace management

## Domain essentials

- **Workspace:** Its root is the workspace repository's main worktree and holds shared files and workflows.
- **Member repository:** Registered by remote URL, with its main worktree at `repositories/<repository-id>`.
- **Worktree group:** The root at `worktrees/<group-name>` is a linked worktree of the workspace repository. Each selected repository has a linked member worktree at `worktrees/<group-name>/<repository-id>`.
- Treat the workspace record, Git worktree registrations, and directories on disk as separate state.
- Use **workspace**, **repository**, **worktree group**, and **worktree** in user-facing descriptions. Include the group or path when it clarifies the target.

## Context and commands

- Start with `mono-deck workspace tree --json`. Outside the workspace, pass `--workspace <root>`. Use the absolute `data.tree.path` as `--workspace` on later calls. Use `--json` for v2 results and subcommand `--help` for syntax.
- Tree nodes have `type`, `path`, and `children`. Child paths are relative to their parent. `main-worktree` and `linked-worktree` have `children: null`. `workspace`, `auxiliary-directory`, and `group` have arrays, possibly empty.
- Queries read local snapshots without taking the workspace lock, writing, or fetching. The tree checks directory and `.git` entry types, omitting missing, mistyped, and symlinked paths even when registered. Use resource status or operation checks for Git health, remotes, and ownership. Refresh relevant lists when state may have changed.
- Get `resource["repository-id"]` from `repository` items in `repo list --json` and `resource["group-name"]` from `group` items in `group list --json`, which also lists `member` items. `resource.path` is relative to the workspace. Repository IDs use the URL basename without trailing `.git`, are unique ignoring case, and are independent of `--display-name`.
- The `repo add` plan action `maintain-workspace-ignore` can commit the entire workspace `.gitignore` when it differs from HEAD, including manual edits. Automatic commits require HEAD to resolve to a local branch.
- Use the App to initialize or recover a workspace, scan local repositories, import or export YAML, update repositories, or update worktrees.

## Planning and execution

- All write commands accept `--dry-run`. It overrides `--yes` and checks local prerequisites without writing, cloning, or fetching. On success, `status: "success"` and `dry-run: true` accompany the unlocked snapshot in `plan.actions` and `plan.deletions`.
- Before deleting, review paths, current branches, and `risks` in `plan.deletions` from `--dry-run --json`. Refresh after `confirmation-changed` or when targets, branches, or risks may have changed. Review known branch tip or worktree changes even if the preview matches. Pass `--yes` only when prior or new user authorization covers the current targets and risks.
- Commands without deletion targets run after validation. Without `--yes`, deletions prompt interactively or return `confirmation-required` in JSON or non-interactive mode before any changes, including additions in the same edit.
- Each execution resolves its own deletion targets. `group delete <group-name> --yes` does so under the workspace lock, skipping the risk and local-change preview while checking ownership, targets, and branches.

## Creating groups

- Choose an unused group name that is a single directory name and a valid Git branch name. If unspecified, suggest `<type>-<task>` in the user's language. Explain invalid names and confirm alternatives. `--branch` accepts Git branch names with `/` and defaults to the group name. The saved initial branch applies to future members even after a checkout switches branches.
- Confirm the workspace root, group name, initial branch, and repository IDs before `group create <group-name> [--branch <branch-name>] --repo <repository-id> [--repo <repository-id> ...]`. Reuse confirmation for the same inputs. Pass at least one `--repo`, once per repository ID. Creation and member addition process resources in order.
- Creation uses local refs and leaves reused branch tips unchanged. Group roots use the matching available local branch or workspace HEAD. Members try the matching local branch, the local ref for the matching `origin` branch, then the locally recorded remote default branch. Report branch-reuse warnings.

## Editing membership

- `group edit <group-name> --repo <repository-id> [--repo <repository-id> ...]` sets the full member list and deletes omitted worktrees and their current local branches. Use `--clear-members` in place of `--repo` to remove all members. Both forms keep the group root and name.
- Extend or complete a group with `group member add <group-name> <repository-id>...`, which keeps existing members. Both add and edit use the saved initial branch for new members. `group member delete <group-name> <repository-id>...` removes the named worktrees and their current local branches.

## Destructive changes

- `group delete <group-name>` removes the entire group directory, including all task member worktrees and any independent Git repositories inside it.
- `repo delete <repository-id>` removes its managed worktrees and their current local branches, then moves the local clone to Trash. Unmanaged Git worktree registrations block deletion even if their directories are missing.
- Report preview read warnings when local-change status is unknown. Authorized linked worktree cleanup can proceed when ownership and target checks pass.
- Deleting a linked worktree permanently removes its files, including ignored files, deregisters it in Git, and deletes its current local branch even if reused. A detached HEAD has no branch to delete. Unmerged commits may become unreachable if no other Git ref retains them. On success the original path is gone, though cleanup and space reclamation may continue in the background.
- When a worktree directory and its Git registration are missing, deletion may only remove the workspace record entry.

## Results and failures

- Judge completion from the final JSON on stdout, even on nonzero exit. Progress goes to stderr.
- Report completed and unfinished items, warnings even on success, and effects as applied, reverted, or unknown. Cancellation or partial failure can leave completed changes in place.
- After `workspace-lock-timeout`, wait for the active write to finish and refresh the state and plan before retrying.
- Stop actions that depend on unavailable resources. For `cleanup-failed` or `save-outcome-unknown`, report causes, retained paths, and unknown effects. Preserve retained data, resolve the cause before retrying, and base recovery claims on observed effects.
- Use the CLI for managed changes. Keep private workspace records read-only and resolve CLI rejections through supported MonoDeck operations.

## Custom workflows

- Put workspace-specific instructions in `.agents/skills/mono-deck-workflow-addon/SKILL.md` under the workspace root. Opening or manually reloading the workspace replaces local edits to the bundled `SKILL.md` and `agents/openai.yaml` in both the working tree and index.
- A new group includes addon content from its group root commit. Existing groups keep their own checkout. Commit custom workflow changes only with the user's authorization.
