%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function out = resample(source, rate, varargin)
  % OUT = edf.resample(SOURCE, RATE) brings every signal of SOURCE to one common
  % RATE (in hertz) and returns them aligned in a single matrix. SOURCE is a
  % file path or a struct from edf.read. OUT has fields data (a matrix, one
  % column per signal), t (the time vector in seconds), rate, labels and units.
  %
  % OUT = edf.resample(SOURCE, RATE, 'Method', M) chooses the interpolation:
  % 'linear' (default) or 'nearest'. 'nearest' is a zero-order hold, which is
  % what a step-like or coded channel wants; 'linear' suits a smooth signal.
  %
  % OUT = edf.resample(SOURCE, RATE, 'Absolute', true) places the samples on the
  % file's real timeline using the per-record start times, so an EDF+D
  % (discontinuous) file resamples correctly: the skipped time of each gap is
  % filled with NaN rather than bridged. OUT.t then starts at the recording's
  % real start.
  %
  % A single common rate is what an analysis that reads every channel on one
  % timeline needs; edf.read keeps each signal at its own native rate instead.
  %
  % See also edf.read.
  narginchk(2, inf);
  nargoutchk(0, 1);
  if ~isnumeric(rate) || ~isscalar(rate) || ~(rate > 0) || ~isfinite(rate)
    error('edf:badRateHz', 'RATE must be one positive number of hertz.');
  end
  method = 'linear';
  absolute = false;
  for k = 1:2:numel(varargin)
    switch lower(char(varargin{k}))
      case 'method'
        method = lower(char(varargin{k + 1}));
      case 'absolute'
        absolute = logical(varargin{k + 1});
      otherwise
        error('edf:unknownOption', 'Unknown option %s.', char(varargin{k}));
    end
  end
  if ~any(strcmp(method, {'linear', 'nearest'}))
    error('edf:badMethod', 'Method must be ''linear'' or ''nearest''.');
  end
  if ischar(source) || isStringScalar(source)
    r = edf.read(char(source));
  elseif isstruct(source) && isfield(source, 'signals')
    r = source;
  else
    error('edf:badSource', 'SOURCE must be a file name or a struct from edf.read.');
  end
  n = numel(r.signals);
  labels = cell(1, n);
  units = cell(1, n);
  for k = 1:n
    labels{k} = r.signals(k).label;
    units{k} = r.signals(k).unit;
  end
  if absolute
    [data, t] = edfResampleAbsolute(r, rate, method, n);
  else
    [data, t] = edfResampleContiguous(r, rate, method, n);
  end
  out = struct('data', data, 't', t, 'rate', double(rate), 'labels', ...
  {labels}, 'units', {units});
end
%=============================================================================
function [data, t] = edfResampleContiguous(r, rate, method, n)
  seconds = 0;
  for k = 1:n
    seconds = max(seconds, numel(r.signals(k).data) / r.signals(k).rate);
  end
  count = max(1, round(seconds * rate));
  t = (0:count - 1)' / rate;
  data = zeros(count, n);
  for k = 1:n
    series = r.signals(k).data(:);
    if isempty(series)
      continue;
    end
    native = (0:numel(series) - 1)' / r.signals(k).rate;
    query = min(t, native(end));
    if numel(series) == 1
      data(:, k) = series;
    else
      data(:, k) = interp1(native, series, query, method);
    end
  end
end
%=============================================================================
function [data, t] = edfResampleAbsolute(r, rate, method, n)
  % Each sample is placed at its real time using the per-record starts, so the
  % gaps of an EDF+D file open up on the output grid and are left as NaN.
  if ~isfield(r, 'recordStarts') || isempty(r.recordStarts)
    starts = (0:r.records - 1)' * r.duration;
  else
    starts = r.recordStarts(:);
  end
  t0 = 0;
  if ~isempty(starts)
    t0 = starts(1);
  end
  spanEnd = t0;
  for k = 1:n
    if ~isempty(r.signals(k).data)
      spanEnd = max(spanEnd, starts(end) + r.signals(k).samplesPerRecord / ...
      r.signals(k).rate);
    end
  end
  count = max(1, round((spanEnd - t0) * rate));
  t = t0 + (0:count - 1)' / rate;
  data = nan(count, n);
  gaps = [];
  if isfield(r, 'gaps')
    gaps = r.gaps;
  end
  for k = 1:n
    series = r.signals(k).data(:);
    if isempty(series)
      continue;
    end
    native = edfNativeTimes(starts, r.signals(k).samplesPerRecord, ...
    r.signals(k).rate, numel(series));
    if numel(series) == 1
      column = repmat(series, count, 1);
    else
      column = interp1(native, series, t, method);
    end
    % Bridge nothing across a gap: a query time inside a skipped interval has no
    % data and stays NaN.
    for g = 1:numel(gaps)
      inGap = t > gaps(g).at & t < gaps(g).at + gaps(g).duration;
      column(inGap) = NaN;
    end
    data(:, k) = column;
  end
end
%=============================================================================
function native = edfNativeTimes(starts, spr, rate, total)
  % The real time of each native sample: record start plus the sample's offset
  % within its record. Built for as many samples as the signal actually holds.
  native = zeros(total, 1);
  pos = 0;
  for rec = 1:numel(starts)
    for i = 0:spr - 1
      pos = pos + 1;
      if pos > total
        return;
      end
      native(pos) = starts(rec) + i / rate;
    end
  end
end
%=============================================================================
