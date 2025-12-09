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
    8, 6;   % Bit 6 (Skips 8, 7)
    8, 8;   % Bit 7
    8, 9;   % Bit 8 
    
    % Horizontal Strip (Row 8)
    1, 8;   % Bit 9
    2, 8;   % Bit 10
    3, 8;   % Bit 11
    4, 8;   % Bit 12
    5, 8;   % Bit 13
    6, 8;   % Bit 14 (Skips 7, 8)
    8, 8;   % Bit 15
];

raw_format_bits = zeros(15, 1);
for i = 1:15
    C = grid_points(i, 1); % Column (X)
    R = grid_points(i, 2); % Row (Y)
    
    % Calculate the center pixel coordinates
    if i <= 8
        center_x = round(TL_x + (C - 3) * M);
        center_y = round(TL_y + (R - 2.5) * M);
    else
        center_x = round(TL_x + (C - 4) * M);
        center_y = round(TL_y + (R - 1.5) * M);
    end
    
    % Sample the binarized image (bw). 
    % We assume 0=White, 1=Black (dark module = 1)
    
    % Check for bounds before sampling (safety)
    [rows, cols] = size(bw);
    if center_y > 0 && center_y <= rows && center_x > 0 && center_x <= cols
        % 1 - bw(y, x) flips the value if bw is 0=Black, 1=White (common)
        raw_value = ~bw(center_y, center_x); 
        disp([center_x, center_y, raw_value]);
        raw_format_bits(i) = raw_value;
    else
        warning(['Format Information sample point is out of bounds at: (', num2str(center_x), ',', num2str(center_y), ')']);
        raw_format_bits(i) = 0; % Default to 0 if out of bounds
    end
end

end
