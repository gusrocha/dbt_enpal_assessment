# Pipedrive Sales Funnel — Analytics Engineering Assessment

A layered dbt project that models a Pipedrive CRM export into a reusable
dimensional model and produces a monthly sales-funnel report
(`rep_sales_funnel_monthly`).

## Setup

1. `docker compose up` starts the local Postgres and loads the source data.
 ```
    Host: localhost
    User: admin
    Password: admin
    Port: 5432
```
2. `dbt deps` installs package dependencies (`dbt_utils`).
3. `dbt build` runs all seeds, models, and tests in dependency order.

Connect to the database with any client (DBeaver, DataGrip). Source data lands
in the `public` schema; models build into `public_pipedrive_analytics`.

`profiles.yml` is committed at the project root intentionally, so the project
runs out of the box. dbt reads it from the working directory before falling
back to `~/.dbt/`.

## The assignment

The task was to model the Pipedrive source data into well-organized dbt layers
and build a reporting model, `rep_sales_funnel_monthly`, at monthly grain,
counting how many deals entered each funnel step:

- Step 1: Lead Generation
- Step 2: Qualified Lead
  - Step 2.1: Sales Call 1
- Step 3: Needs Assessment
  - Step 3.1: Sales Call 2
- Step 4: Proposal/Quote Preparation
- Step 5: Negotiation
- Step 6: Closing
- Step 7: Implementation/Onboarding
- Step 8: Follow-up/Customer Success
- Step 9: Renewal/Expansion

Output columns: `month`, `kpi_name`, `funnel_step`, `deals_count`. The layers
are built to serve future KPIs, not only this one report, so the focus is on
modeling and data flow rather than the report itself.

## Overview

The report is deliberately thin. The real work sits in a general-purpose fact
table, `fct_funnel_events`, built so the monthly funnel is one aggregation among
many the model can serve (conversion, drop-off, velocity, per-rep funnels).

## Architecture

The project follows the standard three-layer dbt structure.

**Staging** (`models/staging/pipedrive/`): one view per source table, renamed
and typed, no business logic. A 1:1 cleaned mirror of the raw data.

**Intermediate** (`models/intermediate/`): business logic and reshaping. Stage
entries and completed calls are extracted as event streams and unified; deals
are reconstructed from the change log.

**Marts** (`models/marts/`): the published dimensional model — `fct_funnel_events`
plus `dim_deals`, `dim_users`, `dim_date`, `dim_funnel_steps`, and the reporting
model.

A single seed, `funnel_steps.csv`, holds the canonical funnel definition (see
below).

Naming follows Kimball convention (`fct_`, `dim_`). The dbt style guide favours
unprefixed entity names; the Kimball prefixes are used here for immediate
fact-versus-dimension legibility.

## The funnel definition: seed and dimension

The nine funnel steps and two sales-call sub-steps are static, business-defined
reference data that originate in the assignment brief. They are therefore loaded
from a seed (`seeds/funnel_steps.csv`) rather than derived from the event data,
and published as a dimension, `dim_funnel_steps`, which every funnel KPI can join
to.

This does two things:

- **It makes the report grid complete by design.** The report crosses every
  reporting month with every canonical step, so a step with zero events in a
  month still appears with a `deals_count` of `0`.
- **It decouples the reported labels from the source.** `kpi_name` is defined in
  the seed, exactly as worded in the brief, and the report joins counts on
  `(funnel_step_order, substep_order)` rather than on names. Whatever the source
  tables happen to call each stage, the report's labels stay canonical.

## Key findings from the data

- **There is no deals table.** A deal exists only as rows in the `deal_changes`
  log (entity-attribute-value shape). `dim_deals` is reconstructed by pivoting it
  and looking for orphaned deals referenced in the activity table.
- **The funnel is two event types.** Main steps are stage transitions from the
  change log; the Sales Call sub-steps are completed activities. `fct_funnel_events`
  unions both into one grain.
- **`activity_id` is not unique.** Distinct activities share ids, so uniqueness
  is not asserted on it.
- **Every deal enters at stage 1.** Confirmed: all deals begin at Lead Generation,
  though they move non-linearly afterwards (skipping and re-entering stages). A
  singular test enforces that every staged deal has a stage-1 entry, guarding the
  top-of-funnel count.
