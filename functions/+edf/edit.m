%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function edit(file, varargin)
  % edf.edit(FILE, NAME, VALUE, ...) changes header fields of an EDF or BDF file
  % without re-encoding the samples: the fixed-width ASCII header is patched and
  % the data block is copied through byte for byte, so nothing is re-quantised.
  %
  % The study-level fields are 'Patient', 'Recording', 'StartDate' (dd.mm.yy)
  % and 'StartTime' (hh.mm.ss). The per-signal fields are 'Labels', 'Units',
  % 'Transducers' and 'Prefilters', each a cellstr with one text per signal
  % (the annotation channel included, at the end). 'Rename', {OLD, NEW, ...}
  % renames signals by matching their current label.
  %
  % edf.edit(FILE, ..., 'Output', DST) writes the edited file to DST instead of
  % overwriting FILE.
  %
  % See also edf.read, edf.write, edf.anonymize.
  narginchk(3, inf);
  if ~ischar(file) && ~isStringScalar(file)
    error('edf:badFileName', 'The file name must be text.');
  end
  file = char(file);
  if ~isfile(file)
    error('edf:noSuchFile', 'The file %s is not on disk.', file);
  end
  output = file;
  ops = {};
  for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    if strcmp(name, 'output')
      output = char(value);
    else
      ops{end + 1} = name; %#ok<AGROW>
      ops{end + 1} = value; %#ok<AGROW>
    end
  end
  fid = fopen(file, 'rb');
  if fid < 0
    error('edf:cannotRead', 'The file %s cannot be read.', file);
  end
  bytes = double(fread(fid, inf, 'uint8'));
  fclose(fid);
  if numel(bytes) < 256
    error('edf:notEdf', 'The file %s is not an EDF or BDF file.', file);
  end
  kind = edfDetectType(bytes(1:8), char(bytes(193:236)'));
  if ~kind.valid
    error('edf:notEdf', 'The file %s is not an EDF or BDF file.', file);
  end
  ns = str2double(strtrim(char(bytes(253:256)')));
  if ~isfinite(ns) || ns < 1 || ns ~= round(ns)
    error('edf:notEdf', 'The file %s is not an EDF or BDF file.', file);
  end
  for k = 1:2:numel(ops)
    bytes = edfApplyEdit(bytes, ns, ops{k}, ops{k + 1});
  end
  out = fopen(output, 'wb');
  if out < 0
    error('edf:cannotWrite', 'The file %s cannot be written.', output);
  end
  fwrite(out, bytes, 'uint8');
  fclose(out);
end
%=============================================================================
function bytes = edfApplyEdit(bytes, ns, name, value)
  switch name
    case 'patient'
      bytes = edfPut(bytes, 8, 80, value);
    case 'recording'
      bytes = edfPut(bytes, 88, 80, value);
    case 'startdate'
      bytes = edfPut(bytes, 168, 8, value);
    case 'starttime'
      bytes = edfPut(bytes, 176, 8, value);
    case 'labels'
      bytes = edfPutPerSignal(bytes, ns, 0, 16, value);
    case 'transducers'
      bytes = edfPutPerSignal(bytes, ns, 16 * ns, 80, value);
    case 'units'
      bytes = edfPutPerSignal(bytes, ns, 96 * ns, 8, value);
    case 'prefilters'
      bytes = edfPutPerSignal(bytes, ns, 136 * ns, 80, value);
    case 'rename'
      bytes = edfRename(bytes, ns, value);
    otherwise
      error('edf:unknownField', 'Unknown field %s.', name);
  end
end
%=============================================================================
function bytes = edfRename(bytes, ns, pairs)
  if ~iscell(pairs) || mod(numel(pairs), 2) ~= 0
    error('edf:badRename', 'Rename takes {OLD, NEW, ...} pairs.');
  end
  base = 256;
  for k = 1:2:numel(pairs)
    from = strtrim(char(pairs{k}));
    to = char(pairs{k + 1});
    for s = 0:ns - 1
      offset = base + s * 16;
      current = strtrim(char(bytes(offset + 1:offset + 16)'));
      if strcmp(current, from)
        bytes = edfPut(bytes, offset, 16, to);
      end
    end
  end
end
%=============================================================================
function bytes = edfPutPerSignal(bytes, ns, blockStart, width, value)
  if ischar(value) || isStringScalar(value)
    value = {char(value)};
  end
  if ~iscell(value) || numel(value) ~= ns
    error('edf:badField', 'This field must be one text per signal (%d expected).', ns);
  end
  base = 256 + blockStart;
  for s = 0:ns - 1
    bytes = edfPut(bytes, base + s * width, width, value{s + 1});
  end
end
%=============================================================================
function bytes = edfPut(bytes, offset, width, text)
  bytes(offset + 1:offset + width) = edfPad(text, width);
end
%=============================================================================
