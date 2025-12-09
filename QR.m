function [err] = QR(im)

err = 0;
gray = rgb2gray(im);
gray = medfilt2(gray, [3 3]);
bw = imbinarize(gray);
imshow(bw);
impixelinfo;
mask = [1,0,1,0,1,0,0,0,0,0,1,0,0,1,0];

[TL_x, TL_y, module_size] = findFinderPattern(bw);
disp('--- TL Pattern ---');
disp(['TL_x: ', num2str(TL_x)]);
disp(['TL_y: ', num2str(TL_y)]);
disp(['Module Size: ', num2str(module_size)]);

if TL_x == 0 
    warning("Scan it better");
    err = 1;
    return;
end

[~, cols] = size(bw);

% Define the starting and ending indices for the search area
potential_start = TL_x + ceil(module_size * 15);
    
% Ensure the starting column is valid (not past the right edge)
if potential_start < cols
    tr_col_start = potential_start;
else
    % If the calculated start is too far right (e.g., for small QR codes), 
    % just start the search from the middle of the image.
    tr_col_start = floor(cols / 2);
end

% Ensure the starting column is at least 1
if tr_col_start < 1
    tr_col_start = 1;
end

tr_row_end = TL_y + ceil(module_size * 10); % Search 10 modules below TL_y
tr_search_area = bw(1:tr_row_end, tr_col_start:cols);

[TR_rel_x, TR_rel_y, ~] = findFinderPattern(tr_search_area);

TR_x = TR_rel_x + tr_col_start - 1;
TR_y = TR_rel_y; % Since tr_row_start is 1, the offset is minimal/zero
width_pix = abs(TR_x - TL_x);

disp('--- TR Pattern ---');
disp(['TR_x (Absolute): ', num2str(TR_x)]);
disp(['TR_y (Absolute): ', num2str(TR_y)]);
disp(['Width (Pixels): ', num2str(width_pix)]);

M = double(width_pix) / module_size;
disp(['M X M: ', num2str(M), ' X ', num2str(M)]);

[fi] = findFI(module_size, bw, TL_x, TL_y);

%disp(fi);
decoded = zeros(15, 1); 
for i = 1:15
    if (mask(i) && ~fi(i)) || (~mask(i) && fi(i))
        decoded(i) = 1; 
    end
end

disp(decoded);

corrected = decryptBCH(decoded);

disp(["Corrected DATA: ", corrected]);

mask = corrected(3:5);

BR_x = TR_x;
BR_y = TR_y +width_pix+3*module_size;


end
