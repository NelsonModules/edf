%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function events = triggers(varargin)
  % EVENTS = edf.triggers(FILE) decodes the trigger channel of a BDF or EDF
  % file and returns one entry per trigger onset. A BioSemi BDF file carries a
  % 'Status' channel whose low sixteen bits are the trigger inputs; a trigger is
  % a sample where that code changes to a nonzero value. Each entry has fields
  % onset (seconds), sample (one based, into the channel) and code (the trigger
  % value).
  %
  % EVENTS = edf.triggers(FILE, 'Channel', NAME) reads a channel by label rather
  % than the default 'Status'. EVENTS = edf.triggers(FILE, 'Mask', M) keeps only
  % the bits of M (default 65535, the low sixteen).
  %
  % The channel is read as raw digital codes, never scaled to a physical value,
  % because its bits are a code and not a measurement.
  %
  % See also edf.read, edf.annotations.
  narginchk(1, inf);
  nargoutchk(0, 1);
  filename = varargin{1};
  if ~ischar(filename) && ~isStringScalar(filename)
    error('edf:badFileName', 'The file name must be text.');
  end
  channelName = 'Status';
  mask = 65535;
  for k = 2:2:numel(varargin)
    switch lower(char(varargin{k}))
      case 'channel'
        channelName = char(varargin{k + 1});
      case 'mask'
        mask = double(varargin{k + 1});
      otherwise
        error('edf:unknownOption', 'Unknown option %s.', char(varargin{k}));
    end
  end
  r = edf.read(char(filename), 'Scale', false, 'Annotations', false);
  index = 0;
  for k = 1:numel(r.signals)
    if strcmpi(strtrim(r.signals(k).label), channelName)
      index = k;
      break;
    end
  end
  if index == 0
    error('edf:noStatusChannel', 'No channel is labelled %s.', channelName);
  end
  codes = r.signals(index).data(:);
  rate = r.signals(index).rate;
  % The codes are signed after the 24 or 16 bit assembly; the trigger bits are
  % the low bits of the UNSIGNED value.
  if strcmp(r.family, 'BDF')
    unsigned = codes + 16777216 * (codes < 0);
  else
    unsigned = codes + 65536 * (codes < 0);
  end
  value = mod(unsigned, mask + 1);
  % A trigger is a rising edge to a nonzero code: the value changes from the
  % previous sample and is not zero. The first sample counts when it is nonzero.
  previous = [NaN; value(1:end - 1)];
  isEdge = value ~= 0 & value ~= previous;
  samples = find(isEdge);
  events = struct('onset', {}, 'sample', {}, 'code', {});
  for k = 1:numel(samples)
    s = samples(k);
    events(end + 1) = struct('onset', (s - 1) / rate, 'sample', s, ...
    'code', value(s)); %#ok<AGROW>
  end
end
%=============================================================================
