# Build verification checklist

Run after **every** phase, before the regression sweep. Takes ~3 minutes.

---

## 1 · Project generation

```
xcodegen generate
```

- [ ] Completes without error
- [ ] `git status` shows `Tinycast.xcodeproj` either unchanged or changed **only** as a consequence of
      files this phase legitimately added, removed or moved

> A `.xcodeproj` diff on a phase that added no files means something unexpected happened. Investigate
> before continuing.

---

## 2 · Debug build

```
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
```

- [ ] `** BUILD SUCCEEDED **`
- [ ] **Zero new warnings.** Compare against the pre-phase baseline you captured in step 2 of the README
      workflow. Pre-existing warnings are not this phase's problem; new ones are.
- [ ] No new Swift 6 concurrency diagnostics of any severity
- [ ] No `@unchecked Sendable`, `nonisolated(unsafe)` or `assumeIsolated` added unless the phase
      explicitly authorised it

---

## 3 · Release build

Only required for phases that touch generic code, `@inlinable` surfaces, or the `Features/Calculator/Model/`,
`Features/Emoji/Model/` and `Features/Snippets/` engines — and always for the final phase of a milestone.

```
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Release \
  CODE_SIGNING_ALLOWED=NO
```

- [ ] `** BUILD SUCCEEDED **`
- [ ] Type-checker did not time out on any expression (watch for
      `the compiler is unable to type-check this expression in reasonable time` — `LauncherList.rows`
      already carries an annotation for exactly this reason)

---

## 4 · Binary size

Locate the built product and check it against the < 3 MB upto 4MB budget:

```
find ~/Library/Developer/Xcode/DerivedData -name "Tinycast*.app" -maxdepth 6 -print -quit
```

- [ ] Executable size recorded in the progress file
- [ ] Release binary is under **3 MB upto 4MB** (3,145,728 bytes)
- [ ] Growth versus the phase-01 baseline is under **2 %**, or the phase document explains why not

---

## 5 · Launch

- [ ] App launches
- [ ] Menu-bar icon appears
- [ ] Palette hotkey summons the window
- [ ] No crash, no hang, no assertion in the first 30 seconds
- [ ] Console shows no new `Tinycast:` log lines that were not there before

---

## 6 · Startup timing

Only required for phases touching `AppCore.init`, `AppCore.start()`, or any store's initialiser —
phases **05, 06, 09, 10, 16, 17, 18, 24, 25**.

- [ ] Cold launch timed three times (quit fully, relaunch) and the median recorded
- [ ] Median is within **10 %** of the phase-01 baseline

---

## Failure handling

| Symptom                                      | Action                                                                                                                  |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Build fails, Claude cannot fix in 2 attempts | `git reset --hard`. Re-run with the error text in the prompt.                                                           |
| New warning introduced                       | Send it back to the same conversation. Do not accept "harmless".                                                        |
| Type-checker timeout                         | Almost always a large literal array or a long expression chain. Ask for an explicit type annotation, not a restructure. |
| Binary grew > 2 %                            | Something was added. Read `git diff --stat` for new files before anything else.                                         |
| Startup regressed                            | Look for work moved _into_ an initialiser. Very common when consolidating helpers.                                      |
