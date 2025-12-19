function [rxbits, conf] = rxofdm_diversity(rxsignal1, rxsignal2, conf)
% RXOFDM_DIVERSITY
%   Processes two received signals and combines them.

%% Independent Pre-processing
% We must process both signals independently up to the FFT stage

% PROCESS SIGNAL 1
[rx_matrix_freq1, conf] = preprocess_chain(rxsignal1, conf, 'RX 1');

% PROCESS SIGNAL 2 
[rx_matrix_freq2, conf] = preprocess_chain(rxsignal2, conf, 'RX 2');

%% Joint Channel Tracking and Combining (MRC)
rx_matrix_eq = channel_tracking_diversity(rx_matrix_freq1, rx_matrix_freq2, conf);

%% Remove Training & Serialize (Standard)
if strcmp(conf.training_method, 'Comb')
    rx_data_matrix = remove_comb(rx_matrix_eq, conf);
elseif strcmp(conf.training_method, 'Block')
    rx_data_matrix = rx_matrix_eq(:, 2:end);
end

rx_syms_serial = rx_data_matrix(:);

% Truncate to expected length
if strcmp(conf.training_method, 'Comb')
    n_data_symbs = conf.nbits / 2;
    if length(rx_syms_serial) > n_data_symbs
        rx_syms_serial = rx_syms_serial(1:n_data_symbs);
    end
end

% Normalize
rx_syms_norm = rx_syms_serial / mean(abs(rx_syms_serial));

% Demap
rxbits = demapper(rx_syms_norm);

% Constellation Plot
figure;
plot(real(rx_syms_norm), imag(rx_syms_norm), '.'); hold on;
plot(real(qammod(0:3,4,'UnitAveragePower',true)), imag(qammod(0:3,4,'UnitAveragePower',true)), 'rx', 'LineWidth',2);
title('Diversity Combined Constellation'); grid on; axis square;
end

function [OFDM_rx_matrix_freq, conf] = preprocess_chain(rxsignal, conf, label)
    % Sync, Downconv, Resample, FFT for one branch
    
    fprintf('Processing %s...\n', label);
    
    % Downconversion
    time = 0:(1/conf.f_s) : size(rxsignal,1)/conf.f_s - (1/conf.f_s);
    rx_down = (rxsignal .* exp(-1i*2*pi*conf.f_c.*time.'));
    
    % Lowpass
    f_cutoff = conf.ofdm.bandwidth + 0.05 * conf.ofdm.bandwidth;
    rx_filt = ofdmlowpass(rx_down, conf, f_cutoff);
    
    % Synchronization (Independent for each mic)
    start_idx = frame_sync(rx_filt, conf);
    start_idx = max(1, start_idx - 20); % Safety margin
    
    % Extract
    len = conf.OFDM_resampled_length;
    if start_idx + len - 1 > length(rx_filt)
        warning('Signal %s too short/cut off.', label);
        rx_cut = [rx_filt(start_idx:end); zeros(len - (length(rx_filt)-start_idx+1), 1)];
    else
        rx_cut = rx_filt(start_idx : start_idx + len - 1);
    end
    
    % Resample
    rx_base = ofdm_rx_resampling(rx_cut, conf);
    
    % Remove CP & Reshape
    nb_symbs = conf.number_OFDM_symb;
    sym_len = conf.ofdm.ncarrier + conf.ofdm.cplen;
    tot_len = sym_len * nb_symbs;
    
    % Length check
    if length(rx_base) < tot_len
        rx_base = [rx_base; zeros(tot_len - length(rx_base), 1)];
    elseif length(rx_base) > tot_len
        rx_base = rx_base(1:tot_len);
    end
    
    mat_cp = reshape(rx_base, [sym_len, nb_symbs]);
    mat_no_cp = mat_cp(conf.ofdm.cplen + 1 : end, :);
    
    % FFT
    OFDM_rx_matrix_freq = fft(mat_no_cp);
end