# Investigate commented-out `loadedModels` cache in `loadEntityModel`

**File:** `source/retrograde/api/opengles3.d:80-84`

There is commented-out code in `loadEntityModel` that attempted to short-circuit GPU upload by checking if a model had already been loaded:

```d
// if (loadedModels.exists(model.name)) {
//     //TODO: Attach a GlModelInfoComponent to this entity with the loaded model.
//     //      Probably need to make loadedModels into a map
// }
```

## Questions to answer

- What was `loadedModels`? Was it ever implemented, or was this written speculatively?
- Why was it commented out — compile error, wrong approach, or just incomplete?
- Is there currently a risk of the same model's mesh data being re-uploaded to the GPU every time a new entity references that model?
- If re-uploading is a real problem, implement a model cache: a map from model name (`StringId`) to `GlModelInfo`, so GPU buffers are shared across entities that use the same model.
- The inner TODO notes that attaching a `GlModelInfoComponent` to the entity with the already-loaded model is still needed even in the cache-hit path.
