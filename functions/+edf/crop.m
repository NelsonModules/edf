%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function info = crop(source, destination, t0, t1, varargin)
  % edf.crop(SRC, DST, T0, T1) writes to DST the window [T0, T1) seconds of SRC,
  % keeping its flavour and its signals' physical ranges, and re-basing the
  % annotations so an onset is measured from the new start. Each signal is cut
  % at its own rate, so signals of different rates stay aligned.
  %
  % edf.crop(SRC, DST, T0, T1, 'Signals', WHICH) keeps only some signals, by
  % label or by index into the ordinary signals.
  %
  % edf.crop(..., 'RecordSeconds', S) sets the record length of the output; the
  % default is the source's.
  %
  % INFO = edf.crop(...) returns the edf.write info of the file written.
  %
  % See also edf.read, edf.write.
  narginchk(4, inf);
  if ~isnumeric(t0) || ~isscalar(t0) || ~isnumeric(t1) || ~isscalar(t1) || ...
    ~(t1 > t0) || t0 < 0
    error('edf:badWindow', 'The window must be two seconds with T1 greater than T0.');
  end
  signalsSel = [];
  recordSeconds = [];
  for k = 1:2:numel(varargin)
    switch lower(char(varargin{k}))
      case 'signals'
        signalsSel = varargin{k + 1};
      case 'recordseconds'
        recordSeconds = varargin{k + 1};
      otherwise
        error('edf:unknownOption', 'Unknown option %s.', char(varargin{k}));
    end
  end
  if isempty(signalsSel)
    r = edf.read(source);
  else
    r = edf.read(source, 'Signals', signalsSel);
  end
  if isempty(recordSeconds)
    recordSeconds = r.duration;
  end
  for k = 1:numel(r.signals)
    rate = r.signals(k).rate;
    first = floor(t0 * rate) + 1;
    last = min(numel(r.signals(k).data), floor(t1 * rate));
    if last < first
      r.signals(k).data = zeros(0, 1);
    else
      r.signals(k).data = r.signals(k).data(first:last);
    end
  end
  kept = struct('onset', {}, 'duration', {}, 'text', {});
  for k = 1:numel(r.annotations)
    onset = r.annotations(k).onset;
    if onset >= t0 && onset < t1
      entry = r.annotations(k);
      entry.onset = onset - t0;
      kept(end + 1) = entry; %#ok<AGROW>
    end
  end
  r.annotations = kept;
  result = edf.write(destination, r, 'Format', r.type, ...
  'RecordSeconds', recordSeconds);
  if nargout > 0
    info = result;
  end
end
%=============================================================================
