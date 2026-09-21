%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function result = isedf(filename)
  % RESULT = edf.isedf(FILE) probes a file and returns its flavour as a text,
  % 'EDF', 'EDF+', 'BDF' or 'BDF+', or false when the file is none of these.
  % It reads only the first bytes and never throws on a file that is not an EDF
  % or BDF, so it can be asked of any path.
  %
  % See also edf.read, edf.header, edf.validate.
  narginchk(1, 1);
  nargoutchk(0, 1);
  result = false;
  if ~ischar(filename) && ~isStringScalar(filename)
    return;
  end
  filename = char(filename);
  if ~isfile(filename)
    return;
  end
  fid = fopen(filename, 'rb');
  if fid < 0
    return;
  end
  main = double(fread(fid, 256, 'uint8'));
  fclose(fid);
  if numel(main) < 256
    return;
  end
  kind = edfDetectType(main(1:8), char(main(193:236)'));
  if ~kind.valid
    return;
  end
  ns = str2double(strtrim(char(main(253:256)')));
  if ~isfinite(ns) || ns < 1 || ns ~= round(ns)
    return;
  end
  result = kind.type;
end
%=============================================================================
