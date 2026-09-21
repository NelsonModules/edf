%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function varargout = info(filename)
  % S = edf.info(FILE) returns a compact summary of an EDF, EDF+, BDF or BDF+
  % file, read from the header alone: its type, the start of the recording, the
  % number of data records and their length, the total duration in seconds, and
  % one row per ordinary signal (label, unit, rate and sample count). It is the
  % quick look before a full edf.read.
  %
  % Called with no output, edf.info(FILE) prints the summary as a readable
  % table instead of returning the struct.
  %
  % See also edf.read, edf.header.
  narginchk(1, 1);
  nargoutchk(0, 1);
  if ~ischar(filename) && ~isStringScalar(filename)
    error('edf:badFileName', 'The file name must be text.');
  end
  filename = char(filename);
  r = edf.header(filename);
  s = struct();
  s.file = filename;
  s.type = r.type;
  s.patient = r.patient;
  s.recording = r.recording;
  s.startDateTime = r.startDateTime;
  s.records = r.records;
  s.recordSeconds = r.duration;
  s.seconds = r.records * r.duration;
  s.signalCount = r.ns;
  labels = cell(1, r.ns);
  units = cell(1, r.ns);
  rates = zeros(1, r.ns);
  samples = zeros(1, r.ns);
  for k = 1:r.ns
    labels{k} = r.signals(k).label;
    units{k} = r.signals(k).unit;
    rates(k) = r.signals(k).rate;
    samples(k) = r.signals(k).samplesPerRecord * r.records;
  end
  s.labels = labels;
  s.units = units;
  s.rates = rates;
  s.samples = samples;
  d = dir(filename);
  if ~isempty(d)
    s.bytes = d.bytes;
  else
    s.bytes = 0;
  end
  if nargout == 0
    edfPrintInfo(s);
  else
    varargout{1} = s;
  end
end
%=============================================================================
function edfPrintInfo(s)
  fprintf('%s  [%s]\n', s.file, s.type);
  if ~isempty(s.patient)
    fprintf('  patient    : %s\n', s.patient);
  end
  if ~isempty(s.startDateTime)
    fprintf('  start      : %s\n', s.startDateTime);
  end
  fprintf('  duration   : %g s  (%d records of %g s)\n', s.seconds, ...
  s.records, s.recordSeconds);
  fprintf('  signals    : %d\n', s.signalCount);
  fprintf('  %-20s %-10s %10s %12s\n', 'label', 'unit', 'rate(Hz)', 'samples');
  for k = 1:s.signalCount
    fprintf('  %-20s %-10s %10g %12d\n', s.labels{k}, s.units{k}, ...
    s.rates(k), s.samples(k));
  end
  fprintf('  size       : %d bytes\n', s.bytes);
end
%=============================================================================
