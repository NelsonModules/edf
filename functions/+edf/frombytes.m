%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function r = frombytes(bytes, varargin)
  % R = edf.frombytes(BYTES) reads an EDF or BDF file that is already in memory,
  % a uint8 vector of the file's bytes, and returns the same neutral struct as
  % edf.read. Every edf.read option is accepted after BYTES. It is for data that
  % arrived over a connection or from an archive without ever being a file.
  %
  % Nelson has no in-memory file handle, so the bytes are written to a temporary
  % file, read, and the temporary file removed; nothing is left behind.
  %
  % See also edf.read, edf.tobytes.
  narginchk(1, inf);
  nargoutchk(0, 1);
  if ~isnumeric(bytes) || ~isvector(bytes)
    error('edf:badBytes', 'BYTES must be a numeric vector of the file bytes.');
  end
  temp = [tempname(), '.edf'];
  fid = fopen(temp, 'wb');
  if fid < 0
    error('edf:cannotWriteTemp', 'A temporary file cannot be written.');
  end
  fwrite(fid, uint8(bytes(:)), 'uint8');
  fclose(fid);
  try
    r = edf.read(temp, varargin{:});
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
