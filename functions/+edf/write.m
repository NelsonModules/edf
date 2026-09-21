%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function info = write(varargin)
  % edf.write(FILE, R) writes the neutral struct R to an EDF+ file, so signals
  % built or processed anywhere can be opened by any EDF tool and read back by
  % edf.read without loss beyond the quantisation. R.signals is a struct array,
  % each entry with a data vector and a rate (samples per second); the optional
  % label, unit, transducer, prefilter and physical or digital range are used
  % when present and defaulted when not. R.annotations, when present, is written
  % to the annotation channel.
  %
  % edf.write(FILE, R, 'Format', FMT) chooses the flavour: 'EDF+' (the default),
  % 'EDF', 'BDF+' or 'BDF'. The '+' flavours carry the annotation channel; BDF
  % stores each sample in three bytes rather than two.
  %
  % edf.write(FILE, R, 'RecordSeconds', S) sets the length of a data record; the
  % default is one second.
  %
  % edf.write(FILE, R, 'Annotations', A) writes A (a struct array with onset,
  % optional duration and text) instead of R.annotations.
  %
  % edf.write(FILE, R, 'Margin', M) sets the fraction by which a signal's own
  % physical range is widened when the signal does not carry one; the default is
  % 0.0015 so the extreme values are not pinned to the digital rails.
  %
  % INFO = edf.write(...) returns what was laid down: the type, the number of
  % records, the samples per record of each signal, the annotation samples per
  % record, the quantisation of each signal, whether the last record was padded
  % and the byte size of the file.
  %
  % See also edf.read.
  narginchk(2, inf);
  nargoutchk(0, 1);
  filename = varargin{1};
  if ~ischar(filename) && ~isStringScalar(filename)
    error('edf:badFileName', 'The file name must be text.');
  end
  r = varargin{2};
  if ~isstruct(r) || ~isfield(r, 'signals')
    error('edf:badStruct', 'The second argument must be a struct with a signals field.');
  end
  opts = edfWriteOptions(r, varargin(3:end));
  result = edfWriteFile(char(filename), r, opts);
  if nargout > 0
    info = result;
  end
end
%=============================================================================
function opts = edfWriteOptions(r, args)
  format = 'EDF+';
  recordSeconds = 1;
  margin = 0.0015;
  annotations = [];
  haveAnnotations = false;
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
      case 'format'
        format = value;
      case 'recordseconds'
        recordSeconds = value;
      case 'margin'
        margin = value;
      case 'annotations'
        annotations = value;
        haveAnnotations = true;
      otherwise
        error('edf:unknownOption', 'Unknown option %s.', char(name));
    end
  end
  if ~isnumeric(recordSeconds) || ~isscalar(recordSeconds) || ...
    ~(recordSeconds > 0) || ~isfinite(recordSeconds)
    error('edf:badRecordSeconds', 'RecordSeconds must be one positive number of seconds.');
  end
  if ~isnumeric(margin) || ~isscalar(margin) || ~(margin >= 0) || ~isfinite(margin)
    error('edf:badMargin', 'Margin must be a non-negative number.');
  end
  opts = edfFormatOptions(format);
  opts.recordSeconds = double(recordSeconds);
  opts.margin = double(margin);
  if haveAnnotations
    opts.annotations = edfNormalizeAnnotations(annotations);
  elseif isfield(r, 'annotations')
    opts.annotations = edfNormalizeAnnotations(r.annotations);
  else
    opts.annotations = struct('onset', {}, 'duration', {}, 'text', {});
  end
end
%=============================================================================
function a = edfNormalizeAnnotations(given)
  a = struct('onset', {}, 'duration', {}, 'text', {});
  if isempty(given)
    return;
  end
  if ~isstruct(given) || ~isfield(given, 'onset') || ~isfield(given, 'text')
    error('edf:badAnnotations', 'Annotations must be a struct array with onset and text fields.');
  end
  for k = 1:numel(given)
    entry = struct('onset', double(given(k).onset), 'duration', 0, ...
    'text', char(given(k).text));
    if isfield(given, 'duration') && ~isempty(given(k).duration)
      entry.duration = double(given(k).duration);
    end
    a(end + 1) = entry; %#ok<AGROW>
  end
end
%=============================================================================
