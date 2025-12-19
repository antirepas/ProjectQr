function [qr_info] = detectQRCode(bw)
    % Improved QR code detection with robust corner alignment
    %
    % Returns structure with fields:
    %   - finder_patterns: [3x3] array with [x, y, module_size] for each pattern
    %   - rotation_angle: rotation in degrees
    %   - version: QR code version (1-40)
    %   - dimensions: [width, height] in modules

    
    % Find all candidate finder patterns
    candidates = findAllFinderPatterns(bw);
    
    if size(candidates, 1) < 3
        error('Could not find at least 3 finder patterns');
    end
    
    % Select the best 3 patterns that form an L-shape with consistent module size
    [pattern_indices, rotation_angle] = selectFinderPatternTriad(candidates);
    
    if isempty(pattern_indices)
        error('Could not identify valid finder pattern triad');
    end
    
    % Extract the 3 patterns
    patterns = candidates(pattern_indices, :);
    avg_module = mean(patterns(:, 3));
    
    % Identify which pattern is which
    [tl_pattern, tr_pattern, bl_pattern] = identifyPatternPositions(patterns, rotation_angle);
    
    % Determine QR code version and dimensions
    [version, dimensions] = estimateQRDimensions(tl_pattern, tr_pattern, bl_pattern, avg_module);
    
    % Package results
    qr_info = struct();
    qr_info.finder_patterns = [tl_pattern; tr_pattern; bl_pattern];
    qr_info.rotation_angle = rotation_angle;
    qr_info.version = version;
    qr_info.dimensions = dimensions;
end

function [tl, tr, bl] = identifyPatternPositions(patterns, rotation_angle)
    % Improved: Identify patterns based on their geometric relationship
    
    centers = patterns(:, 1:2);
    
    % Find the pattern closest to the rotation origin (top-left)
    % Convert to angle-aligned coordinate system
    angle_rad = deg2rad(rotation_angle);
    cos_a = cos(angle_rad);
    sin_a = sin(angle_rad);
    
    % Project points onto rotated axes
    x_proj = centers(:,1) * cos_a + centers(:,2) * sin_a;
    y_proj = -centers(:,1) * sin_a + centers(:,2) * cos_a;
    
    % Top-left has minimum x_proj + y_proj
    [~, tl_idx] = min(x_proj + y_proj);
    
    % Remove top-left
    remaining = setdiff(1:3, tl_idx);
    
    % Top-right has larger x_proj, bottom-left has larger y_proj
    if x_proj(remaining(1)) > x_proj(remaining(2))
        tr_idx = remaining(1);
        bl_idx = remaining(2);
    else
        tr_idx = remaining(2);
        bl_idx = remaining(1);
    end
    
    tl = patterns(tl_idx, :);
    tr = patterns(tr_idx, :);
    bl = patterns(bl_idx, :);
end

function candidates = findAllFinderPatterns(bw)
    % Find ALL potential finder patterns with more lenient initial detection
    
    [rows, cols] = size(bw);
    
    RATIO_TOLERANCE = 0.45; % More lenient initially
    MIN_MODULE_SIZE = 2; % Lower threshold
    MIN_SEPARATION = 10;
    
    candidates = [];
    
    % Scan with adaptive step size
    step_size = 3;
    
    % Horizontal scan
    for r = floor(rows*0.05) : step_size : floor(rows*0.95)
        profile = double(bw(r, :));
        matches = findPatternInProfile(profile, RATIO_TOLERANCE, MIN_MODULE_SIZE);
        
        for i = 1:size(matches, 1)
            candidate = [matches(i, 1), r, matches(i, 2)];
            candidates = addUniqueCandidate(candidates, candidate, MIN_SEPARATION);
        end
    end
    
    % Vertical scan
    for c = floor(cols*0.05) : step_size : floor(cols*0.95)
        profile = double(bw(:, c))';
        matches = findPatternInProfile(profile, RATIO_TOLERANCE, MIN_MODULE_SIZE);
        
        for i = 1:size(matches, 1)
            candidate = [c, matches(i, 1), matches(i, 2)];
            candidates = addUniqueCandidate(candidates, candidate, MIN_SEPARATION);
        end
    end
    
    if isempty(candidates)
        return;
    end

    disp(candidates);
    
    % Verify candidates - but keep verification simple
    refined = [];
    for i = 1:size(candidates, 1)
        x = round(candidates(i, 1));
        y = round(candidates(i, 2));
        m = candidates(i, 3);
        
        if x < 1 || x > cols || y < 1 || y > rows
            continue;
        end
        
        % Use the simpler verification
        if verifyFinderPattern(bw, x, y, m)
            refined = [refined; candidates(i, :)];
        end
    end
    
    candidates = refined;
end

