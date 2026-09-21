%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function info = select(source, destination, which)
  % edf.select(SRC, DST, WHICH) writes to DST only the signals WHICH of SRC, by
  % label (a char or a cellstr) or by index into the ordinary signals, keeping
  % the whole recording in time and its annotations. It is how a channel subset
  % is dropped to a new file; to rename channels in place instead, use edf.edit.
  %
  % INFO = edf.select(...) returns the edf.write info of the file written.
  %
  % See also edf.read, edf.write, edf.edit, edf.crop.
  narginchk(3, 3);
  nargoutchk(0, 1);
  r = edf.read(source, 'Signals', which);
  result = edf.write(destination, r, 'Format', r.type, ...
  'RecordSeconds', r.duration);
  if nargout > 0
    info = result;
  end
end
%=============================================================================
