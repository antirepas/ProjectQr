function [err] = QR(im)

err = 0;
gray = rgb2gray(im);
gray = medfilt2(gray, [3 3]);
bw = imbinarize(gray);
imshow(bw);
impixelinfo;
CONST_MASK = [1,0,1,0,1,0,0,0,0,0,1,0,0,1,0];

qr_info = detectQRCode(bw);
rot = imrotate(bw, qr_info.rotation_angle);

imshow(rot);
impixelinfo;
qr_info = detectQRCode(rot);

fprintf('Found QR Code:\n');
fprintf('  Version: %d\n', qr_info.version);
fprintf('  Dimensions: %dx%d modules\n', qr_info.dimensions, qr_info.dimensions);
fprintf('  Rotation: %.1f degrees\n', qr_info.rotation_angle);
fprintf('  Module size: %.2f pixels\n', ceil(min(qr_info.finder_patterns(:,3))));

disp(qr_info.finder_patterns);

x_coords = qr_info.finder_patterns(:, 1);
y_coords = qr_info.finder_patterns(:, 2);

sum_coords = x_coords + y_coords;

[~, tl_index] = min(sum_coords);

tl_x = qr_info.finder_patterns(tl_index, 1);
tl_y = qr_info.finder_patterns(tl_index, 2);

disp([tl_x, tl_y]);
module_size = ceil(min(qr_info.finder_patterns(:,3)));
version = qr_info.version;

[fi] = findFI(module_size, bw, tl_x, tl_y);

disp(fi);

decoded = xor(fi, CONST_MASK);
decoded = decoded(:, 1);

disp("DECODED DATA: ");
disp(decoded);

corrected = decryptBCH(decoded);

disp(corrected);

ECbits = corrected(1:2);

if ~ECbits(1) && ~ECbits(2)
    EC = 'L';
elseif ~ECbits(1) && ECbits(2)
    EC = 'M';
elseif ECbits(1) && ~ECbits(2)
    EC = 'Q';
elseif ECbits(1) && ECbits(2)
    EC = 'H';
end


disp(["Error correction level: ", EC]);

QRmask = corrected(3:5);

maxX = round(max(qr_info.finder_patterns(:, 1)));
maxY = round(max(qr_info.finder_patterns(:, 2)));

module = round(module_size);

x = round(maxX + 1.5*module);
y = round(maxY + 3*module);



%if false
boxes = zeros(qr_info.dimensions, qr_info.dimensions);
boxes(:) = ' ';
for l = 1:qr_info.dimensions
    for k = 1:qr_info.dimensions
        if rot(y - (l-1)*module, x - (k-1)*module)
            boxes(l, k) = '█';
        end
    end
end

for k = qr_info.dimensions:-1:1
    for l = qr_info.dimensions:-1:1
        fprintf("%c", boxes(l, k));
    end
    fprintf("\n");
end

disp("Bottom right corner: ");
disp([x, y]);

left_edge_x = round(x - qr_info.dimensions * module_size);
top_edge_y = round(y - qr_info.dimensions * module_size);



%get the mask formula by QRmask
maskFunc = findMask(QRmask);
%find the encoding
[goUp, goDown, goLeftUp, goLeftDown] = getMovement();

encbits = goUp(~bw, x, y, 4, module, maskFunc, left_edge_x, top_edge_y);
y = y-2*module - module;

disp(encbits);

if ~encbits(1) && ~encbits(2) && ~encbits(3) && ~encbits(4)
    maskType = "numeric";
elseif ~encbits(1) && ~encbits(2) && encbits(3) && ~encbits(4)
    maskType = "alphanumeric";
elseif ~encbits(1) && encbits(2) && ~encbits(3) && ~encbits(4)
    maskType = "byte";
elseif encbits(1) && ~encbits(2) && ~encbits(3) && ~encbits(4)
    maskType = "kanji";
else
    err = 1;
    return;
end



if maskType == "numeric"
    if version <=9
        lengthlen = 10;
    elseif version <= 26
        lengthlen = 12;
    elseif version <= 40
        lengthlen = 14;
    end
elseif maskType == "alphanumeric"
    if version <=9
        lengthlen = 9;
    elseif version <= 26
        lengthlen = 11;
    elseif version <= 40
        lengthlen = 13;
    end
elseif maskType == "byte"
    if version <=9
        lengthlen = 8;
    elseif version <= 26
        lengthlen = 16;
    elseif version <= 40
        lengthlen = 16;
    end
    bitsPerChar=8;
