# iOS test reference

See the [validation guide](../../../../docs/VALIDATION.md). The repository's `scripts/workflow.json` maps available suites to real targets and test classes.

Select tests covering the change. `python3 scripts/validate.py ios --suite ains` runs standalone AINS tests; other behavior needs relevant coverage. Use incremental `xcodebuild test` for current sources and inspect the test results. A build or preflight alone does not prove tests passed.

Summarize results and remaining coverage. Diagnose environment failures and choose retries from evidence; record the dependency if testing remains unavailable.
