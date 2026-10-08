function calib = readCalibrationFile(filename)
% readCalibrationFile reads a stereo calibration txt file and returns a struct.
% 
% Example usage:
%   calib = readCalibrationFile('calib.txt');
%   focal_length = calib.cam0(1,1);
%   max_disparity = calib.ndisp;

    % Initialize an empty structure to hold the data
    calib = struct();
    
    % Open the text file for reading
    fid = fopen(filename, 'r');
    if fid == -1
        error('Error: Could not open the file %s. Check if the file exists and the path is correct.', filename);
    end
    
    % Read the file line by line
    while ~feof(fid)
        line = fgetl(fid); % Get current line
        
        % Skip empty lines
        if isempty(line) || ~ischar(line)
            continue;
        end
        
        % Split the line at the '=' character
        parts = strsplit(line, '=');
        
        if length(parts) == 2
            key = strtrim(parts{1});
            val_str = strtrim(parts{2});
            
            % Check if the value is a matrix (enclosed in brackets [ ])
            if startsWith(val_str, '[') && endsWith(val_str, ']')
                % Remove the brackets
                val_str = val_str(2:end-1);
                
                % Convert the string matrix into an actual MATLAB matrix
                % str2num handles the spaces and semicolons perfectly
                val = str2num(val_str); 
            else
                % If it's not a matrix, it's a standard numeric scalar
                val = str2double(val_str);
            end
            
            % Dynamically add the key and value to the struct
            calib.(key) = val;
        end
    end
    
    % Close the file
    fclose(fid);
end