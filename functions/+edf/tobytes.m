%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function bytes = tobytes(r, varargin)
  % BYTES = edf.tobytes(R) writes the neutral struct R and returns the file as a
  % uint8 vector of bytes instead of writing it to disk. Every edf.write option
  % is accepted after R. It is for a file that will be sent over a connection or
  % kept in memory rather than saved.
  %
  % Nelson has no in-memory file handle, so the file is written to a temporary
  % file, read back, and the temporary file removed; nothing is left behind.
  %
  % See also edf.write, edf.frombytes.
  narginchk(1, inf);
  nargoutchk(0, 1);
  if ~isstruct(r) || ~isfield(r, 'signals')
    error('edf:badStructArg', 'The first argument must be a struct with a signals field.');
  end
  temp = [tempname(), '.edf'];
  try
    edf.write(temp, r, varargin{:});
    fid = fopen(temp, 'rb');
    if fid < 0
      error('edf:cannotReadTemp', 'The temporary file cannot be read.');
    end
    bytes = uint8(fread(fid, inf, 'uint8'));
    fclose(fid);
  catch e
    edfRemove(temp);
    rethrow(e);
  end
  edfRemove(temp);
end
%=============================================================================
function edfRemove(path)
  if isfile(path)
    rmfile(path);
  end
end
%=============================================================================
