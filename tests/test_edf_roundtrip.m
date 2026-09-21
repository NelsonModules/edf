%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
% This module is external and test_run gives every test its own process, so
% each test loads the module it is testing rather than inheriting it.
if ~ismodule('edf')
  run([fileparts(nfilename('fullpath')), '/../loader.m']);
end
% A writer is proved by the reader: signals are written and read back, and the
% only difference allowed is the one the quantisation forces. Every file here is
% written by the test, so nothing reaches the network.
%=============================================================================
folder = strrep(tempname(), char(92), '/');
mkdir(folder);
%=============================================================================
% Two signals at DIFFERENT rates, and a length that is not a whole number of
% one second records, so the last record is padded.
rate1 = 100;
rate2 = 10;
n1 = 350;
n2 = 35;
d1 = sin(2 * pi * (0:n1 - 1)' / rate1);
d2 = cos(2 * pi * (0:n2 - 1)' / rate2);
r = struct();
r.signals = struct('label', {'ECG', 'RESP'}, 'unit', {'mV', 'uV'}, ...
  'transducer', {'electrode', 'belt'}, 'rate', {rate1, rate2}, ...
  'data', {d1, d2});
%=============================================================================
f = [folder, '/a.edf'];
info = edf.write(f, r);
assert_isequal(info.type, 'EDF+');
assert_isequal(info.records, 4);
assert_isequal(info.samplesPerRecord, [100, 10]);
assert_istrue(info.padded);
%=============================================================================
b = edf.read(f);
assert_isequal(b.type, 'EDF+');
assert_isequal(b.family, 'EDF');
assert_istrue(b.continuous);
assert_isequal(b.ns, 2);
assert_isequal(b.records, 4);
assert_isequal(b.signals(1).label, 'ECG');
assert_isequal(b.signals(2).label, 'RESP');
assert_isequal(b.signals(1).unit, 'mV');
assert_isequal(b.signals(1).transducer, 'electrode');
assert_isequal(b.signals(1).rate, 100);
assert_isequal(b.signals(2).rate, 10);
%=============================================================================
% One LSB of the physical range is the most the reconstruction can differ by.
q1 = b.signals(1).physicalMax - b.signals(1).physicalMin;
q1 = q1 / (b.signals(1).digitalMax - b.signals(1).digitalMin);
assert_istrue(max(abs(b.signals(1).data(1:n1) - d1)) <= q1);
% The partial last record was padded with the digital minimum, which reads
% back as the physical minimum.
assert_isequal(numel(b.signals(1).data), 400);
assert_isapprox(b.signals(1).data(end), b.signals(1).physicalMin, 1e-6);
%=============================================================================
% Signal selection by label and by index into the ordinary signals.
justResp = edf.read(f, 'Signals', {'RESP'});
assert_isequal(justResp.ns, 1);
assert_isequal(justResp.signals(1).label, 'RESP');
byIndex = edf.read(f, 'Signals', 2);
assert_isequal(byIndex.signals(1).label, 'RESP');
%=============================================================================
% Header only: no samples, but the record count comes from the file size.
h = edf.read(f, 'Data', false);
assert_isequal(h.records, 4);
assert_isequal(numel(h.signals(1).data), 0);
%=============================================================================
% Plain EDF has no annotation channel and refuses to carry annotations.
r.annotations = struct('onset', {0.5}, 'duration', {0}, 'text', {'mark'});
plainFile = [folder, '/plain.edf'];
edf.write(plainFile, r, 'Format', 'EDF');
plain = edf.read(plainFile);
assert_isequal(plain.type, 'EDF');
assert_isequal(numel(plain.annotations), 0);
%=============================================================================
% A record length other than one second.
twoSec = [folder, '/two.edf'];
info2 = edf.write(twoSec, r, 'RecordSeconds', 2);
assert_isequal(info2.recordSeconds, 2);
back2 = edf.read(twoSec);
assert_isequal(back2.duration, 2);
assert_istrue(max(abs(back2.signals(1).data(1:n1) - d1)) <= q1);
%=============================================================================
% A single signal given as a vector round-trips.
one = struct();
one.signals = struct('label', {'X'}, 'unit', {'mV'}, 'rate', {50}, ...
  'data', {linspace(-3, 3, 200)'});
oneFile = [folder, '/one.edf'];
edf.write(oneFile, one);
backOne = edf.read(oneFile);
assert_isequal(backOne.ns, 1);
assert_isequal(numel(backOne.signals(1).data), 200);
%=============================================================================
% Errors: a missing file, and a file that is not EDF.
absent = [folder, '/nope.edf'];
assert_checkerror(['edf.read(''', absent, ''')'], ...
  sprintf('The file %s is not on disk.', absent));
notEdf = [folder, '/not.edf'];
fid = fopen(notEdf, 'wb');
fwrite(fid, uint8('this is not an edf file at all, really not'), 'uint8');
fclose(fid);
assert_checkerror(['edf.read(''', notEdf, ''')'], ...
  sprintf('The file %s is not an EDF or BDF file.', notEdf));
%=============================================================================
rmdir(folder, 's');
%=============================================================================
