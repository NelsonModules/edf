%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% Build the small EDF+ example shipped in data/edf_example.edf. It is a twenty
% second recording of three channels at different rates, with two annotations,
% written entirely through the public edf.write so its provenance is this file.
%=============================================================================
if ~ismodule('edf')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
%=============================================================================
seconds = 20;
% An EEG at 100 Hz, an ECG at 200 Hz, and an oxygen saturation at 1 Hz: three
% channels a sleep or Holter recording would carry, at three different rates.
teeg = (0:seconds * 100 - 1) / 100;
eeg = 40 * sin(2 * pi * 10 * teeg) + 8 * sin(2 * pi * 2 * teeg);
tecg = (0:seconds * 200 - 1) / 200;
ecg = 1.2 * sin(2 * pi * 1.1 * tecg) .^ 3;
spo2 = 97 + zeros(1, seconds * 1);
spo2(10:13) = [95 92 90 93];
%=============================================================================
r = struct();
r.signals = struct( ...
  'label', {'EEG Fpz-Cz', 'ECG II', 'SpO2'}, ...
  'unit', {'uV', 'mV', '%'}, ...
  'transducer', {'AgAgCl electrode', 'AgAgCl electrode', 'pulse oximeter'}, ...
  'prefilter', {'HP:0.5Hz LP:35Hz N:50Hz', 'HP:0.05Hz LP:40Hz', ''}, ...
  'rate', {100, 200, 1}, ...
  'data', {eeg', ecg', spo2'});
r.annotations = struct( ...
  'onset', {5, 9.5}, ...
  'duration', {0, 3}, ...
  'text', {'lights off', 'desaturation'});
r.patient = 'X X X X';
r.recording = 'Startdate 01-JAN-2000 X X edf_example';
r.startdate = '01.01.00';
r.starttime = '22.15.00';
%=============================================================================
target = [fileparts(nfilename('fullpath')), '/edf_example.edf'];
info = edf.write(target, r, 'Format', 'EDF+');
fprintf('Wrote %s (%d bytes, %d records)\n', target, info.bytes, info.records);
%=============================================================================
