%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function kind = channeltype(label, transducer)
  % KIND = edf.channeltype(LABEL) guesses the kind of a signal from its label:
  % 'eeg', 'eog', 'ecg', 'emg', 'resp', 'spo2', 'status' or 'misc'. A second
  % argument TRANSDUCER refines the guess. This is a hint from the label text,
  % not a measurement, so it is deliberately coarse; every signal returned by
  % edf.read already carries it as its kind field.
  %
  % See also edf.read.
  narginchk(1, 2);
  nargoutchk(0, 1);
  if ~ischar(label) && ~isStringScalar(label)
    error('edf:badLabel', 'The label must be text.');
  end
  if nargin < 2
    transducer = '';
  end
  kind = edfChannelKind(char(label), char(transducer));
end
%=============================================================================