elseif maskType == "kanji"
    if version <=9
        lengthlen = 8;
    elseif version <= 26
        lengthlen = 10;
    elseif version <= 40
        lengthlen = 12;
    end
    bitsPerChar=13;
end

disp(["ENC DATA: ", maskType, lengthlen, version]);


lenBits = goUp(~bw, x, y, lengthlen, module, maskFunc, left_edge_x, top_edge_y);
disp(lenBits);
length = bit2int(lenBits',lengthlen);
disp(["The length of the message will be: ", length, " characters long"]);


if false
    %find the rest of the data
    %unmask the rest of the data
    allBits  = [];
    
    %go up 2 to get the data
    data = goUp(bw, x, y, bitsPerChar, module, maskFunc, left_edge_x, top_edge_y);
    y = y-(bitsPerChar/2)*module - module;
    allBits = [allBits data];
    
    
    data = goUp(bw, x, y, bitsPerChar, module, maskFunc, left_edge_x, top_edge_y);
    y = y-(bitsPerChar/2)*module - module;
    allBits = [allBits data];
    
    
    %go left
    data = goLeftUp(bw, x, y, bitsPerChar, module, maskFunc, left_edge_x, top_edge_y);
    x = x-(bitsPerChar/2)*module;
    allBits = [allBits data];
    
    
    %go down
    
    data = goDown(bw, x, y, bitsPerChar, module, maskFunc, left_edge_x, top_edge_y);
    y = y + (bitsPerChar/2)*module + module;
    allBits = [allBits data];
    
    data = goDown(bw, x, y, bitsPerChar, module, maskFunc, left_edge_x, top_edge_y);
    y = y + (bitsPerChar/2)*module + module;
    allBits = [allBits data];
    
    data = goDown(bw, x, y, bitsPerChar, module, maskFunc, left_edge_x, top_edge_y);
    y = y + (bitsPerChar/2)*module + module;
    allBits = [allBits data];
    
    data = goLeftDown(bw, x, y, bitsPerChar, module, maskFunc, left_edge_x, top_edge_y);
    x = x - (bitsPerChar/2)*module + module;
    allBits = [allBits data];
    
    data = goUp(bw, x, y, bitsPerChar/2, module, maskFunc, left_edge_x, top_edge_y);
    y = y + (bitsPerChar/4)*module + module;
    allBits = [allBits data];
    
    %skip the weird square
    y = y + 6 *module;
    
    data = goUp(bw, x, y, bitsPerChar/2, module, maskFunc, left_edge_x, top_edge_y);
    y = y -(bitsPerChar/4)*module - module;
    allBits = [allBits data];
    
    data = goUp(bw, x, y, bitsPerChar, module, maskFunc, left_edge_x, top_edge_y);
    y = y-(bitsPerChar/2)*module - module;
    allBits = [allBits data];
    
    %get the last 2 squares and then go left by 3 (if bitsPerChar is 8)
    data = goUp(bw, x, y, bitsPerChar/4, module, maskFunc, left_edge_x, top_edge_y);
    x = x - (bitsPerChar/4) * module - module;
    allBits = [allBits data];
    
    data = goDown(bw, x, y, bitsPerChar, module, maskFunc, left_edge_x, top_edge_y);
    y = y + (bitsPerChar/2)*module + module;
    allBits = [allBits data];
    
    data = goDown(bw, x, y, bitsPerChar, module, maskFunc, left_edge_x, top_edge_y);
    y = y + (bitsPerChar/2)*module + module;
    allBits = [allBits data];
    
    y = y + 6 * module;
    
    data = goDown(bw, x, y, bitsPerChar, module, maskFunc, left_edge_x, top_edge_y);
    y = y + (bitsPerChar/2)*module + module;
    allBits = [allBits data];
    
    x = x + 2*module;
    
    data = goUp(bw, x, y, bitsPerChar/2, module, maskFunc, left_edge_x, top_edge_y);
    y = y -(bitsPerChar/4)*module - module;
    allBits = [allBits data];
    
    x = x - module;
    % go up by 1 square at a time for 6 squares
    for i = 1:6
        data = goUp(bw, x, y, 1, module, maskFunc, left_edge_x, top_edge_y);
        y = y - module;
        allBits = [allBits data];
    end
    
    x = x + module;
    data = goUp(bw, x, y, 1, module, maskFunc, left_edge_x, top_edge_y);
    y = y - module;
    allBits = [allBits data];
    
    data = goUp(bw, x, y, 1, module, maskFunc, left_edge_x, top_edge_y);
    y = y - module;
    allBits = [allBits data];
    
    disp(allBits);
    
    disp("The characters so far: ")

end

end



