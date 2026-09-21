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
% An annotations-only EDF+ file (a PhysioNet-style hypnogram): one 'EDF
% Annotations' channel, a record duration of zero, and the sleep stages as
% TALs whose onsets are absolute. Such a file is out of the strict spec but
% common, and it must read rather than be refused.
%=============================================================================
folder = strrep(tempname(), char(92), '/');
mkdir(folder);
%=============================================================================
stages = {'Sleep stage W', 'Sleep stage 1', 'Sleep stage 2', 'Sleep stage R'};
onsets = [0, 1560, 1650, 2220];
durations = [1560, 90, 570, 60];
tal = [];
for k = 1:numel(stages)
  tal = [tal, double(sprintf('+%g', onsets(k))), 21, ...
    double(sprintf('%g', durations(k))), 20, double(stages{k}), 20, 0]; %#ok<AGROW>
end
annotSpr = ceil(numel(tal) / 2);
f = [folder, '/hypnogram.edf'];
writeAnnotOnly(f, annotSpr, tal);
%=============================================================================
% It reads by default (no Tolerant needed): no ordinary signal, the stages as
% annotations.
r = edf.read(f);
assert_isequal(r.type, 'EDF+');
assert_isequal(r.ns, 0);
assert_isequal(numel(r.annotations), 4);
assert_isequal(r.annotations(1).text, 'Sleep stage W');
assert_isapprox(r.annotations(2).onset, 1560, 1e-6);
assert_isapprox(r.annotations(2).duration, 90, 1e-6);
%=============================================================================
% edf.annotations returns them too.
a = edf.annotations(f);
assert_isequal(numel(a), 4);
%=============================================================================
% validate tolerates the zero duration as a warning, not a fatal problem.
report = edf.validate(f);
assert_istrue(report.valid);
assert_istrue(numel(report.warnings) >= 1);
%=============================================================================
rmdir(folder, 's');
%=============================================================================
function writeAnnotOnly(path, annotSpr, tal)
  ns = 1;
  fid = fopen(path, 'wb');
  fwrite(fid, padf('0', 8), 'uint8');
  fwrite(fid, padf('X X X X', 80), 'uint8');
  fwrite(fid, padf('Startdate X', 80), 'uint8');
  fwrite(fid, padf('01.01.85', 8), 'uint8');
  fwrite(fid, padf('00.00.00', 8), 'uint8');
  fwrite(fid, padf(sprintf('%d', 256 * (ns + 1)), 8), 'uint8');
  fwrite(fid, padf('EDF+C', 44), 'uint8');
  fwrite(fid, padf('1', 8), 'uint8');
  fwrite(fid, padf('0', 8), 'uint8');      % record duration 0
  fwrite(fid, padf(sprintf('%d', ns), 4), 'uint8');
  fwrite(fid, padf('EDF Annotations', 16), 'uint8');
  fwrite(fid, padf('', 80), 'uint8');
  fwrite(fid, padf('', 8), 'uint8');
  fwrite(fid, padf('-1', 8), 'uint8');
  fwrite(fid, padf('1', 8), 'uint8');
  fwrite(fid, padf('-32768', 8), 'uint8');
  fwrite(fid, padf('32767', 8), 'uint8');
  fwrite(fid, padf('', 80), 'uint8');
  fwrite(fid, padf(sprintf('%d', annotSpr), 8), 'uint8');
  fwrite(fid, padf('', 32), 'uint8');
  b = [tal, zeros(1, 2 * annotSpr - numel(tal))];
  value = b(1:2:end) + 256 * b(2:2:end);
  value(value > 32767) = value(value > 32767) - 65536;
  fwrite(fid, int16(value(:)), 'int16');
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
