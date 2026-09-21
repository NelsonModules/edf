%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function opts = edfFormatOptions(format)
  % Resolve a format name into the writer's flags. The accepted names are
  % 'EDF+' (the default), 'EDF', 'BDF+' and 'BDF'. EDF stores each sample in two
  % bytes, BDF in three; the '+' flavours add the annotation channel and mark
  % themselves in the reserved field with a 'C' for a continuous recording.
  format = upper(strtrim(char(format)));
  opts = struct();
  switch format
    case {'EDF+', 'EDF+C'}
      opts.family = 'EDF';
      opts.plus = true;
      opts.bytesPerSample = 2;
      opts.type = 'EDF+';
      opts.reserved = 'EDF+C';
    case 'EDF'
      opts.family = 'EDF';
      opts.plus = false;
      opts.bytesPerSample = 2;
      opts.type = 'EDF';
      opts.reserved = '';
    case {'BDF+', 'BDF+C'}
      opts.family = 'BDF';
      opts.plus = true;
      opts.bytesPerSample = 3;
      opts.type = 'BDF+';
      opts.reserved = 'BDF+C';
    case 'BDF'
      opts.family = 'BDF';
      opts.plus = false;
      opts.bytesPerSample = 3;
      opts.type = 'BDF';
      opts.reserved = '24BIT';
    otherwise
      error('edf:badFormat', 'The format must be one of EDF+, EDF, BDF+ or BDF.');
  end
end
%=============================================================================
