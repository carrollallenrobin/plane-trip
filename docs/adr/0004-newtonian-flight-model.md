---
status: accepted
---

# Newtonian flight model

ADR 0002 kept the original Triplane Classic flight model, a scalar speed along the nose with gravity and drag as rules on that scalar. Playtests on 2026-10-17 found it sluggish and unable to sustain a climb, and a tuned scalar variant with fading thrust and weak drag felt like a dead end. We replaced it with a force model: velocity is a vector, and propeller thrust, gravity, parasitic and induced drag and lift from the angle of attack act on it. The nose is only where the plane points; a weathervane trims it to one G, and the stick cannot hold more than the stall angle. Everything that is not about speed keeps the original's rules: the half-roll, the landing cone, the ground roll, the stop speed, the Spin on death, the gun's rate of fire and the hit box.

## Considered options

- **Keep tuning the scalar model**: every feel request became a new special rule (fading thrust, dive-scaled coasting drag, asymmetric gravity). The rules fought each other.
- **Full aerodynamics with pitching moments and rotational inertia**: fights an arcade stick; rejected during the design grilling.

## Consequences

- Acceleration time and dive gain are tied through the drag at top speed. A force model cannot give both two seconds to top speed and large dive gains; this one is punchy early, slow over the last 20 percent, and rewards dives. That trade-off is the design, not a tuning gap.
- Stall speed and corner turn rate are the same number: both come from maximum lift at a given speed. Turn rate rises with speed up to the corner and falls beyond it, the opposite of the scalar model at low speed.
- The AI was written for the original energy model. It navigates by velocity direction and uses the model's turn rates and drag for its turn-around and ceiling guard; the deviations that lift-based turning forced (speed thresholds as fractions of top speed, the braking turn-around, the approach that holds speed) are listed at the top of `AiPilot` and in docs/design.md, Missions.
- The original's research remains the reference for the kept rules; the speed terms are documented in docs/design.md, Flight, with the derivations in FlightModel.
