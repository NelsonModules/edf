%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function kind = edfChannelKind(label, transducer)
  % Guess the kind of a signal from its label (and transducer), the way a
  % reader that groups channels needs. This is a hint from the label text, not a
  % measurement of the signal, so it is deliberately coarse: 'eeg', 'eog',
  % 'ecg', 'emg', 'resp', 'spo2', 'status' or 'misc'. Domain modules refine it.
  if nargin < 2
    transducer = '';
  end
  text = edfUpperText([char(label), ' ', char(transducer)]);
  words = edfWordSet(edfUpperText(char(label)));
  if edfHas(text, {'STATUS', 'TRIGGER', 'MARKER', 'EVENT'})
    kind = 'status';
  elseif edfHas(text, {'SPO2', 'SAO2', 'SAT', 'OXIMET', 'PLETH'})
    kind = 'spo2';
  elseif edfHas(text, {'ECG', 'EKG'}) || edfAnyWord(words, {'MLII', 'MLI'})
    kind = 'ecg';
  elseif edfHas(text, {'EOG', 'LOC', 'ROC'})
    kind = 'eog';
  elseif edfHas(text, {'EMG', 'CHIN', 'LEG', 'TIBIAL'})
    kind = 'emg';
  elseif edfHas(text, {'FLOW', 'RESP', 'THOR', 'ABDO', 'SNORE', 'CANNULA', ...
    'AIRFLOW', 'THERM', 'RIP', 'PRESS'})
    kind = 'resp';
  elseif edfHas(text, {'EEG'}) || edfAnyWord(words, edfEegNames())
    kind = 'eeg';
  else
    kind = 'misc';
  end
end
%=============================================================================
function tf = edfHas(text, needles)
  tf = false;
  for k = 1:numel(needles)
    if ~isempty(strfind(text, needles{k}))
      tf = true;
      return;
    end
  end
end
%=============================================================================
function tf = edfAnyWord(words, names)
  tf = false;
  for k = 1:numel(names)
    if any(strcmp(words, names{k}))
      tf = true;
      return;
    end
  end
end
%=============================================================================
function words = edfWordSet(text)
  words = {};
  pieces = strsplit(text, {' ', char(9), '-', '_', '.'});
  for k = 1:numel(pieces)
    if ~isempty(pieces{k})
      words{end + 1} = pieces{k}; %#ok<AGROW>
    end
  end
end
%=============================================================================
function names = edfEegNames()
  % The 10-20 electrode names, so a channel labelled only 'C3' or 'O2-A1' is
  % recognised as EEG without an 'EEG' prefix.
  names = {'FP1', 'FP2', 'FPZ', 'F3', 'F4', 'F7', 'F8', 'FZ', 'C3', 'C4', ...
  'CZ', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8', 'P3', 'P4', 'PZ', 'O1', 'O2', ...
  'OZ', 'A1', 'A2', 'M1', 'M2', 'F9', 'F10'};
end
%=============================================================================
function upper = edfUpperText(text)
  upper = char(text);
  mask = upper >= 'a' & upper <= 'z';
  upper(mask) = upper(mask) - 32;
end
%=============================================================================
