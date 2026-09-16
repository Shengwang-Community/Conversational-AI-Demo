# Review checklist

Use this as a reminder, selecting items relevant to the change. See [shared guidance](../../AI_WORKFLOW.md) and [Android context](../AGENTS.md).

- Does the change solve the stated problem and handle likely failures?
- Are module boundaries, lifecycle, cancellation, callback threads and cleanup correct?
- Are affected RTC/RTM, Toolkit, transcript, permission and IoT/BLE paths consistent?
- Do build, flavor, configuration and dependency changes preserve compatibility?
- Does review cover the requested scope, including new files in a local review?
- Do the checks support the claims? State failures, skipped checks and device or visual coverage still needed.
- Are user changes preserved and credentials or local notes excluded from the proposed commit?

Report actionable findings with evidence. A review does not require task-state files or a prescribed role sequence.
