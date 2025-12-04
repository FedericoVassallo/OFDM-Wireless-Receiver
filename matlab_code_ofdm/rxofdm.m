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

%% Transmission Parameters


%% Downconversion

% Define the time frame
time = 0:(1/conf.f_s) : size(rxsignal,1)/conf.f_s - (1/conf.f_s);

% Perform the downconversion by removing the RF carrier
rxsignal_downconverted = (rxsignal.*exp(-1i*2*pi*conf.f_c.*time.'));
% Keep in mind that downconversion is done once for the entire signal

%% Filter the Downconverted RX Signal

% Apply the low pass filter given
f_cutoff = conf.ofdm.bandwidth + 0.05 * conf.ofdm.bandwidth;      % Define the filter cutoff as 5% above the baseband BW
rx_signal_filtered = ofdmlowpass(rxsignal_downconverted, conf, f_cutoff);

%% Resampling
% 2. Resample from Sound Card rate (fs') to Baseband rate (fs)
% "ofdm_rx_resample.m: Resamples ... from fs' to fs" 
rx_baseband = ofdm_rx_resampling(rx_signal_filtered, conf);

%% Frame Synchronization
OFDM_start = frame_sync(rx_baseband, conf);
OFDM_signal_len = (conf.number_OFDM_symb) * (conf.OFDM_resampled_length + conf.ofdm.cplen);  
OFDM_rx_signal = rx_baseband(OFDM_start: OFDM_start + OFDM_signal_len - 1);

%% 1. Remove CP & Serial-to-Parallel Conversion (Vectorized)
% Calculate total length of a symbol including CP
sym_len_tot = conf.OFDM_resampled_length + conf.ofdm.cplen;

% Reshape into a matrix: [rows=samples_per_symb, cols=number_of_symbols]
% This organizes the signal so each column is one OFDM symbol with CP
rx_matrix_with_cp = reshape(OFDM_rx_signal, [sym_len_tot, conf.number_OFDM_symb]);

% Remove the CP by selecting rows from (cplen+1) to the end
% This variable 'OFDM_rx_matrix' is now your parallel data ready for FFT
OFDM_rx_matrix_time = rx_matrix_with_cp(conf.cplen + 1 : end, :);

%% FFT (Vectorized)
% Apply standard FFT to the matrix. 
% MATLAB's fft() operates on columns by default, so no loop is needed.
OFDM_rx_matrix_freq = fft(OFDM_rx_matrix_time);

%% Channel Equalization

rx_matrix_eq = channel_equalize_f(OFDM_rx_matrix_freq, conf);

%% Remove Training Symbol & Serialize
% Remove the first column (Training)
rx_data_matrix = rx_matrix_eq(:, 2:end);

% serialize
rx_syms_serial = rx_data_matrix(:);

%% Normalizing
% Normalize energy before demapping
rx_syms_norm = rx_syms_serial / mean(abs(rx_syms_serial));

%% Demapper

%rxbits = zeros(conf.nbits,1);

rxbits = demapper(rx_syms_norm);

%% Plotting the Constellation
% Visualize the Received Symbols vs the Ideal Constellation
% (Place this at the end of rxofdm.m)

figure; 
% 1. Plot the Received Equalized Symbols (Blue dots)
plot(real(OFDM_rx_vector_norm), imag(OFDM_rx_vector_norm), '.'); 
hold on;

% 2. Plot the Ideal QPSK Constellation (Red crosses)
% We generate the 4 ideal QPSK points
ideal_constellation = qammod(0:3, 4, 'UnitAveragePower', true);
plot(real(ideal_constellation), imag(ideal_constellation), 'rx', 'LineWidth', 2, 'MarkerSize', 10);

% Formatting
title('RX Constellation');
xlabel('In-Phase');
ylabel('Quadrature');
grid on; 
axis square; 
legend('Received Symbols', 'Ideal Constellation');
hold off;

end

