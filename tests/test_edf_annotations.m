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
% Annotations are the EDF+ TAL byte stream. A reader that stops at a record
% boundary loses a mark written late in a record, and a writer that misplaces a
% mark in the wrong record moves it in time; both are checked with marks spread
% across several records.
%=============================================================================
folder = strrep(tempname(), char(92), '/');
mkdir(folder);
%=============================================================================
rate = 20;
data = sin(2 * pi * (0:5 * rate - 1)' / rate);
r = struct();
r.signals = struct('label', {'S'}, 'unit', {'mV'}, 'rate', {rate}, ...
  'data', {data});
% Marks in different one second records; some with a duration, some without;
% two in the same record; free text and a single symbol.
r.annotations = struct( ...
  'onset', {0.5, 0.5, 2.75, 4.1}, ...
  'duration', {0, 1.5, 0, 0.25}, ...
  'text', {'N', 'apnea', 'arousal', 'V'});
%=============================================================================
f = [folder, '/ann.edf'];
edf.write(f, r);
a = edf.annotations(f);
assert_isequal(numel(a), 4);
% The order is by record then within the record, so the two at 0.5 come first.
onsets = [a.onset];
assert_isapprox(sort(onsets), [0.5, 0.5, 2.75, 4.1], 1e-6);
% A mark's text and duration survive.
apnea = findAnnotation(a, 'apnea');
assert_isapprox(apnea.onset, 0.5, 1e-6);
assert_isapprox(apnea.duration, 1.5, 1e-6);
assert_isapprox(findAnnotation(a, 'arousal').onset, 2.75, 1e-6);
assert_isapprox(findAnnotation(a, 'V').duration, 0.25, 1e-6);
assert_isapprox(findAnnotation(a, 'N').duration, 0, 1e-6);
%=============================================================================
% edf.read returns the same list in r.annotations.
full = edf.read(f);
assert_isequal(numel(full.annotations), 4);
%=============================================================================
% Writing the read struct back preserves the annotations (round trip).
g = [folder, '/ann2.edf'];
edf.write(g, full);
a2 = edf.annotations(g);
assert_isequal(numel(a2), 4);
%=============================================================================
% A file with no marks has an empty annotation list, still an EDF+ file.
r2 = r;
r2 = rmfield(r2, 'annotations');
bare = [folder, '/bare.edf'];
edf.write(bare, r2);
assert_isequal(numel(edf.annotations(bare)), 0);
assert_isequal(edf.isedf(bare), 'EDF+');
%=============================================================================
rmdir(folder, 's');
%=============================================================================
function entry = findAnnotation(a, text)
  entry = [];
  for k = 1:numel(a)
    if strcmp(a(k).text, text)
      entry = a(k);
      return;
    end
  end
  error('annotation %s not found', text);
end
%=============================================================================
