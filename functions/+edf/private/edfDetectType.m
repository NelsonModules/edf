%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function kind = edfDetectType(versionBytes, reserved)
  % Decide the flavour of a file from its first eight header bytes and its 44
  % byte reserved field. EDF and EDF+ begin with the ASCII version '0'; BDF and
  % BDF+ begin with the byte 255 then 'BIOSEMI'. EDF+ and BDF+ are marked in the
  % reserved field, 'C' for a continuous recording and 'D' for a discontinuous
  % one; a plain EDF or BDF leaves it blank.
  %
  % KIND has fields:
  %   .type            'EDF' | 'EDF+' | 'BDF' | 'BDF+'
  %   .family          'EDF' | 'BDF'
  %   .bytesPerSample  2 for EDF, 3 for BDF
  %   .plus            true for EDF+/BDF+
  %   .continuous      true for plain EDF/BDF and *+C, false for *+D
  %   .valid           whether the magic is one this module understands
  kind = struct('type', '', 'family', '', 'bytesPerSample', 2, ...
  'plus', false, 'continuous', true, 'valid', false);
  versionBytes = double(versionBytes(:)');
  reserved = char(reserved);
  isBdf = numel(versionBytes) >= 8 && versionBytes(1) == 255 && ...
  strcmp(char(versionBytes(2:8)), 'BIOSEMI');
  isEdf = numel(versionBytes) >= 8 && strcmp(strtrim(char(versionBytes(1:8))), '0');
  if isBdf
    kind.family = 'BDF';
    kind.bytesPerSample = 3;
    kind.valid = true;
  elseif isEdf
    kind.family = 'EDF';
    kind.bytesPerSample = 2;
    kind.valid = true;
  else
    return;
  end
  % The reserved field opens with the flavour tag; a strfind rather than an
  % equality keeps a tag that a writer padded or prefixed from being missed.
  if ~isempty(strfind(reserved, [kind.family, '+']))
    kind.plus = true;
    kind.continuous = isempty(strfind(reserved, [kind.family, '+D']));
  end
  if kind.plus
    kind.type = [kind.family, '+'];
  else
    kind.type = kind.family;
  end
end
%=============================================================================
