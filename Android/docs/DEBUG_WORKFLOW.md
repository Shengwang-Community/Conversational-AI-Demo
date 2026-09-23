# Debugging notes

Use [shared guidance](../../AI_WORKFLOW.md) and [Android project context](../AGENTS.md). Adapt the investigation to the issue.

- Establish the symptom, expected behavior and conditions that reproduce it.
- Inspect relevant code and logs; separate observed facts from hypotheses about the backend, device or SDK.
- Use focused experiments to narrow the cause. For RTC/RTM and transcripts, follow event delivery, parsing, state updates and cleanup. For IoT/BLE, check permissions and device conditions.
- Fix the confirmed cause and verify the affected path and likely regressions. Retry with new evidence when useful.
- Report what changed, what ran and what remains uncertain. Continue independent work if a device, account or environment is unavailable.

Optional note: **Symptom / Evidence / Hypothesis / Change / Checks / Remaining work**. Use only the parts that help.
