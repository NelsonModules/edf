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
% Scale off: the raw digital codes come back, not the physical value.
r = struct();
r.signals = struct('label', {'S'}, 'unit', {'mV'}, 'rate', {10}, ...
  'data', {linspace(-1, 1, 50)'}, 'physicalMin', {-1}, 'physicalMax', {1});
f = [folder, '/s.edf'];
edf.write(f, r);
raw = edf.read(f, 'Scale', false);
assert_istrue(all(raw.signals(1).data == round(raw.signals(1).data)));
scaled = edf.read(f);
assert_istrue(max(abs(scaled.signals(1).data - r.signals(1).data)) < 1e-3);
%=============================================================================
% recordStarts: for a continuous EDF+ they are the record positions, read from
% the time-keeping stamp that opens each record.
multi = struct();
multi.signals = struct('label', {'A'}, 'unit', {'mV'}, 'rate', {4}, ...
  'data', {(1:20)'});
mf = [folder, '/multi.edf'];
edf.write(mf, multi, 'RecordSeconds', 1);
rr = edf.read(mf);
assert_isequal(rr.records, 5);
assert_isequal(rr.recordStarts(:)', [0 1 2 3 4]);
%=============================================================================
% triggers: a BDF Status channel decoded into rising-edge trigger events.
rate = 100;
n = 300;
eeg = sin(2 * pi * (0:n - 1)' / rate);
status = zeros(n, 1);
status(50:60) = 1;      % one trigger, code 1, held for a while
status(120) = 255;      % a second trigger, code 255
status(121:130) = 255;  % held, still one event
status(200:210) = 3;    % a third trigger, code 3
bdf = struct();
bdf.signals = struct('label', {'EEG', 'Status'}, 'unit', {'uV', 'Boolean'}, ...
  'rate', {rate, rate}, 'data', {eeg, status}, ...
  'physicalMin', {[], -8388608}, 'physicalMax', {[], 8388607}, ...
  'digitalMin', {[], -8388608}, 'digitalMax', {[], 8388607});
bf = [folder, '/trig.bdf'];
edf.write(bf, bdf, 'Format', 'BDF+');
ev = edf.triggers(bf);
assert_isequal(numel(ev), 3);
assert_isequal([ev.code], [1 255 3]);
assert_isequal([ev.sample], [50 120 200]);
assert_isapprox(ev(1).onset, 49 / rate, 1e-9);
%=============================================================================
% merge: two files end to end, annotations shifted onto the merged timeline.
a = struct('signals', struct('label', {'X'}, 'unit', {'mV'}, 'rate', {5}, ...
  'data', {(1:25)'}), 'annotations', struct('onset', {1}, 'duration', {0}, ...
  'text', {'first'}));
b = struct('signals', struct('label', {'X'}, 'unit', {'mV'}, 'rate', {5}, ...
  'data', {(26:50)'}), 'annotations', struct('onset', {2}, 'duration', {0}, ...
  'text', {'second'}));
fa = [folder, '/a.edf'];
fb = [folder, '/b.edf'];
edf.write(fa, a);
edf.write(fb, b);
fm = [folder, '/merged.edf'];
edf.merge(fm, {fa, fb});
m = edf.read(fm);
assert_isequal(numel(m.signals(1).data), 50);
assert_istrue(max(abs(m.signals(1).data - (1:50)')) < 1e-2);
onsets = sort([m.annotations.onset]);
assert_isapprox(onsets, [1, 7], 1e-6);   % second file starts at 5 s: 2 -> 7
%=============================================================================
% merge refuses files whose signals do not match.
bad = struct('signals', struct('label', {'Y'}, 'unit', {'mV'}, 'rate', {5}, ...
  'data', {(1:25)'}));
fbad = [folder, '/bad.edf'];
edf.write(fbad, bad);
assert_checkerror(['edf.merge(''', folder, '/x.edf'', {''', fa, ''', ''', ...
  fbad, '''})'], ['File ', fbad, ' does not carry the same signals as the first.']);
%=============================================================================
% resample: two signals at different rates onto one common rate and matrix.
two = struct('signals', struct('label', {'Fast', 'Slow'}, ...
  'unit', {'mV', 'mV'}, 'rate', {20, 5}, ...
  'data', {linspace(0, 1, 40)', linspace(0, 1, 10)'}));
ft = [folder, '/two.edf'];
edf.write(ft, two);
out = edf.resample(ft, 10);
assert_isequal(size(out.data, 2), 2);
assert_isequal(out.rate, 10);
assert_isequal(out.labels, {'Fast', 'Slow'});
assert_isequal(numel(out.t), size(out.data, 1));
% Both ramps run 0..1, so at the common rate they broadly agree (they span
% slightly different durations, so allow more than a hair near the tail).
assert_istrue(max(abs(out.data(:, 1) - out.data(:, 2))) < 0.12);
% nearest is a zero-order hold.
outN = edf.resample(ft, 10, 'Method', 'nearest');
assert_isequal(size(outN.data), size(out.data));
%=============================================================================
rmdir(folder, 's');
%=============================================================================
