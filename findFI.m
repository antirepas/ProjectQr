function [raw_format_bits] = findFI(module_size, bw, TL_x, TL_y)

% Assuming TL_x, TL_y, module_size, and bw are available.
M = module_size;
grid_points = [
    % Vertical Strip (Column 8)
    8, 1;   % Bit 1
    8, 2;   % Bit 2
    8, 3;   % Bit 3
    8, 4;   % Bit 4
    8, 5;   % Bit 5
    8, 7;   % Bit 6 (Skips 8, 6)
    8, 9;   % Bit 7 
    
    % Horizontal Strip (Row 8)
    1, 8;   % Bit 8
    2, 8;   % Bit 9
    3, 8;   % Bit 10
    4, 8;   % Bit 11
    5, 8;   % Bit 12
    7, 8;   % Bit 13 (Skips 6, 8)
    9, 8;   % Bit 14
    6, 8    % Bit 15 (The last bit of the sequence)
];

raw_format_bits = zeros(15, 1);
for i = 1:15
    C = grid_points(i, 1); % Column (X)
    R = grid_points(i, 2); % Row (Y)
    
    % Calculate the center pixel coordinates
    center_x = round(TL_x + (C - 3.5) * M);
    center_y = round(TL_y + (R - 3.5) * M);
    
    % Sample the binarized image (bw). 
    % We assume 0=White, 1=Black (dark module = 1)
    
    % Check for bounds before sampling (safety)
    [rows, cols] = size(bw);
    if center_y > 0 && center_y <= rows && center_x > 0 && center_x <= cols
        % 1 - bw(y, x) flips the value if bw is 0=Black, 1=White (common)
        raw_value = ~bw(center_y, center_x); 
        raw_format_bits(i) = raw_value;
    else
        warning(['Format Information sample point is out of bounds at: (', num2str(center_x), ',', num2str(center_y), ')']);
        raw_format_bits(i) = 0; % Default to 0 if out of bounds
    end
end

% The fixed Dark Module (always Black/1) at (8, 8) is at bit index 6
% The 7th element in the raw_format_bits array is the actual 7th bit.
raw_format_bits = [raw_format_bits(1:6); 1; raw_format_bits(7:14)];

end
