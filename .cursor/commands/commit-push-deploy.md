# Commit, Push and Deploy

## Overview

Commit all local changes, push to the remote (e.g. GitHub), then deploy to Heroku. The commit message is generated automatically from the diff unless the user provides one.

## Steps

1. **Inspect changes**
   - Run: `git status` and `git diff` (and `git diff --staged` if needed) to see what changed.
   - Use this to write a short, descriptive commit message.

2. **Generate commit message**
   - If the user typed a message after the command (e.g. `/commit-push-deploy fix login bug`), use that.
   - Otherwise, from the diff and status output, write a single-line commit message that summarizes the changes (e.g. "Add currency field to Airwallex transfer payload", "Fix validation in signup form", "Update report styles"). Prefer conventional style: verb first, lowercase after (e.g. "Add ...", "Fix ...", "Update ..."). Keep it under ~72 characters.

3. **Stage all changes**
   - Run: `git add -A`
   - Use `git_write` permission.

4. **Commit**
   - Run: `git commit -m "<generated or user message>"`
   - Use `git_write` permission.
   - If there is nothing to commit (clean working tree), say so and stop; do not push or deploy.

5. **Push to origin**
   - Run: `git push`
   - Use `network` (and `git_write` if required) permission.

6. **Deploy to Heroku**
   - Run: `git push heroku main` (or `git push heroku HEAD:main` if on another branch).
   - Use `network` and `git_write` permission.
   - If there is no `heroku` remote, report that and stop.

Do not ask for confirmation; execute the steps. If a step fails, report the error and stop.
