# edf

A EDF / EDF+ / BDF / BDF+ toolbox for [Nelson](https://nelson-lang.github.io/nelson-website/).

The European Data Format (EDF) and its `plus` extension (EDF+) are the
interchange formats every sleep, EEG and Holter system reads and writes; BDF and
BDF+ are BioSemi's 24-bit variants. This module owns the binary format in one
place and returns a **domain-free** struct, so a reader that gets the header
arithmetic, the little-endian samples or the 24-bit assembly wrong cannot return
a signal that looks plausible and is wrong. It is designed to be a **dependency**
of higher-level toolboxes (such as `ecglab`) rather than to
interpret the signals itself.

## Load

```matlab
run('/path/to/edf/loader.m')
```

## Functions

All functions live in the `edf` package (call them as `edf.read`, `edf.write`, ...).

| Function | Purpose |
|---|---|
| `edf.read(file, ...)` | Read signals and annotations into the neutral struct. Options: `'Signals'`, `'Annotations'`, `'Data'`. |
| `edf.write(file, r, ...)` | Write the neutral struct. Options: `'Format'` (`'EDF+'`\|`'EDF'`\|`'BDF+'`\|`'BDF'`), `'RecordSeconds'`, `'Annotations'`, `'Margin'`. |
| `edf.header(file)` | Read only the header (no samples), fast. |
| `edf.info(file)` | A compact human-readable summary. |
| `edf.isedf(file)` | Probe a file; returns the flavour or `false`, never throws. |
| `edf.annotations(file)` | Read only the annotation list. |
| `edf.anonymize(src, dst, ...)` | Copy a file with the identifying header fields blanked. |
| `edf.crop(src, dst, t0, t1, ...)` | Write a time window (and optional channel subset) to a new file. |
| `edf.select(src, dst, which)` | Write a channel subset to a new file (drop channels). |
| `edf.edit(file, ...)` | Change header/metadata fields in place without re-encoding samples. |
| `edf.merge(dst, sources, ...)` | Concatenate compatible files end to end in time. |
| `edf.resample(source, rate, ...)` | Bring every signal to one common rate in a single aligned matrix (`'Absolute'` = gap-aware). |
| `edf.convert(source, target)` | Convert voltage signals to a target unit (V/mV/uV/nV). |
| `edf.triggers(file, ...)` | Decode the trigger channel (BDF `Status`) into rising-edge events. |
| `edf.prefilter(text)` | Parse a prefilter field into highpass/lowpass/notch. |
| `edf.channeltype(label)` | Guess a signal's kind (eeg/eog/ecg/emg/resp/spo2/status/misc). |
| `edf.compare(a, b, ...)` | Check whether two files carry the same signals/header (round-trip testing). |
| `edf.tobytes(r, ...)` / `edf.frombytes(bytes, ...)` | Write to / read from an in-memory byte vector. |
| `edf.validate(file, ...)` | Check a file against the specification; `'Fix'` repairs the header. |

`edf.read` options: `'Signals'` subset, `'Annotations'` on/off, `'Data'`
header-only, `'Scale', false` (raw digital codes), `'Records', [i j]` /
`'Interval', [t0 t1]` (read only a window of a huge file without loading it all),
`'Units'` (override blank unit fields), and `'Tolerant', true` (read a slightly
out-of-spec file, reporting problems in `r.warnings` instead of failing). Every read also exposes, per signal,
the parsed `highpass`/`lowpass`/`notch` and a `kind`; and at the top level
`recordStarts` (real per-record start times — the true jumping timeline for an
EDF+D file), `gaps` (the discontinuities) and `startFraction` (EDF+ sub-second
start).

## The neutral struct

`edf.read` returns one struct with no domain assumptions:

```
r.type          % 'EDF' | 'EDF+' | 'BDF' | 'BDF+'
r.continuous    % false for the discontinuous (*+D) flavours
r.patient, r.recording, r.startdate, r.starttime, r.startDateTime, r.reserved
r.records, r.duration, r.ns
r.signals(k)    % .label .transducer .unit .prefilter
                % .physicalMin .physicalMax .digitalMin .digitalMax
                % .samplesPerRecord .rate .data  (native-rate physical vector)
r.annotations(k) % .onset .duration .text  (seconds)
```

`edf.write` accepts the same shape: a `signals` struct array whose entries carry
a `data` vector and a `rate`; the physical/digital ranges, labels and units are
used when present and defaulted when not.

## Example

A ready-to-run tour is in [`examples/read_write_demo.m`](examples/read_write_demo.m),
driven by the shipped `data/edf_example.edf` (built by `data/make_edf_example.m`).

```matlab
% Round-trip a two-channel recording with annotations.
r.signals = struct('label', {'ECG', 'RESP'}, 'unit', {'mV', 'uV'}, ...
  'rate', {250, 25}, 'data', {sin(2*pi*(0:2499)/250)', cos(2*pi*(0:249)/25)'});
r.annotations = struct('onset', {1.0}, 'duration', {0.5}, 'text', {'event'});
edf.write('demo.edf', r);
back = edf.read('demo.edf');
```

## Localization

All `edf:*` error messages are translatable (one identifier per message). The
catalogs live in `locale/` (English and French) and are registered at load time
through `i18nHelpers`; regenerate them after changing a message with
`ngen.i18n('<path>/edf')`.

## License

LGPL-3.0-or-later.
