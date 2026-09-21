%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function report = validate(filename, varargin)
  % REPORT = edf.validate(FILE) checks a file against the EDF, EDF+, BDF and
  % BDF+ specification without throwing, and returns a report: valid (whether no
  % problem was found), type, problems (a cellstr of what breaks the format) and
  % warnings (a cellstr of what is unusual but tolerated). It is the first thing
  % to run on a file another tool wrote before trusting edf.read on it.
  %
  % edf.validate(FILE, 'Fix', DST) also writes to DST a copy with the header
  % byte count and the record count recomputed from the file itself, which
  % repairs the two fields most often left wrong by a writer that stopped early.
  %
  % See also edf.read, edf.isedf.
  narginchk(1, inf);
  nargoutchk(0, 1);
  if ~ischar(filename) && ~isStringScalar(filename)
    error('edf:badFileName', 'The file name must be text.');
  end
  filename = char(filename);
  fixTo = '';
  for k = 1:2:numel(varargin)
    switch lower(char(varargin{k}))
      case 'fix'
        fixTo = char(varargin{k + 1});
      otherwise
        error('edf:unknownOption', 'Unknown option %s.', char(varargin{k}));
    end
  end
  report = struct('valid', false, 'type', false, 'problems', {{}}, ...
  'warnings', {{}});
  if ~isfile(filename)
    report.problems{end + 1} = 'The file is not on disk.';
    return;
  end
  fid = fopen(filename, 'rb');
  if fid < 0
    report.problems{end + 1} = 'The file cannot be read.';
    return;
  end
  bytes = double(fread(fid, inf, 'uint8'));
  fclose(fid);
  if numel(bytes) < 256
    report.problems{end + 1} = 'The file is shorter than one header.';
    return;
  end
  kind = edfDetectType(bytes(1:8), char(bytes(193:236)'));
  if ~kind.valid
    report.problems{end + 1} = 'The magic is neither EDF nor BDF.';
    return;
  end
  report.type = kind.type;
  ns = str2double(strtrim(char(bytes(253:256)')));
  if ~isfinite(ns) || ns < 1 || ns ~= round(ns)
    report.problems{end + 1} = 'The number of signals is not a positive integer.';
    return;
  end
  if numel(bytes) < 256 * (ns + 1)
    report.problems{end + 1} = 'The file is shorter than its signal headers.';
    return;
  end
  headerBytes = str2double(strtrim(char(bytes(185:192)')));
  if ~isfinite(headerBytes) || headerBytes ~= 256 * (ns + 1)
    report.problems{end + 1} = sprintf( ...
    'The header byte count is %s, not %d.', ...
    strtrim(char(bytes(185:192)')), 256 * (ns + 1));
  end
  sh = bytes(257:256 * (ns + 1));
  labels = edfTextBlock(sh, 0, 16, ns);
  annotationsOnly = true;
  for k = 1:ns
    if isempty(strfind(labels{k}, 'Annotations'))
      annotationsOnly = false;
    end
  end
  duration = str2double(strtrim(char(bytes(245:252)')));
  if ~isfinite(duration) || duration <= 0
    if annotationsOnly
      % An annotations-only file (a hypnogram) carries no sampled signal, so a
      % zero record duration is tolerated rather than flagged as broken.
      report.warnings{end + 1} = 'The data record duration is not positive (annotations-only file).';
    else
      report.problems{end + 1} = 'The data record duration is not a positive number.';
    end
  end
  spr = edfNumberBlock(sh, ns * 216, 8, ns);
  pmin = edfNumberBlock(sh, ns * 104, 8, ns);
  pmax = edfNumberBlock(sh, ns * 112, 8, ns);
  dmin = edfNumberBlock(sh, ns * 120, 8, ns);
  dmax = edfNumberBlock(sh, ns * 128, 8, ns);
  if any(~isfinite(spr)) || any(spr < 0)
    report.problems{end + 1} = 'A signal has no valid sample count.';
  end
  if any(~isfinite(pmin)) || any(~isfinite(pmax))
    report.problems{end + 1} = 'A signal has a non-numeric physical range.';
  elseif any(pmax <= pmin)
    report.warnings{end + 1} = 'A signal has a physical maximum not above its minimum.';
  end
  if any(~isfinite(dmin)) || any(~isfinite(dmax))
    report.problems{end + 1} = 'A signal has a non-numeric digital range.';
  elseif any(dmax <= dmin)
    report.warnings{end + 1} = 'A signal has a digital maximum not above its minimum.';
  end
  headerRecords = round(str2double(strtrim(char(bytes(237:244)'))));
  perRecord = sum(spr);
  if all(isfinite(spr)) && perRecord > 0
    dataBytes = numel(bytes) - 256 * (ns + 1);
    actual = floor(dataBytes / (perRecord * kind.bytesPerSample));
    if isfinite(headerRecords) && headerRecords > 0 && headerRecords ~= actual
      report.problems{end + 1} = sprintf( ...
      'The record count is %d but the file holds %d.', headerRecords, actual);
    end
    if mod(dataBytes, perRecord * kind.bytesPerSample) ~= 0
      report.warnings{end + 1} = 'The data block is not a whole number of records.';
    end
  end
  if kind.plus
    hasAnnot = false;
    for k = 1:ns
      if ~isempty(strfind(labels{k}, 'Annotations'))
        hasAnnot = true;
      end
    end
    if ~hasAnnot
      report.problems{end + 1} = 'An EDF+ or BDF+ file has no annotation channel.';
    end
  end
  report.valid = isempty(report.problems);
  if ~isempty(fixTo)
    edfFixFile(bytes, ns, kind, spr, fixTo);
  end
end
%=============================================================================
function edfFixFile(bytes, ns, kind, spr, destination)
  % Recompute the header byte count and the record count from the file and write
  % a repaired copy; the samples are left untouched.
  bytes(185:192) = edfPad(sprintf('%d', 256 * (ns + 1)), 8);
  perRecord = sum(spr);
  if perRecord > 0
    dataBytes = numel(bytes) - 256 * (ns + 1);
    actual = floor(dataBytes / (perRecord * kind.bytesPerSample));
    bytes(237:244) = edfPad(sprintf('%d', actual), 8);
  end
  out = fopen(destination, 'wb');
  if out < 0
    error('edf:cannotWrite', 'The file %s cannot be written.', destination);
  end
  fwrite(out, bytes, 'uint8');
  fclose(out);
end
%=============================================================================
function values = edfNumberBlock(sh, offset, width, ns)
  texts = edfTextBlock(sh, offset, width, ns);
  values = zeros(1, ns);
  for k = 1:ns
    values(k) = str2double(texts{k});
  end
end
%=============================================================================
function texts = edfTextBlock(sh, offset, width, ns)
  texts = cell(1, ns);
  for k = 1:ns
    piece = sh(offset + (k - 1) * width + 1:offset + k * width);
    texts{k} = strtrim(char(reshape(piece, 1, [])));
  end
end
%=============================================================================
