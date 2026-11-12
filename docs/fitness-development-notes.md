# Scone Labs fitness update

Prepared against the source uploaded November 2, 2026. This is a change package for your existing `feature/fitness-tracking` branch, not a replacement repository. Nothing has been deployed or imported.

## What is included

- My Workouts Lightning component tab, first in the existing Scone Labs app navigation. Other tabs, branding, recipe page overrides, and utility bar are preserved.
- One responsive Lightning Web Component: routine selection, unfinished workouts, recent history, exercise cards, per-set weights/reps or seconds, previous weights, form notes, explicit skips, rest timer, saved drafts, and completion summary.
- FitnessHubController creates sessions/exercises/sets in one transaction, supports 1–10 target sets and at most 30 exercises, checks ownership and object/field access, reuses an unfinished session on a repeated start, and updates existing set IDs instead of inserting duplicates.
- Start_Workout and Log_Workout retain their API names and recordId inputs but now host the new component. The existing Start Workout quick action continues to work. Existing legacy Apex services and Review Recent Workouts are retained without modification.
- Rep ranges, timed targets, rest seconds, weight basis, prescription snapshots, form confirmation, skipped sets, actual seconds, and session timing fields. No new core objects.
- New fields added in a separate Fitness Tracking section of existing affected layouts.
- A dedicated Scone Fitness User permission set. It grants fitness object read/create/edit, relevant fields, controller execution and the new tab. It does not grant deletion, View All, Modify All, or nutrition access.
- Six Apex test methods and local JavaScript behavior checks.
- A separately executed, rerunnable seed script for Upper Body, Lower Body, Core and Full Body. This reuses exact exercise names, creates missing exercises, uses Sit-to-Stand for chair squats and Goblet Squat to Bench for goblet squats, and leaves Foundation/Strength A/B/C unchanged. Paired alternative records are not renamed. No rowing machines, commercial machines, or planks are programmed.

## Intentional behavior

- Saving, changing exercise, and finishing persist the displayed exercise plus workout notes/duration. Unsaved edits prevent navigation to Workout home. Closing Salesforce without saving can still lose unsaved inputs; this is not an offline application.
- Blank sets can be saved as a draft. Completion requires every stored set to have positive reps/seconds or an explicit skip, plus at least one performed set. Completion with skipped sets is permitted and shown in the summary.
- Completed sessions are read-only in this logger. Standard Salesforce record permissions still allow administrator edits outside the logger.
- Weight is in pounds. Prescriptions specify whether weight is per dumbbell, a single held weight, or added bodyweight. Band resistance belongs in notes. Legacy weight basis is unknown; historical comparisons only match the same stored basis and timed/repetition mode.
- A suggestion is shown only when the previous comparable completed exercise has at least the current target set count, all performed sets meet the current maximum reps at an identical known weight, and good form was recorded. It does not change weights. No automatic medical or training decisions are made.
- History examines up to 2,000 prior exercise records and 10,000 sets and discloses when capped. “Heaviest logged set” is scoped to that reviewed history, not an all-time or estimated one-rep-max claim. Charts, automatic weight increments, kilogram conversion, per-side split logging, Apple Health integration, and offline sync are not included.
- Old sessions keep their stored weights/reps and target values. New prescriptions are snapshotted only for sessions created by the new workflow; past targets cannot be reconstructed reliably.
- The rest timer uses an absolute deadline to reduce background-tab drift. It provides visual feedback, not guaranteed background audio/push notifications.
- Session duration is editable; suggested wall time may include breaks. Draft saves preserve the last entered duration rather than silently adding time away.

## Checks performed here

- All LWC JavaScript, HTML and CSS compiled with `@lwc/compiler`, API 66.
- Apex classes and anonymous seed script parsed without syntax errors with `@apexdevtools/apex-parser`.
- Local JavaScript checks passed for variable rows, copying weights without inventing reps, explicit skips, clearing inputs, persisting drafts, save failure retention, blocking completion after save failure, and timed entries.
- XML parsing, package member coverage, layout references, and source diff checks completed.

These checks are not a Salesforce deployment validation. Apex type checking, runtime tests, actual coverage, org automation interactions, and phone rendering must be verified in Scone Labs. No Salesforce CLI credentials are present in this package.

## Apply locally, one step at a time

