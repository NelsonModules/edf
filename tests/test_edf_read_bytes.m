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
% The reader is proved WITHOUT the writer here: the header is laid down byte by
% byte with the physical range set equal to the digital range, so the physical
% value the reader returns must equal the stored integer exactly. A wrong
% scaling, offset or byte order would show at once.
%=============================================================================
folder = strrep(tempname(), char(92), '/');
mkdir(folder);
%=============================================================================
% One EDF signal, one record, the digital span mapped to itself.
digital = [-32768, -1, 0, 1, 100, -12345, 32767];
edfFile = [folder, '/exact.edf'];
writeRawEdf(edfFile, digital);
r = edf.read(edfFile);
assert_isequal(r.type, 'EDF');
assert_isequal(r.ns, 1);
assert_isequal(r.signals(1).label, 'TEST');
assert_isequal(r.signals(1).unit, 'uV');
assert_isequal(r.signals(1).samplesPerRecord, numel(digital));
assert_isequal(r.signals(1).data', digital);
%=============================================================================
% One BDF signal, one record, three byte samples, identity scaling, a value
% that is negative in 24 bits.
digital24 = [-8388608, -1, 0, 1, 8388607, -100000];
bdfFile = [folder, '/exact.bdf'];
writeRawBdf(bdfFile, digital24);
rb = edf.read(bdfFile);
assert_isequal(rb.type, 'BDF');
assert_isequal(rb.family, 'BDF');
assert_isequal(rb.signals(1).data', digital24);
%=============================================================================
rmdir(folder, 's');
%=============================================================================
function writeRawEdf(filename, digital)
  spr = numel(digital);
  fid = fopen(filename, 'wb');
  fwrite(fid, padf('0', 8), 'uint8');
  fwrite(fid, padf('X X X X', 80), 'uint8');
  fwrite(fid, padf('Startdate X', 80), 'uint8');
  fwrite(fid, padf('01.01.85', 8), 'uint8');
  fwrite(fid, padf('00.00.00', 8), 'uint8');
  fwrite(fid, padf('512', 8), 'uint8');
  fwrite(fid, padf('', 44), 'uint8');
  fwrite(fid, padf('1', 8), 'uint8');
  fwrite(fid, padf('1', 8), 'uint8');
  fwrite(fid, padf('1', 4), 'uint8');
  fwrite(fid, padf('TEST', 16), 'uint8');
  fwrite(fid, padf('', 80), 'uint8');
  fwrite(fid, padf('uV', 8), 'uint8');
  fwrite(fid, padf('-32768', 8), 'uint8');
  fwrite(fid, padf('32767', 8), 'uint8');
  fwrite(fid, padf('-32768', 8), 'uint8');
  fwrite(fid, padf('32767', 8), 'uint8');
  fwrite(fid, padf('', 80), 'uint8');
  fwrite(fid, padf(sprintf('%d', spr), 8), 'uint8');
  fwrite(fid, padf('', 32), 'uint8');
  fwrite(fid, int16(digital(:)), 'int16');
  fclose(fid);
end
%=============================================================================
function writeRawBdf(filename, digital)
  spr = numel(digital);
  fid = fopen(filename, 'wb');
  fwrite(fid, [255, double('BIOSEMI')], 'uint8');
  fwrite(fid, padf('X X X X', 80), 'uint8');
  fwrite(fid, padf('Startdate X', 80), 'uint8');
  fwrite(fid, padf('01.01.85', 8), 'uint8');
  fwrite(fid, padf('00.00.00', 8), 'uint8');
  fwrite(fid, padf('512', 8), 'uint8');
  fwrite(fid, padf('24BIT', 44), 'uint8');
  fwrite(fid, padf('1', 8), 'uint8');
  fwrite(fid, padf('1', 8), 'uint8');
  fwrite(fid, padf('1', 4), 'uint8');
  fwrite(fid, padf('TEST', 16), 'uint8');
  fwrite(fid, padf('', 80), 'uint8');
  fwrite(fid, padf('uV', 8), 'uint8');
  fwrite(fid, padf('-8388608', 8), 'uint8');
  fwrite(fid, padf('8388607', 8), 'uint8');
  fwrite(fid, padf('-8388608', 8), 'uint8');
  fwrite(fid, padf('8388607', 8), 'uint8');
  fwrite(fid, padf('', 80), 'uint8');
  fwrite(fid, padf(sprintf('%d', spr), 8), 'uint8');
  fwrite(fid, padf('', 32), 'uint8');
  values = digital(:)';
  unsigned = values + 16777216 * (values < 0);
  b1 = mod(unsigned, 256);
  b2 = mod(floor(unsigned / 256), 256);
  b3 = mod(floor(unsigned / 65536), 256);
  fwrite(fid, reshape([b1; b2; b3], 1, []), 'uint8');
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
