%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function info = merge(destination, sources, varargin)
  % edf.merge(DST, SOURCES) concatenates several EDF or BDF files end to end in
  % time into DST. SOURCES is a cellstr of paths, read in order; every file must
  % carry the same signals (same labels and rates) as the first, so the result
  % is one continuous recording. The annotations of each file are shifted by the
  % time already written, so a mark keeps its place on the merged timeline.
  %
  % edf.merge(DST, SOURCES, 'RecordSeconds', S) sets the output record length;
  % the default is the first file's.
  %
  % INFO = edf.merge(...) returns the edf.write info of the file written.
  %
  % See also edf.read, edf.write, edf.crop.
  narginchk(2, inf);
  nargoutchk(0, 1);
  if ~ischar(destination) && ~isStringScalar(destination)
    error('edf:badFileName', 'The file name must be text.');
  end
  if ischar(sources) || isStringScalar(sources)
    sources = {char(sources)};
  end
  if ~iscell(sources) || isempty(sources)
    error('edf:badSources', 'SOURCES must be a non-empty cellstr of file paths.');
  end
  recordSeconds = [];
  for k = 1:2:numel(varargin)
    switch lower(char(varargin{k}))
      case 'recordseconds'
        recordSeconds = varargin{k + 1};
      otherwise
        error('edf:unknownOption', 'Unknown option %s.', char(varargin{k}));
    end
  end
  first = edf.read(char(sources{1}));
  labels = edfLabels(first);
  rates = [first.signals.rate];
  merged = first;
  elapsed = first.records * first.duration;
  for f = 2:numel(sources)
    r = edf.read(char(sources{f}));
    if numel(r.signals) ~= numel(first.signals) || ...
      ~isequal(edfLabels(r), labels) || ~isequal([r.signals.rate], rates)
      error('edf:mergeMismatch', 'File %s does not carry the same signals as the first.', char(sources{f}));
    end
    for k = 1:numel(merged.signals)
      merged.signals(k).data = [merged.signals(k).data(:); r.signals(k).data(:)];
    end
    for a = 1:numel(r.annotations)
      entry = r.annotations(a);
      entry.onset = entry.onset + elapsed;
      merged.annotations(end + 1) = entry; %#ok<AGROW>
    end
    elapsed = elapsed + r.records * r.duration;
  end
  % The concatenated signal spans a wider range than any one file, so the
  % per-signal physical and digital ranges the first file carried must be
  % dropped and recomputed by the writer over the merged data; keeping them
  % would clamp every value outside the first file's range.
  for k = 1:numel(merged.signals)
    merged.signals(k).physicalMin = [];
    merged.signals(k).physicalMax = [];
    merged.signals(k).digitalMin = [];
    merged.signals(k).digitalMax = [];
  end
  if isempty(recordSeconds)
    recordSeconds = first.duration;
  end
  result = edf.write(char(destination), merged, 'Format', first.type, ...
  'RecordSeconds', recordSeconds);
  if nargout > 0
    info = result;
  end
end
%=============================================================================
function labels = edfLabels(r)
  labels = cell(1, numel(r.signals));
  for k = 1:numel(r.signals)
    labels{k} = r.signals(k).label;
  end
end
%=============================================================================
