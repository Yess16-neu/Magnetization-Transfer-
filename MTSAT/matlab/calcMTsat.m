function MTsat = calcMTsat(refPD, refT1, MTon, alphPD, alphT1, TRPD, TRT1, RFlocal, dofilt)

if nargin < 9
    dofilt = 1;
end

% Evita divisiones por cero o diferencias mínimas

R1app = 0.5 * (refT1 * alphT1 / TRT1 - refPD * alphPD / TRPD) ./ (refPD / alphPD - refT1 / alphT1);
Aapp = (TRPD * alphT1 / alphPD - TRT1 * alphPD / alphT1) * refPD .* refT1 ./ ...
       (refT1 * TRPD * alphT1 - refPD * TRT1 * alphPD);

MTsatApp = (Aapp * alphPD ./ MTon - 1) .* R1app * TRPD - alphPD^2 / 2;

% --- Corrección B1 ---
if ~isempty(RFlocal)
    denom = (1 - 0.4 * RFlocal);
    MTsat = (MTsatApp * (1 - 0.4)) ./ denom;
else
    MTsat = MTsatApp;
end

% --- Filtrado y limpieza ---
MTsat(~isfinite(MTsat)) = 0;
if dofilt
    filt = ones(3,3,3,'single'); filt(2,2,2)=0; filt = filt/sum(filt(:));
    MTsat = convn(MTsat, filt, 'same');
end

% --- Limitar a rango razonable ---
%MTsat = min(max(MTsat, 0), 0.1);
%end
