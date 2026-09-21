%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function filter = edfParsePrefilter(text)
  % Parse the free-text prefilter field of a signal into structured cut-offs.
  % The field has no rigid grammar, but the common form names a high-pass, a
  % low-pass and a notch, as in 'HP:0.1Hz LP:75Hz N:50Hz'. The three cut-offs
  % are returned in hertz, NaN when the field does not state one, and the raw
  % text is kept so nothing the parser did not understand is lost.
  filter = struct('highpass', NaN, 'lowpass', NaN, 'notch', NaN, ...
  'raw', char(text));
  text = char(text);
  if isempty(strtrim(text))
    return;
  end
  filter.highpass = edfFindCutoff(text, {'HP', 'HIGHPASS', 'HIGH PASS'});
  filter.lowpass = edfFindCutoff(text, {'LP', 'LOWPASS', 'LOW PASS'});
  filter.notch = edfFindCutoff(text, {'N', 'NOTCH'});
end
%=============================================================================
function value = edfFindCutoff(text, keys)
  % The first number that follows any of the keys, in hertz. A key is matched on
  % a word boundary so 'N' does not match inside 'GAIN'.
  value = NaN;
  upper = edfUpperText(text);
  for k = 1:numel(keys)
    key = keys{k};
    pattern = ['(^|[^A-Z])', key, '\s*[:=]?\s*([0-9]*\.?[0-9]+)'];
    tokens = regexp(upper, pattern, 'tokens', 'once');
    if ~isempty(tokens)
      parsed = str2double(tokens{end});
      if isfinite(parsed)
        value = parsed;
        return;
      end
    end
  end
end
%=============================================================================
function upper = edfUpperText(text)
  upper = char(text);
  mask = upper >= 'a' & upper <= 'z';
  upper(mask) = upper(mask) - 32;
end
%=============================================================================