function isValid = verifyFinderPattern(bw, x, y, module_size)
    % Simplified but effective verification of finder pattern
    
    [rows, cols] = size(bw);
    
    % Check bounds with enough margin
    margin = round(3.5 * module_size);
    if x - margin < 1 || x + margin > cols || y - margin < 1 || y + margin > rows
        isValid = false;
        return;
    end
    
    % Simply verify the horizontal and vertical profiles pass through center
    v_profile = double(bw(:, x))';
    
    % Check both profiles at the candidate position
    %h_valid = verifyProfileAtPosition(h_profile, x, module_size);
    v_valid = verifyProfileAtPosition(v_profile, y, module_size);
    
    isValid = v_valid;
end

function isValid = verifyProfileAtPosition(profile, center_pos, module_size)
    % Verify 1:1:3:1:1 pattern centered approximately at given position
    % More robust - doesn't assume perfect centering
    
    len = length(profile);
    m = module_size;
    
    % Need at least 7 modules worth of data around the center
    half_span = round(3.5 * m);
    
    if center_pos - half_span < 1 || center_pos + half_span > len
        isValid = false;
        return;
    end
    
    % Sample directly from the original profile using absolute positions
    % This avoids any offset errors from extracting sub-regions
    
    % Define the 5 regions relative to center_pos directly
    % Pattern: black(1) white(1) black(3) white(1) black(1)
    % Total span: 7 modules, so from center-3.5m to center+3.5m
    
    % Region 1: First black (leftmost) - 1 module wide
    r1_start = max(1, round(center_pos - 3.5*m));
    r1_end = max(1, round(center_pos - 2.5*m));
    if r1_end <= r1_start || r1_end > len
        isValid = false;
        return;
    end
    black1 = mean(profile(r1_start:r1_end));
    
    % Region 2: First white - 1 module wide
    r2_start = max(1, round(center_pos - 2.5*m));
    r2_end = max(1, round(center_pos - 1.5*m));
    if r2_end <= r2_start || r2_end > len
        isValid = false;
        return;
    end
    white1 = mean(profile(r2_start:r2_end));
    
    % Region 3: Center black - 3 modules wide
    r3_start = max(1, round(center_pos - 1.5*m));
    r3_end = min(len, round(center_pos + 1.5*m));
    if r3_end <= r3_start
        isValid = false;
        return;
    end
    black_center = mean(profile(r3_start:r3_end));
    
    % Region 4: Second white - 1 module wide
    r4_start = min(len, round(center_pos + 1.5*m));
    r4_end = min(len, round(center_pos + 2.5*m));
    if r4_end <= r4_start || r4_start > len
        isValid = false;
        return;
    end
    white2 = mean(profile(r4_start:r4_end));
    
    % Region 5: Last black (rightmost) - 1 module wide
    r5_start = min(len, round(center_pos + 2.5*m));
    r5_end = min(len, round(center_pos + 3.5*m));
    if r5_end <= r5_start || r5_start > len
        isValid = false;
        return;
    end
    black2 = mean(profile(r5_start:r5_end));
    
    % Check pattern with lenient thresholds
    blacks_dark = (black1 < 0.5) && (black_center < 0.5) && (black2 < 0.5);
    whites_light = (white1 > 0.4) && (white2 > 0.4);
    
    % Alternative: check contrast (center darker than surroundings)
    contrast_ok = (black_center < white1 - 0.2) && (black_center < white2 - 0.2);
    
    % Also verify the center is darkest
    center_darkest = (black_center <= black1) && (black_center <= black2);
    
    isValid = blacks_dark && (whites_light || contrast_ok) && center_darkest;
end

function matches = findPatternInProfile(profile, tolerance, min_module)
    % Find all 1:1:3:1:1 patterns with improved accuracy
    
    matches = [];
    
    % Find runs of same color
    transitions = [true, abs(diff(profile)) ~= 0, true];
    run_starts = find(transitions);
    run_lengths = diff(run_starts);
    colors = profile(run_starts(1:end-1)) < 0.5; % true = black, false = white
    
    if length(run_lengths) < 5
        return;
    end
    
    for k = 1:length(run_lengths) - 4
        % Must start with black
        if ~colors(k)
            continue;
        end
        
        % Must be black-white-black-white-black
        if ~(colors(k) && ~colors(k+1) && colors(k+2) && ~colors(k+3) && colors(k+4))
            continue;
        end
        
        L = run_lengths(k:k+4);
        
        % Check minimum size
        if any(L < 2) || mean(L) < min_module
            continue;
        end
        
        % Calculate ratios relative to the 1-unit modules
        M_avg = mean([L(1), L(2), L(4), L(5)]);
        
        if M_avg < min_module
            continue;
        end
        
        ratios = L / M_avg;
        expected = [1, 1, 3, 1, 1];
        
        % Check ratio with tolerance
        errors = abs(ratios - expected) ./ expected;
        
        if max(errors) < tolerance
            start_pos = sum(run_lengths(1:k-1)) + 1;
            center_pos = start_pos + sum(L) / 2;
            module_size = sum(L) / 7;
            
            matches = [matches; center_pos, module_size];
        end
    end
end

