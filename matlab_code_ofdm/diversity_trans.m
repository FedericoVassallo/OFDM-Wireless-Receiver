% diversity_trans.m
% Wireless Receivers: Diversity Audio Transmission Framework 

clear all;
close all;
clc;

% DIVERSITY CONFIGURATION
% Set these specific microphone IDs
mic1_id = 1; % e.g., Laptop Internal Mic
mic2_id = 2; % e.g., USB Microphone


% Configuration Values
conf.audiosystem = 'audio'; % Diversity only makes sense with real audio
conf.emulator_snr = 100;

% General parameters 
conf.nbits   = 512*2*50;  
conf.f_c     = 8000;

% Preamble
conf.sc.f_sym = 1000;  
conf.sc.nsyms = 500;   

% OFDM
conf.ofdm.bandwidth = 2000; 
conf.ofdm.ncarrier  = 512;
conf.ofdm.cplen     = 256;
conf.modulation_order = 2; 
conf.channel_type = 'Comb'; 
conf.training_method = 'Comb';
conf.comb_insertion_rate = 4; 

% Fix audio settings 
conf.f_s = 48000; 
conf.bitsps = 16;   

% Calculations
conf.ofdm.spacing  = conf.ofdm.bandwidth/conf.ofdm.ncarrier;
conf.sc.os_factor  = conf.f_s/conf.sc.f_sym;
conf.ofdm.os_factor = conf.f_s/(conf.ofdm.ncarrier*conf.ofdm.spacing);

% Pregenerate useful data
conf.sc.txpulse_length = 20*conf.sc.os_factor;
conf.sc.txpulse    = rrc(conf.sc.os_factor,0.22,conf.sc.txpulse_length);

disp('Start OFDM Diversity Transmission')

% Generate random data
txbits = randi([0 1],conf.nbits,1);
conf.txbits = txbits; % Save for BER calculation

% Transmit Function
[txsignal, conf] = txofdm(txbits,conf);

% Prepare Signal
rawtxsignal = [ zeros(conf.f_s,1) ; txsignal ; zeros(conf.f_s,1) ];
rawtxsignal = [  rawtxsignal  zeros(size(rawtxsignal)) ];

%DIVERSITY RECORDING
disp('Setting up Recorders...');
try
    recobj1 = audiorecorder(conf.f_s, conf.bitsps, 1, mic1_id);
    recobj2 = audiorecorder(conf.f_s, conf.bitsps, 1, mic2_id);
catch e
    disp('Error initializing recorders. Check Device IDs with audiodevinfo.');
    rethrow(e);
end

disp('Press any key to start transmission...');
pause;

disp('Recording on both channels...');
record(recobj1);
record(recobj2);
pause(0.5);

disp('Playing Signal...');
playobj = audioplayer(rawtxsignal, conf.f_s, conf.bitsps);
playblocking(playobj);
pause(1); 

stop(recobj1);
stop(recobj2);
disp('Recording ended.');

% Retrieve Data
rawrx1 = getaudiodata(recobj1, 'int16');
rawrx2 = getaudiodata(recobj2, 'int16');

% Normalize to doubles
rxsignal1 = double(rawrx1) / double(intmax('int16'));
rxsignal2 = double(rawrx2) / double(intmax('int16'));


% Call Diversity Receiver
% We pass both signals to the new receiver function
[rxbits, conf] = rxofdm_diversity(rxsignal1, rxsignal2, conf);

res.biterrors = sum(rxbits ~= txbits);
ber = res.biterrors/length(rxbits);
fprintf('Diversity BER: %.4f\n', ber);