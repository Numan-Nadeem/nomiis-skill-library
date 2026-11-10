---
name: strip-image-metadata
description: Detect and remove AI-generation fingerprints (C2PA / Content Credentials manifests) and other embedded metadata (EXIF, XMP, IPTC) from image files, while keeping the visible pixels byte-for-byte identical. Use this when asked to strip AI watermarks/fingerprints/synth IDs from an image, remove Content Credentials, "clean" an image's metadata, or check whether an image carries a C2PA provenance manifest.
---

# Strip Image Metadata / AI Content Credentials

## Goal

Remove provenance/fingerprinting data embedded in an image file — most
importantly **C2PA (Content Credentials)** manifests, which are JUMBF-boxed
data that tools like Adobe Firefly, OpenAI, and others embed to record
generation/edit history — plus any other non-essential metadata (EXIF, XMP,
IPTC, custom ancillary chunks). The visible image content must remain
pixel-identical; only container-level metadata is removed.

Never re-encode or recompress the pixel data. Only strip/rebuild the
container structure.

## Step 1: Locate and identify the file

Confirm the exact path of the target image before doing anything. If given
only a filename, search for it rather than guessing a path.

Determine the format from the file signature:
- PNG: starts with `89 50 4E 47 0D 0A 1A 0A`
- JPEG: starts with `FF D8`

## Step 2: Inspect before modifying

Hex-dump the first ~150-200 lines of the file (e.g. `xxd file | head -150`,
or read the file's binary content directly) and identify what's embedded.
Look for these signatures in the dump:

- `c2pa`, `jumb`, `jumd`, `JUMBF`, `urn:c2pa:` — C2PA / Content Credentials
- `xmp`, `adobe:ns:meta` — XMP metadata
- `Exif` — EXIF metadata
- `Photoshop`, `IPTC` — IPTC/Photoshop metadata
- Names of AI tools/vendors (`OpenAI`, `DALL`, `Midjourney`, `Stability`,
  `Firefly`, `digitalSourceType`, `trainedAlgorithmicMedia`)

For PNG specifically, walk the chunk structure: each chunk is
`[4-byte length][4-byte type][data][4-byte CRC]` after the 8-byte signature.
C2PA is often smuggled into a non-standard chunk type (seen in the wild as
`caBX`, but it can be any 4-byte type — treat any chunk type outside
`IHDR, PLTE, tRNS, IDAT, IEND` as removable metadata).

For JPEG, walk the marker segments (`FF xx [2-byte length incl. itself][data]`).
C2PA/EXIF/XMP/IPTC live in `APPn` markers (`FF E0`-`FF EF`) and `COM` (`FF FE`).
C2PA specifically is usually in `APP11` (`FF EB`).

**Report findings to the user before stripping** (what was found, chunk/segment
names and sizes, and any manifest ID like a `urn:c2pa:...` UUID).

## Step 3: Choose a stripping method

Prefer, in order, whatever is actually installed and working in the current
environment (verify with `--version` — don't assume a tool is present just
because it's on PATH in theory; e.g. Windows' `python.exe` App Execution Alias
stub can appear present but fail to actually run):

1. `exiftool -all= -F <file>` — best general option if available.
2. ImageMagick: `magick <in> -strip <out>` / `convert <in> -strip <out>`.
3. Bundled scripts in this skill (`scripts/strip_png_metadata.js` and
   `scripts/strip_jpeg_metadata.js`) — pure Node.js, no dependencies, works
   anywhere Node is available. These directly rebuild the file keeping only
   rendering-critical chunks/markers, which is exactly what's needed to
   remove C2PA/EXIF/XMP/IPTC without touching pixel data.

Usage of the bundled scripts:
```
node scripts/strip_png_metadata.js <input.png> <output.png>
node scripts/strip_jpeg_metadata.js <input.jpg> <output.jpg>
```
Both print which chunks/segments were kept vs. removed, plus before/after
file sizes.

Note: the JPEG script handles standard baseline/progressive files by keeping
everything from the first `SOS` marker onward untouched (scan data), and only
strips `APPn`/`COM` marker segments that appear before it. This covers the
vast majority of real-world JPEGs. If a file is unusually structured, prefer
`exiftool` if available.

## Step 4: Never overwrite the original

Write output to a new file (e.g. `name_clean.png`) unless the user explicitly
asks to replace the original in place.

## Step 5: Verify

- Re-scan the cleaned file for the signatures from Step 2 and confirm zero
  matches (e.g. `grep -c "c2pa" output_file` → `0`).
- Open/render the cleaned image and visually confirm it's identical to the
  original.
- Report the removed chunk/segment types, sizes, and the before/after file
  size.

## Step 6: Wrap up

Summarize what was found and removed, where the clean file was written, and
that the original is untouched. Offer to delete the original or replace it
in place if the user wants. Clean up any one-off temporary scripts you wrote
yourself (the bundled scripts in this skill directory should stay, they're
reusable).
