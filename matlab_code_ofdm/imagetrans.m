% % % % %
% Wireless Receivers: algorithms and architectures
% Audio Transmission Framework 

clear all;
close all;
clc;

% Configuration Values

% Options for transmission are : 
% emulator: use a channel emulator with 5 different configurations.
% audio: use the loudspeaker and microphone for the data transmission
conf.audiosystem = 'audio'; 

%Emulator configuration
conf.emulator_idx = 4; % 1 to 5 yields different channels
conf.emulator_snr = 100;

% General parameters 
conf.nbits   = 512*2*500;  % number of bits 
conf.f_c     = 8000;

% Preamble
conf.sc.f_sym = 1000;  % symbol rate
conf.sc.nsyms = 500;    %number of preamble symbols

%OFDM
conf.ofdm.bandwidth = 2000; %f_s/bw should be an integer for resampling
conf.ofdm.ncarrier  = 512;
conf.ofdm.cplen     = 256;
conf.modulation_order = 2; % 2 for QPSK
conf.channel_type = 'Block_Viterbi'; % Options: 'Block', 'Block_Viterbi'
conf.training_method = 'Block'; % Options: 'Block', 'Comb'

conf.comb_insertion_rate = 4; % Example: 1 pilot every 4 subcarriers
   
% Fix audio settings 
conf.f_s = 48000; % audio sampling rate, fixed by audiocard
conf.bitsps = 16;   % bits per audio sample

% all calculations that you only have to do once
conf.ofdm.spacing  = conf.ofdm.bandwidth/conf.ofdm.ncarrier;
conf.sc.os_factor  = conf.f_s/conf.sc.f_sym;

if mod(conf.sc.os_factor,1) ~= 0
   disp('WARNING: Sampling rate must be a multiple of the symbol rate for single carrier system'); 
end

conf.ofdm.os_factor = conf.f_s/(conf.ofdm.ncarrier*conf.ofdm.spacing);

% Pregenerate useful data
conf.sc.txpulse_length = 20*conf.sc.os_factor;
conf.sc.txpulse    = rrc(conf.sc.os_factor,0.22,conf.sc.txpulse_length);

fprintf('Start Image Transmission\n');

% Load Image
image_filename = 'image.jpg'; % Ensure this file exists
try
    raw_img = imread(image_filename);
catch
    warning('Image file not found.');
end

% Convert to Grayscale if necessary
if size(raw_img, 3) == 3
    raw_img = rgb2gray(raw_img);
end

% Quality of the image sent
target_size = [128 128]; 
img = imresize(raw_img, target_size);
img_size = size(img); 

% Display Original Image
figure('Name', 'Image Comparison');
subplot(1,2,1);
imshow(img);
title(sprintf('Transmitted (%dx%d)', img_size(1), img_size(2)));

% Encode Image to Bits
% Flatten image matrix to vector
img_vec = img(:); 
% Convert to bits (8 bits per pixel)
tx_bits_matrix = de2bi(img_vec, 8); 
txbits = tx_bits_matrix';
txbits = txbits(:);

% Update configuration with exact bit count
conf.nbits = length(txbits);
fprintf('Image Size: %dx%d pixels\n', img_size(1), img_size(2));
fprintf('Total Bits: %d\n', conf.nbits);

%% Transmission
[txsignal, conf] = txofdm(txbits, conf);

rawtxsignal = [ zeros(conf.f_s,1) ; txsignal ; zeros(conf.f_s,1) ];
rawtxsignal = [  rawtxsignal  zeros(size(rawtxsignal)) ];

% MATLAB audio mode
switch(conf.audiosystem)
    case 'emulator'
        rxsignal = channel_emulator(rawtxsignal(:,1),conf);
    case 'audio'
        % % % % % % % % % % % % %
        % Begin
        % Audio Transmission    
       
        txdur       = length(rawtxsignal)/conf.f_s; % calculate length of transmitted signal
        audiowrite('out.wav',rawtxsignal,conf.f_s)
        disp('MATLAB generic');
        playobj = audioplayer(rawtxsignal,conf.f_s,conf.bitsps);
        recobj  = audiorecorder(conf.f_s,conf.bitsps,1);
        record(recobj);
        pause(2);
        disp('Recording...');
        playblocking(playobj)
        pause(2);
        stop(recobj);
        disp('Recording ended')
        rawrxsignal  = getaudiodata(recobj,'int16');
        rawrxsignal     = double(rawrxsignal(1:end))/double(intmax('int16')) ;
        rxsignal = rawrxsignal; 

end

%% Receiver 
[rxbits_raw, conf] = rxofdm(rxsignal, conf);

%% Image Decoding and BER Calculation
% Truncate received bits to expected length
if length(rxbits_raw) >= conf.nbits
    rxbits = rxbits_raw(1:conf.nbits);
else
    warning('Received fewer bits than expected. Padding with zeros.');
    rxbits = [rxbits_raw; zeros(conf.nbits - length(rxbits_raw), 1)];
end

res.biterrors    = sum(rxbits ~= txbits);
ber = res.biterrors/length(rxbits)

% Decode and Display
% Use image_decoder file
img_rx = image_decoder(rxbits, img_size);

%rotation of the image
img_rx = img_rx';

% Show received image 
figure(findobj('Name', 'Image Comparison')); 
subplot(1,2,2);
imshow(img_rx);
title(sprintf('Received (BER: %.2f%%)', ber*100));


