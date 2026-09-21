%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function info = edfWriteFile(filename, r, opts)
  % The one writer of the EDF, EDF+, BDF and BDF+ binary format. It takes the
  % neutral struct and lays down a file any EDF or BDF tool can read and this
  % module reads back without loss beyond the quantisation. Nothing here knows
  % about leads or sleep events; the caller has already reduced its recording
  % to signals and annotation texts.
  plus = opts.plus;
  bytesPerSample = opts.bytesPerSample;
  recordSeconds = opts.recordSeconds;
  signals = edfNormalizeSignals(r, opts);
  n = numel(signals);
  % Every signal contributes a whole number of samples per record; the record
  % count is the longest signal's, and a shorter signal is padded with its own
  % digital minimum, which reads back as its physical minimum.
  spr = zeros(1, n);
  records = 1;
  for k = 1:n
    spr(k) = round(signals(k).rate * recordSeconds);
    if spr(k) < 1
      error('edf:badRate', 'The rate and record length give fewer than one sample per record for signal %d.', k);
    end
    records = max(records, ceil(numel(signals(k).data) / spr(k)));
  end
  % Quantise each signal to its digital codes.
  digital = cell(1, n);
  quantum = zeros(1, n);
  padded = false;
  for k = 1:n
    s = signals(k);
    scale = (s.digitalMax - s.digitalMin) / (s.physicalMax - s.physicalMin);
    code = round((s.data(:) - s.physicalMin) * scale) + s.digitalMin;
    code = max(s.digitalMin, min(s.digitalMax, code));
    column = s.digitalMin * ones(records * spr(k), 1);
    column(1:numel(code)) = code;
    if numel(code) < records * spr(k)
      padded = true;
    end
    digital{k} = column;
    quantum(k) = (s.physicalMax - s.physicalMin) / (s.digitalMax - s.digitalMin);
  end
  % The annotation channel, present only for the EDF+ and BDF+ flavours.
  annotSpr = 0;
  annotCodes = [];
  if plus
    [annotCodes, annotSpr] = edfAnnotationChannel(opts.annotations, ...
    recordSeconds, records, bytesPerSample);
  end
  % Assemble one column per record: every signal's block, then the annotation
  % block. Built once and written once, because writing a column at a time into
  % the whole-file matrix copies the matrix each time.
  perRecord = sum(spr) + annotSpr;
  recordMatrix = zeros(perRecord, records);
  offset = 0;
  for k = 1:n
    recordMatrix(offset + 1:offset + spr(k), :) = reshape(digital{k}, spr(k), records);
    offset = offset + spr(k);
  end
  if annotSpr > 0
    recordMatrix(offset + 1:offset + annotSpr, :) = annotCodes;
  end
  bytes = edfEmit(filename, r, opts, signals, spr, annotSpr, records, ...
  recordSeconds, recordMatrix);
  info = struct();
  info.file = char(filename);
  info.type = opts.type;
  info.records = records;
  info.samplesPerRecord = spr;
  info.annotationSamplesPerRecord = annotSpr;
  info.signals = n + double(plus);
  info.recordSeconds = recordSeconds;
  info.quantum = quantum;
  info.padded = padded;
  info.bytes = bytes;
end
%=============================================================================
function signals = edfNormalizeSignals(r, opts)
  % Fill in every field a signal needs to be written: a rate, a physical range
  % (from the signal, or from its data with a small margin so the extremes are
  % not pinned to the digital rails), and a digital range (the flavour's full
  % span unless the signal carries its own).
  if ~isfield(r, 'signals') || isempty(r.signals)
    error('edf:noSignal', 'The struct carries no signal.');
  end
  src = r.signals;
  n = numel(src);
  margin = opts.margin;
  [defLow, defHigh] = edfDefaultDigital(opts.bytesPerSample);
  signals = struct('label', {}, 'transducer', {}, 'unit', {}, ...
  'prefilter', {}, 'physicalMin', {}, 'physicalMax', {}, 'digitalMin', {}, ...
  'digitalMax', {}, 'rate', {}, 'data', {});
  for k = 1:n
    s = src(k);
    entry = struct();
    entry.data = double(s.data(:));
    entry.rate = edfSignalRate(s, opts.recordSeconds, k);
    entry.label = edfFieldOr(s, 'label', sprintf('signal%d', k));
    entry.transducer = edfFieldOr(s, 'transducer', '');
    entry.unit = edfFieldOr(s, 'unit', '');
    entry.prefilter = edfFieldOr(s, 'prefilter', '');
    [entry.physicalMin, entry.physicalMax] = edfPhysicalRange(s, entry.data, margin);
    entry.digitalMin = edfNumOr(s, 'digitalMin', defLow);
    entry.digitalMax = edfNumOr(s, 'digitalMax', defHigh);
    if entry.digitalMax <= entry.digitalMin
      entry.digitalMin = defLow;
      entry.digitalMax = defHigh;
    end
    signals(end + 1) = entry; %#ok<AGROW>
  end
