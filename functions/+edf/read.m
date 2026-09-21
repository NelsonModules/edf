%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function r = read(varargin)
  % R = edf.read(FILE) reads an EDF, EDF+, BDF or BDF+ file into the neutral
  % struct this module returns. Nothing in R assumes a domain: it is the header,
  % one entry per ordinary signal with its samples in physical units at its own
  % rate, and the annotations parsed from the annotation channel. A reader that
  % gets the header arithmetic or the little-endian samples wrong returns a
  % signal that looks plausible and is wrong, so the format is read in one
  % place, here.
  %
  % R = edf.read(FILE, 'Signals', WHICH) keeps only some ordinary signals, by
  % label (a char or cellstr) or by index into the ordinary signals.
  %
  % R = edf.read(FILE, 'Kinds', K) keeps the signals whose guessed kind is in K
  % (a char or cellstr of 'eeg', 'eog', 'ecg', 'emg', 'resp', 'spo2', 'status'
  % or 'misc'), for example 'Kinds', {'eeg', 'eog'}.
  %
  % R = edf.read(FILE, 'Annotations', false) skips the annotation channel.
  %
  % R = edf.read(FILE, 'Data', false) reads the header only and returns no
  % samples; edf.header is the shorthand for that.
  %
  % R = edf.read(FILE, 'Scale', false) returns the raw digital codes in
  % r.signals(k).data instead of the physical value, which a bit-coded channel
  % (a BDF Status/trigger channel) needs untouched.
  %
  % R = edf.read(FILE, 'Records', [I J]) reads only data records I to J (one
  % based, inclusive); R = edf.read(FILE, 'Interval', [T0 T1]) reads only the
  % records covering seconds T0 to T1. Only that span is lifted off the disk, so
  % a window of a huge file is cheap. The signals' data hold the window; the
  % annotations and recordStarts are those of the window, with their onsets
  % still on the file's absolute timeline.
  %
  % R = edf.read(FILE, 'Units', U) overrides the physical dimension of each kept
  % signal with U (a cellstr, one per signal), for a file that left the unit
  % field blank.
  %
  % Each signal also carries the prefilter parsed into highpass, lowpass and
  % notch (hertz, NaN when absent), and a kind guessed from its label ('eeg',
  % 'eog', 'ecg', 'emg', 'resp', 'spo2', 'status' or 'misc'). R.gaps lists the
  % discontinuities of an EDF+D file, and R.startFraction is the EDF+ sub-second
  % start offset.
  %
  % R = edf.read(FILE, 'Tolerant', true) reads a slightly out-of-spec file
  % instead of refusing it: a non-positive record duration or a bad sample count
  % is worked around, and what was wrong is listed in R.warnings rather than
  % thrown. R.warnings is otherwise empty.
  %
  % R has fields: file, type ('EDF'|'EDF+'|'BDF'|'BDF+'), family, continuous,
  % version, patient, recording, startdate, starttime, startDateTime, reserved,
  % records, duration, ns, signals (a struct array with label, transducer, unit,
  % prefilter, physicalMin, physicalMax, digitalMin, digitalMax,
  % samplesPerRecord, rate and data), and annotations (a struct array with
  % onset, duration and text).
  %
  % Example:
  %   r = edf.read('record.edf');
  %   plot((0:numel(r.signals(1).data) - 1) / r.signals(1).rate, r.signals(1).data);
  %
  % See also edf.write, edf.header, edf.info, edf.annotations.
  narginchk(1, inf);
  nargoutchk(0, 1);
  filename = varargin{1};
  if ~ischar(filename) && ~isStringScalar(filename)
    error('edf:badFileName', 'The file name must be text.');
  end
  opts = edfReadOptions(varargin(2:end));
  r = edfReadFile(char(filename), opts);
end
%=============================================================================
function opts = edfReadOptions(args)
  opts = struct('data', true, 'annotations', true, 'signals', [], ...
  'scale', true, 'records', [], 'interval', [], 'units', [], ...
  'tolerant', false, 'kinds', []);
  if mod(numel(args), 2) ~= 0
    error('edf:badOptions', 'Options come in name-value pairs.');
  end
  for k = 1:2:numel(args)
    name = args{k};
    value = args{k + 1};
    if ~ischar(name) && ~isStringScalar(name)
      error('edf:badOptionName', 'An option name must be text.');
    end
    switch lower(char(name))
      case 'data'
        opts.data = logical(value);
      case 'annotations'
        opts.annotations = logical(value);
      case 'signals'
        opts.signals = value;
      case 'scale'
        opts.scale = logical(value);
      case 'records'
        opts.records = value;
      case 'interval'
        opts.interval = value;
      case 'units'
        opts.units = value;
      case 'tolerant'
        opts.tolerant = logical(value);
      case 'kinds'
        opts.kinds = value;
      otherwise
        error('edf:unknownOption', 'Unknown option %s.', char(name));
    end
  end
  if ~isempty(opts.records) && ~isempty(opts.interval)
    error('edf:bothWindows', 'Give Records or Interval, not both.');
  end
  if ~isempty(opts.signals) && ~isempty(opts.kinds)
    error('edf:badSelection', 'Give Signals or Kinds, not both.');
  end
end
%=============================================================================
