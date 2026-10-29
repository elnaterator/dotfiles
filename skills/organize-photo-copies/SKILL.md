---
name: organize-photo-copies
description: Help photographers organize a shoot into verified photo copies, with capture-time ordering, shared names for RAW/JPEG companions and sidecars, and optional date folders. Guide source, destination, and naming choices conversationally while preserving originals. Use for preparing photo collections for import or delivery; not image editing or in-place catalog reorganization.
---

# Organize Photo Copies

Help a photographer answer a few questions and receive an organized, verified collection. Use `scripts/organize_photos.py`, resolved relative to this skill. Handle commands and records yourself; users should not need to understand script options, EXIF tags, or JSON.

## Guide the photographer

Use information already provided. Ask only unanswered questions, in small batches, and use examples instead of technical terminology.

1. **Locate the shoot.** “Where are the photos, and where should the organized copies go?” Require an existing input folder and a new destination outside it. Include subfolders by default. If a destination is missing, suggest a sibling folder named after the shoot and confirm that choice. Never guess a source from unrelated folders.
2. **Choose the look.** “What should we call this shoot? Would you like numbered names such as Wedding_0001, date-and-number names, or your original filenames? One folder or folders by capture date?” Recommend numbered names and one shoot folder for a single event. Offer the alternatives without requiring every setting to become a question. Ask about video only if the source contains video or the user mentions it; default to photos and attached sidecars.
3. **Inspect and resolve timing.** Inspect the selected scope before copying. For capture ordering, ask “Should I use the camera times exactly as recorded, or account for time zones and differences between cameras?” Explain recorded times simply and recommend them only when the user indicates camera clocks are comparable. Ask about clock differences when multiple cameras or travel make them relevant; do not require proof of synchronization for an explicitly chosen recorded-time workflow. If timestamps already include offsets, absolute ordering needs no timezone question. Ask where/when the shoot happened only when an offset is needed. Never guess an offset from the computer's current timezone. Travel or daylight-saving transitions may require separate batches or corrected metadata supplied by the user; one assumed offset cannot resolve those automatically.
4. **Show a compact preview.** Report photo groups versus files, size, date range, cameras, excluded items, unmatched sidecars, timing basis, and a few before/after groups. Explain that RAW/JPEG companions count as one photo group. Group repetitive problems into one question, such as “Twelve photos have no capture date. Use their file dates, organize this collection by filename, or stop to correct the dates?” Do not silently fall back. Explain that file dates can reflect export/copy dates.
5. **Finish the authorized job.** Once choices and issues are resolved, copy and verify. Do not introduce another approval step when organizing copies is already authorized. Report the collection location, photo/file counts, verification result, and any exclusions or accepted fallback. Keep the records beside the collection.

Do not ask all possible questions up front. A request giving source, destination, naming, and timing choices can go straight to inspection and preview. If it is unclear whether the request includes a linked working catalog, establish that before renaming copies: catalog references are not updated. Do not rename inside catalogs or application libraries using this workflow.

## Photo selection and grouping

The script selects supported photo extensions plus attached `.xmp`, `.aae`, and `.dop` sidecars. `--include-video` adds supported video files; video capture tags may be unavailable, so resolve missing dates explicitly. Hidden files/directories, catalogs, unrelated files, and unmatched sidecars are excluded and listed in `Organization_Records/summary.json`. This is a photo workflow: an all-files request needs a different approach, never silently claim all files were copied.

Companions share a case-insensitive original stem **within the same source folder**. `IMG_01.CR3`, `IMG_01.JPG`, `IMG_01.xmp`, and `IMG_01.CR3.xmp` become `Wedding_0001.CR3`, `Wedding_0001.JPG`, `Wedding_0001.xmp`, and `Wedding_0001.CR3.xmp`. Folder boundaries prevent unrelated repeated camera filenames from being paired. This is a naming heuristic, not proof of the same exposure. Conflicting capture times/serials or output collisions stop copying for resolution. Same-format variants may need separate source folders or original naming. Do not rewrite sidecar contents or promise internal references or catalog compatibility.

## Check setup automatically

