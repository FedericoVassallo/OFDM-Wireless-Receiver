% % % % % % % % % % % % %
% Wireless Receivers: algorithms and architectures
% Throughput Analysis Framework
%
% This script analyzes how different Bandwidth and CP configurations 
% affect throughput and BER while maintaining QPSK modulation.

clear all;
close all;
clc;

% % % % % % % % % % % % % % % % % % % % % % % % % % %
% 1. DEFINE SCENARIOS
% % % % % % % % % % % % % % % % % % % % % % % % % % %

% We test combinations of Bandwidth (B) and Cyclic Prefix (CP).
% QPSK is fixed (2 bits/symbol) as per instruction.

% Scenario 1: Default (Reference)
scenarios(1) = struct('name', 'Baseline (2k, CP256)', 'bw', 2000, 'cp', 256);

% Scenario 2: Reduced Overhead
scenarios(2) = struct('name', 'Low Overhead (2k, CP128)', 'bw', 2000, 'cp', 128);

% Scenario 3: Double Bandwidth
scenarios(3) = struct('name', 'High Speed (4k, CP256)', 'bw', 4000, 'cp', 256);

% Scenario 4: Max Throughput (High BW + Low CP)
scenarios(4) = struct('name', 'Max T-put (4k, CP128)', 'bw', 4000, 'cp', 128);

% Scenario 5: Experimental (Very High BW)
scenarios(5) = struct('name', 'Ultra (6k, CP128)', 'bw', 6000, 'cp', 128);

% % % % % % % % % % % % % % % % % % % % % % % % % % %
% 2. GLOBAL CONFIGURATION (Base)
% % % % % % % % % % % % % % % % % % % % % % % % % % %

conf.audiosystem = 'emulator'; 
conf.emulator_idx = 1;       % Channel 2 (Time varying)
conf.emulator_snr = 40;      % High SNR to test theoretical limits
conf.f_c     = 8000;
conf.f_s     = 48000;
conf.bitsps  = 16;

% Preamble parameters
conf.sc.f_sym = 1000;
conf.sc.nsyms = 500;
conf.sc.os_factor  = conf.f_s/conf.sc.f_sym;
conf.sc.txpulse_length = 20*conf.sc.os_factor;
conf.sc.txpulse    = rrc(conf.sc.os_factor, 0.22, conf.sc.txpulse_length);

% Base OFDM parameters
conf.ofdm.ncarrier  = 512;
conf.channel_type = 'Block'; 
conf.training_method = 'Block'; 

fprintf('------------------------------------------------------------------------------------\n');
fprintf('| %-25s | %-12s | %-10s | %-10s |\n', 'Scenario', 'Throughput', 'BER (%)', 'Status');
fprintf('------------------------------------------------------------------------------------\n');

% % % % % % % % % % % % % % % % % % % % % % % % % % %
% 3. ANALYSIS LOOP
% % % % % % % % % % % % % % % % % % % % % % % % % % %

for i = 1:length(scenarios)
    s = scenarios(i);
    
    % --- Update Config for this Scenario ---
    conf.ofdm.bandwidth = s.bw;
    conf.ofdm.cplen     = s.cp;
    
    % Recalculate dependent parameters (Critical!)
    conf.ofdm.spacing  = conf.ofdm.bandwidth / conf.ofdm.ncarrier;
    conf.ofdm.os_factor = conf.f_s / (conf.ofdm.ncarrier * conf.ofdm.spacing);
    
    % Generate Data
    % We want enough bits for approx 50 OFDM symbols to get a stable BER
    bits_per_symbol = conf.ofdm.ncarrier * 2; % QPSK fixed
    conf.nbits = 50 * bits_per_symbol;
    
    txbits = randi([0 1], conf.nbits, 1);
    
    % --- TRANSMIT ---
    [txsignal, conf] = txofdm(txbits, conf);
    
    % --- CHANNEL (Emulator) ---
    rawtxsignal = [zeros(conf.f_s/4,1); txsignal; zeros(conf.f_s/4,1)];
    rxsignal = channel_emulator(rawtxsignal, conf);
    
    % --- RECEIVE ---
    try
        [rxbits, conf] = rxofdm(rxsignal, conf);
        
        % Calculate BER
        % Truncate to the shorter length to compare
        L = min(length(txbits), length(rxbits));
        biterrors = sum(rxbits(1:L) ~= txbits(1:L));
        ber = biterrors / L;
        
    catch
        ber = 1.0; % Fail safe
    end
    
    % --- THROUGHPUT CALCULATION ---
    % Formula: R = (Bits per OFDM Symbol) / (Time per OFDM Symbol)
    % Bits per Symbol = N_carriers * 2 (QPSK)
    % Time per Symbol = T_useful + T_cp = (N + N_cp) / Bandwidth
    
    bits_per_ofdm_sym = conf.ofdm.ncarrier * 2;
    duration_per_ofdm_sym = (conf.ofdm.ncarrier + conf.ofdm.cplen) / conf.ofdm.bandwidth;
    
    throughput_val = bits_per_ofdm_sym / duration_per_ofdm_sym;
    
    % Evaluation
    if ber < 0.10
        status = 'PASS';
    else
        status = 'FAIL';
    end
    
    fprintf('| %-25s | %6.0f bps   | %9.2f%% | %-10s |\n', ...
        s.name, throughput_val, ber*100, status);
    
end

fprintf('------------------------------------------------------------------------------------\n');