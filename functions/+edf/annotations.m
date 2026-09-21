%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function a = annotations(filename)
  % A = edf.annotations(FILE) returns the annotation list of an EDF+ or BDF+
  % file: a struct array with onset (seconds), duration (seconds) and text. The
  % signals are not returned, only the annotation channel is parsed. A file with
  % no annotation channel returns an empty list.
  %
  % See also edf.read, edf.write.
  narginchk(1, 1);
  nargoutchk(0, 1);
  if ~ischar(filename) && ~isStringScalar(filename)
    error('edf:badFileName', 'The file name must be text.');
  end
  opts = struct('data', true, 'annotations', true, 'signals', [], ...
  'skipsignals', true);
  r = edfReadFile(char(filename), opts);
  a = r.annotations;
end
%=============================================================================
