#!/usr/bin/env python3
"""Create organized, checksum-verified photo copies without changing originals.
Python 3.9+; capture sorting requires ExifTool. Default is a records-only preview.
No third-party Python packages are required. Check setup with --check-dependencies.
RAW/JPEG companions and sidecars share a sequence number. See --help for options.
"""
import argparse
import csv
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


def capture_time(value, subsecond='', offset='', assumed_offset=None, time_basis='absolute'):
    """Parse EXIF or XMP capture times without throwing away fractions/offsets."""
    value = str(value).strip()
    value = re.sub(r'^(\d{4}):(\d{2}):(\d{2})', r'\1-\2-\3', value)
    value = value.replace(' ', 'T', 1)
    if subsecond and not re.search(r'T\d\d:\d\d:\d\d\.', value):
        value = re.sub(r'(T\d\d:\d\d:\d\d)', r'\1.' + str(subsecond), value)
    has_offset = bool(re.search(r'(Z|[+-]\d\d:\d\d)$', value))
    used_assumption = False
    if time_basis == 'recorded':
        value = re.sub(r'(Z|[+-]\d\d:\d\d)$', '', value)
        offset, assumed_offset, has_offset = '', '+00:00', False
    if not has_offset:
        chosen = offset or assumed_offset
        if not chosen:
            raise ValueError('capture time has no timezone; supply a verified --assume-offset')
        value += chosen
        used_assumption = not bool(offset)
    # Python datetime supports microseconds. Refuse finer precision rather than
    # silently truncate it and potentially change the chronological ordering.
    fraction = re.search(r'\.(\d+)', value)
    if fraction and len(fraction.group(1)) > 6:
        raise ValueError('capture time precision exceeds six fractional digits')
    # Python 3.9 accepts only three or six fractional digits. Padding preserves
    # the exact instant while also supporting the cameras' two-digit fractions.
    if fraction:
        value = value[:fraction.start(1)] + fraction.group(1).ljust(6, '0') + value[fraction.end(1):]
    parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.tzinfo is None:
        raise ValueError('timezone could not be established')
    return parsed.astimezone(timezone.utc), used_assumption


def digest(path):
    """Read the file in small pieces so large PNGs do not fill memory."""
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def inventory(source, recursive=True):
    """Include every regular file; refuse links and special files explicitly."""
    files = []
    def fail(error):
        raise error
    for directory, dirs, names in os.walk(source, followlinks=False, onerror=fail):
        for name in dirs + names:
            path = Path(directory) / name
            if path.is_symlink():
                raise ValueError(f'Symbolic links are not supported: {path}')
        for name in names:
            path = Path(directory) / name
            if not path.is_file():
                raise ValueError(f'Not a regular file: {path}')
            files.append(path)
        if not recursive:
            dirs[:] = []
    return sorted(files)


def read_metadata(files):
    """Read explicit file batches so every extension and hidden file is covered.

    ExifTool may report an unsupported format for ordinary documents; those files
    remain included and use the selected missing-time policy.
    """
    metadata = {}
    for index in range(0, len(files), 100):
        command = ['exiftool', '-json', '-G', '-DateTimeOriginal',
                   '-SubSecTimeOriginal', '-OffsetTimeOriginal', '-Model',
                   '-SerialNumber'] + [str(p) for p in files[index:index + 100]]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode not in (0, 1) or not result.stdout.strip():
            raise RuntimeError('Metadata reader failed: ' + result.stderr.strip())
        for item in json.loads(result.stdout):
            metadata[Path(item['SourceFile']).resolve()] = item
    if set(metadata) != set(files):
        raise RuntimeError('Metadata reader did not return every input file')
    return metadata


PHOTO_EXTENSIONS = set('.jpg .jpeg .tif .tiff .png .heic .heif .avif .webp .dng .cr2 .cr3 .crw .nef .nrw .arw .srf .sr2 .raf .orf .rw2 .rwl .pef .ptx .3fr .fff .iiq .mos .mrw .x3f .srw .raw'.split())
VIDEO_EXTENSIONS = set('.mov .mp4 .m4v .avi .mts .m2ts .mxf'.split())
SIDECAR_EXTENSIONS = {'.xmp', '.aae', '.dop'}


