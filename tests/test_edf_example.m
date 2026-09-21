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
% The shipped example file reads and validates. Its provenance is
% data/make_edf_example.m, built through the public edf.write.
shipped = [modulepath('edf'), '/data/edf_example.edf'];
assert_istrue(isfile(shipped));
report = edf.validate(shipped);
assert_istrue(report.valid);
s = edf.info(shipped);
assert_isequal(s.type, 'EDF+');
assert_isequal(s.signalCount, 3);
assert_isequal(s.seconds, 20);
assert_isequal(s.labels, {'EEG Fpz-Cz', 'ECG II', 'SpO2'});
%=============================================================================
% edf.info with no output prints a summary and does not error.
edf.info(shipped);
%=============================================================================
% Selection by kind.
eeg = edf.read(shipped, 'Kinds', {'eeg'});
assert_isequal(eeg.ns, 1);
assert_isequal(eeg.signals(1).label, 'EEG Fpz-Cz');
two = edf.read(shipped, 'Kinds', {'ecg', 'spo2'});
assert_isequal(two.ns, 2);
% Signals and Kinds cannot both be given.
assert_checkerror(['edf.read(''', shipped, ''', ''Signals'', 1, ''Kinds'', ''eeg'')'], ...
  'Give Signals or Kinds, not both.');
%=============================================================================
% The parsed prefilter and kind on a read signal.
r = edf.read(shipped);
assert_isequal(r.signals(1).kind, 'eeg');
assert_isapprox(r.signals(1).highpass, 0.5, 1e-9);
assert_isequal(r.signals(2).kind, 'ecg');
assert_isequal(r.signals(3).kind, 'spo2');
%=============================================================================
% anonymize with a date shift keeps the date but moves it by N days.
folder = strrep(tempname(), char(92), '/');
mkdir(folder);
shifted = [folder, '/shifted.edf'];
edf.anonymize(shipped, shifted, 'ShiftDays', 5);
a = edf.read(shifted);
assert_isequal(strtrim(a.patient), 'X X X X');
% 2000-01-01 shifted by five days is 2000-01-06.
assert_isequal(a.startDateTime(1:10), '2000-01-06');
% A plain anonymize (no shift) blanks the date to the neutral one.
blanked = [folder, '/blanked.edf'];
edf.anonymize(shipped, blanked);
b = edf.read(blanked);
assert_isequal(b.startdate, '01.01.85');
%=============================================================================
% The example script runs end to end without error.
run([modulepath('edf'), '/examples/read_write_demo.m']);
%=============================================================================
rmdir(folder, 's');
%=============================================================================
