# Per-material shadow casting and receiving

**Depends on:** `investigate-shadow-caster-receiver-opt-in.md`

The opt-in plan makes casting and receiving a per-entity choice. That cannot exempt part of a
model: a solid body with a glass window is one entity with two meshes and two materials, and
for now the window has to be split into its own entity to stop it casting.

The next step is to let a material say it does not cast or receive - a flag in RGM, so glass is
marked where it is defined rather than wherever it is placed - on top of the per-entity rule.

(TODO: flesh out this plan)