def photo_groups(files, source, include_video=False):
    """Match companions only inside the same source directory."""
    groups, excluded, unmatched = {}, [], []
    media_extensions = PHOTO_EXTENSIONS | (VIDEO_EXTENSIONS if include_video else set())
    visible = [p for p in files if not any(part.startswith('.') for part in p.relative_to(source).parts)]
    for p in visible:
        if p.suffix.lower() in media_extensions:
            key = (p.parent, p.stem.casefold())
            groups.setdefault(key, []).append(p)
    for p in visible:
        if p.suffix.lower() not in SIDECAR_EXTENSIONS:
            continue
        # Both IMG_01.xmp and IMG_01.CR3.xmp retain their attachment syntax.
        base = Path(p.stem)
        stem = base.stem if base.suffix.lower() in media_extensions else p.stem
        key = (p.parent, stem.casefold())
        if key in groups:
            groups[key].append(p)
        else:
            unmatched.append(str(p.relative_to(source)))
    selected = {p for group in groups.values() for p in group}
    excluded = [str(p.relative_to(source)) for p in files if p not in selected]
    return list(groups.values()), excluded, unmatched


def member_suffix(path):
    if path.suffix.lower() in SIDECAR_EXTENSIONS and Path(path.stem).suffix.lower() in PHOTO_EXTENSIONS | VIDEO_EXTENSIONS:
        return Path(path.stem).suffix + path.suffix
    return path.suffix


