%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function v = edf_version()
  % The module version, read from module.json so the manifest is the single
  % source of truth and a hard-coded copy cannot drift from it.
  manifest = jsondecode(fileread([modulepath('edf'), '/module.json']));
  v = manifest.version;
end
%=============================================================================
