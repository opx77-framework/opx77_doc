---
title: The scheduler
description: OPX.Scheduler.Every is how a module runs repeating work on the server and on the client, and the two implementations behave differently.
---

# The scheduler

`OPX.Scheduler` runs repeating work. Use it instead of writing
`CreateThread(function() while true do ... Wait(n) end end)`. It has the same
four functions on both sides, but the server and the client implement it
differently because the two runtimes fail differently.

```lua
local handle = OPX.Scheduler.Every('mymodule.sweep', 1000, function()
	-- runs about once a second
end)
OPX.Scheduler.Cancel(handle)   -- in M.Stop
```

| Function | Server | Client |
|---|---|---|
| [`Every(name, intervalMs, step)`](../reference/core.md#opx-scheduler-every) | One managed task per job. `intervalMs` may be a number **or a function** re-read every pass (to follow a live tunable). | One shared loop for every job. `intervalMs` must be a number; a function raises. `0` means every pass. |
| [`Cancel(handle)`](../reference/core.md#opx-scheduler-cancel) | Stops the job. | Stops the job; it is dropped at the next pass. |
| [`Report()`](../reference/core.md#opx-scheduler-report) | One line per job. | One line per job: name, interval, `running`/`stopped`. |
| `Stop()` | Stops every job (resource stop). | Stops the loop (resource stop). |

`name` is only used in log lines; write it as `<module>.<purpose>`.

## Server behaviour {#server}

| Rule | Value |
|---|---|
| First run | One interval after registration, never at once. |
| Smallest interval | 50 ms. A smaller value is raised to 50. |
| Interval that cannot be read | The job runs at its last good interval, or every 60 s, and logs once. |
| A step that raises | Logged once per run of failures. The job is **never** suspended. |

## Client behaviour {#client}

| Rule | Value |
|---|---|
| Jobs per pass | At most 4 due jobs run in one resume, in rotation, so none starves. |
| First run | Staggered, so jobs on the same interval do not all land on the same frame. |
| A step that raises | Logged on the first and third failure. After 3 failures in a row the job is **suspended** (cancelled) with `[scheduler] <name> suspended after 3 failures`. |
| Idle | The loop sleeps at most 100 ms between passes. |

The client loop starts after every module's `Start`. Run `/opx.client` in the
client console to print the job list.

!!! warning "Keep each client step small"

    All client jobs share the loop. A step that walks a long list every frame can
    exceed the client's instruction budget, and the platform then kills the
    coroutine **without any log line**. Spread long work over several passes. See
    [Two runtimes](two-runtimes.md#budget).
