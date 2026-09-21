%=============================================================================
% Copyright (c) 2026-present Allan CORNET (Nelson)
%=============================================================================
% This file is part of the edf module for Nelson.
%=============================================================================
% LICENCE_BLOCK_BEGIN
% SPDX-License-Identifier: LGPL-3.0-or-later
% LICENCE_BLOCK_END
%=============================================================================
function r = convert(source, target)
  % R = edf.convert(SOURCE, TARGET) converts every voltage signal of SOURCE to
  % the TARGET unit, scaling its samples and physical range and setting its
  % unit. SOURCE is a file path or a struct from edf.read; TARGET is one of 'V',
  % 'mV', 'uV' or 'nV'. A signal whose unit is not a voltage in that family is
  % left untouched, so a mixed montage converts only what it can.
  %
  % See also edf.read.
  narginchk(2, 2);
  nargoutchk(0, 1);
  if ischar(source) || isStringScalar(source)
    r = edf.read(char(source));
  elseif isstruct(source) && isfield(source, 'signals')
    r = source;
  else
    error('edf:badSource', 'SOURCE must be a file name or a struct from edf.read.');
  end
  targetScale = edfVoltScale(target);
  if isnan(targetScale)
    error('edf:badUnit', 'TARGET must be one of V, mV, uV or nV.');
  end
  for k = 1:numel(r.signals)
    fromScale = edfVoltScale(r.signals(k).unit);
    if isnan(fromScale)
      continue;
    end
    factor = fromScale / targetScale;
    r.signals(k).data = r.signals(k).data * factor;
    if isfield(r.signals(k), 'physicalMin') && ~isempty(r.signals(k).physicalMin)
      r.signals(k).physicalMin = r.signals(k).physicalMin * factor;
      r.signals(k).physicalMax = r.signals(k).physicalMax * factor;
    end
    r.signals(k).unit = char(target);
  end
end
%=============================================================================
function scale = edfVoltScale(unit)
  % The size of a unit in volts, or NaN when it is not a voltage this function
  % handles. Microvolts are spelled 'uV', the ASCII form EDF files use.
  switch lower(strtrim(char(unit)))
    case 'v'
      scale = 1;
    case 'mv'
      scale = 1e-3;
    case 'uv'
      scale = 1e-6;
    case 'nv'
      scale = 1e-9;
    otherwise
      scale = NaN;
  end
end
%=============================================================================
