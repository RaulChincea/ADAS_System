function img = readPFM(filename)
% Reads a Portable FloatMap (.pfm) file and returns it as a numeric matrix.

    fid = fopen(filename, 'rb');
    if fid == -1
        error('Could not open the file %s.', filename);
    end
    
    % Read header information
    type = fscanf(fid, '%s', 1);
    width = fscanf(fid, '%d', 1);
    height = fscanf(fid, '%d', 1);
    scale = fscanf(fid, '%f', 1);
    
    % Read the single newline character separating header and data
    fread(fid, 1, 'uint8');
    
    % Read the raw floating point data
    % If scale is negative, the data is Little-Endian (Standard for PCs)
    if scale < 0
        img = fread(fid, [width, height], 'single', 0, 'ieee-le');
    else
        img = fread(fid, [width, height], 'single', 0, 'ieee-be');
    end
    
    fclose(fid);
    
    % MATLAB reads the binary data column-by-column bottom-up, 
    % so we must transpose and flip it to match the original image orientation.
    img = flipud(img');
    
    % In Middlebury datasets, infinite values represent unknown/occluded pixels
    img(img == Inf) = 0; 
end