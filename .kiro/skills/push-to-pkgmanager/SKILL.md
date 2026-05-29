---
name: push-to-pkgmanager
description: Use this skill when the user asks to publish, release, or push the package to the internal JNJ package manager, or mentions "jnj-pkg", "internal release", "package manager", or "sourcecode.jnj.com".
---

## What this does

Force-pushes the current local branch to all three branches on the `jnj-pkg` remote
(`https://sourcecode.jnj.com/scm/asx-ncrv/appendmcp.git`):

- `development`
- `qa`
- `production`

All three are kept identical. The internal R package manager builds from these branches
and appends a build suffix to the version (e.g., `0.3.0` becomes `0.3.0.17xxxxx`).

## Before publishing

1. Confirm with the user which branch to publish (usually `main` or the current branch).
2. Verify the branch is clean (`git status --short`).
3. Ask if the version in DESCRIPTION should be bumped before publishing.
4. Show the last few commits (`git log --oneline -5`).
5. Get explicit confirmation before force-pushing.

## Commands

```bash
git push jnj-pkg <branch>:development --force
git push jnj-pkg <branch>:qa --force
git push jnj-pkg <branch>:production --force
```

## After publishing

Report success and remind the user to verify on the internal package manager that the new version is available.
