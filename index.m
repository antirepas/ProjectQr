video = videoinput("winvideo", 2);
start(video);
im = getsnapshot(video);
imshow(im);
black = rgb2gray(im) > 80;
imshow(black);
