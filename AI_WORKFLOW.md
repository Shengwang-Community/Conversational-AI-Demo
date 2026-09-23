# Working with AI agents

Use the agent's judgment to solve the task. These guidelines provide project context, not a prescribed execution sequence. User instructions take precedence.

- Work directly from the request and current code. Choose the depth of planning, tools, collaboration, review and validation that the task needs, within available permissions.
- Plans, skills, templates and local notes are optional aids. Start implementation without a frozen contract, risk score or role handoff.
- Ask when unresolved intent or missing authorization affects the outcome. Make routine decisions and continue work already authorized.
- On continue, use the conversation and any relevant notes, verify the current files and resume unfinished work. Save a short checkpoint when useful for recovery.
- Investigate failures, use new evidence to guide retries and keep independent work moving. Report a blocker when progress needs an external change.

## Review and validation

- For local review, include staged, unstaged and untracked files. Read new files explicitly; `git diff` omits them. Use a commit range when the user asks for one, and preserve pre-existing changes.
- Focus review on correctness, regressions and material risks. Report findings with a location, trigger, impact and supporting evidence; resolve confirmed issues within scope.
- Choose checks that cover the changed behavior. The platform guides provide useful commands, not mandatory full-app test gates. Add meaningful tests where needed; documentation edits usually need consistency checks.
- Test current inputs. A build, stale artifact, zero tests or all-skipped result does not establish passing tests. Summarize actual checks, failures and unverified behavior accurately.

## Notes and maintenance

For long tasks, optional notes under a platform's ignored `.agents/state/` can record the goal, decisions, results and next step. Use one note for a cross-platform task when helpful; keep historical notes as context without requiring their old fields or process.

Keep guidance concise and in English. Put shared advice here and project facts in platform guides; load optional references only when useful. Keep common copies aligned across repositories. `python3 scripts/check_workflow.py --peer ../<sibling-repo>` checks wiring and shared files; run `python3 -m unittest discover -s scripts/tests -v` when changing validation scripts.