function candidates = addUniqueCandidate(candidates, new_candidate, min_sep)
    if isempty(candidates)
        candidates = new_candidate;
        return;
    end
    
    distances = sqrt((candidates(:,1) - new_candidate(1)).^2 + ...
                     (candidates(:,2) - new_candidate(2)).^2);
    
    if min(distances) > min_sep
        candidates = [candidates; new_candidate];
    else
        % If close to existing, keep the one with better module size consistency
        [min_dist, idx] = min(distances);
        if min_dist < min_sep
            % Average the positions and module sizes
            candidates(idx, :) = (candidates(idx, :) + new_candidate) / 2;
        end
    end
end

function [indices, rotation_angle] = selectFinderPatternTriad(candidates)
    % Improved selection with module size consistency check
    
    n = size(candidates, 1);
    
    if n < 3
        indices = [];
        rotation_angle = 0;
        return;
    end
    
    best_score = inf;
    best_indices = [];
    best_angle = 0;
    
    for i = 1:n-2
        for j = i+1:n-1
            for k = j+1:n
                % Check module size consistency (within 30%)
                modules = candidates([i,j,k], 3);
                module_var = std(modules) / mean(modules);
                
                if module_var > 0.3
                    continue;
                end
                
                pts = candidates([i,j,k], 1:2);
                
                [is_valid, score, angle] = validateLShape(pts);
                
                % Penalize module size inconsistency
                total_score = score + module_var * 0.5;
                
                if is_valid && total_score < best_score
                    best_score = total_score;
                    best_indices = [i, j, k];
                    best_angle = angle;
                end
            end
        end
    end
    
    indices = best_indices;
    rotation_angle = best_angle;
end

function [is_valid, score, angle] = validateLShape(pts)
    % Validate that three points form an L-shape (right angle)
    
    % Calculate all distances
    d12 = norm(pts(1,:) - pts(2,:));
    d13 = norm(pts(1,:) - pts(3,:));
    d23 = norm(pts(2,:) - pts(3,:));
    
    distances = [d12, d13, d23];
    [sorted_dist, ~] = sort(distances);
    
    % For an L-shape, the two shorter sides should be similar,
    % and the longest should be sqrt(2) times the others
    ratio = sorted_dist(3) / mean(sorted_dist(1:2));
    expected_ratio = sqrt(2);
    ratio_error = abs(ratio - expected_ratio) / expected_ratio;
    
    % Check right angle exists
    sides_similar = abs(sorted_dist(1) - sorted_dist(2)) / mean(sorted_dist(1:2)) < 0.25;
    
    if ratio_error > 0.25 || ~sides_similar
        is_valid = false;
        score = inf;
        angle = 0;
        return;
    end
    
    % Find the corner point (connected to both shorter sides)
    [~, corner_idx] = min([d12+d13, d12+d23, d13+d23]);
    
    if corner_idx == 1
        corner = pts(1,:);
        arm1 = pts(2,:);
        arm2 = pts(3,:);
    elseif corner_idx == 2
        corner = pts(2,:);
        arm1 = pts(1,:);
        arm2 = pts(3,:);
    else
        corner = pts(3,:);
        arm1 = pts(1,:);
        arm2 = pts(2,:);
    end
    
    % Calculate vectors from corner
    v1 = arm1 - corner;
    v2 = arm2 - corner;
    
    % Check right angle
    dot_product = dot(v1, v2);
    angle_between = acosd(dot_product / (norm(v1) * norm(v2)));
    angle_error = abs(angle_between - 90) / 90;
    
    if angle_error > 0.15
        is_valid = false;
        score = inf;
        angle = 0;
        return;
    end
    
    % Calculate rotation (use the vector pointing more rightward)
    if v1(1) > v2(1)
        angle = atan2d(v1(2), v1(1));
    else
        angle = atan2d(v2(2), v2(1));
    end
    
    is_valid = true;
    score = ratio_error + angle_error;
end

function [version, dimensions] = estimateQRDimensions(tl_pattern, tr_pattern, bl_pattern, avg_module)
    % Improved dimension estimation using both distances
    
    % Distance between top-left and top-right
    dist_top = norm(tl_pattern(1:2) - tr_pattern(1:2));
    
    % Distance between top-left and bottom-left
    dist_left = norm(tl_pattern(1:2) - bl_pattern(1:2));
    
    % Average distance (should be similar for square QR code)
    avg_distance = mean([dist_top, dist_left]);
    
    % Number of modules between finder patterns
    % Finder patterns are 7 modules, centers are at position 3.5
    % For version 1 (21x21): distance between centers = 21 - 7 = 14 modules
    modules_between = avg_distance / avg_module;
    
    % Total modules = modules_between + 2 * 3.5 (half of each finder pattern) + 7 (one full pattern)
    total_modules = modules_between + 7;
    
    % Calculate version: modules = 17 + 4*version
    version = round((total_modules - 17) / 4);
    version = max(1, min(40, version));
    
    % Recalculate exact dimensions
    dimensions = 17 + 4 * version;
end
