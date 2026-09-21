%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function anonymize(source, destination, varargin)
  % edf.anonymize(SRC, DST) copies SRC to DST byte for byte, except the header
  % fields that name a person or a day: the patient field becomes 'X X X X' (the
  % format's anonymous patient), the recording identification keeps its
  % 'Startdate' keyword but drops the rest, and the start date becomes
  % '01.01.85'. The signals, the annotations and every other byte are untouched,
  % so the file still reads back identically apart from the blanked fields.
  %
  % edf.anonymize(SRC, DST, 'StartDate', false) leaves the start date in place;
  % 'StartTime', false (the default is to keep the time) has no effect but is
  % accepted for symmetry.
  %
  % edf.anonymize(SRC, DST, 'ShiftDays', N) keeps a date but shifts it by N days
  % instead of blanking it, so the relative timing across a set of files shifted
  % by the same N is preserved while the true date is hidden.
  %
  % See also edf.read, edf.write.
  narginchk(2, inf);
  if (~ischar(source) && ~isStringScalar(source)) || ...
    (~ischar(destination) && ~isStringScalar(destination))
    error('edf:badFileNames', 'The file names must be text.');
  end
  source = char(source);
  destination = char(destination);
  blankDate = true;
  shiftDays = [];
  for k = 1:2:numel(varargin)
    switch lower(char(varargin{k}))
      case 'startdate'
        blankDate = logical(varargin{k + 1});
      case 'starttime'
        % Accepted for symmetry; the time is kept by default.
      case 'shiftdays'
        shiftDays = double(varargin{k + 1});
        if ~isscalar(shiftDays) || ~isfinite(shiftDays)
          error('edf:badShiftDays', 'ShiftDays must be one finite number of days.');
        end
      otherwise
        error('edf:unknownOption', 'Unknown option %s.', char(varargin{k}));
    end
  end
  if ~isfile(source)
    error('edf:noSuchFile', 'The file %s is not on disk.', source);
  end
  fid = fopen(source, 'rb');
  if fid < 0
    error('edf:cannotRead', 'The file %s cannot be read.', source);
  end
  bytes = double(fread(fid, inf, 'uint8'));
  fclose(fid);
  if numel(bytes) < 256
    error('edf:notEdf', 'The file %s is not an EDF or BDF file.', source);
  end
  kind = edfDetectType(bytes(1:8), char(bytes(193:236)'));
  if ~kind.valid
    error('edf:notEdf', 'The file %s is not an EDF or BDF file.', source);
  end
  bytes = edfPutField(bytes, 8, 80, 'X X X X');
  if ~isempty(shiftDays)
    % Keep a shifted date rather than blanking it: the true date is hidden but
    % the interval between files shifted by the same amount is preserved.
    [edfDate, recDate] = edfShiftDate(char(bytes(169:176)'), shiftDays);
    if ~isempty(edfDate)
      bytes = edfPutField(bytes, 168, 8, edfDate);
      bytes = edfPutField(bytes, 88, 80, ['Startdate ', recDate, ' X X']);
    else
      bytes = edfPutField(bytes, 88, 80, 'Startdate X X X X');
    end
  else
    bytes = edfPutField(bytes, 88, 80, 'Startdate X X X X');
    if blankDate
      bytes = edfPutField(bytes, 168, 8, '01.01.85');
    end
  end
  out = fopen(destination, 'wb');
  if out < 0
    error('edf:cannotWrite', 'The file %s cannot be written.', destination);
  end
  fwrite(out, bytes, 'uint8');
  fclose(out);
end
%=============================================================================
function bytes = edfPutField(bytes, offset, width, text)
  bytes(offset + 1:offset + width) = edfPad(text, width);
end
%=============================================================================
function [edfDate, recDate] = edfShiftDate(field, shiftDays)
  % Shift a 'dd.mm.yy' start-date field by a whole number of days, returning the
  % new 'dd.mm.yy' and the 'dd-MMM-yyyy' the EDF+ recording id uses. The two
  % digit year is expanded with the format's rule (85 to 99 the 1900s, 00 to 84
  % the 2000s). An empty result means the field was not a date.
  edfDate = '';
  recDate = '';
  field = strtrim(field);
  if numel(field) ~= 8 || field(3) ~= '.' || field(6) ~= '.'
    return;
  end
  day = str2double(field(1:2));
  month = str2double(field(4:5));
  year = str2double(field(7:8));
  if ~isfinite(day) || ~isfinite(month) || ~isfinite(year)
    return;
  end
  if year >= 85
    year = 1900 + year;
  else
    year = 2000 + year;
  end
  shifted = datevec(datenum([year, month, day, 0, 0, 0]) + round(shiftDays));
  y = shifted(1);
  m = shifted(2);
  d = shifted(3);
  edfDate = sprintf('%02d.%02d.%02d', d, m, mod(y, 100));
  months = {'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', ...
  'OCT', 'NOV', 'DEC'};
  recDate = sprintf('%02d-%s-%04d', d, months{m}, y);
end
%=============================================================================