At the start, locate an available Python 3.9+ interpreter and run the bundled script with `--check-dependencies --sort capture` (or the user's already selected ordering). No photo paths are needed and no files are read or written. Reuse that interpreter for the workflow. If Python is absent or too old, guide setup using the platform's existing installation tools and permission process. Do not have the photographer run diagnostics themselves when you can do it.

The runtime uses only Python's standard library: no pip install, virtual environment, requirements file, or PyYAML is needed. PyYAML is only relevant to the separate skill-development validator, never photographer setup.

ExifTool is the sole additional tool for capture-date ordering. Filename (`--sort name`) and file-date (`--sort modified`) organization need only Python; do not check for or install ExifTool for those modes. File dates are not capture dates.

If ExifTool is missing, explain: “To put photos in capture-date order, I need to set up a photo metadata reader once. Organizing by filename works without it.” Retain the user's chosen capture ordering and guide installation through the environment's normal permission process. Use an existing platform package manager when available; otherwise consult the official ExifTool installation instructions for that platform. Do not install a package manager just for this skill, add Python packages, or automatically download executables. Keep technical installation details out of the photo questions. If installation cannot proceed, offer filename/file-date ordering or stopping; change modes only with the user's choice. Re-run the dependency check after setup. Do not install dependencies merely to review or edit this skill.

## Run the workflow

Run `--help` for options. Here `SCRIPT` represents the absolute bundled script path; replace illustrative paths and labels with actual choices.

```bash
python3 "$SCRIPT" --input "/photos/shoot" --output "/photos/shoot-preview" --prefix Wedding --time-basis recorded
```

Default runs write records only. Read `summary.json`, `rename_manifest.csv` when present, and any `issues.txt`; an issue run still writes a diagnostic summary. Resolve issues before copying. Preview and copy runs must use different nonexistent output folders; choose a temporary preview location yourself. Keep input and options unchanged between runs: the script recalculates the plan rather than applying an edited manifest.

```bash
python3 "$SCRIPT" --input "/photos/shoot" --output "/photos/Wedding" --prefix Wedding --time-basis recorded --copy
```

Useful options:

- `--naming sequence` (default), `date` (`YYYY-MM-DD_LABEL_NNNN`), or `original`. `--folders shoot` (default) or `date`. Date folders/names use the recorded capture date before camera-clock adjustment; modified-time ordering/fallback uses the UTC file date. Explain this if corrections cross midnight.
- `--sort capture` (default), `name` (lexicographic relative paths), or `modified`. Date names/folders require capture or modified ordering.
- `--missing-time error` is the default. `modified` is an explicitly accepted fallback at photo-group level. Companions inherit their group's timestamp; sidecars do not need their own dates.
- `--time-basis absolute` (default) normalizes capture timestamps to UTC, preserving fractions and explicit offsets. Missing offsets require a verified `--assume-offset=-07:00`. `--time-basis recorded` compares camera wall-clock times, ignoring offsets; its internal normalized values do not establish real UTC instants. Do not combine it with an assumed offset.
- `--clock-offsets /path/to/offsets.json` maps camera serials to seconds to **add** for sorting only. A camera two minutes ahead needs `-120`. Prepare this file yourself from the user's answers. Ties use serial and source path deterministically; they cannot prove exact shot order.
- `--prefix` defaults to `Photo`, allowing 1–120 letters, digits, underscores, and hyphens. Translate a human shoot label into a readable compatible prefix and show it in the preview. `--start 1`, `--digits 4`, and recursive selection are defaults; `--top-level` excludes subfolders. `--source`/`--label` remain aliases. `--clocks-confirmed` is an optional recorded decision.

## Preserve and verify

Never rename, move, delete, re-export, or write metadata into originals. Existing output folders are refused. Symlinks and special files are refused. Do not bypass protections with overwrite commands.

The script makes exclusive byte copies and checks source/copy SHA-256 hashes, final copied-file counts, and the source file inventory. Checksums cover content and embedded metadata, not filesystem times, permissions, or extended attributes. This does not deduplicate images or establish a separate backup.

Require `verification_report.txt` to say `PASS`, each manifest row to say `SHA-256 verified`, and counts/names to match the plan. Interrupted runs may leave partial files and an `INCOMPLETE` report; retain them and retry in a fresh output folder after addressing the cause. No resume or automatic cleanup is provided. Remove previews or partial outputs only within the user's authorization after inspecting their contents; never remove originals as cleanup.
