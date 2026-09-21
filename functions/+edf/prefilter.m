%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function f = prefilter(text)
  % F = edf.prefilter(TEXT) parses a signal's prefilter field into structured
  % cut-offs: F.highpass, F.lowpass and F.notch in hertz (NaN when the field
  % does not state one), and F.raw, the text as written. The field has no rigid
  % grammar; the common 'HP:0.1Hz LP:75Hz N:50Hz' form is understood. Every
  % signal returned by edf.read already carries these as highpass, lowpass and
  % notch; this function is for a field in hand.
  %
  % See also edf.read.
  narginchk(1, 1);
  nargoutchk(0, 1);
  if ~ischar(text) && ~isStringScalar(text)
    error('edf:badPrefilter', 'The prefilter must be text.');
  end
  f = edfParsePrefilter(char(text));
end
%=============================================================================
