# Branch workflow

- Use `dev` for ongoing feature development, fixes, and beta iterations. Commit and push development changes to `origin/dev`.
- Reserve `main` for formal releases. Do not push development changes directly to `main`.
- Merge `dev` into `main` and create release tags only when the user explicitly requests a formal release.
- Before editing, check the current branch and working tree. If on `main`, switch to `dev` while preserving any existing work.

## Local game testing

- Use the live Forever client at `E:\bilzzard games\World of Warcraft\_forever_` for addon testing and local deployment. Install Bel Toolbox under `Interface\AddOns\BelToolbox` in that client. The former beta client is closed.
