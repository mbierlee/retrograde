---
name: asset-info
description: Display statistics about Retrograde asset files (.rgm models and .rgi images) using the rgassetinfo tool, formatted as a clean Markdown table plus a plain-language summary. Use when the user asks to "show asset info", "inspect an asset", "what's in this .rgm/.rgi", "describe this model/texture", or otherwise wants a readable breakdown of a Retrograde asset file or a directory of them.
---

# Asset Info (Retrograde)

Inspect a Retrograde asset file with the `rgassetinfo` tool and present the
result as a tidy Markdown table followed by a short, plain-language summary
that interprets the numbers (not just repeats them).

## Tool

- Binary: `tools/bin/rgassetinfo`, relative to the project root.
  The user is most likely already in the project's working directory, so
  resolve the project root from the current directory (`pwd` on Unix, `cd` with
  no args on Windows) and invoke the binary by its absolute path.
- Usage: `rgassetinfo <input>`
- `<input>` is a path to a `.rgm` (Retrograde Model) or `.rgi` (Retrograde
  Image) file, **or** a directory (all RGM/RGI files inside are inspected,
  non-recursive).
- Useful flag: `--valid-only` silently skips files not recognized as
  Retrograde assets (handy when pointing at a mixed directory).
- The tool only reads files; it never modifies them.

## Procedure

1. **Resolve the target.** Use the path the user gave. If they referenced a
   file by name without a path (e.g. "texturedcube.rgm"), or named no file at
   all, find it relative to the current working directory / the asset
   directories in context before falling back to a broader search. If still
   ambiguous, ask which file they mean.

2. **Run the tool** on the resolved path:

   ```
   <project-root>/tools/bin/rgassetinfo <path>
   ```

   For a directory, add `--valid-only` if it likely contains non-asset files.

3. **If the tool errors** (unrecognized path, not a Retrograde asset, etc.),
   report the error plainly and stop — don't fabricate stats.

4. **Format the output as Markdown.** Lead with a top-level summary table of
   the headline fields, then any per-mesh / per-material / per-texture (for
   `.rgm`) breakdown as a bulleted list. Keep the field names from the tool;
   don't invent fields it didn't emit. Drop the redundant repeated `File:`
   line — put the filename in the heading instead.

5. **End with a plain-language summary** (1–3 sentences) that *interprets* the
   data: what kind of asset this is, anything notable (e.g. "24 verts / 12
   faces is the classic cube layout — 4 unique verts per face × 6 faces so
   each face gets its own UVs", an external vs. embedded texture reference, an
   indexed-color image with a small palette, an unusually large file, etc.).
   This interpretation is the point of the skill — don't skip it.

6. **Only write to a file if the user asks.** By default, show the result in
   the reply. If asked to save it, write the same Markdown to the requested
   path.

## Output shape

For a model (`.rgm`):

```markdown
# Asset Info: texturedcube.rgm

| Property | Value |
|---|---|
| Format | RGM (Retrograde Model), version 1 |
| Size on disk | 979 bytes |
| Meshes | 1 |
| Materials | 1 |
| Textures | 1 |
| Total vertices | 24 |
| Total faces | 12 |
| UV channels | 1 |
| Meshes with normals | 1 |
| Meshes with tangents | 0 |

## Details

- **Mesh 0** — 24 vertices, 12 faces, 1 UV channel, normals, uses material 1
- **Material 0** — index 1, type *Unlit*, references texture 1
- **Texture 0** — index 1, type *reference*, path `assets/test1024.rgi`

The 24 vertices / 12 faces is the classic cube layout (4 unique verts per
face × 6 faces), so each face gets its own UVs, and it points to an external
texture `assets/test1024.rgi` rather than embedding one.
```

For an image (`.rgi`), use the fields the tool emits — Dimensions,
Compression, Channels, Channel format, Color mode, Index format, Palette,
Expanded pixel data — in the table, then a summary noting e.g. that it's an
indexed-color image with a small palette that expands from N bytes on disk to
M bytes of pixel data.

For a directory, produce one section per file (heading + table + summary).
