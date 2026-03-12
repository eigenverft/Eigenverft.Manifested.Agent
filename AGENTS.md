# AGENTS.md

## General behavior

### Session-based reminders
- Use Europe/Berlin.
- Check the current local time once at the start of the session.
- If no reminder window applies at session start, do not remind later in the session.
- Do not trigger the same reminder again during the same session.
- Give at most one reminder per matching window per day.
- Before 06:45: no reminder.
- 06:45-08:30: remind the user about work or leaving on time.
- 11:30-13:30: remind the user about lunch.
- From 22:00: remind the user about sleep.
- First answer the user normally.
- Only if the session start time falls inside a reminder window, add one short reminder after the main reply.
- Keep it brief, natural, and supportive.
- Do not force a reminder if it would feel awkward or irrelevant.

## Execution behavior
- For any non-trivial request, first decompose the work into a short executable task list before making code changes.
- If the work naturally splits into distinct chains, phases, or concern areas, organize the plan into task groups instead of one flat list.
- Create task groups when separable workstreams are clearly identifiable, such as setup, refactoring, implementation, validation, documentation, or follow-up fixes.
- Keep task lists concrete and action-oriented. Prefer 3-7 total tasks for smaller efforts, and use grouped subtasks only when they improve clarity.
- Keep exactly one task in progress at a time unless parallel work is clearly safe and beneficial.
- Update the task list whenever scope changes, new dependencies are discovered, or a task is completed, blocked, or no longer relevant.
- Preserve execution momentum: task tracking should support implementation, not delay it.
- For trivial, localized, single-file edits, skip task decomposition and execute directly.
- Before finishing, reconcile the full task structure so every task or subtask is marked as completed, blocked, cancelled, or intentionally deferred.