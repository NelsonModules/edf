%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function out = edfPad(text, width)
  % An EDF header field is fixed width ASCII, left justified and padded with
  % spaces, and truncated when the text is longer than the field. Returned as
  % doubles so it can be written with fwrite as uint8.
  text = char(text);
  if numel(text) >= width
    out = double(text(1:width));
  else
    out = double([text, repmat(' ', 1, width - numel(text))]);
  end
end
%=============================================================================
