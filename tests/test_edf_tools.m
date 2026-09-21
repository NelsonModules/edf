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
rate = 50;
data = linspace(-2, 2, 10 * rate)';
r = struct();
r.signals = struct('label', {'A', 'B'}, 'unit', {'mV', 'mV'}, ...
  'rate', {rate, rate}, 'data', {data, -data});
r.patient = 'Jane Doe';
r.annotations = struct('onset', {1, 5}, 'duration', {0, 0}, 'text', {'x', 'y'});
f = [folder, '/t.edf'];
edf.write(f, r);
%=============================================================================
% header: no samples, right record count.
h = edf.header(f);
assert_isequal(h.records, 10);
assert_isequal(h.ns, 2);
assert_isequal(numel(h.signals(1).data), 0);
%=============================================================================
% info: a compact summary read from the header alone.
s = edf.info(f);
assert_isequal(s.type, 'EDF+');
assert_isequal(s.signalCount, 2);
assert_isequal(s.seconds, 10);
assert_isequal(s.labels, {'A', 'B'});
assert_isequal(s.rates, [50, 50]);
assert_istrue(s.bytes > 0);
%=============================================================================
% isedf: a probe that never throws.
assert_isequal(edf.isedf(f), 'EDF+');
assert_isfalse(edf.isedf([folder, '/does_not_exist.edf']));
txt = [folder, '/plain.txt'];
fid = fopen(txt, 'wb'); fwrite(fid, uint8('hello'), 'uint8'); fclose(fid);
assert_isfalse(edf.isedf(txt));
%=============================================================================
% anonymize: the patient is blanked, the signals are untouched.
anon = [folder, '/anon.edf'];
edf.anonymize(f, anon);
ba = edf.read(anon);
original = edf.read(f);
assert_isequal(strtrim(ba.patient), 'X X X X');
% The signal bytes are copied verbatim, so the anonymized file reads back
% exactly as the source does.
assert_isequal(ba.signals(1).data, original.signals(1).data);
assert_isequal(numel(ba.annotations), 2);
%=============================================================================
% crop: a window measured from the new start, annotations re-based.
cropped = [folder, '/crop.edf'];
edf.crop(f, cropped, 2, 6);
bc = edf.read(cropped);
assert_isequal(bc.records * bc.duration, 4);
assert_isequal(numel(bc.signals(1).data), 4 * rate);
% The mark at 5 s falls in the window and is now at 3 s; the one at 1 s is gone.
assert_isequal(numel(bc.annotations), 1);
assert_isapprox(bc.annotations(1).onset, 3, 1e-6);
%=============================================================================
% crop with a signal subset.
cropOne = [folder, '/crop1.edf'];
edf.crop(f, cropOne, 0, 3, 'Signals', {'B'});
bco = edf.read(cropOne);
assert_isequal(bco.ns, 1);
assert_isequal(bco.signals(1).label, 'B');
%=============================================================================
% validate: a good file has no problems.
report = edf.validate(f);
assert_istrue(report.valid);
assert_isequal(report.type, 'EDF+');
assert_isequal(numel(report.problems), 0);
%=============================================================================
% validate + Fix: a file whose record-count field lies is diagnosed and repaired.
broken = [folder, '/broken.edf'];
bytes = readAll(f);
bytes(237:244) = double(sprintf('%-8s', '999'));
writeAll(broken, bytes);
bad = edf.validate(broken);
assert_isfalse(bad.valid);
assert_istrue(numel(bad.problems) >= 1);
fixed = [folder, '/fixed.edf'];
edf.validate(broken, 'Fix', fixed);
good = edf.validate(fixed);
assert_istrue(good.valid);
%=============================================================================
rmdir(folder, 's');
%=============================================================================
function bytes = readAll(filename)
  fid = fopen(filename, 'rb');
  bytes = double(fread(fid, inf, 'uint8'));
  fclose(fid);
end
%=============================================================================
function writeAll(filename, bytes)
  fid = fopen(filename, 'wb');
  fwrite(fid, bytes, 'uint8');
  fclose(fid);
end
%=============================================================================
