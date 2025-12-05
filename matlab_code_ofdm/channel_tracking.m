function [rx_matrix_equalized] = channel_tracking(rx_matrix, conf)
% CHANNEL_EQUALIZE_F: Channel estimation and equalization
% ... (header comments) ...

%% 1. Initialization
[n_subcarriers, n_cols] = size(rx_matrix);
rx_matrix_equalized = zeros(n_subcarriers, n_cols);

% Get the known training symbol
tx_training = conf.ofdm.training_symbol; 
valid_carriers = abs(tx_training) > 1e-10;

%% 2. Initial Channel Estimation
rx_training = rx_matrix(:, 1);
H_est = zeros(n_subcarriers, 1);
H_est(valid_carriers) = rx_training(valid_carriers) ./ tx_training(valid_carriers);

% Store the initial estimate
rx_matrix_equalized(valid_carriers, 1) = rx_training(valid_carriers) ./ H_est(valid_carriers);

%% 3. Equalization and Phase/Magnitude Tracking Loop
% Set specific alphas
alpha_phase = 0.05;  % Fast enough to catch rotation
alpha_mag   = 0.01;  % SLOWER than phase to avoid tracking noise

for i = 2 : n_cols
    % 1. Equalize with current H (Pre-Equalization for Error Est)
    rx_symbol = rx_matrix(:, i);
    rx_symbol_eq = zeros(n_subcarriers, 1);
    rx_symbol_eq(valid_carriers) = rx_symbol(valid_carriers) ./ H_est(valid_carriers);
    
    % 2. Phase Tracking (Viterbi & Viterbi)
    phase_est = zeros(n_subcarriers, 1);
    phase_est(valid_carriers) = (1/4) * angle( - (rx_symbol_eq(valid_carriers)).^4 );
    
    % Update Phase
    H_est = H_est .* exp(1i * 2 * alpha_phase * phase_est);
    
    % 3. Magnitude Tracking (Gain Control)
    % Error > 0 means Rx is too big -> H needs to increase
    mag_error = abs(rx_symbol_eq) - 1; 
    
    % Update Magnitude
    H_est(valid_carriers) = H_est(valid_carriers) .* (1 + alpha_mag * mag_error(valid_carriers));
    
    % 4. Final Re-equalization (Apply new H to current symbol)
    rx_symbol_eq(valid_carriers) = rx_symbol(valid_carriers) ./ H_est(valid_carriers);
    
    % Store result
    rx_matrix_equalized(:, i) = rx_symbol_eq;
    
end % <--- THIS END WAS MISSING/MISPLACED. IT CLOSES THE LOOP.

%% 4. Diagnostic Plots (Required for Report)
% MOVED OUTSIDE THE LOOP
if (1) 
    figure;
    subplot(2,1,1);
    % Plot magnitude of the FINAL H estimate
    plot(20*log10(abs(H_est)));
    title('Final Estimated Channel Magnitude (dB)');
    xlabel('Subcarrier Index'); ylabel('Magnitude [dB]');
    grid on; axis tight;
    
    subplot(2,1,2);
    % Plot phase of the FINAL H estimate
    plot(unwrap(angle(H_est)));
    title('Final Estimated Channel Phase (rad)');
    xlabel('Subcarrier Index'); ylabel('Phase [rad]');
    grid on; axis tight;
end

end % Closes the function