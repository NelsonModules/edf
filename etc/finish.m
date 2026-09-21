%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
if isdir([modulepath('edf'), '/locale'])
  [status, message] = i18nHelpers('unregister', 'edf');
  if ~status
    warning(message);
  end
end
rmpath([modulepath('edf'), '/functions']);
%=============================================================================
