# Headscale-after-wrtbak implementation plan

1. Add failing wrtbak tests for atomic gate receipts and every terminal state.
2. Add the receipt writer to `wrtbak-firstboot-auto` and update its runbook.
3. Add failing OpenWRT-CI tests for gate configuration, lock handling, restored
   state reload, and CPE-5G inheritance.
4. Implement the Headscale wait/reload/lock behavior and document operations.
5. Run both repositories' complete shell suites, `git diff --check`, shell
   syntax checks, and workflow YAML parsing.
6. Push both short-lived branches, merge without force-push after CI passes,
   and confirm the CPE-5G workflow resolves the merged shared overlay.
