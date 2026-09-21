%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function report = compare(a, b, varargin)
  % REPORT = edf.compare(A, B) checks whether two EDF or BDF files carry the same
  % signals and header, and returns a report: equal (whether nothing differs
  % beyond the tolerance) and differences (a cellstr naming what does). It is the
  % check a round trip needs: write a file, read it back, compare.
  %
  % edf.compare(A, B, 'Tolerance', T) allows each signal's samples to differ by
  % up to T in physical units (default 0, an exact match); the header fields are
  % always compared exactly.
  %
  % A and B are file paths or structs from edf.read.
  %
  % See also edf.read, edf.write, edf.validate.
  narginchk(2, inf);
  nargoutchk(0, 1);
  tolerance = 0;
  for k = 1:2:numel(varargin)
    switch lower(char(varargin{k}))
      case 'tolerance'
        tolerance = double(varargin{k + 1});
      otherwise
        error('edf:unknownOption', 'Unknown option %s.', char(varargin{k}));
    end
  end
  ra = edfAsStruct(a);
  rb = edfAsStruct(b);
  na = numel(ra.signals);
  nb = numel(rb.signals);
  d = {};
  % Fields a raw write-struct may not carry are compared only when both sides
  % have them, so a struct on its way to disk can be checked against the file.
  if isfield(ra, 'type') && isfield(rb, 'type')
    d = edfDiffField(d, 'type', ra.type, rb.type);
  end
  d = edfDiffNumber(d, 'number of signals', na, nb);
  if isfield(ra, 'records') && isfield(rb, 'records')
    d = edfDiffNumber(d, 'record count', ra.records, rb.records);
  end
  if isfield(ra, 'duration') && isfield(rb, 'duration')
    d = edfDiffNumber(d, 'record duration', ra.duration, rb.duration);
  end
  if isfield(ra, 'annotations') && isfield(rb, 'annotations')
    d = edfDiffNumber(d, 'annotation count', numel(ra.annotations), ...
    numel(rb.annotations));
  end
  if na == nb
    for k = 1:na
      sa = ra.signals(k);
      sb = rb.signals(k);
      tag = sprintf('signal %d', k);
      d = edfDiffField(d, [tag, ' label'], edfFieldOr(sa, 'label', ''), ...
      edfFieldOr(sb, 'label', ''));
      d = edfDiffField(d, [tag, ' unit'], edfFieldOr(sa, 'unit', ''), ...
      edfFieldOr(sb, 'unit', ''));
      if isfield(sa, 'rate') && isfield(sb, 'rate')
        d = edfDiffNumber(d, [tag, ' rate'], sa.rate, sb.rate);
      end
      if numel(sa.data) ~= numel(sb.data)
        d{end + 1} = sprintf('%s length: %d vs %d', tag, numel(sa.data), ...
        numel(sb.data)); %#ok<AGROW>
      else
        gap = max(abs(sa.data(:) - sb.data(:)));
        if isempty(gap)
          gap = 0;
        end
        if gap > tolerance
          d{end + 1} = sprintf('%s samples differ by up to %g', tag, gap); %#ok<AGROW>
        end
      end
    end
  end
  report = struct('equal', isempty(d), 'differences', {d});
end
%=============================================================================
function r = edfAsStruct(x)
  if ischar(x) || isStringScalar(x)
    r = edf.read(char(x));
  elseif isstruct(x) && isfield(x, 'signals')
    r = x;
  else
    error('edf:badCompareArg', 'Each argument must be a file name or a struct from edf.read.');
  end
end
%=============================================================================
function d = edfDiffField(d, name, a, b)
  if ~strcmp(char(a), char(b))
    d{end + 1} = sprintf('%s: %s vs %s', name, char(a), char(b));
  end
end
%=============================================================================
function d = edfDiffNumber(d, name, a, b)
  if a ~= b
    d{end + 1} = sprintf('%s: %g vs %g', name, a, b);
  end
end
%=============================================================================
function value = edfFieldOr(s, name, fallback)
  if isfield(s, name)
    value = s.(name);
  else
    value = fallback;
  end
end
%=============================================================================
