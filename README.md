# Pipedrive Sales Funnel — Analytics Engineering Assessment

A layered dbt project that models a Pipedrive CRM export into a reusable
dimensional model and produces a monthly sales-funnel report
(`rep_sales_funnel_monthly`).

## Setup

1. `docker compose up` — starts the local Postgres and loads the source data.
 ```
    Host: localhost
    User: admin
    Password: admin
    Port: 5432 
```
2. `dbt deps` — installs package dependencies (`dbt_utils`).
3. `dbt build` — runs all models and tests.

Connect to the database with any client (DBeaver, DataGrip). Source data lands
in the `public` schema; models build into `public_pipedrive_analytics`.

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
many the model can serve (conversion, drop-off, velocity, per-rep funnels,
activity intensity).

## Architecture

The project follows the standard three-layer dbt structure.

**Staging** (`models/staging/pipedrive/`): one view per source table, renamed
and typed, no business logic. A 1:1 cleaned mirror of the raw data.

**Intermediate** (`models/intermediate/`): business logic and reshaping. Stage
entries and completed calls are extracted as event streams and unified; deals
are reconstructed from the change log.

**Marts** (`models/marts/`): the published dimensional model: `fct_funnel_events`
plus `dim_deals`, `dim_stages`, `dim_users`, `dim_date`, and the reporting model.

Naming follows Kimball convention (`fct_`, `dim_`). The dbt style guide favours
unprefixed entity names; the Kimball prefixes are used here for immediate
fact-versus-dimension legibility.

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
  though they move non-linearly afterwards (skipping and re-entering stages).
- **Activity-only deals.** A relationships test revealed deals referenced by
  activities that have no change-log record. `dim_deals` was widened to the full
  referenced deal universe (6,559 deals); these carry null creation, owner, and
  lost-reason attributes.

## Modeling decisions

- **Atomic event grain.** `fct_funnel_events` holds one row per funnel event, so
  re-entries are preserved and the report deduplicates at read time with
  `count(distinct deal_id)`.
- **Ordering keys.** `funnel_step_order` (1–9) plus `substep_order` (0/1) place
  the sub-steps correctly (1, 2, 2.1, 3, 3.1, …) and keep conversion math clean.
- **Call timing.** Only completed calls count as funnel entries. The source has
  no completion timestamp, so the scheduled time is used as a monthly-grain proxy.
- **Surrogate key.** `funnel_event_id` is hashed from the grain columns and tested
  for uniqueness.

## KPIs the model supports

Beyond the monthly funnel, the fact table serves, as aggregations over the same
grain: stage-to-stage conversion, funnel drop-off, velocity (time between events
via a window function) and per-rep funnels (joining `dim_deals`).

## SQL efficiency

The dataset is small, so all models run in milliseconds. Efficiency choices
(early filtering, `union all` over `union`, single-pass window functions,
integer joins on ordering keys, explicit column selection in marts) are made for
scalability and clarity.

## Testing

56 tests: source key integrity, `not_null`/`unique` on grains, `relationships`
tests enforcing referential integrity from the fact to its dimensions, and
`accepted_values` on controlled vocabularies.