1. Keep your current branch `feature/fitness-tracking`. Before overlaying, commit the current retrieved baseline (review `git status` first). Do not include `.sf`, `.sfdx`, or review ZIPs in a commit.
2. Extract this ZIP into a separate folder. Copy only its `force-app`, `manifest`, `scripts`, and `checks` folders into your existing project. This replaces the two workout flows, four affected layouts, and Scone Labs app file, and adds the new files. Existing metadata not included in the package stays in place.
3. Review `git diff` and `git status`. Restrict the deployment to `manifest/fitness-package.xml`; do not deploy the entire force-app directory, which also contains unrelated retrieved metadata.
4. Run the validation command below and share its complete result. Stop on any compilation, access, test, or coverage failure.

```powershell
sf project deploy start --target-org scone-labs --manifest .\manifest\fitness-package.xml --dry-run --test-level RunSpecifiedTests --tests FitnessHubControllerTest --wait 20
```

## After validation and review

Only after successful validation and your review:

```powershell
sf project deploy start --target-org scone-labs --manifest .\manifest\fitness-package.xml --test-level RunSpecifiedTests --tests FitnessHubControllerTest --wait 20
sf org assign permset --target-org scone-labs --name Scone_Fitness_User
```

The permission assignment applies to the current authenticated CLI user. Assign other users separately only if intended.

Then, as a separate explicit data step:

```powershell
sf apex run --target-org scone-labs --file .\scripts\seed-home-workouts.apex
```

The seed script aborts if exact names or planned positions are ambiguous; it does not delete extra rows. It updates the four named routines on rerun. Review those routines before rerunning it after personal edits. Fixed-rep movements have equal minimum and maximum targets; their weight progression still requires a manual comfort/recovery decision.

## Acceptance checks in Salesforce

1. Open My Workouts on desktop and in Salesforce mobile. The new tab may require refreshing navigation if the user personalized the app.
2. Start Upper Body. Verify 6 exercises with 3 sets each, correct order, target ranges, and per-dumbbell weight labels.
3. Save one exercise. Leave and resume from home; verify set values, notes and duration. Retry Start on the same unfinished template; confirm it resumes instead of creating another session.
4. Clear an entered number and save. Confirm it stays cleared on reload. Force a network/save failure and confirm the UI retains the edits and does not advance.
5. Try completing with a blank set. Confirm it is rejected. Explicitly skip unfinished sets, perform at least one set, and complete; verify summary and persisted status.
6. Start Full Body and verify Farmer Carry uses seconds. Check previous weights copy without copying performed reps or seconds.
7. Verify a new session retains its prescription after the template is edited. Verify old Foundation and Strength records are unchanged.
8. Verify the existing template Start Workout action opens the new logger on desktop and phone. Verify the existing recent-workout automation still works with the retained data model.
9. Complete a comparable rep-range exercise with the maximum reps in every set and good form recorded. Start another workout and verify the suggestion; it must not appear with missing good-form confirmation, insufficient sets, or a different stored weight basis.

## Recovery

Record the baseline commit before applying the package. To roll back behavior, restore only the original two flows, affected app file, and affected layouts from that baseline and deploy that explicit set. Restore the previously active flow versions if needed. Keep additive fields and all records; do not delete the new fields during rollback. No destructive deployment manifest is included.

---

## Development Checkpoint: November 12, 2026

### Completed and Verified
- Created and deployed workout-duration calculation fields.
- Added exercise-duration formulas and workout-level rollups.
- Corrected blank-value handling for unilateral exercises and warm-up time.
- Updated Scone_Fitness_User permissions for the new fields.
- Renamed three workout templates to remove weekday dependencies.
- Configured Full Body A with 60-second rests, unilateral rows, and timed Farmer Carries.
- Verified Full Body A estimated duration: 29 minutes.
- Added 60-second rest periods to all seven Full Body B exercises.

### In Progress
- Finalize Full Body B Dead Bug configuration: 2 sets of 8 reps per side.
- Verify Full Body B estimated duration.
- Review and configure Full Body C.
- Review remaining workout templates and their duration estimates.
- Confirm estimated durations are displayed appropriately in the fitness app.
- Review previously modified flows, layouts, and metadata for unfinished work.

### Git Status
- Working branch: feature/fitness-tracking.
- Changes from multiple development sessions remain uncommitted.
- Repository contains untracked Salesforce metadata, temporary files, and review archives.
- Review and stage intended project files before committing.
- Do not run git add . or git clean without reviewing the file list.

### Next Session
1. Preserve and commit existing development work safely.
2. Finish Full Body B and C exercise configuration.
3. Validate workout-duration displays and end-to-end workout logging.