- **Activity-only deals.** A relationships test revealed deals referenced by
  activities that have no change-log record. `dim_deals` was widened to the full
  referenced deal universe (6,559 deals); these carry null creation, owner, and
  lost-reason attributes.

## Modeling decisions

- **Atomic event grain.** `fct_funnel_events` holds one row per funnel event, so
  re-entries are preserved and the report deduplicates at read time with
  `count(distinct deal_id)`. The natural grain
  (`deal_id, funnel_step_order, substep_order, event_at`) is tested directly, and
  a surrogate key `funnel_event_id` is hashed from those same columns.
- **Ordering keys.** `funnel_step_order` (1–9) plus `substep_order` (0/1) place
  the sub-steps correctly (1, 2, 2.1, 3, 3.1, …) and keep conversion math clean.
  The composed identifier (`2.1`) lives on `dim_funnel_steps`, as a property of
  the step.
- **Two label columns, on purpose.** The fact carries `funnel_step_name`, a
  denormalized label taken from the source stage/activity name, for consumers
  querying the fact directly. The report takes its published `kpi_name` from
  `dim_funnel_steps`, the canonical source.
- **"Entered" means a literal stage-entry event.** Skipped stages are not
  backfilled. A deal jumping 1→4 produces no synthetic rows for 2 and 3. This
  matches the non-linear reality of the data rather than assuming monotonic
  progression.
- **Call timing uses `due_at` (scheduled time)** as a monthly-grain proxy, since
  the source has no completion timestamp. Only completed (`is_done`) calls count.

## KPIs the model supports

Beyond the monthly funnel, the fact table serves, as aggregations over the same
grain: stage-to-stage conversion, funnel drop-off, velocity (time between events
via a window function) and per-rep funnels (joining `dim_deals`).

## Assumptions and limitations

The design rests on a few assumptions, each stated here and, where possible,
enforced by a test:

- **Every deal begins at stage 1 (Lead Generation).** `int_deal_stage_events`
  reads explicit `stage_id` *changes*; if the source ever stopped logging the
  initial stage as a change, Step 1 would undercount. Enforced by a singular test.
- **`stage_id` encodes funnel order.** The source offers no separate order column,
  so `stage_id` is used as the funnel position.
- **Activity type keys `meeting` and `sc_2` decode to Sales Call 1 and 2.** These
  were identified by inspecting `activity_types`; an `accepted_values` test on the
  decoded `call_name` guards the mapping.
- **The event grain has no exact duplicates.** The source `deal_changes` log has
  no natural row key, so the grain's uniqueness is an assertion about source
  cleanliness, enforced by a `unique_combination_of_columns` test on the fact.
- **Call timing is approximated by `due_at`.** See below.

## Testing

Over 70 tests run as part of `dbt build`: source key integrity,
`not_null`/`unique` on grains, `relationships` tests enforcing referential
integrity from the fact to its dimensions, `accepted_values` on controlled
vocabularies, and a set of singular tests covering project-specific invariants,
that every fact step exists in `dim_funnel_steps`, that every fact month is covered
by the date spine, that every staged deal enters Step 1, and that the report grid is
fully dense.

**Severity is chosen deliberately.** Most tests run at `error`: structural
invariants (grain, referential integrity, the brief's step contract) that should
fail the build if violated. One test, `assert_deal_created_before_first_event`,
runs at `warn` by design: because completed calls have no completion timestamp,
their scheduled time (`due_at`) is used as a monthly-grain proxy, and a call
scheduled just before a deal's logged creation can legitimately invert the
timeline. It currently flags 1 of 6,559 deals (`deal_id` 984965), confirming the
proxy is sound rather than systematically skewed.

## SQL efficiency

The dataset is small, so all models run in milliseconds. Efficiency choices are
made for scalability and clarity: early filtering in staging and intermediate
CTEs, `union all` for the funnel event stream (where the two event types are
disjoint and no dedup is needed) versus `union` for the deal universe (where the
distinct grain is required), single-pass window functions for deal reconstruction,
integer joins on ordering keys, and explicit column selection in the marts.