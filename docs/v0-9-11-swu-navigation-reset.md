# Version 0.9.11 — SWU Navigation Reset

Some SWU builds retain the completed destination after exiting hyperspace.
This leaves the navigation console showing the previous planet and prevents a
new planet from being selected.

After every successful or forced arrival, Convergence now resets:

- selected/target planet
- target vector
- loading state
- jump progress
- estimated jump time
- search term and page
- Convergence's external speed modifier
- cached destination and travel profile

The ship's current universe position is not cleared.

## Recovery command

If a navigation computer was already stuck before installing this update, run:

```text
convergence_swu_reset_navigation
```

Then reopen or use the navigation console and select a new destination.