end
%=============================================================================
function rate = edfSignalRate(s, recordSeconds, k)
  if isfield(s, 'rate') && isfinite(s.rate) && s.rate > 0
    rate = double(s.rate);
  elseif isfield(s, 'samplesPerRecord') && isfinite(s.samplesPerRecord) && ...
    s.samplesPerRecord > 0
    rate = double(s.samplesPerRecord) / recordSeconds;
  else
    error('edf:noRate', 'Signal %d has neither a rate nor a samplesPerRecord.', k);
  end
end
%=============================================================================
function [low, high] = edfPhysicalRange(s, data, margin)
  if isfield(s, 'physicalMin') && isfield(s, 'physicalMax') && ...
    ~isempty(s.physicalMin) && ~isempty(s.physicalMax) && ...
    isfinite(s.physicalMin) && isfinite(s.physicalMax) && ...
    s.physicalMax > s.physicalMin
    low = double(s.physicalMin);
    high = double(s.physicalMax);
    return;
  end
  if isempty(data)
    low = -1;
    high = 1;
    return;
  end
  lo = min(data);
  hi = max(data);
  if hi > lo
    m = (hi - lo) * margin;
  else
    m = max(1, abs(hi));
  end
  low = lo - m;
  high = hi + m;
end
%=============================================================================
function [codes, spr] = edfAnnotationChannel(annotations, recordSeconds, records, bytesPerSample)
  % Every record opens with a time keeping TAL stating its own onset, then the
  % annotations whose onset falls in that record. The channel is wide enough to
  % hold the busiest record, and each record's bytes are packed into samples,
  % two bytes each for EDF or three for BDF, low byte first.
  recordBytes = cell(1, records);
  starts = (0:records - 1)' * recordSeconds;
  startText = edfOnsetStrings(starts);
  for rec = 1:records
    recordBytes{rec} = [startText{rec}, 20, 20, 0];
  end
  if ~isempty(annotations)
    onsets = [annotations.onset];
    onsetText = edfOnsetStrings(onsets(:));
    which = floor(onsets / recordSeconds) + 1;
    which(which < 1) = 1;
    which(which > records) = records;
    for j = 1:numel(annotations)
      rec = which(j);
      tal = onsetText{j};
      if isfield(annotations, 'duration') && ~isempty(annotations(j).duration) ...
        && annotations(j).duration ~= 0
        tal = [tal, 21, double(sprintf('%.10g', annotations(j).duration))]; %#ok<AGROW>
      end
      tal = [tal, 20, double(annotations(j).text), 20, 0]; %#ok<AGROW>
      recordBytes{rec} = [recordBytes{rec}, tal];
    end
  end
  widest = 0;
  for rec = 1:records
    widest = max(widest, numel(recordBytes{rec}));
  end
  spr = max(1, ceil(widest / bytesPerSample));
  width = bytesPerSample * spr;
  % Lay every record's bytes into one width-by-records matrix, then pack the
  % whole matrix into samples in one vectorised pass. Packing record by record
  % is one small call per record and, on a night of tens of thousands of
  % records, that loop dominated the write; a single matrix pass removes it.
  block = zeros(width, records);
  for rec = 1:records
    b = recordBytes{rec};
    block(1:numel(b), rec) = b;
  end
  codes = edfBytesMatrixToSamples(block, bytesPerSample);
end
%=============================================================================
function codes = edfBytesMatrixToSamples(block, bytesPerSample)
  % A width-by-records byte matrix to a (width/bytesPerSample)-by-records sample
  % matrix, low byte first, in one vectorised operation over the whole matrix.
  if bytesPerSample == 2
    value = block(1:2:end, :) + 256 * block(2:2:end, :);
    value(value > 32767) = value(value > 32767) - 65536;
  else
    value = block(1:3:end, :) + 256 * block(2:3:end, :) + ...
    65536 * block(3:3:end, :);
    value(value > 8388607) = value(value > 8388607) - 16777216;
  end
  codes = value;
end
%=============================================================================
function texts = edfOnsetStrings(values)
  % The onsets formatted all at once, each kept with its sign and enough digits
  % that round(onset * rate) lands back on the same sample.
  texts = cell(1, numel(values));
  if isempty(values)
    return;
  end
  block = num2str(values(:), '%+.10g');
  for r = 1:size(block, 1)
    texts{r} = double(strtrim(block(r, :)));
  end
