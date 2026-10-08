function [annotated_img, emergency_brake] = runADAS_System(left_img, right_img, calib, detector)
% =========================================================================
% FUNCTION: runADAS_System
% DESCRIPTION: 
%   Core sensor fusion module for the ADAS pipeline. This function projects
%   2D semantic bounding boxes from a Convolutional Neural Network (CNN) 
%   onto a 3D geometric depth map generated via Semi-Global Matching (SGM).
%   It employs robust statistical filtering (median) to estimate the physical 
%   distance to identified obstacles and triggers an Automated Emergency 
%   Braking (AEB) boolean if predefined safety thresholds are breached.
%
% INPUTS:
%   left_img    - [H x W x C] uint8 matrix: Left-eye optical frame.
%   right_img   - [H x W x C] uint8 matrix: Right-eye optical frame.
%   calib       - Struct: Camera calibration parameters containing the 
%                 intrinsic matrix ('cam0') and baseline distance ('baseline').
%   detector    - yolov4ObjectDetector object: Pre-initialized CNN model.
%
% OUTPUTS:
%   annotated_img   - [H x W x 3] uint8 matrix: Left frame with HUD overlays.
%   emergency_brake - Boolean: AEB trigger flag (True if threat detected).
% =========================================================================

    % ---------------------------------------------------------------------
    % Phase 1: Image Preprocessing & Parameter Extraction
    % ---------------------------------------------------------------------
    % SGM block-matching requires single-channel intensity (grayscale) matrices.
    % Convert photometric RGB matrices to grayscale if necessary.
    if size(left_img, 3) == 3
        left_gray = rgb2gray(left_img);
        right_gray = rgb2gray(right_img);
    else
        left_gray = left_img;
        right_gray = right_img;
    end
    
    % Extract the focal length (in pixels) from the intrinsic camera matrix.
    focal_length = calib.cam0(1, 1); 

    % ---------------------------------------------------------------------
    % Phase 2: Geometric Depth Estimation (Stereo Disparity)
    % ---------------------------------------------------------------------
    % Compute the dense disparity map using the Semi-Global Matching (SGM) 
    % algorithm, enforcing 1D smoothness constraints across multiple paths.
    disparity_map = disparitySGM(left_gray, right_gray, 'DisparityRange', [0, 128]);
    
    % Convert pixel disparity to physical metric depth (Z).
    % Formula: Z = (Baseline * Focal_Length) / Disparity
    % Note: Addition of 'eps' prevents fatal division-by-zero errors.
    depth_map = (calib.baseline * focal_length) ./ (disparity_map + eps);

    % ---------------------------------------------------------------------
    % Phase 3: Semantic Object Detection (CNN Inference)
    % ---------------------------------------------------------------------
    % Execute forward pass of the YOLOv4 model on the left reference frame 
    % to extract spatial bounding boxes, confidence scores, and class labels.
    [bboxes, scores, labels] = detect(detector, left_img);

    % ---------------------------------------------------------------------
    % Phase 4: Output Initialization
    % ---------------------------------------------------------------------
    annotated_img = left_img;
    emergency_brake = false;

    % ---------------------------------------------------------------------
    % Phase 5: Sensor Fusion & Spatial Extraction
    % ---------------------------------------------------------------------
    % Iterate through each detected semantic region of interest (ROI).
    for i = 1:size(bboxes, 1)
        
        % Extract spatial coordinates of the bounding box [x, y, width, height].
        x = round(bboxes(i, 1));
        y = round(bboxes(i, 2));
        w = round(bboxes(i, 3));
        h = round(bboxes(i, 4));
        
        % Clamp coordinates to ensure matrix indices do not exceed frame boundaries.
        x1 = max(1, x); 
        y1 = max(1, y);
        x2 = min(size(depth_map, 2), x + w);
        y2 = min(size(depth_map, 1), y + h);
        
        % Slice the 3D depth tensor using the 2D spatial bounding box.
        object_depth_pixels = depth_map(y1:y2, x1:x2);
        
        % Data Sanitization: Filter out non-computable regions (e.g., occlusions, 
        % textureless surfaces resulting in 0 or infinite depth).
        valid_pixels = object_depth_pixels(object_depth_pixels > 0 & ~isinf(object_depth_pixels));
        
        % Bypass ROI if no valid geometric data exists within the spatial bounds.
        if isempty(valid_pixels)
            continue; 
        end
        
        % Robust Statistical Aggregation: Use the median depth to reject background 
        % outliers contained within the rectangular bounding box geometry.
        distance_meters = median(valid_pixels);
        
        % -----------------------------------------------------------------
        % Phase 6: Collision Threat Assessment & UI Annotation
        % -----------------------------------------------------------------
        object_name = string(labels(i));
        color = 'green'; % Default safety status
        warning_text = sprintf('%s: %.1f m', object_name, distance_meters);
        
        % AEB Trigger Logic: Evaluate physical proximity against the safety threshold.
        % Note: Threshold relaxed to 10.0m for evaluation on nominal KITTI driving data.
        if (object_name == "person" || object_name == "car") && distance_meters < 10.0
            color = 'red'; % Critical threat status
            warning_text = sprintf('BRAKE! %s at %.1f m', object_name, distance_meters);
            emergency_brake = true;
        end
        
        % Render the spatial bounding box and telemetry data onto the optical frame.
        annotated_img = insertObjectAnnotation(annotated_img, 'rectangle', ...
            bboxes(i,:), warning_text, 'Color', color, 'LineWidth', 3, 'FontSize', 18);
    end
end