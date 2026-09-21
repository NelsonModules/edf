%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function annotations = edfParseTal(bytes)
  % Parse the byte stream of an 'EDF Annotations' (or 'BDF Annotations') signal
  % into a neutral list. A TAL is
  %   onset [21 duration] 20 text 20 text 20 ... 20 0
  % where the onset carries a sign, the duration is optional, each text ends
  % with a 20 and the whole TAL with a 0. The first TAL of every data record is
  % a time keeping stamp with an empty text and carries no annotation, so it
  % falls out naturally: an empty text is never emitted.
  %
  % ANNOTATIONS is a struct array with fields onset (seconds), duration
  % (seconds, 0 when the TAL gave none) and text. A TAL that lists several
  % texts under one onset yields one entry per text, all sharing the onset and
  % duration, which is what the format means by them.
  annotations = struct('onset', {}, 'duration', {}, 'text', {});
  bytes = double(bytes(:)');
  total = numel(bytes);
  pos = 1;
  while pos <= total
    % Zeros pad the tail of a record and separate consecutive TALs.
    while pos <= total && bytes(pos) == 0
      pos = pos + 1;
    end
    if pos > total
      break;
    end
    start = pos;
    while pos <= total && bytes(pos) ~= 20 && bytes(pos) ~= 21
      pos = pos + 1;
    end
    if pos > total
      break;
    end
    onset = str2double(char(bytes(start:pos - 1)));
    duration = 0;
    if bytes(pos) == 21
      pos = pos + 1;
      mark = pos;
      while pos <= total && bytes(pos) ~= 20
        pos = pos + 1;
      end
      parsed = str2double(char(bytes(mark:pos - 1)));
      if isfinite(parsed)
        duration = parsed;
      end
    end
    % Step over the 20 that closes the onset or the duration.
    if pos <= total && bytes(pos) == 20
      pos = pos + 1;
    end
    while pos <= total && bytes(pos) ~= 0
      mark = pos;
      while pos <= total && bytes(pos) ~= 20
        pos = pos + 1;
      end
      text = char(bytes(mark:pos - 1));
      if pos <= total && bytes(pos) == 20
        pos = pos + 1;
      end
      if ~isempty(text) && isfinite(onset)
        annotations(end + 1) = struct('onset', onset, 'duration', ...
        duration, 'text', text); %#ok<AGROW>
      end
    end
    % Step over the 0 that closes the TAL.
    if pos <= total && bytes(pos) == 0
      pos = pos + 1;
    end
  end
end
%=============================================================================
