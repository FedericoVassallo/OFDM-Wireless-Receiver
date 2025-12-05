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
% The CP is ~6000 samples at 48kHz. We back off by 50-100 samples to be safe.
safety_margin = 20; 
OFDM_start = max(1, OFDM_start - safety_margin);
% ----------------------------

OFDM_signal_len = conf.OFDM_resampled_length;  
OFDM_rx_signal = rx_signal_filtered(OFDM_start: OFDM_start + OFDM_signal_len - 1);

%% Resampling
% 2. Resample from Sound Card rate (fs') to Baseband rate (fs)
rx_baseband = ofdm_rx_resampling(OFDM_rx_signal, conf);


%% Serial-to-Parallel Conversion (Vectorized) & Remove CP

% --- FIX 2: ROBUST RESHAPING ---
% Calculate expected dimensions strictly
nb_symbs = conf.number_OFDM_symb;
sym_len_expected = conf.ofdm.ncarrier + conf.ofdm.cplen;
total_len_expected = sym_len_expected * nb_symbs;

% Force rx_baseband to the exact expected length
if length(rx_baseband) > total_len_expected
    rx_baseband = rx_baseband(1:total_len_expected);
elseif length(rx_baseband) < total_len_expected
    % Pad with zeros if slightly short (unlikely but safe)
    rx_baseband = [rx_baseband; zeros(total_len_expected - length(rx_baseband), 1)];
end

% Reshape into a matrix
rx_matrix_with_cp = reshape(rx_baseband, [sym_len_expected, nb_symbs]);

% Remove the CP by selecting rows from (cplen+1) to the end
OFDM_rx_matrix_time = rx_matrix_with_cp(conf.ofdm.cplen + 1 : end, :);

%% FFT (Vectorized)
% Apply standard FFT to the matrix. 
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

%% Plotting the Constellation (Optional)
figure; 
plot(real(rx_syms_norm), imag(rx_syms_norm), '.'); 
hold on;
ideal_constellation = qammod(0:3, 4, 'UnitAveragePower', true);
plot(real(ideal_constellation), imag(ideal_constellation), 'rx', 'LineWidth', 2);
title('RX Constellation');
grid on; axis square; 
hold off;

end