function [center_x, center_y, module_size] = findFinderPattern(bw)
    % Improved QR code finder pattern detection
    % Returns the center coordinates and module size of the finder pattern
    
    [rows, cols] = size(bw);
    
    RATIO_TOLERANCE = 0.4; % Increased tolerance for more robust detection
    MIN_MODULE_SIZE = 3; % Minimum expected module size in pixels
    
    % Initialize variables
    best_match = struct('score', inf, 'x', 0, 'y', 0, 'module', 0);
    
    % Scan both horizontally and vertically for better detection
    for scan_direction = 1:2
        if scan_direction == 1
            % Horizontal scan
            scan_max = floor(rows * 0.9);
            scan_min = floor(rows * 0.1);
        else
            % Vertical scan
            scan_max = floor(cols * 0.9);
            scan_min = floor(cols * 0.1);
        end
        
        for idx = scan_min:scan_max
            % Get profile (row or column)
            if scan_direction == 1
                profile = bw(idx, :);
            else
                profile = bw(:, idx)';
            end
            
            % Calculate run lengths more efficiently
            transitions = [true, diff(profile) ~= 0, true];
            run_starts = find(transitions);
            run_lengths = diff(run_starts);
            colors = profile(run_starts(1:end-1));
            
            % Need at least 5 runs
            if length(run_lengths) < 5
                continue;
            end
            
            % Look for 1:1:3:1:1 pattern starting with BLACK
            for k = 1:length(run_lengths) - 4
                % Check if pattern starts with white (0)
                if colors(k) ~= 0
                    continue;
                end
                
                L = run_lengths(k:k+4);
                
                % Skip if any run is too small
                if any(L < 2)
                    continue;
                end
                
                % Calculate average of the four '1' modules
                M_avg = mean([L(1), L(2), L(4), L(5)]);

                if M_avg < MIN_MODULE_SIZE
                    continue;
                end
                
                % Normalized ratios relative to M_avg
                ratios = L / M_avg;
                expected = [1, 1, 3, 1, 1];
                
                % Calculate deviation score
                deviations = abs(ratios - expected) ./ expected;
                max_deviation = max(deviations);
                avg_deviation = mean(deviations);
                
                % Check if pattern matches within tolerance
                if max_deviation < RATIO_TOLERANCE
                    % Calculate position
                    start_pos = sum(run_lengths(1:k-1)) + 1;
                    total_width = sum(L);
                    center_pos = start_pos + floor(total_width / 2);
                    
                    % Estimated module size
                    M_est = total_width / 7;
                    
                    % Assign coordinates based on scan direction
                    if scan_direction == 1
                        x_match = center_pos;
                        y_match = idx;
                    else
                        x_match = idx;
                        y_match = center_pos;
                    end
                    
                    % Verify with cross-scan at the detected center
                    if scan_direction == 1 && y_match <= rows && x_match <= cols
                        cross_profile = bw(:, x_match)';
                    elseif scan_direction == 2 && x_match <= rows && y_match <= cols
                        cross_profile = bw(y_match, :);
                    else
                        continue;
                    end
                    
                    % Quick verification that cross direction also has pattern
                    if verifyCrossPattern(cross_profile, M_est)
                        % Use average deviation as quality score (lower is better)
                        if avg_deviation < best_match.score
                            best_match.score = avg_deviation;
                            best_match.x = x_match;
                            best_match.y = y_match;
                            best_match.module = M_est;

                            center_x = best_match.x;
                            center_y = best_match.y;
                            module_size = best_match.module;
                            return;
                        end
                    end
                end
            end
        end
    end
    
    % Return best match found
    if best_match.x == 0
        warning('Finder pattern not detected!');
        center_x = 0;
        center_y = 0;
        module_size = 0;
    else
        center_x = best_match.x;
        center_y = best_match.y;
        module_size = best_match.module;
    end
end

function isValid = verifyCrossPattern(profile, expected_module_size)
    % Quick verification that perpendicular direction also shows pattern
    % Look for alternating black-white pattern with reasonable sizes
    
    transitions = [true, diff(profile) ~= 0, true];
    run_starts = find(transitions);
    run_lengths = diff(run_starts);
    
    if length(run_lengths) < 3
        isValid = false;
        return;
    end
    
    % Check if there are runs of reasonable size near expected module size
    reasonable_runs = sum(run_lengths > expected_module_size * 0.5 & ...
                         run_lengths < expected_module_size * 4);
    
    isValid = reasonable_runs >= 3;
end
