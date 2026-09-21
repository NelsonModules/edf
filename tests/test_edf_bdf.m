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
% BDF stores each sample in three bytes, not two. A reader that assembles the
% int24 wrongly, or forgets its sign, returns a signal that looks plausible and
% is wrong; the values here span the extremes of the 24 bit range to show it.
%=============================================================================
folder = strrep(tempname(), char(92), '/');
mkdir(folder);
%=============================================================================
% A signal that reaches deep negative and high positive so the 24 bit sign and
% the three byte assembly are both exercised.
data = [linspace(-1000, 1000, 256)'; -1000; 1000];
r = struct();
r.signals = struct('label', {'EEG'}, 'unit', {'uV'}, 'rate', {258}, ...
  'data', {data});
r.annotations = struct('onset', {0.25}, 'duration', {0}, 'text', {'K'});
%=============================================================================
% BDF+ (with the annotation channel).
fp = [folder, '/a.bdf'];
info = edf.write(fp, r, 'Format', 'BDF+');
assert_isequal(info.type, 'BDF+');
bp = edf.read(fp);
assert_isequal(bp.type, 'BDF+');
assert_isequal(bp.family, 'BDF');
assert_isequal(bp.signals(1).digitalMin, -8388608);
assert_isequal(bp.signals(1).digitalMax, 8388607);
% Twenty four bits over a two thousand unit span is a quantum far below a
% thousandth of a unit, so the reconstruction is nearly exact.
assert_istrue(max(abs(bp.signals(1).data(1:numel(data)) - data)) < 1e-3);
assert_isequal(numel(bp.annotations), 1);
assert_isequal(bp.annotations(1).text, 'K');
assert_isequal(edf.isedf(fp), 'BDF+');
%=============================================================================
% Plain BDF (no annotation channel), reserved marked 24BIT.
fb = [folder, '/b.bdf'];
edf.write(fb, r, 'Format', 'BDF');
bb = edf.read(fb);
assert_isequal(bb.type, 'BDF');
assert_isequal(numel(bb.annotations), 0);
assert_istrue(max(abs(bb.signals(1).data(1:numel(data)) - data)) < 1e-3);
%=============================================================================
% The first byte of a BDF file is 255 then BIOSEMI: prove the magic on disk.
fid = fopen(fb, 'rb');
magic = double(fread(fid, 8, 'uint8'));
fclose(fid);
assert_isequal(magic(1), 255);
assert_isequal(char(magic(2:8)'), 'BIOSEMI');
%=============================================================================
rmdir(folder, 's');
%=============================================================================
