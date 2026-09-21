%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function text = edfParseStart(startdate, starttime, recording)
  % The start of the recording as one readable text 'YYYY-MM-DD hh:mm:ss', or
  % '' when the date field is not a date. The two digit year of the startdate
  % field is expanded with the format's rule (85 to 99 is the 1900s, 00 to 84
  % the 2000s); when the EDF+ recording identification carries the full year
  % after 'Startdate', that year is used instead, since the format stores it
  % there precisely because two digits cannot reach past 2084.
  text = '';
  startdate = strtrim(char(startdate));
  starttime = strtrim(char(starttime));
  if numel(startdate) ~= 8 || startdate(3) ~= '.' || startdate(6) ~= '.'
    return;
  end
  day = str2double(startdate(1:2));
  month = str2double(startdate(4:5));
  year = str2double(startdate(7:8));
  if ~isfinite(day) || ~isfinite(month) || ~isfinite(year)
    return;
  end
  if year >= 85
    year = 1900 + year;
  else
    year = 2000 + year;
  end
  fullYear = edfYearFromRecid(recording, month, day);
  if ~isempty(fullYear)
    year = fullYear;
  end
  hour = 0;
  minute = 0;
  second = 0;
  if numel(starttime) == 8 && starttime(3) == '.' && starttime(6) == '.'
    hour = str2double(starttime(1:2));
    minute = str2double(starttime(4:5));
    second = str2double(starttime(7:8));
    if ~isfinite(hour) || ~isfinite(minute) || ~isfinite(second)
      hour = 0;
      minute = 0;
      second = 0;
    end
  end
  text = sprintf('%04d-%02d-%02d %02d:%02d:%02d', year, month, day, ...
  hour, minute, second);
end
%=============================================================================
function year = edfYearFromRecid(recording, month, day)
  % The EDF+ recording id is 'Startdate dd-MON-yyyy ...'. The full year is taken
  % only when its day and month agree with the startdate field, so a
  % mismatched or non EDF+ identification is ignored rather than trusted.
  year = [];
  recording = strtrim(char(recording));
  parts = strsplit(recording, ' ');
  if numel(parts) < 2 || ~strcmpi(parts{1}, 'Startdate')
    return;
  end
  stamp = parts{2};
  pieces = strsplit(stamp, '-');
  if numel(pieces) ~= 3
    return;
  end
  months = {'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', ...
  'OCT', 'NOV', 'DEC'};
  d = str2double(pieces{1});
  m = find(strcmpi(pieces{2}, months), 1);
  y = str2double(pieces{3});
  if isempty(m) || ~isfinite(d) || ~isfinite(y) || y < 1000
    return;
  end
  if d == day && m == month
    year = y;
  end
end
%=============================================================================
