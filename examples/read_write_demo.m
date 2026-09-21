%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% A tour of the edf toolbox on the shipped example file: read it, look at it,
% pick channels by kind, decode annotations, write a copy and check the copy is
% the same recording.
%=============================================================================
if ~ismodule('edf')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
%=============================================================================
file = [modulepath('edf'), '/data/edf_example.edf'];

% A quick look without reading the samples: type, duration, channels.
disp('--- edf.info ---');
edf.info(file);

% Read the whole recording. Each signal keeps its own rate.
r = edf.read(file);
fprintf('\nRead %d signals; EEG is %d samples at %g Hz.\n', ...
  r.ns, numel(r.signals(1).data), r.signals(1).rate);

% The prefilter and the guessed kind come parsed on every signal.
fprintf('EEG kind=%s  highpass=%g Hz  lowpass=%g Hz\n', ...
  r.signals(1).kind, r.signals(1).highpass, r.signals(1).lowpass);

% Pick channels by kind instead of by name.
eeg = edf.read(file, 'Kinds', {'eeg'});
fprintf('By kind, %d EEG channel(s): %s\n', eeg.ns, eeg.signals(1).label);

% The annotations of the EDF+ file.
fprintf('\nAnnotations:\n');
for k = 1:numel(r.annotations)
  fprintf('  %6.2f s (%g s): %s\n', r.annotations(k).onset, ...
    r.annotations(k).duration, r.annotations(k).text);
end

% Convert the EEG microvolts channel to millivolts on the fly.
mv = edf.convert(file, 'mV');
fprintf('\nEEG converted to %s (was uV).\n', mv.signals(1).unit);

% Write a copy and confirm it is the same recording, within quantisation.
copy = [tempname(), '.edf'];
edf.write(copy, r);
report = edf.compare(file, copy, 'Tolerance', 1e-3);
fprintf('\nRound trip equal: %d (%d difference(s)).\n', ...
  report.equal, numel(report.differences));
rmfile(copy);

% Crop the first ten seconds of just the EEG to a new file.
clip = [tempname(), '.edf'];
edf.crop(file, clip, 0, 10, 'Signals', {'EEG Fpz-Cz'});
fprintf('Cropped clip: %g s of %d channel.\n', ...
  edf.info(clip).seconds, edf.info(clip).signalCount);
rmfile(clip);
%=============================================================================
