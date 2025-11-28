function [labels, status] = CCL(im)
    [ysize, xsize] = size(im);
    label = 0;
    labels = zeros(ysize, xsize);
    status = zeros(ysize, xsize) ~= 0;
    processed = zeros(ysize, xsize) ~= 0;
    queue1 = [];
    queue2 = [];
    dx = [0 0 1 -1]; % north, south, east, west
    dy = [1 -1 0 0];

    for x = 1:xsize
        for y = 1:ysize
            if ~status(y, x)
                if im(y, x)
                    for k = 1:4
                        ny = y + dy(k);
                        nx = x + dx(k);
                        if nx < 1 || nx > xsize || ny < 1 || ny > ysize
                            continue;
                        end
                        
                        if status(ny, nx) == 1
                            continue;
                        end
                        
                        if im(y, x)
                            queue1 = [queue1, ny, nx];
                        else
                            status(ny, nx) = true;
                        end
                        labels(y, x) = label;
                        status(y, x) = true;
                        disp([y, x]);
                        
                        while size(queue1, 2) > 0
                            for p = 1:size(queue1, 2) + 1:2
                                px = queue1(p);
                                py = queue1(p + 1);
                                for l = 1:4
                                    mx = px + dx(l);
                                    my = py + dy(l);
                                    if mx < 1 || mx > xsize || my < 1 || my > ysize
                                        continue;
                                    end
                                    
                                    disp([my mx]);
                                    if status(my, mx) == 1
                                        continue;
                                    end

                                    if im(my, mx)
                                        queue2 = [queue2, my, mx];
                                    else
                                        status(my, mx) = true;
                                        disp([my mx]);
                                    end

                                    labels(my, mx) = label;
                                    status(my, mx) = true;
                                    queue1 = queue1(3:end);
                                    queue1 = [queue1, queue2];
                                end
                            end
                        end
                        label = label + 1;
                    end
                end
                status(y, x) = true;
            end
        end
    end
end
