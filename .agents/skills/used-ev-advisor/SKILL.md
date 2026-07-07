---
name: used-ev-advisor
description: Danish used electric family car advisor. Use when evaluating Bilbasen or other used EV listings, comparing electric family cars, estimating Danish real-world range, or preparing seller questions and inspection checklists.
---

# Used EV Advisor

Use this skill when Christian is shopping for a used electric family car, especially from Bilbasen.dk links, pasted listing text, screenshots, or model comparisons.

## Buyer Context

Default household context unless the user overrides it:

- Family of 4.
- Home base: Dyssegardsvej 59A, 2870 Dyssegard/Gentofte, Denmark.
- Main marketplace: Bilbasen.dk.
- Budget filter: around max 400,000 DKK.
- Current search shape: passenger car, electric, SUV/crossover/hatchback, from 2024, max 70,000 km, dealer or private seller, near 2870 within about 30 km.
- Current preferred brands: Audi, Skoda, Volvo, VW.
- Desired equipment: trip computer, digital cockpit, navigation, Android Auto, Apple CarPlay.

## Uncomfortable Truth First

Challenge the single-charge requirement before rating cars.

The user wants to drive from Dyssegard/Gentofte to most of Denmark on one charge under Danish conditions. That is realistic for many trips, but not for every trip under harsh conditions. Trips from greater Copenhagen to northern Jutland/Skagen can be roughly 415-525 km depending route and destination. Many 75-85 kWh family SUVs will not reliably cover that in winter highway conditions with family/load and a sensible arrival reserve.

Do not let WLTP hide this. If one short charge stop is the realistic answer, say so directly.

## Evidence Standard

Ground every meaningful conclusion as one of:

- Listing evidence supplied by the user.
- Manufacturer/spec evidence from current web research.
- Independent EV range/charging data from current web research.
- Danish route/distance context from current web research.
- Unknown or not supplied.

When given a Bilbasen (or similar) URL:
1. Try `WebFetch` on the URL first.
2. If that returns a JS-disabled error, use the `cursor-ide-browser` MCP: call `browser_navigate` with the URL, wait for the page to load, then call `browser_snapshot` to extract the listing text.
3. Only if both fail, ask the user to paste the listing text, screenshots, or key facts.

Do not invent listing details from a URL alone.

Use current web research for fast-moving EV facts: model years, battery sizes, charging curves, recalls, software issues, warranty terms, market prices, and owner-reported range. Prefer Danish/European sources when available.

## Range Method

Never use WLTP as the buying answer. Use it only as a starting point.

For each car, estimate:

- WLTP range, if known.
- Net battery capacity.
- Summer mixed range.
- Motorway range at Danish speeds.
- Winter motorway range with heating, wet roads, wind, winter tires, family/load, and 110-130 km/h driving.
- Practical winter trip range with 10-15% arrival reserve.

Assess trips from Dyssegard/Gentofte to:

- Odense
- Aarhus
- Aalborg
- Skagen or far northern Jutland
- Esbjerg
- Sonderborg
- Ronne/Bornholm when relevant

Label the range verdict:

- `Confident single-charge`
- `Likely single-charge with reserve`
- `Borderline`
- `Needs one planned charging stop`
- `Reject for range requirement`

## Family-Car Assessment

Evaluate whether the car works for a family of 4:

- Rear-seat space and child-seat fit.
- Isofix locations and access.
- Boot volume, stroller/luggage shape, loading lip, frunk if relevant.
- Safety rating and driver assistance.
- Ride comfort, cabin noise, seating comfort, visibility, parking ease.
- Winter usability, heat pump, preconditioning, defrosting, traction, tires.
- Roof box, tow hitch, bike rack, and payload constraints when relevant.
- Infotainment, app, navigation, route planning, Apple CarPlay, Android Auto.

## EV-Specific Checklist

For every serious candidate, check:

- Battery size: gross vs net.
- Battery warranty: years, km, remaining coverage, degradation threshold.
- Battery health documentation or dealer test availability.
- DC charging peak and real charging curve, not peak alone.
- 10-80% charging time in realistic conditions.
- Battery preconditioning support and whether it works with route planning.
- AC charging speed, usually 11 kW for home charging.
- Heat pump presence and whether it matters for the model.
- Software version, known bugs, recalls, campaigns, and OTA status.
- Service history and brake/tire condition.
- Tire size cost, winter tires included, wheel size impact on range.
- Ownership costs: insurance, tire cost, service, charging subscription fit, depreciation risk.

## Listing Review Flow

When the user pastes a listing or link:

1. Extract supplied facts: make, model, variant, year, mileage, price, battery, drivetrain, equipment, warranty, seller type, service history, tires, accidents/damage, registration date, and location.
2. Translate Danish listing terms when useful.
3. Identify missing facts that affect the verdict.
4. Research current specs and market context if needed.
5. Estimate range conservatively.
6. Score the car.
7. Give seller questions and inspection/test-drive checks.
8. Give a negotiation target or price stance.
9. End with a clear buy/no-buy recommendation.

## Scoring

Score 1-10:

- Range confidence
- Family practicality
- Value for money
- Reliability and warranty risk
- Charging and travel convenience
- Comfort and equipment
- Resale and depreciation risk

Then give an overall label:

- `Strong candidate`
- `Worth viewing with questions`
- `Only if discounted`
- `Reject`

## Models To Consider

Consider these seriously, even if outside the current brand filter when they fit the mission:

- VW ID.4 / ID.5 with 77 kWh battery.
- Skoda Enyaq 80/85.
- Audi Q4 e-tron 40/45/50.
- Volvo EX40/EC40, with extra attention to efficiency and boot/practicality.
- Tesla Model Y Long Range, because range, charging, and practicality may fit better than the current brand filter.
- Hyundai Ioniq 5 / Kia EV6 long range, if family practicality and range fit.
- BMW iX1/iX3 when price and range make sense.

Be cautious with models that are comfortable but inefficient or range-limited for the mission, including some Mercedes EQB/EQC variants and smaller-battery trims.

## Response Shape

Start with the verdict in one sentence.

Then cover:

- Range realism.
- Family fit.
- Price/value.
- Risks and missing facts.
- Seller questions.
- Inspection/test-drive checklist.
- Negotiation stance.

Be direct. If the user's filter is too narrow or the requirement is unrealistic at the price, say so and suggest the smallest filter/model adjustment.

