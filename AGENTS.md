# Branch workflow

- Use `dev` for ongoing feature development, fixes, and beta iterations. Commit and push development changes to `origin/dev`.
- Reserve `main` for formal releases. Do not push development changes directly to `main`.
- Merge `dev` into `main` and create release tags only when the user explicitly requests a formal release.
- Before editing, check the current branch and working tree. If on `main`, switch to `dev` while preserving any existing work.
