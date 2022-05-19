function I = freqclean(I)

func = str2func(class(I));
freq = fftshift(fft2(I));

line_x = 1:16:size(I,2);
line_x(line_x==1+size(I,2)/2) = [];
line_half_height = 2;
freq = fftshift(fft2(I));
for k = line_x
    row_min = size(freq,1)/2+1-line_half_height;
    row_max = size(freq,1)/2+1+line_half_height;
    freq(row_min:row_max,k) = 0;
end
freq(2:2:size(freq,1),size(freq,2)/2+1) = 0;
%freq(size(freq,1)/2+1,2:2:end) = 0;

imagesc(log(1+abs(freq)))
axis image

I = func(ifft2(fftshift(freq)));
