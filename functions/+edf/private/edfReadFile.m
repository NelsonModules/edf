%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function r = edfReadFile(filename, opts)
  % The one reader of the EDF, EDF+, BDF and BDF+ binary format. It returns the
  % neutral struct every caller adapts: the header fields, one entry per
  % ordinary signal with its samples in physical units at its own rate, and the
  % annotations parsed from the annotation channel. Nothing here knows about
  % leads, sleep events or any other domain; that mapping is the caller's.
  %
  % OPTS has fields data (read the samples, default true), annotations (parse
  % the annotation channel, default true) and signals (a subset of the ordinary
  % signals to keep, by label or index, default all). Reading the annotations
  % needs the data block, so annotations imply data.
  if ~isfile(filename)
    error('edf:noSuchFile', 'The file %s is not on disk.', filename);
  end
  fid = fopen(filename, 'rb');
  if fid < 0
    error('edf:cannotRead', 'The file %s cannot be read.', filename);
  end
  main = double(fread(fid, 256, 'uint8'));
  if numel(main) < 256
    fclose(fid);
    error('edf:notEdf', 'The file %s is not an EDF or BDF file.', filename);
  end
  kind = edfDetectType(main(1:8), char(main(193:236)'));
  if ~kind.valid
    fclose(fid);
    error('edf:notEdf', 'The file %s is not an EDF or BDF file.', filename);
  end
  ns = str2double(edfText(main, 252, 4));
  if ~isfinite(ns) || ns < 1 || ns ~= round(ns)
    fclose(fid);
    error('edf:notEdf', 'The file %s is not an EDF or BDF file.', filename);
  end
  sh = double(fread(fid, ns * 256, 'uint8'));
  if numel(sh) < ns * 256
    fclose(fid);
    error('edf:notEdf', 'The file %s is not an EDF or BDF file.', filename);
  end
  tolerant = isfield(opts, 'tolerant') && opts.tolerant;
  warnings = {};
  sig = edfSignalHeaders(sh, ns);
  isAnnot = edfIsAnnotationLabel(sig.labels, kind.family);
  duration = str2double(edfText(main, 244, 8));
  if ~isfinite(duration) || duration <= 0
    if ~any(~isAnnot)
      % An annotations-only file (a PhysioNet-style hypnogram is one) carries no
      % sampled signal, so the record duration is irrelevant: the annotation
      % onsets are absolute times. Accept it rather than refuse a common file.
      duration = 1;
    elseif tolerant
      warnings{end + 1} = 'The data record duration is not a positive number; using 1.';
      duration = 1;
    else
      fclose(fid);
      error('edf:badDuration', 'The data record duration of %s is not a positive number.', filename);
    end
  end
  if any(~isfinite(sig.samplesPerRecord)) || any(sig.samplesPerRecord < 0)
    if tolerant
      warnings{end + 1} = 'A signal has an invalid sample count; treating it as zero.';
      sig.samplesPerRecord(~isfinite(sig.samplesPerRecord)) = 0;
      sig.samplesPerRecord(sig.samplesPerRecord < 0) = 0;
    else
      fclose(fid);
      error('edf:badSampleCount', 'A signal of %s has no valid sample count.', filename);
    end
  end
  headerRecords = round(str2double(edfText(main, 236, 8)));
  wantData = ~isfield(opts, 'data') || opts.data;
  wantAnnot = (~isfield(opts, 'annotations') || opts.annotations) && any(isAnnot);
  [firstRec, count] = edfWindow(opts, duration);
  block = [];
  recordOffset = 0;
  if wantData || wantAnnot
    [block, nrec, recordOffset] = edfReadBlock(fid, ns, kind, ...
    sig.samplesPerRecord, headerRecords, firstRec, count);
  else
    nrec = edfCountRecords(fid, ns, kind, sig.samplesPerRecord, headerRecords);
  end
  fclose(fid);
  r = struct();
  r.file = char(filename);
  r.type = kind.type;
  r.family = kind.family;
  r.continuous = kind.continuous;
  r.version = strtrim(edfText(main, 0, 8));
  r.patient = strtrim(edfText(main, 8, 80));
  r.recording = strtrim(edfText(main, 88, 80));
  r.startdate = strtrim(edfText(main, 168, 8));
  r.starttime = strtrim(edfText(main, 176, 8));
  r.startDateTime = edfParseStart(r.startdate, r.starttime, r.recording);
  r.reserved = strtrim(edfText(main, 192, 44));
  r.records = nrec;
  r.duration = duration;
  % Ordinary signals only; the annotation channel is a byte stream, not a
  % physiological signal, and is turned into r.annotations instead.
  ordinary = find(~isAnnot);
  if isfield(opts, 'skipsignals') && opts.skipsignals
    % An annotations-only read still reads the interleaved data block (the
    % annotation channel lives in it) but builds and scales no ordinary signal.
    keep = zeros(1, 0);
  elseif isfield(opts, 'kinds') && ~isempty(opts.kinds)
    keep = edfSelectByKind(sig, ordinary, opts.kinds);
  else
    keep = edfSelectSignals(sig.labels, ordinary, opts);
  end
  scale = ~isfield(opts, 'scale') || opts.scale;
  r.signals = edfBuildSignals(sig, keep, duration, wantData, block, nrec, scale);
  r.signals = edfApplyUnits(r.signals, opts);
  r.ns = numel(r.signals);
  if wantAnnot
    r.annotations = edfReadAnnotations(block, sig.samplesPerRecord, ...
    find(isAnnot), kind);
    % The real start time of each data record. For a continuous file these are
    % (0:n-1) * duration by definition, so they are computed rather than parsed;
    % only an EDF+D (discontinuous) file needs the time-keeping stamp of every
    % record read out, which on a long night is tens of thousands of records.
    if kind.continuous
      r.recordStarts = (recordOffset + (0:nrec - 1)') * duration;
    else
      r.recordStarts = edfRecordStarts(block, sig.samplesPerRecord, ...
      find(isAnnot, 1), kind, nrec, duration, recordOffset);
    end
  else
    r.annotations = struct('onset', {}, 'duration', {}, 'text', {});
    r.recordStarts = (recordOffset + (0:nrec - 1)') * duration;
  end
  % The EDF+ sub-second start offset: the onset the first record states when it
  % is a fraction of a record rather than zero. Only meaningful for a full read
  % from the file's first record.
  r.startFraction = 0;
  if recordOffset == 0 && ~isempty(r.recordStarts) && r.recordStarts(1) > 0 ...
    && r.recordStarts(1) < duration
    r.startFraction = r.recordStarts(1);
  end
  % The discontinuities: where the next record does not start one record after
  % the previous one, an EDF+D file has skipped time.
  r.gaps = edfGaps(r.recordStarts, duration);
  r.warnings = warnings;
end
%=============================================================================
function sig = edfSignalHeaders(sh, ns)
  % The per-signal header block stores each field for every signal before the
  % next field, so each field is a contiguous run of ns fixed width texts.
  sig = struct();
  sig.labels = edfPerSignal(sh, 0, 16, ns);
  sig.transducers = edfPerSignal(sh, ns * 16, 80, ns);
  sig.units = edfPerSignal(sh, ns * 96, 8, ns);
  sig.physicalMin = edfPerSignalNumber(sh, ns * 104, 8, ns);
  sig.physicalMax = edfPerSignalNumber(sh, ns * 112, 8, ns);
  sig.digitalMin = edfPerSignalNumber(sh, ns * 120, 8, ns);
  sig.digitalMax = edfPerSignalNumber(sh, ns * 128, 8, ns);
  sig.prefilters = edfPerSignal(sh, ns * 136, 80, ns);
  sig.samplesPerRecord = edfPerSignalNumber(sh, ns * 216, 8, ns);
end
%=============================================================================
function [block, nrec, recordOffset] = edfReadBlock(fid, ns, kind, samplesPerRecord, headerRecords, firstRec, count)
  % One read of the requested data records, then a reshape to one column per
  % record. EDF stores each sample as a little-endian int16, BDF as a
  % little-endian signed int24 assembled here from its three bytes. A window
  % (firstRec, count) seeks to that record and reads only it, so a slice of a
  % huge file is cheap; firstRec 1 and an empty count read the whole block.
  perRecord = sum(samplesPerRecord);
  dataStart = 256 * (ns + 1);
  recordOffset = 0;
  if perRecord == 0
    block = zeros(0, 0);
    nrec = 0;
    return;
  end
  recordBytes = perRecord * kind.bytesPerSample;
  fseek(fid, 0, 'eof');
  available = floor((ftell(fid) - dataStart) / recordBytes);
  if headerRecords > 0
    available = min(available, headerRecords);
  end
  if available < 0
    available = 0;
  end
  first = max(1, round(firstRec));
  if first > available
    block = zeros(perRecord, 0);
    nrec = 0;
    recordOffset = min(first - 1, available);
    return;
  end
  if isempty(count) || count < 0
    last = available;
  else
    last = min(available, first + round(count) - 1);
  end
  nrec = last - first + 1;
  recordOffset = first - 1;
  fseek(fid, dataStart + recordOffset * recordBytes, 'bof');
  if kind.bytesPerSample == 2
    raw = double(fread(fid, nrec * perRecord, 'int16'));
  else
    bytes = double(fread(fid, nrec * perRecord * 3, 'uint8'));
    nsamp = floor(numel(bytes) / 3);
    bytes = reshape(bytes(1:nsamp * 3), 3, nsamp);
    raw = bytes(1, :) + 256 * bytes(2, :) + 65536 * bytes(3, :);
    raw(raw >= 8388608) = raw(raw >= 8388608) - 16777216;
    raw = raw(:);
  end
  nrec = floor(numel(raw) / perRecord);
  block = reshape(raw(1:nrec * perRecord), perRecord, nrec);
end
%=============================================================================
function [firstRec, count] = edfWindow(opts, duration)
  % The record window a caller asked for, as a first record (one based) and a
  % count, from either a record range or a time interval. The default is the
  % whole file.
  firstRec = 1;
  count = [];
  if isfield(opts, 'records') && ~isempty(opts.records)
    rng = round(opts.records(:)');
    if numel(rng) ~= 2 || rng(1) < 1 || rng(2) < rng(1)
      error('edf:badRecords', 'Records must be [first last] with 1 <= first <= last.');
    end
    firstRec = rng(1);
    count = rng(2) - rng(1) + 1;
  elseif isfield(opts, 'interval') && ~isempty(opts.interval)
    iv = opts.interval(:)';
    if numel(iv) ~= 2 || ~(iv(2) > iv(1)) || iv(1) < 0
      error('edf:badInterval', 'Interval must be [t0 t1] seconds with t1 > t0 >= 0.');
    end
    firstRec = floor(iv(1) / duration) + 1;
    lastRec = ceil(iv(2) / duration);
    count = max(1, lastRec - firstRec + 1);
  end
end
%=============================================================================
function signals = edfApplyUnits(signals, opts)
  % Override the physical dimension of each kept signal, for a file that left
  % the unit field blank.
  if ~isfield(opts, 'units') || isempty(opts.units)
    return;
  end
  units = opts.units;
  if ischar(units) || isStringScalar(units)
    units = {char(units)};
  end
  if numel(units) ~= numel(signals)
    error('edf:badUnits', 'Units must be one text per kept signal (%d expected).', numel(signals));
  end
  for k = 1:numel(signals)
    if ~isempty(units{k})
      signals(k).unit = char(units{k});
    end
  end
end
%=============================================================================
function gaps = edfGaps(recordStarts, duration)
  % A gap is a record whose start is more than one record after the previous
  % one; the list gives where (seconds) and how long (seconds) time was skipped.
  gaps = struct('at', {}, 'duration', {});
  starts = recordStarts(:);
  for k = 2:numel(starts)
    expected = starts(k - 1) + duration;
    skip = starts(k) - expected;
    if skip > 1e-6
      gaps(end + 1) = struct('at', expected, 'duration', skip); %#ok<AGROW>
    end
  end
end
%=============================================================================
function nrec = edfCountRecords(fid, ns, kind, samplesPerRecord, headerRecords)
  % The record count from the file size when the data block is not read, so
  % edf.header and edf.info report the true length cheaply. The count includes
  % the annotation channel's samples, since every channel contributes to a
  % record on disk.
  perRecord = sum(samplesPerRecord);
  if perRecord == 0
    nrec = max(0, headerRecords);
    return;
  end
  fseek(fid, 0, 'eof');
  fileBytes = ftell(fid);
  dataBytes = fileBytes - 256 * (ns + 1);
  nrec = floor(dataBytes / (perRecord * kind.bytesPerSample));
  if nrec < 0
    nrec = 0;
  end
  if headerRecords > 0
    nrec = min(nrec, headerRecords);
  end
end
%=============================================================================
function signals = edfBuildSignals(sig, keep, duration, wantData, block, nrec, scale)
  signals = struct('label', {}, 'transducer', {}, 'unit', {}, ...
  'prefilter', {}, 'highpass', {}, 'lowpass', {}, 'notch', {}, 'kind', {}, ...
  'physicalMin', {}, 'physicalMax', {}, 'digitalMin', {}, ...
  'digitalMax', {}, 'samplesPerRecord', {}, 'rate', {}, 'data', {});
  offsets = [0; cumsum(sig.samplesPerRecord(:))];
  for j = 1:numel(keep)
    index = keep(j);
    entry = struct();
    entry.label = strtrim(sig.labels{index});
    entry.transducer = strtrim(sig.transducers{index});
    entry.unit = strtrim(sig.units{index});
    entry.prefilter = strtrim(sig.prefilters{index});
    filter = edfParsePrefilter(entry.prefilter);
    entry.highpass = filter.highpass;
    entry.lowpass = filter.lowpass;
    entry.notch = filter.notch;
    entry.kind = edfChannelKind(entry.label, entry.transducer);
    entry.physicalMin = sig.physicalMin(index);
    entry.physicalMax = sig.physicalMax(index);
    entry.digitalMin = sig.digitalMin(index);
    entry.digitalMax = sig.digitalMax(index);
    entry.samplesPerRecord = sig.samplesPerRecord(index);
    entry.rate = sig.samplesPerRecord(index) / duration;
    if wantData && nrec > 0 && sig.samplesPerRecord(index) > 0
      rows = offsets(index) + 1:offsets(index + 1);
      digital = reshape(block(rows, :), [], 1);
      % With scaling off the raw digital codes are returned instead of the
      % physical value, which a caller reading a bit-coded channel (a BDF
      % Status/trigger channel) needs untouched.
      if scale
        entry.data = edfDigitalToPhysical(digital, entry);
      else
        entry.data = digital;
      end
    else
      entry.data = zeros(0, 1);
    end
    signals(end + 1) = entry; %#ok<AGROW>
  end
end
%=============================================================================
function starts = edfRecordStarts(block, samplesPerRecord, channel, kind, nrec, duration, recordOffset)
  % The onset the time-keeping TAL states at the head of each record (an
  % absolute time on the file's timeline). The first annotation channel is read
  % record by record and the onset before its first separator is taken; a record
  % without a readable stamp falls back to its continuous position, which for a
  % windowed read starts at the window's first record.
  if nargin < 7
    recordOffset = 0;
  end
  starts = (recordOffset + (0:nrec - 1)') * duration;
  if isempty(channel) || nrec == 0
    return;
  end
  offsets = [0; cumsum(samplesPerRecord(:))];
  rows = offsets(channel) + 1:offsets(channel + 1);
  for rec = 1:nrec
    bytes = edfSamplesToBytes(block(rows, rec), kind.bytesPerSample);
    pos = 1;
    total = numel(bytes);
    while pos <= total && bytes(pos) == 0
      pos = pos + 1;
    end
    start = pos;
    while pos <= total && bytes(pos) ~= 20 && bytes(pos) ~= 21
      pos = pos + 1;
    end
    onset = str2double(char(bytes(start:pos - 1)));
    if isfinite(onset)
      starts(rec) = onset;
    end
  end
end
%=============================================================================
function physical = edfDigitalToPhysical(digital, entry)
  % physical = (digital - dmin) * (pmax - pmin) / (dmax - dmin) + pmin. A zero
  % digital span would divide by zero, so a degenerate signal is handed back as
  % its physical minimum rather than as NaN.
  span = entry.digitalMax - entry.digitalMin;
  if span == 0
    physical = repmat(entry.physicalMin, size(digital));
    return;
  end
  scale = (entry.physicalMax - entry.physicalMin) / span;
  physical = (digital - entry.digitalMin) * scale + entry.physicalMin;
end
%=============================================================================
function annotations = edfReadAnnotations(block, samplesPerRecord, channels, kind)
  % Recover the byte stream of every annotation channel and parse its TALs. A
  % sample of the channel packs two bytes for EDF or three for BDF, low byte
  % first; the records are concatenated in time order before parsing so a TAL
  % that a writer laid across a record boundary is not lost.
  offsets = [0; cumsum(samplesPerRecord(:))];
  annotations = struct('onset', {}, 'duration', {}, 'text', {});
  for c = channels(:)'
    rows = offsets(c) + 1:offsets(c + 1);
    values = reshape(block(rows, :), [], 1);
    bytes = edfSamplesToBytes(values, kind.bytesPerSample);
    parsed = edfParseTal(bytes);
    for k = 1:numel(parsed)
      annotations(end + 1) = parsed(k); %#ok<AGROW>
    end
  end
end
%=============================================================================
function bytes = edfSamplesToBytes(values, bytesPerSample)
  values = double(values(:)');
  if bytesPerSample == 2
    unsigned = values + 65536 * (values < 0);
    low = mod(unsigned, 256);
    high = floor(unsigned / 256);
    bytes = reshape([low; high], 1, []);
  else
    unsigned = values + 16777216 * (values < 0);
    b1 = mod(unsigned, 256);
    b2 = mod(floor(unsigned / 256), 256);
    b3 = mod(floor(unsigned / 65536), 256);
    bytes = reshape([b1; b2; b3], 1, []);
  end
end
%=============================================================================
function keep = edfSelectSignals(labels, ordinary, opts)
  % The ordinary signals to return. With no selection every ordinary signal is
  % kept; a numeric selection indexes the ordinary signals; a text or cellstr
  % selection matches labels, in the order asked.
  if ~isfield(opts, 'signals') || isempty(opts.signals)
    keep = ordinary;
    return;
  end
  want = opts.signals;
  if isnumeric(want)
    index = round(want(:)');
    if any(index < 1) || any(index > numel(ordinary))
      error('edf:badSignalIndex', 'A signal index is outside the range of the signals.');
    end
    keep = ordinary(index);
    return;
  end
  if ischar(want) || isStringScalar(want)
    want = {char(want)};
  end
  if ~iscell(want)
    error('edf:badSignals', 'Signals must be a label, a cellstr of labels, or indices.');
  end
  keep = zeros(1, 0);
  for k = 1:numel(want)
    target = strtrim(char(want{k}));
    hit = [];
    for c = ordinary(:)'
      if strcmpi(strtrim(labels{c}), target)
        hit = c;
        break;
      end
    end
    if isempty(hit)
      error('edf:noSuchSignal', 'No signal is labelled %s.', target);
    end
    keep(end + 1) = hit; %#ok<AGROW>
  end
end
%=============================================================================
function keep = edfSelectByKind(sig, ordinary, kinds)
  % The ordinary signals whose guessed kind is one of those asked, in file
  % order. The kind is guessed from the label and transducer, the same way
  % edf.read tags every signal.
  if ischar(kinds) || isStringScalar(kinds)
    kinds = {char(kinds)};
  end
  if ~iscell(kinds)
    error('edf:badKinds', 'Kinds must be a kind name or a cellstr of kind names.');
  end
  want = cell(1, numel(kinds));
  for k = 1:numel(kinds)
    want{k} = lower(strtrim(char(kinds{k})));
  end
  keep = zeros(1, 0);
  for c = ordinary(:)'
    kind = edfChannelKind(sig.labels{c}, sig.transducers{c});
    if any(strcmp(kind, want))
      keep(end + 1) = c; %#ok<AGROW>
    end
  end
end
%=============================================================================
function tf = edfIsAnnotationLabel(labels, family)
  tf = false(1, numel(labels));
  target = [family, ' Annotations'];
  for k = 1:numel(labels)
    tf(k) = ~isempty(strfind(strtrim(labels{k}), target)) || ...
    ~isempty(strfind(strtrim(labels{k}), 'EDF Annotations'));
  end
end
%=============================================================================
function values = edfPerSignalNumber(sh, offset, width, ns)
  texts = edfPerSignal(sh, offset, width, ns);
  values = zeros(1, ns);
  for k = 1:ns
    values(k) = str2double(texts{k});
  end
end
%=============================================================================
function texts = edfPerSignal(sh, offset, width, ns)
  texts = cell(1, ns);
  for k = 1:ns
    piece = sh(offset + (k - 1) * width + 1:offset + k * width);
    texts{k} = strtrim(char(reshape(piece, 1, [])));
  end
end
%=============================================================================
function s = edfText(bytes, offset, width)
  s = char(reshape(bytes(offset + 1:offset + width), 1, []));
end
%=============================================================================
