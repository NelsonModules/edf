%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
if ~ismodule('edf')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
%=============================================================================
folder = strrep(tempname(), char(92), '/');
mkdir(folder);
%=============================================================================
% Windowed read: only the asked records are lifted off the disk.
big = struct('signals', struct('label', {'A'}, 'unit', {'mV'}, 'rate', {4}, ...
  'data', {(1:40)'}));
bf = [folder, '/big.edf'];
edf.write(bf, big, 'RecordSeconds', 1);
w = edf.read(bf, 'Records', [3, 5]);
assert_isequal(w.records, 3);
assert_isequal(numel(w.signals(1).data), 12);
assert_istrue(max(abs(w.signals(1).data - (9:20)')) < 1e-2);
assert_isequal(w.recordStarts(:)', [2 3 4]);
iv = edf.read(bf, 'Interval', [2, 4]);
assert_isequal(iv.records, 2);
assert_isequal(iv.recordStarts(:)', [2 3]);
%=============================================================================
% edit: header and per-signal fields change without re-encoding the samples.
plain = struct('signals', struct('label', {'A', 'B'}, 'unit', {'mV', 'mV'}, ...
  'rate', {5, 5}, 'data', {(1:25)', (26:50)'}), 'patient', 'Old Name');
pf = [folder, '/edit.edf'];
edf.write(pf, plain, 'Format', 'EDF');
before = edf.read(pf);
edf.edit(pf, 'Patient', 'New Name', 'Rename', {'A', 'X'}, ...
  'Units', {'uV', 'uV'});
after = edf.read(pf);
assert_isequal(after.patient, 'New Name');
assert_isequal(after.signals(1).label, 'X');
assert_isequal(after.signals(1).unit, 'uV');
% The samples are untouched by an edit (same bytes, same values).
assert_isequal(after.signals(1).data, before.signals(1).data);
%=============================================================================
% prefilter read into structured cut-offs, and channel kind guessed.
edf.edit(pf, 'Labels', {'EEG Fpz', 'ECG II'}, ...
  'Prefilters', {'HP:0.3Hz LP:35Hz N:50Hz', ''});
pp = edf.read(pf);
assert_isapprox(pp.signals(1).highpass, 0.3, 1e-9);
assert_isapprox(pp.signals(1).lowpass, 35, 1e-9);
assert_isapprox(pp.signals(1).notch, 50, 1e-9);
assert_isequal(pp.signals(1).kind, 'eeg');
assert_isequal(pp.signals(2).kind, 'ecg');
%=============================================================================
% edf.prefilter and edf.channeltype as standalone helpers.
f = edf.prefilter('HP: 0.1 Hz LP: 75 Hz');
assert_isapprox(f.highpass, 0.1, 1e-9);
assert_isapprox(f.lowpass, 75, 1e-9);
assert_istrue(isnan(f.notch));
assert_isequal(edf.channeltype('Status'), 'status');
assert_isequal(edf.channeltype('SpO2'), 'spo2');
assert_isequal(edf.channeltype('C3-A2'), 'eeg');
assert_isequal(edf.channeltype('Flow'), 'resp');
assert_isequal(edf.channeltype('EOG L'), 'eog');
assert_isequal(edf.channeltype('Chin EMG'), 'emg');
assert_isequal(edf.channeltype('Body position'), 'misc');
%=============================================================================
% select: keep a channel subset to a new file.
three = struct('signals', struct('label', {'A', 'B', 'C'}, ...
  'unit', {'mV', 'mV', 'mV'}, 'rate', {5, 5, 5}, ...
  'data', {(1:25)', (26:50)', (51:75)'}));
tf3 = [folder, '/three.edf'];
edf.write(tf3, three);
sel = [folder, '/sel.edf'];
edf.select(tf3, sel, {'B'});
s = edf.read(sel);
assert_isequal(s.ns, 1);
assert_isequal(s.signals(1).label, 'B');
%=============================================================================
% convert: a millivolt signal to microvolts scales the data and the unit.
mvolt = struct('signals', struct('label', {'E'}, 'unit', {'mV'}, ...
  'rate', {10}, 'data', {linspace(-1, 1, 100)'}));
mf = [folder, '/mv.edf'];
edf.write(mf, mvolt);
c = edf.convert(mf, 'uV');
assert_isequal(c.signals(1).unit, 'uV');
assert_istrue(max(abs(c.signals(1).data - 1000 * linspace(-1, 1, 100)')) < 5);
%=============================================================================
% EDF+D: a discontinuous file's real timeline, gaps and gap-aware resample.
dfile = [folder, '/disc.edf'];
writeDiscontinuous(dfile, [0, 1, 5], {[10 20], [30 40], [50 60]});
d = edf.read(dfile);
assert_isequal(d.type, 'EDF+');
assert_isfalse(d.continuous);
assert_isequal(d.recordStarts(:)', [0 1 5]);
assert_isequal(numel(d.gaps), 1);
assert_isapprox(d.gaps(1).at, 2, 1e-9);
assert_isapprox(d.gaps(1).duration, 3, 1e-9);
% Absolute resample opens the gap as NaN and keeps the real times.
ra = edf.resample(d, 2, 'Absolute', true);
assert_isapprox(ra.t(1), 0, 1e-9);
% A time inside the gap (say 3 s) is NaN; a time with data (0.5 s) is not.
gapIdx = find(abs(ra.t - 3) < 1e-6, 1);
dataIdx = find(abs(ra.t - 0.5) < 1e-6, 1);
assert_istrue(~isempty(gapIdx) && isnan(ra.data(gapIdx, 1)));
assert_istrue(~isempty(dataIdx) && ~isnan(ra.data(dataIdx, 1)));
%=============================================================================
rmdir(folder, 's');
%=============================================================================
function writeDiscontinuous(path, starts, records)
  % A minimal EDF+D writer for the test: one signal of two samples per record,
  % plus an 'EDF Annotations' channel whose only content is each record's
  % time-keeping stamp '+<start>\x14\x14\x00'. The reserved field marks EDF+D.
  nrec = numel(starts);
  spr = 2;
  tal = cell(1, nrec);
  width = 0;
  for r = 1:nrec
    tal{r} = [double(sprintf('%+g', starts(r))), 20, 20, 0];
    width = max(width, numel(tal{r}));
  end
  annotSpr = ceil(width / 2);
  ns = 2;
  fid = fopen(path, 'wb');
  fwrite(fid, padf('0', 8), 'uint8');
  fwrite(fid, padf('X X X X', 80), 'uint8');
  fwrite(fid, padf('Startdate X', 80), 'uint8');
  fwrite(fid, padf('01.01.85', 8), 'uint8');
  fwrite(fid, padf('00.00.00', 8), 'uint8');
  fwrite(fid, padf(sprintf('%d', 256 * (ns + 1)), 8), 'uint8');
  fwrite(fid, padf('EDF+D', 44), 'uint8');
  fwrite(fid, padf(sprintf('%d', nrec), 8), 'uint8');
  fwrite(fid, padf('1', 8), 'uint8');
  fwrite(fid, padf(sprintf('%d', ns), 4), 'uint8');
  fwrite(fid, [padf('A', 16), padf('EDF Annotations', 16)], 'uint8');
  fwrite(fid, [padf('', 80), padf('', 80)], 'uint8');
  fwrite(fid, [padf('mV', 8), padf('', 8)], 'uint8');
  fwrite(fid, [padf('-100', 8), padf('-1', 8)], 'uint8');
  fwrite(fid, [padf('100', 8), padf('1', 8)], 'uint8');
  fwrite(fid, [padf('-32768', 8), padf('-32768', 8)], 'uint8');
  fwrite(fid, [padf('32767', 8), padf('32767', 8)], 'uint8');
  fwrite(fid, [padf('', 80), padf('', 80)], 'uint8');
  fwrite(fid, [padf(sprintf('%d', spr), 8), padf(sprintf('%d', annotSpr), 8)], 'uint8');
  fwrite(fid, [padf('', 32), padf('', 32)], 'uint8');
  for r = 1:nrec
    codes = records{r};
    % Physical -100..100 maps to digital -32768..32767; write the digital code.
    digital = round((codes - (-100)) * (32767 - (-32768)) / (100 - (-100))) - 32768;
    fwrite(fid, int16(digital(:)), 'int16');
    b = tal{r};
    b = [b, zeros(1, 2 * annotSpr - numel(b))];
    value = b(1:2:end) + 256 * b(2:2:end);
    value(value > 32767) = value(value > 32767) - 65536;
    fwrite(fid, int16(value(:)), 'int16');
  end
  fclose(fid);
end
%=============================================================================
function out = padf(text, width)
  text = char(text);
  if numel(text) >= width
    out = double(text(1:width));
  else
    out = double([text, repmat(' ', 1, width - numel(text))]);
  end
end
%=============================================================================