end
%=============================================================================
function bytes = edfEmit(filename, r, opts, signals, spr, annotSpr, records, recordSeconds, recordMatrix)
  fid = fopen(filename, 'wb');
  if fid < 0
    error('edf:cannotWrite', 'The file %s cannot be written.', filename);
  end
  plus = opts.plus;
  n = numel(signals);
  ns = n + double(plus);
  % The version field: '0' for EDF, the byte 255 then 'BIOSEMI' for BDF.
  if strcmp(opts.family, 'BDF')
    fwrite(fid, [255, double('BIOSEMI')], 'uint8');
  else
    fwrite(fid, edfPad('0', 8), 'uint8');
  end
  fwrite(fid, edfPad(edfHeaderText(r, 'patient', 'X X X X'), 80), 'uint8');
  fwrite(fid, edfPad(edfHeaderText(r, 'recording', 'Startdate X'), 80), 'uint8');
  fwrite(fid, edfPad(edfHeaderText(r, 'startdate', '01.01.85'), 8), 'uint8');
  fwrite(fid, edfPad(edfHeaderText(r, 'starttime', '00.00.00'), 8), 'uint8');
  fwrite(fid, edfPad(sprintf('%d', 256 * (ns + 1)), 8), 'uint8');
  fwrite(fid, edfPad(opts.reserved, 44), 'uint8');
  fwrite(fid, edfPad(sprintf('%d', records), 8), 'uint8');
  fwrite(fid, edfPad(edfNum8(recordSeconds), 8), 'uint8');
  fwrite(fid, edfPad(sprintf('%d', ns), 4), 'uint8');
  labels = edfCollect(signals, 'label', plus, [opts.family, ' Annotations']);
  transducers = edfCollect(signals, 'transducer', plus, '');
  units = edfCollect(signals, 'unit', plus, '');
  prefilters = edfCollect(signals, 'prefilter', plus, '');
  for k = 1:ns, fwrite(fid, edfPad(labels{k}, 16), 'uint8'); end
  for k = 1:ns, fwrite(fid, edfPad(transducers{k}, 80), 'uint8'); end
  for k = 1:ns, fwrite(fid, edfPad(units{k}, 8), 'uint8'); end
  pmin = edfCollectNumber(signals, 'physicalMin', plus, -1);
  pmax = edfCollectNumber(signals, 'physicalMax', plus, 1);
  dmin = edfCollectNumber(signals, 'digitalMin', plus, edfAnnotDigital(opts, 'min'));
  dmax = edfCollectNumber(signals, 'digitalMax', plus, edfAnnotDigital(opts, 'max'));
  for k = 1:ns, fwrite(fid, edfPad(edfNum8(pmin(k)), 8), 'uint8'); end
  for k = 1:ns, fwrite(fid, edfPad(edfNum8(pmax(k)), 8), 'uint8'); end
  for k = 1:ns, fwrite(fid, edfPad(sprintf('%d', dmin(k)), 8), 'uint8'); end
  for k = 1:ns, fwrite(fid, edfPad(sprintf('%d', dmax(k)), 8), 'uint8'); end
  for k = 1:ns, fwrite(fid, edfPad(prefilters{k}, 80), 'uint8'); end
  counts = [spr, repmat(annotSpr, 1, double(plus))];
  for k = 1:ns, fwrite(fid, edfPad(sprintf('%d', counts(k)), 8), 'uint8'); end
  for k = 1:ns, fwrite(fid, edfPad('', 32), 'uint8'); end
  edfWriteSamples(fid, recordMatrix, opts.bytesPerSample);
  bytes = ftell(fid);
  fclose(fid);
end
%=============================================================================
function edfWriteSamples(fid, recordMatrix, bytesPerSample)
  flat = reshape(recordMatrix, [], 1);
  if bytesPerSample == 2
    fwrite(fid, int16(flat), 'int16');
  else
    unsigned = flat + 16777216 * (flat < 0);
    b1 = mod(unsigned, 256);
    b2 = mod(floor(unsigned / 256), 256);
    b3 = mod(floor(unsigned / 65536), 256);
    stream = reshape([b1'; b2'; b3'], 1, []);
    fwrite(fid, stream, 'uint8');
  end
end
%=============================================================================
function [low, high] = edfDefaultDigital(bytesPerSample)
  if bytesPerSample == 2
    low = -32768;
    high = 32767;
  else
    low = -8388608;
    high = 8388607;
  end
end
%=============================================================================
function value = edfAnnotDigital(opts, which)
  [low, high] = edfDefaultDigital(opts.bytesPerSample);
  if strcmp(which, 'min')
    value = low;
  else
    value = high;
  end
end
%=============================================================================
function list = edfCollect(signals, field, plus, annotValue)
  n = numel(signals);
  list = cell(1, n + double(plus));
  for k = 1:n
    list{k} = signals(k).(field);
  end
  if plus
    list{n + 1} = annotValue;
  end
end
%=============================================================================
function values = edfCollectNumber(signals, field, plus, annotValue)
  n = numel(signals);
  values = zeros(1, n + double(plus));
  for k = 1:n
    values(k) = signals(k).(field);
  end
  if plus
    values(n + 1) = annotValue;
  end
end
%=============================================================================
function text = edfHeaderText(r, field, fallback)
  text = fallback;
  if isfield(r, field) && ~isempty(r.(field))
    text = char(r.(field));
  end
end
%=============================================================================
function value = edfFieldOr(s, field, fallback)
  if isfield(s, field) && ~isempty(s.(field))
    value = char(s.(field));
  else
    value = fallback;
  end
end
%=============================================================================
function value = edfNumOr(s, field, fallback)
  if isfield(s, field) && ~isempty(s.(field)) && isfinite(s.(field))
    value = double(s.(field));
  else
    value = fallback;
  end
end
%=============================================================================