def main():
    if sys.version_info < (3, 9):
        raise RuntimeError('Python 3.9 or newer is required. No Python packages need installing.')
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--check-dependencies', action='store_true', help='Check setup without reading photos or writing files; optionally select --sort')
    parser.add_argument('--input', '--source', dest='source', type=Path, help='Existing input root folder')
    parser.add_argument('--output', type=Path, help='New output folder outside the input root')
    parser.add_argument('--prefix', '--label', dest='prefix', default='Photo', help='Shoot label (default: Photo)')
    parser.add_argument('--start', type=int, default=1, help='First sequence number')
    parser.add_argument('--digits', type=int, default=4, help='Minimum sequence width')
    parser.add_argument('--top-level', action='store_true', help='Do not include subfolders')
    parser.add_argument('--sort', choices=['capture', 'modified', 'name'], default='capture')
    parser.add_argument('--missing-time', choices=['modified', 'error'], default='error', help='Policy for groups without capture metadata (default: error)')
    parser.add_argument('--assume-offset', help='Verified timezone for capture times without an offset, e.g. --assume-offset=-07:00')
    parser.add_argument('--clock-offsets', type=Path, help='JSON mapping camera body serials to seconds to ADD for sorting')
    parser.add_argument('--clocks-confirmed', action='store_true', help='Record a reviewed decision about camera clocks (optional)')
    parser.add_argument('--include-video', action='store_true', help='Include video companions; capture tags may be unavailable')
    parser.add_argument('--time-basis', choices=['absolute', 'recorded'], default='absolute', help='Absolute instants or camera wall-clock times as recorded')
    parser.add_argument('--naming', choices=['sequence', 'date', 'original'], default='sequence')
    parser.add_argument('--folders', choices=['shoot', 'date'], default='shoot', help='One shoot folder or capture-date subfolders')
    parser.add_argument('--copy', action='store_true', help='Create copies; default writes a preview manifest only')
    args = parser.parse_args()
    exiftool = shutil.which('exiftool') if args.sort == 'capture' else None
    if args.check_dependencies:
        ready = args.sort != 'capture' or bool(exiftool)
        print(json.dumps(dict(ready=ready, python=sys.version.split()[0],
            python_packages_required=[], ordering=args.sort,
            exiftool_required=args.sort == 'capture', exiftool_path=exiftool,
            guidance=('Ready. No additional setup needed.' if ready else
                'Capture-date organization needs ExifTool. Install it using your platform installer or existing package manager, then check again. Filename and file-date organization work without it; change ordering only if the photographer chooses it.')), indent=2))
        return 0 if ready else 1
    if args.source is None or args.output is None:
        parser.error('--input and --output are required except when checking dependencies.')
    if args.sort == 'capture' and not exiftool:
        parser.error('Organizing by capture date needs ExifTool. Run --check-dependencies for setup guidance. No photos were read or copied. Filename and file-date ordering work without it; choose those only if intended.')
    source, output = args.source.expanduser().resolve(), args.output.expanduser().resolve()
    if not source.is_dir():
        parser.error('Input must be an existing folder.')
    if output == source or source in output.parents:
        parser.error('Output must be outside the input root to prevent copying output into itself.')
    if output.exists() or args.output.expanduser().is_symlink():
        parser.error('Output already exists. Choose a new folder for each run.')
    if not output.parent.is_dir():
        parser.error('The output parent folder must already exist.')
    if not re.fullmatch(r'[A-Za-z0-9_-]+', args.prefix) or len(args.prefix) > 120:
        parser.error('Prefix must be 1–120 letters, digits, underscores, or hyphens.')
    if args.start < 0 or not 1 <= args.digits <= 20:
        parser.error('Start must be nonnegative and digits must be between 1 and 20.')
    if args.assume_offset and not re.fullmatch(r'[+-](?:[01]\d|2[0-3]):[0-5]\d', args.assume_offset):
        parser.error('Use a timezone offset such as -07:00.')
    adjustments = json.loads(args.clock_offsets.read_text()) if args.clock_offsets else {}
    if not isinstance(adjustments, dict) or any(type(v) not in (int, float) or not math.isfinite(v) for v in adjustments.values()):
        parser.error('Clock offsets must map serial numbers to finite numeric seconds.')
    if adjustments and args.sort != 'capture':
        parser.error('Clock adjustments require --sort capture.')

    if args.time_basis == 'recorded' and args.assume_offset:
        parser.error('Recorded local times do not use --assume-offset.')
    if args.sort == 'name' and (args.naming == 'date' or args.folders == 'date'):
        parser.error('Date names/folders require capture or modified ordering.')
    all_files = inventory(source, not args.top_level)
    groups, excluded, unmatched = photo_groups(all_files, source, args.include_video)
    if not groups:
        parser.error('No supported photos found. Videos require --include-video.')
    files = sorted(p for group in groups for p in group)
    metadata = read_metadata(files) if args.sort == 'capture' else {}
    rows, issues, serials, planned = [], [], set(), []
    cameras = set()
    for members in groups:
        media = sorted(p for p in members if p.suffix.lower() not in SIDECAR_EXTENSIONS)
        times, group_serials = [], set()
        for path in members:
            m = metadata.get(path, {})
            serial = str(m.get('EXIF:SerialNumber') or m.get('XMP:SerialNumber') or '')
            model = str(m.get('EXIF:Model') or m.get('XMP:Model') or '')
            if serial:
                serials.add(serial)
                group_serials.add(serial)
            if model or serial:
                cameras.add((model, serial))
            for namespace in ('EXIF', 'XMP'):
                raw = m.get(namespace + ':DateTimeOriginal')
                if not raw:
                    continue
                try:
                    moment, assumed = capture_time(raw, m.get(namespace + ':SubSecTimeOriginal', ''),
                        m.get(namespace + ':OffsetTimeOriginal', ''), args.assume_offset, args.time_basis)
                    # Keep the recorded date for folder names, independent of UTC conversion.
                    day = re.sub(r'^(\d{4}):(\d{2}):(\d{2})', r'\1-\2-\3', str(raw))[:10]
                    times.append((moment, str(raw), assumed, serial, day))
                except (ValueError, OverflowError) as error:
                    issues.append(f'{path.relative_to(source)}: {error}')
        if len(group_serials) > 1:
            issues.append(f'{media[0].relative_to(source)}: companion camera serials conflict')
        serial = next(iter(group_serials), '')
        adjustment = adjustments.get(serial, 0)
        raw, assumed, day = '', False, ''
        if args.sort == 'capture' and times:
            if any(t[0] != times[0][0] for t in times[1:]):
                issues.append(f'{media[0].relative_to(source)}: companion capture times conflict; resolve grouping or metadata')
            moment, raw, assumed, _, day = times[0]
            moment += timedelta(seconds=adjustment)
            basis = 'capture ' + args.time_basis
        elif args.sort == 'capture' and args.missing_time == 'error':
            issues.append(f'{media[0].relative_to(source)}: missing capture timestamp for photo group')
            continue
        elif args.sort != 'name':
            moment = datetime.fromtimestamp(media[0].stat().st_mtime, timezone.utc)
            day = moment.date().isoformat()
            basis = 'modified fallback' if args.sort == 'capture' else 'modified'
        else:
            moment, basis = None, 'relative filename'
        planned.append(dict(members=members, media=media, moment=moment, day=day, raw=raw,
                            assumed=assumed, serial=serial, adjustment=adjustment, basis=basis))
    if set(adjustments) - serials:
        issues.append('Clock offsets include unknown camera serial numbers')
    planned.sort(key=lambda g: (g['moment'].isoformat() if g['moment'] else '', g['serial'], str(g['media'][0].relative_to(source))))
    width = max(args.digits, len(str(args.start + len(planned) - 1)))
    targets = set()
    for number, group in enumerate(planned, args.start):
        stem = f'{args.prefix}_{number:0{width}d}'
        if args.naming == 'date':
            stem = group['day'] + '_' + stem
        for path in sorted(group['members']):
            name = path.name if args.naming == 'original' else stem + member_suffix(path)
            proposed = str(Path(group['day']) / name) if args.folders == 'date' else name
            if proposed.casefold() in targets:
                issues.append(f'Output name collision: {proposed}; choose sequence naming or resolve duplicate companions')
            targets.add(proposed.casefold())
            rows.append(dict(group_number=number, original_path=str(path.relative_to(source)), proposed_name=proposed,
                recorded_capture_time=group['raw'], sort_time=group['moment'].isoformat() if group['moment'] else '',
                ordering_basis=group['basis'], camera_serial=group['serial'],
                assumed_offset=args.assume_offset if group['assumed'] and args.time_basis == 'absolute' else '',
                clock_adjustment_seconds=group['adjustment'], sha256='', verification='pending'))

    output.mkdir(exist_ok=False)
    records = output / 'Organization_Records'
    records.mkdir()
    settings = {key: str(value) if isinstance(value, Path) else value for key, value in vars(args).items()}
    settings.update(source=str(source), output=str(output), clock_offsets_seconds=adjustments)
    (records / 'settings.json').write_text(json.dumps(settings, indent=2) + '\n')
    total_bytes = sum(p.stat().st_size for p in files)
    summary = dict(photo_groups=sum(any(p.suffix.lower() in PHOTO_EXTENSIONS for p in g) for g in groups),
        media_groups=len(groups), files=len(files), total_bytes=total_bytes,
        capture_date_range=[min((g['day'] for g in planned if g['day']), default=''), max((g['day'] for g in planned if g['day']), default='')],
        cameras=[dict(model=m, serial=s) for m, s in sorted(cameras)],
        missing_time_groups=sum('missing capture timestamp' in issue for issue in issues),
        fallback_groups=sum(g['basis'] == 'modified fallback' for g in planned),
        excluded_files=excluded, unmatched_sidecars=unmatched, issues=issues,
        sample_groups=[[dict(source=r['original_path'], destination=r['proposed_name']) for r in rows if r['group_number'] == n]
                       for n in sorted({r['group_number'] for r in rows})[:5]])
    (records / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(f"Found {summary['photo_groups']} photo groups, {len(files)} files, {total_bytes} bytes; {len(excluded)} excluded; {len(unmatched)} unmatched sidecars.")
    if issues:
        (records / 'issues.txt').write_text('\n'.join(issues) + '\n')
        print(f'Stopped: {len(issues)} issue(s). No files copied. See {records}')
        return 1
    manifest = records / 'rename_manifest.csv'
    def save_manifest():
        with manifest.open('w', newline='', encoding='utf-8') as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
    save_manifest()
    fallback_count = sum(r['ordering_basis'] == 'modified fallback' for r in rows)
    print(f'Planned {len(rows)} files; {fallback_count} use modification-time fallback.', flush=True)
    if not args.copy:
        print(f'Preview only. No files copied. Review {manifest}')
        return 0
    total_bytes = sum(p.stat().st_size for p in files)
    if shutil.disk_usage(output).free < total_bytes:
        raise RuntimeError('Insufficient free space for the copies')
    destination = output / 'Organized'
    destination.mkdir()
    report = records / 'verification_report.txt'
    report.write_text('INCOMPLETE: copying and verification in progress.\n')
    try:
        for number, row in enumerate(rows, 1):
            original, target = source / row['original_path'], destination / row['proposed_name']
            if original.is_symlink() or not original.is_file():
                raise RuntimeError(f'Source is no longer a regular file: {original}')
            target.parent.mkdir(parents=True, exist_ok=True)
            before = digest(original)
            # Exclusive creation prevents overwrites. Binary copying never
            # decodes images, re-exports them, or rewrites embedded metadata.
            with original.open('rb') as incoming, target.open('xb') as outgoing:
                shutil.copyfileobj(incoming, outgoing, length=1024 * 1024)
            if digest(target) != before or digest(original) != before:
                raise RuntimeError(f'Checksum mismatch or source changed: {original}')
            row['sha256'], row['verification'] = before, 'SHA-256 verified'
            save_manifest()
            print(f'Verified {number}/{len(rows)}: {target.name}', flush=True)
        if set(inventory(source, not args.top_level)) != set(all_files):
            raise RuntimeError('Input file inventory changed during copying')
        if len([p for p in destination.rglob('*') if p.is_file()]) != len(files):
            raise RuntimeError('Final file count mismatch')
        report.write_text(f'PASS: {len(rows)} copies verified with SHA-256.\nOriginals were not written.\n')
    except BaseException as error:
        report.write_text(f'INCOMPLETE: {error}\nOriginals were not written; retain records for review.\n')
        raise
    print(f'Complete. Verified collection: {destination}')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.SubprocessError, RuntimeError) as error:
        print(f'Stopped safely: {error}', file=sys.stderr)
        sys.exit(1)
