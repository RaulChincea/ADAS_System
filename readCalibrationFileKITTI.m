function calib = readCalibrationFileKITTI(filePath)
% =========================================================================
% FUNCTION: readCalibrationFileKITTI
% DESCRIPTION: 
%   A multi-format deserialization parser for stereo camera calibration data.
%   This module ingests raw text files and extracts intrinsic, extrinsic, 
%   and rectification matrices. It is equipped with dynamic tensor allocation 
%   to handle both Middlebury (synthetic/lab) and KITTI (real-world odometry) 
%   conventions. Furthermore, it mathematically derives the stereo baseline 
%   and primary intrinsic matrix directly from the raw projection vectors.
%
% INPUTS:
%   filePath - String: Absolute or relative path to the calibration .txt file.
%
% OUTPUTS:
%   calib    - Struct: Populated data structure containing all raw matrices, 
%              plus the algorithmically derived 'cam0' (Intrinsic Matrix 3x3), 
%              'baseline' (Physical camera separation in meters), and 
%              'focal_length' (in pixels).
% =========================================================================

    calib = struct();
    
    % ---------------------------------------------------------------------
    % Phase 1: File Stream Initialization
    % ---------------------------------------------------------------------
    fid = fopen(filePath, 'r');
    if fid == -1
        error('File I/O Error: Calibration file unreadable or missing at: %s', filePath); 
    end
    
    isKITTI = false; % Format state flag
    
    % ---------------------------------------------------------------------
    % Phase 2: Sequential Parsing & Dynamic Tensor Allocation
    % ---------------------------------------------------------------------
    while ~feof(fid)
        line = strtrim(fgetl(fid));
        if isempty(line), continue; end
        
        % Format Heuristic: KITTI denotes keys via colons (e.g., P_rect_00:), 
        % whereas Middlebury utilizes standard assignment operators (cam0 = ).
        if contains(line, ':')
            isKITTI = true;
            parts = strsplit(line, ':');
        else
            parts = strsplit(line, '=');
        end
        
        if length(parts) == 2
            key = strtrim(parts{1});
            val_str = strtrim(parts{2});
            
            if isKITTI
                % Convert space-delimited string to a 1D numerical array
                vec = str2num(val_str); %#ok<ST2NM>
                
                % Dynamic Shape Inference based on element count:
                if length(vec) == 12
                    % 3x4 Projection Matrix (e.g., P_rect)
                    calib.(key) = reshape(vec, 4, 3)'; 
                elseif length(vec) == 9
                    % 3x3 Intrinsic or Rectification Matrix (e.g., K, R_rect)
                    calib.(key) = reshape(vec, 3, 3)'; 
                else
                    % 1D Translation or Size Vector (e.g., T, S)
                    calib.(key) = vec; 
                end
            else
                % Middlebury Parsing Logic (Bracketed Array Processing)
                if startsWith(val_str, '[')
                    val_str = strrep(strrep(strrep(val_str, '[', ''), ']', ''), ';', ' ');
                    calib.(key) = reshape(str2num(val_str), 3, 3)'; %#ok<ST2NM>
                else
                    calib.(key) = str2double(val_str);
                end
            end
        end
    end
    fclose(fid);
    
    % ---------------------------------------------------------------------
    % Phase 3: Matrix Translation & Parameter Derivation
    % ---------------------------------------------------------------------
    % ADAS logic requires explicit intrinsic (cam0) and baseline parameters.
    % We derive these mathematically from the color cameras (Sensors 02 & 03)
    % to ensure spatial alignment with the RGB YOLOv4 neural network.
    
    if isKITTI 
        % Check for Raw KITTI Odometry Format (P_rect_02 / P_rect_03)
        if isfield(calib, 'P_rect_02') && isfield(calib, 'P_rect_03')
            
            % Extract the 3x3 Intrinsic Matrix (K) from Left Color Cam
            calib.cam0 = calib.P_rect_02(1:3, 1:3); 
            focal_length = calib.P_rect_02(1,1);
            
            % Baseline spatial derivation from Right Camera projection matrix.
            % Formula: B = abs( Tx / fx ) where Tx is P(1,4)
            calib.baseline = abs(calib.P_rect_03(1,4) / focal_length);
            calib.focal_length = focal_length; 
            
        % Check for KITTI Benchmark Format (P2 / P3)
        elseif isfield(calib, 'P2') && isfield(calib, 'P3')
            
            % Fallback extraction for legacy benchmark dataset conventions
            calib.cam0 = calib.P2(1:3, 1:3);
            calib.baseline = abs(calib.P3(1,4) / calib.P2(1,1));
            calib.focal_length = calib.P2(1,1);
        end
    end
end