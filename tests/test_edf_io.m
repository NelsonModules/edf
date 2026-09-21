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
r = struct('signals', struct('label', {'A', 'B'}, 'unit', {'mV', 'mV'}, ...
  'rate', {10, 10}, 'data', {sin(2 * pi * (0:99)' / 10), (1:100)'}), ...
  'annotations', struct('onset', {2}, 'duration', {0}, 'text', {'m'}));
f1 = [folder, '/one.edf'];
f2 = [folder, '/two.edf'];
edf.write(f1, r);
edf.write(f2, r);
%=============================================================================
% compare: two identical files are equal.
same = edf.compare(f1, f2);
assert_istrue(same.equal);
assert_isequal(numel(same.differences), 0);
% A relabelled file differs, and the difference is named.
edf.edit(f2, 'Rename', {'A', 'Z'});
diff = edf.compare(f1, f2);
assert_isfalse(diff.equal);
assert_istrue(numel(diff.differences) >= 1);
% Comparing a struct to a file works too, within a tolerance.
approx = edf.compare(r, f1, 'Tolerance', 1e-2);
assert_istrue(approx.equal);
%=============================================================================
% tobytes / frombytes: a struct through bytes and back is the same recording.
bytes = edf.tobytes(r);
assert_istrue(isa(bytes, 'uint8'));
assert_istrue(numel(bytes) > 256 * 3);
back = edf.frombytes(bytes);
assert_isequal(back.ns, 2);
assert_isequal(back.signals(1).label, 'A');
assert_isequal(numel(back.annotations), 1);
roundtrip = edf.compare(f1, back);
assert_istrue(roundtrip.equal);
% frombytes accepts read options.
head = edf.frombytes(bytes, 'Data', false);
assert_isequal(numel(head.signals(1).data), 0);
%=============================================================================
% tolerant read: a file whose record duration field is zero.
broken = [folder, '/broken.edf'];
raw = readAll(f1);
raw(245:252) = double(sprintf('%-8s', '0'));
writeAll(broken, raw);
% Strict read refuses it.
assert_checkerror(['edf.read(''', broken, ''')'], ...
  ['The data record duration of ', broken, ' is not a positive number.']);
% Tolerant read works around it and says what was wrong.
tol = edf.read(broken, 'Tolerant', true);
assert_istrue(numel(tol.warnings) >= 1);
assert_isequal(tol.duration, 1);
% A good file has no warnings.
good = edf.read(f1);
assert_isequal(numel(good.warnings), 0);
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
