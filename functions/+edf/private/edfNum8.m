%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function s = edfNum8(x)
  % A number in at most eight ASCII characters, keeping as many significant
  % digits as fit. The physical range fields are what turn the stored integers
  % back into physical units, so a coarse range coarsens every sample; as many
  % digits as the eight byte field holds are kept.
  if x == round(x) && abs(x) < 1e7
    s = sprintf('%d', x);
    return;
  end
  s = '';
  for precision = 8:-1:1
    candidate = sprintf('%.*g', precision, x);
    if numel(candidate) <= 8
      s = candidate;
      break;
    end
  end
  if isempty(s)
    s = sprintf('%.0f', x);
    s = s(1:min(8, numel(s)));
  end
end
%=============================================================================
