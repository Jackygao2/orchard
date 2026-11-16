# T-A4 — partial idle observation

Host: macOS 27.2.1 (26B131), arm64. Runtime: Apple `container` 1.7.1 was running. The sample observed the installed ContainerDesk app (reported as PID 60365 during collection); its source revision and relationship to the integrated candidate are unknown.

Command behavior: `ps` values were collected once per second for 61 samples. Raw rows are in [a4-idle-ps-samples-2026-11-16.txt](a4-idle-ps-samples-2026-11-16.txt); columns are timestamp, `%CPU`, RSS in KiB, and elapsed process time.

- Sample interval: 2026-11-16 14:43:46–14:44:46 EST.
- Mean sampled `%CPU`: 1.3689%.
- RSS: 125,616–127,680 KiB (122.7–124.7 MiB); mean 127,135 KiB (124.2 MiB).

This is a partial observation of an installed build with unknown source provenance. It does not measure cold launch, log-poll cost under a chatty container, or the integrated release candidate. Do not use these numbers as final NFR-10 budgets. The E-01 attempt used retained Runtime data; it was recorded but was not a clean-install pass. T-A4 remains in progress.
