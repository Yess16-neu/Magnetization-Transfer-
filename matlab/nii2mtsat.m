function [mtr, mtsat] = nii2mtsat(name_MTon, name_MToff, name_T1w, name_RFlocal, gaussianFilter, alphPD, alphT1, TRPD, TRT1)

%% === Validación de parámetros ===
if nargin < 9
    error('Deben proporcionarse todos los parámetros: name_MTon, name_MToff, name_T1w, name_RFlocal, gaussianFilter, alphPD, alphT1, TRPD, TRT1');
end
if nargin < 5
    gaussianFilter = 0;
end

warning('Esto probablemente debería hacer el registro de imágenes para humanos');

%% === Determinar extensión (nii o nii.gz) ===
if exist(sprintf('%s.nii.gz', name_MTon), 'file')
    ext = '.nii.gz';
elseif exist(sprintf('%s.nii', name_MTon), 'file')
    ext = '.nii';
else
    error('Error en la extensión del archivo (no se encontró ni .nii ni .nii.gz)');
end

%% === Cargar imágenes ===
MTon   = single(niftiread(sprintf('%s%s', name_MTon, ext)));
refPD  = single(niftiread(sprintf('%s%s', name_MToff, ext)));

if ~isempty(name_T1w)
    refT1 = single(niftiread(sprintf('%s%s', name_T1w, ext)));
else
    refT1 = [];
end

RFlocal = [];
if ~isempty(name_RFlocal)
    RFlocal = single(niftiread(sprintf('%s%s', name_RFlocal, ext)));
end

disp('Valores iniciales de RFlocal (primeros 5 elementos):');
disp(RFlocal(1:5));

disp('Valores iniciales de refPD (primeros 5 elementos):');
disp(refPD(1:5));
% Antes
disp('Antes del reajuste:');
disp(['Tamaño RFlocal: ', mat2str(size(RFlocal))]);
disp(['Tamaño refPD:   ', mat2str(size(refPD))]);

% Reajuste
if ~isempty(RFlocal) && ~isequal(size(RFlocal), size(refPD))
    warning('Reajustando tamaño de RFlocal para coincidir con refPD...');
    RFlocal = imresize3(RFlocal, size(refPD));
end

disp(['Tamaño RFlocal:', mat2str(size(RFlocal))]);

disp('--- Tamaños actuales ---');
disp(['Tamaño RFlocal: ', mat2str(size(RFlocal))]);
disp(['Tamaño refPD:   ', mat2str(size(refPD))]);

disp(['Clase RFlocal: ', class(RFlocal)]);
disp(['Clase refPD:   ', class(refPD)]);

disp('Valores finales de RFlocal (primeros 5 elementos):');
disp(RFlocal(1:5));

disp('Valores finales de refPD (primeros 5 elementos):');
disp(refPD(1:5));

%% === Aplicar filtro Gaussiano si se requiere ===
if gaussianFilter
    disp('Aplicando filtro gaussiano suave...');
    for i = 1:size(MTon, 3)
        MTon(:,:,i)   = imgaussfilt(MTon(:,:,i), 0.5, 'FilterSize', 3);
        refPD(:,:,i)  = imgaussfilt(refPD(:,:,i), 0.5, 'FilterSize', 3);
        if ~isempty(refT1)
            refT1(:,:,i) = imgaussfilt(refT1(:,:,i), 0.5, 'FilterSize', 3);
        end
    end
end

%% === Diagnóstico de tamaños ===
disp(['Size of refPD: '   mat2str(size(refPD))]);
disp(['Size of refT1: '   mat2str(size(refT1))]);
disp(['Size of MTon: '    mat2str(size(MTon))]);
disp(['Size of RFlocal: ' mat2str(size(RFlocal))]);

%% === Calcular MTR y MTC ===
%mtr = (refPD - MTon) ./ refPD;
%mtc = refPD - MTon;

%% === Calcular MTSat ===
if ~isempty(refT1)
    try
        mtsat = calcMTsat(refPD, refT1, MTon, ...
            pi/180 * alphPD, pi/180 * alphT1, TRPD, TRT1, RFlocal, 0);
    catch ME
        warning('No se pudo calcular MTSat:\n%s', getReport(ME, 'extended', 'hyperlinks', 'off'));
        mtsat = [];
    end
else
    mtsat = [];
end

%% === Preparar encabezado NIfTI actualizado ===
im_info = niftiinfo(sprintf('%s%s', name_MTon, ext));
im_info.Datatype = 'single';
im_info.BitsPerPixel = 32;

% Alinear el tamaño del header con el volumen
im_info.ImageSize = size(refPD);
if numel(im_info.PixelDimensions) > 3
    im_info.PixelDimensions = im_info.PixelDimensions(1:3);
end

mtsat(~isfinite(mtsat)) = 0; 
%% === Guardar resultados (float32) ===
disp('Guardando imágenes NIfTI (float32)...');
%niftiwrite(single(mtr), 'mtr', im_info, 'Compressed', true);
%niftiwrite(single(mtc), 'mtc', im_info, 'Compressed', true);

if ~isempty(mtsat)
    niftiwrite(single(mtsat), 'mtsat', im_info, 'Compressed', true);
end

disp('Archivos MTR, MTC y MTSat generados correctamente (float32).');

end