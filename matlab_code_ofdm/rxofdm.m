function [rxbits, conf] = rxofdm(rxsignal,conf)
% Digital Receiver
%
%   [txsignal conf] = tx(txbits,conf) implements a complete causal
%   receiver in digital domain.
%
%   rxsignal    : received signal
%   conf        : configuration structure
%
%   rxbits      : received bits
%
%% Receiver Parameters
txbis = conf.txbits;
%% Downconversion
% Define the time frame
time = 0:(1/conf.f_s) : size(rxsignal,1)/conf.f_s - (1/conf.f_s);
% Perform the downconversion by removing the RF carrier
rxsignal_downconverted = (rxsignal.*exp(-1i*2*pi*conf.f_c.*time.'));
%% Filter the Downconverted RX Signal
% Apply the low pass filter given
f_cutoff = conf.ofdm.bandwidth + 0.05 * conf.ofdm.bandwidth;
rx_signal_filtered = ofdmlowpass(rxsignal_downconverted, conf, f_cutoff);
%% Frame Synchronization
OFDM_start = frame_sync(rx_signal_filtered, conf);
% --- FIX 1: SAFETY MARGIN ---
% Back off by a margin to ensure we are inside the Cyclic Prefix (Early).
% Being 'Early' = Phase Shift (Fixed by Equalizer).
% Being 'Late' = ISI (Destroys Signal).
%{
safety_margin = 20; 
OFDM_start = max(1, OFDM_start - safety_margin);
%}
% ----------------------------
OFDM_signal_len = conf.OFDM_resampled_length;  
OFDM_rx_signal = rx_signal_filtered(OFDM_start: OFDM_start + OFDM_signal_len - 1);
%% Resampling
% 2. Resample from Sound Card rate (fs') to Baseband rate (fs)
rx_baseband = ofdm_rx_resampling(OFDM_rx_signal, conf);
%% Serial-to-Parallel Conversion (Vectorized) & Remove CP
% --- FIX 2: ROBUST RESHAPING ---
nb_symbs = conf.number_OFDM_symb;
sym_len_expected = conf.ofdm.ncarrier + conf.ofdm.cplen;
total_len_expected = sym_len_expected * nb_symbs;
% Force rx_baseband to the exact expected length
if length(rx_baseband) > total_len_expected
    rx_baseband = rx_baseband(1:total_len_expected);
elseif length(rx_baseband) < total_len_expected
    % Pad with zeros if slightly short
    rx_baseband = [rx_baseband; zeros(total_len_expected - length(rx_baseband), 1)];
end
% Reshape into a matrix
rx_matrix_with_cp = reshape(rx_baseband, [sym_len_expected, nb_symbs]);
% Remove the CP by selecting rows from (cplen+1) to the end
OFDM_rx_matrix_time = rx_matrix_with_cp(conf.ofdm.cplen + 1 : end, :);
%% FFT (Vectorized)
OFDM_rx_matrix_freq = fft(OFDM_rx_matrix_time);
%% Channel Equalization
rx_matrix_eq = channel_tracking(OFDM_rx_matrix_freq, conf);
%% Remove Training Symbol & Serialize
% Remove the first column (Training)
rx_data_matrix = rx_matrix_eq(:, 2:end);
% serialize
rx_syms_serial = rx_data_matrix(:);
%% Normalizing
% Normalize energy before demapping
rx_syms_norm = rx_syms_serial / mean(abs(rx_syms_serial));
%% Demapper
rxbits = demapper(rx_syms_norm);

%% Plotting the Constellation (Optional - Final)
figure; 
plot(real(rx_syms_norm), imag(rx_syms_norm), '.'); 
hold on;
ideal_constellation = qammod(0:3, 4, 'UnitAveragePower', true);
plot(real(ideal_constellation), imag(ideal_constellation), 'rx', 'LineWidth', 2);
title('RX Constellation (Final)');
grid on; axis square; 
hold off;

%% Plotting the Constellation (4 Fasi with BER)
figure('Name', 'RX Constellation Evolution'); 
% Ideal constellation for QPSK/4-QAM
ideal_constellation = qammod(0:3, 4, 'UnitAveragePower', true);

% Total received symbols
N = length(rx_syms_norm);

% Define ranges
idx_groups = { ...
    1:min(1024, N), ...          
    1:min(2048, N), ...          
    1:min(4096, N), ...          
    1:min(5120, N), ...            
};

base_titles = {'First 2 OFDM Symbols', 'First 4 OFDM Symbols', ...
               'First 8 OFDM Symbols', 'First 10 OFDM Symbols'};
           
% Parameters for BER calculation (QPSK = 2 bits per symbol)
bits_per_symbol = 2; 

for k = 1:4
    subplot(2, 2, k);
    
    current_idx = idx_groups{k};
    
    if ~isempty(current_idx) && current_idx(1) <= N
        % 1. Plot Symbols
        plot(real(rx_syms_norm(current_idx)), imag(rx_syms_norm(current_idx)), '.', 'MarkerSize', 4);
        hold on;
        plot(real(ideal_constellation), imag(ideal_constellation), 'rx', 'LineWidth', 2, 'MarkerSize', 8);
        
        % 2. Calculate BER for this specific phase
        % Calculate how many bits correspond to the current number of symbols
        num_bits_current = length(current_idx) * bits_per_symbol;
        
        % Ensure we don't exceed the available TX bits (sanity check)
        num_bits_current = min(num_bits_current, length(txbis));
        
        % Extract the subsets
        rx_bits_subset = rxbits(1:num_bits_current);
        tx_bits_subset = txbis(1:num_bits_current);
        
        % Compute Errors
        bit_errors = sum(rx_bits_subset ~= tx_bits_subset);
        ber_val = bit_errors / num_bits_current;
        
        % 3. Update Title with BER
        title({base_titles{k}, sprintf('BER: %.4f', ber_val)});
        
        % Formatting
        grid on; 
        axis square;
        xlabel('In-Phase'); 
        ylabel('Quadrature');
        xlim([-2 2]); 
        ylim([-2 2]);
        hold off;
    else
        text(0.5, 0.5, 'No Data', 'HorizontalAlignment', 'center');
        title(base_titles{k});
        axis off;
    end
end
end