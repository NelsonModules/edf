%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function r = header(filename)
  % R = edf.header(FILE) reads only the header of an EDF, EDF+, BDF or BDF+
  % file: the same neutral struct edf.read returns, but with no samples and no
  % annotations. The data block is never touched, so a whole night is read in a
  % few kilobytes and the record count comes from the file size.
  %
  % See also edf.read, edf.info.
  narginchk(1, 1);
  nargoutchk(0, 1);
  if ~ischar(filename) && ~isStringScalar(filename)
    error('edf:badFileName', 'The file name must be text.');
  end
  opts = struct('data', false, 'annotations', false, 'signals', []);
  r = edfReadFile(char(filename), opts);
end
%=============================================================================
