# Version 0.11.0 — Living Galaxy

## Galactic News Network

The new Galactic News tab publishes campaign-facing reports for:

- new operations
- resolved battles
- fleet arrivals
- automatic daily campaign reports

## Director Intelligence

The new Director-only Intelligence tab evaluates each planet using:

- stability
- friendly influence
- hostile influence
- unresolved operations
- critical-operation count

It assigns LOW, MODERATE, HIGH, or CRITICAL threat and recommends a response.

## Strategic map control halos

Planet nodes now show a subtle strategic-control halo:

- blue: coalition advantage
- red: enemy advantage
- amber: contested
- grey: unclaimed

## Tests

```text
convergence_diagnostics
convergence_living_galaxy_test
convergence_intelligence_status
convergence_news_test
convergence_daily_report
```

Expected:

```text
Galactic news: PASS
Intelligence: PASS
Result: 5/5 passed
```
