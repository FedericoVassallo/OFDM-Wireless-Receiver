% % % % % % % % % % % % %
% Wireless Receivers: algorithms and architectures
% Throughput Analysis: LUDICROUS MODE
%
% Objectives:
% 1. Shift carrier to 12kHz to maximize available spectrum.
% 2. Push Bandwidth to 16kHz (System Hardware Limit).
% 3. Remove Cyclic Prefix entirely to find the "Breaking Point".

clear all;
close all;
clc;

% % % % % % % % % % % % % % % % % % % % % % % % % % %
% 1. DEFINE EXTREME SCENARIOS
% % % % % % % % % % % % % % % % % % % % % % % % % % %

% Scenario 1: The "Safe" Maximum
% fc=12k, BW=16k. Signal spans 4k-20k.
scenarios(1) = struct('name', 'Ultra (16k, CP128)', 'fc', 12000, 'bw', 16000, 'cp', 128);

% Scenario 2: Aggressive Overhead Reduction
% Reducing CP to ~2ms.
scenarios(2) = struct('name', 'Hyper (16k, CP32)',  'fc', 12000, 'bw', 16000, 'cp', 32);

% Scenario 3: Theoretical Maximum (Zero Protection)
% CP=0. If this works, your channel is perfect (no echoes).
% Throughput = 32,000 bps (QPSK).
scenarios(3) = struct('name', 'Ludicrous (16k, CP0)', 'fc', 12000, 'bw', 16000, 'cp', 0);

% % % % % % % % % % % % % % % % % % % % % % % % % % %
% 2. GLOBAL CONFIGURATION
% % % % % % % % % % % % % % % % % % % % % % % % % % %

conf.audiosystem = 'audio'; 
conf.emulator_idx = 5;       % 1=Static, 5=Severe Multipath (Try 5 to force errors!)
conf.emulator_snr = 40;
conf.f_s     = 48000;
conf.bitsps  = 16;

% Standard Preamble (Must remain robust)
conf.sc.f_sym = 1000;
conf.sc.nsyms = 500;
conf.sc.os_factor  = conf.f_s/conf.sc.f_sym;
conf.sc.txpulse_length = 20*conf.sc.os_factor;
conf.sc.txpulse    = rrc(conf.sc.os_factor, 0.22, conf.sc.txpulse_length);

% OFDM Base
conf.ofdm.ncarrier  = 512;
conf.channel_type = 'Block'; 
conf.training_method = 'Block'; 

fprintf('--------------------------------------------------------------------------------------------\n');
fprintf('| %-20s | %-10s | %-12s | %-10s | %-10s |\n', 'Scenario', 'Bandwidth', 'Throughput', 'BER (%)', 'Status');
fprintf('--------------------------------------------------------------------------------------------\n');

% % % % % % % % % % % % % % % % % % % % % % % % % % %
% 3. ANALYSIS LOOP
% % % % % % % % % % % % % % % % % % % % % % % % % % %

for i = 1:length(scenarios)
    s = scenarios(i);
    
    % --- Apply Dynamic Configuration ---
    conf.f_c            = s.fc;   % Shift Center Frequency
    conf.ofdm.bandwidth = s.bw;   % Maximize Bandwidth
    conf.ofdm.cplen     = s.cp;   % Minimize Overhead
    
    % Recalculate dependent parameters
    conf.ofdm.spacing   = conf.ofdm.bandwidth / conf.ofdm.ncarrier;
    conf.ofdm.os_factor = conf.f_s / (conf.ofdm.ncarrier * conf.ofdm.spacing);
    
    % Data Generation (Approx 100 symbols for statistical relevance)
    bits_per_symbol = conf.ofdm.ncarrier * 2; % QPSK
    conf.nbits = 100 * bits_per_symbol;
    txbits = randi([0 1], conf.nbits, 1);
    
    % --- TRANSMIT ---
    [txsignal, conf] = txofdm(txbits, conf);
    
    % --- CHANNEL ---
    rawtxsignal = [ zeros(conf.f_s,1) ; txsignal ; zeros(conf.f_s,1) ];
    rawtxsignal = [ rawtxsignal zeros(size(rawtxsignal)) ];

    switch(conf.audiosystem)
        case 'emulator'
            rxsignal = channel_emulator(rawtxsignal(:,1), conf);
        case 'audio'
            fprintf('Running: %s...\n', s.name);
            playobj = audioplayer(rawtxsignal, conf.f_s, conf.bitsps);
            recobj  = audiorecorder(conf.f_s, conf.bitsps, 1);
            record(recobj); pause(1); 
            playblocking(playobj); pause(1);
            stop(recobj);
            rxsignal = getaudiodata(recobj, 'int16');
            rxsignal = double(rxsignal)/double(intmax('int16'));
    end
    
    % --- RECEIVE ---
    try
        [rxbits, conf] = rxofdm(rxsignal, conf);
        
        L = min(length(txbits), length(rxbits));
        biterrors = sum(rxbits(1:L) ~= txbits(1:L));
        ber = biterrors / L;
    catch
        ber = 1.0; % Sync failure
    end
    
    % --- METRICS ---
    % Throughput = Data Bits / (T_symbol + T_cp)
    T_total = (conf.ofdm.ncarrier + conf.ofdm.cplen) / conf.ofdm.bandwidth;
    throughput_val = bits_per_symbol / T_total;
    
    % Check Constraints
    if ber < 0.10
        status = 'PASS';
    else
        status = 'FAIL';
    end
    
    fprintf('| %-20s | %5d Hz  | %6.0f bps   | %9.2f%% | %-10s |\n', ...
        s.name, s.bw, throughput_val, ber*100, status);
    
    if strcmp(conf.audiosystem, 'audio')
        pause(1); 
    end
end
fprintf('--------------------------------------------------------------------------------------------\n');