function [labels, status] = CCL(im)
    [ysize, xsize] = size(im);
    label = 0;
    labels = zeros(ysize, xsize);
    status = zeros(ysize, xsize);
    processed = zeros(ysize, xsize) ~= 0;
    queue1 = [];
    queue2 = [];

    for i = 1:xsize
        for j = 1:ysize
            if processed(i, j) 
                if im(i,j) == 1
                    %check its four neighbours (north, south, west, east)
                    north = [];
                    south = [];
                    east = [];
                    west = [];

                    if j + 1 <= ysize
                        north = [i, j + 1];
                    end
                    if j - 1 >= 1
                        south = [i, j - 1];
                    end
                    if i + 1 <= xsize
                        east = [i + 1, j];
                    end
                    if i - 1 >= 1
                        west = [i - 1, j];
                    end

                    for [oy, ox] = [north, south, east, west]
                        if processed(neighbor)
                    end
                end
            end

        end

    end
    
    
end