% Wireless Receivers: algorithms and architectures
% Image Transmission Script (imagetrans.m)
clear all;
close all;
clc;

%% 1. Configuration
% Transmission Options
conf.audiosystem = 'audio'; 
% Emulator settings
conf.emulator_idx = 1; 
conf.emulator_snr = 100; % High SNR for clear image initially

% OFDM Configuration
conf.f_c     = 8000;
conf.sc.f_sym = 1000;
conf.sc.nsyms = 500;   
conf.ofdm.bandwidth = 2000; 
conf.ofdm.ncarrier  = 512;
conf.ofdm.cplen     = 256;
conf.modulation_order = 2; % QPSK (2 bits per symbol)

% Channel Estimation & Training Configuration
conf.channel_type = 'Comb';       
conf.training_method = 'Comb';    
conf.comb_insertion_rate = 4;     

% Audio Hardware Settings
conf.f_s = 48000; 
conf.bitsps = 16;   

% Calculated Parameters
conf.ofdm.spacing  = conf.ofdm.bandwidth/conf.ofdm.ncarrier;
conf.sc.os_factor  = conf.f_s/conf.sc.f_sym;
conf.ofdm.os_factor = conf.f_s/(conf.ofdm.ncarrier*conf.ofdm.spacing);

% Pulse shaping
conf.sc.txpulse_length = 20*conf.sc.os_factor;
conf.sc.txpulse    = rrc(conf.sc.os_factor,0.22,conf.sc.txpulse_length);

%% 2. Image Loading and Encoding
fprintf('--- Starting Image Transmission ---\n');

% Load Image
image_filename = 'image.jpg'; % Ensure this file exists
try
    raw_img = imread(image_filename);
catch
    warning('Image file not found. Generating a 50x50 Checkerboard image.');
    raw_img = uint8(checkerboard(10) * 255);
end

% Convert to Grayscale if necessary
if size(raw_img, 3) == 3
    raw_img = rgb2gray(raw_img);
end

% --- CHANGE 1: INCREASE QUALITY ---
% A 128x128 image is much sharper than 50x50. 
% Note: This increases transmission time but improves visual quality significantly.
target_size = [128 128]; 
img = imresize(raw_img, target_size);
img_size = size(img); 

% Display Original Image
figure('Name', 'Image Comparison');
subplot(1,2,1);
imshow(img);
title(sprintf('Transmitted (%dx%d)', img_size(1), img_size(2)));

% Encode Image to Bits
% 1. Flatten image matrix to vector
img_vec = img(:); 
% 2. Convert to bits (8 bits per pixel)
tx_bits_matrix = de2bi(img_vec, 8); 
txbits = tx_bits_matrix';
txbits = txbits(:);

% Update configuration with exact bit count
conf.nbits = length(txbits);
fprintf('Image Size: %dx%d pixels\n', img_size(1), img_size(2));
fprintf('Total Bits: %d\n', conf.nbits);

%% 3. Transmitter (OFDM)
[txsignal, conf] = txofdm(txbits, conf);

%% 4. Channel (Audio or Emulator)
% Prepare raw signal with silence padding

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

%% 5. Receiver (OFDM)
[rxbits_raw, conf] = rxofdm(rxsignal, conf);

%% 6. Image Decoding and BER Calculation
% Truncate received bits to expected length
if length(rxbits_raw) >= conf.nbits
    rxbits = rxbits_raw(1:conf.nbits);
else
    warning('Received fewer bits than expected. Padding with zeros.');
    rxbits = [rxbits_raw; zeros(conf.nbits - length(rxbits_raw), 1)];
end

% Calculate Bit Error Rate
bit_errors = sum(rxbits ~= txbits);
ber = bit_errors / conf.nbits;
fprintf('Transmission Complete.\n');
fprintf('Bit Error Rate (BER): %.4f\n', ber);

% Decode and Display
try
    % Use provided image_decoder
    img_rx = image_decoder(rxbits, img_size);
    
    % --- CHANGE 2: FIX ROTATION ---
    % MATLAB reconstructs column-by-column, but visuals often expect row-by-row.
    % Transposing the result fixes the 90-degree rotation.
    img_rx = img_rx';
    
    % Show result
    figure(findobj('Name', 'Image Comparison')); 
    subplot(1,2,2);
    imshow(img_rx);
    title(sprintf('Received (BER: %.2f%%)', ber*100));
    
catch e
    fprintf('Error decoding image: %s\n', e.message);
    disp('Check if conf.nbits matches image size exactly.');
end