# Branch workflow

- Use `dev` for ongoing feature development, fixes, and beta iterations. Commit and push development changes to `origin/dev`.
- Reserve `main` for formal releases. Do not push development changes directly to `main`.
- Merge `dev` into `main` and create release tags only when the user explicitly requests a formal release.
- Before editing, check the current branch and working tree. If on `main`, switch to `dev` while preserving any existing work.

## Local game testing

- Use the live Forever client at `E:\bilzzard games\World of Warcraft\_forever_` for addon testing and local deployment. Install Bel Toolbox under `Interface\AddOns\BelToolbox` in that client. The former beta client is closed.

## Check EllesmereUI before adding features

- Before adding a user-facing feature, inspect the locally installed Forever version of EllesmereUI, including its options and the relevant module implementation, for matching or similar behavior.
- When EUI already covers part or all of the request, tell the user before implementing it. Give the EUI setting or entry point, note what remains useful in Bel Toolbox, and prefer reusing EUI behavior where it meets the request.
- If no match is found or the local EUI source is unavailable, say what was checked when reporting the change.
