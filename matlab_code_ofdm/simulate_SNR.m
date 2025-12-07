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
conf.audiosystem = 'emulator'; 

%Emulator configuration
conf.emulator_idx = 1; % 1 to 5 yields different channels
conf.emulator_snr = 100;

% General parameters 
conf.nbits   = 512*2*50;  % number of bits 
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


% Fix audio settings 
conf.f_s = 48000; % audio sampling rate, fixed by audiocard
conf.bitsps = 16;   % bits per audio sample

% Calculations
conf.ofdm.spacing  = conf.ofdm.bandwidth/conf.ofdm.ncarrier;
conf.sc.os_factor  = conf.f_s/conf.sc.f_sym;
conf.ofdm.os_factor = conf.f_s/(conf.ofdm.ncarrier*conf.ofdm.spacing);

% Pre-generate Tx pulse
conf.sc.txpulse_length = 20*conf.sc.os_factor;
conf.sc.txpulse = rrc(conf.sc.os_factor, 0.22, conf.sc.txpulse_length);

% --- 2. SNR Loop Setup ---
snr_range = -8:1:2;        % Test SNR from 0dB to 30dB in steps of 2
ber_results = zeros(size(snr_range));

disp('Starting SNR Simulation Loop...');

for i = 1:length(snr_range)
    % A. Set the current SNR
    conf.emulator_snr = snr_range(i); 
    
    % B. Generate Random Bits
    txbits = randi([0 1], conf.nbits, 1);
    
    % C. Transmit (Your implemented txofdm)
    [txsignal, conf] = txofdm(txbits, conf);
    
    % Prepare signal for emulator (stereo padding)
    rawtxsignal = [zeros(conf.f_s,1); txsignal; zeros(conf.f_s,1)];
    rawtxsignal = [rawtxsignal zeros(size(rawtxsignal))];
    
    % D. Channel Emulator
    % Passes the signal through the emulator with the current SNR
    rxsignal = channel_emulator(rawtxsignal(:,1), conf);
    
    % E. Receive (Your implemented rxofdm)
    [rxbits, ~] = rxofdm(rxsignal, conf);
    
    % F. Calculate BER
    % Compare received bits to transmitted bits
    biterrors = sum(rxbits ~= txbits);
    ber = biterrors / length(txbits);
    
    % Store result
    ber_results(i) = ber;
    
    fprintf('SNR: %2d dB | BER: %.4f\n', snr_range(i), ber);
end

% --- 3. Plotting the Results ---
figure('Name', 'BER vs SNR');
semilogy(snr_range, ber_results, '-bo', 'LineWidth', 2, 'MarkerSize', 6);
hold on;

% Add the 1% Threshold Line (Required to answer the question) 
yline(0.01, 'r--', 'Target BER (1%)', 'LineWidth', 2);

grid on;
xlabel('SNR (dB)');
ylabel('Bit Error Rate (BER)');
title('OFDM BER on Channel 1');
legend('Measured BER', '1% Threshold');