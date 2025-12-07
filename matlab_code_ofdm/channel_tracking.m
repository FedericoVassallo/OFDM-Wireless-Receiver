function [rx_matrix_equalized] = channel_tracking(rx_matrix, conf)
% CHANNEL_TRACKING: Estimation and correction of the channel
% 
% INPUT: rx_matrix = matrix storing in each column an OFDM symbol (freq domain).
%        conf = structure storing all our global variables
% OUTPUT: rx_matrix_equalized = matrix storing in each column the OFDM data
%         symbols after equalization.

nb_symbs_between_training = conf.number_OFDM_symb; % Entire frame is one block
nb_tot_symbs = size(rx_matrix, 2); 

% Use the training symbol defined in txofdm.m
training = conf.ofdm.training_symbol; 

% Initialize storage
h_hat = zeros(conf.ofdm.ncarrier, 1); 
rx_matrix_equalized = zeros(size(rx_matrix));

% [NEW] Matrix to store the complex Channel Estimate for every symbol
% Dimensions: (Subcarriers x Time)
H_evolution = zeros(conf.ofdm.ncarrier, nb_tot_symbs); 

% -------------------------------------------------------------------------
% Case 1: Block Channel (Static over the frame/block)
% -------------------------------------------------------------------------
if strcmp(conf.channel_type, 'Block')

    % At every loop we work on a training symbol + all the data symbols between it
    for i = 1 : nb_symbs_between_training + 1 : nb_tot_symbs
      
        % Extract the training
        training_rx = rx_matrix(:, i);
        
        % Divide the rx training by the original one and get the estimated channel
        H_hat = training_rx ./ training;
        h_hat = fftshift(ifft(H_hat)); % Store impulse response
        
        % Store the channel estimate for the training symbol
        H_evolution(:, i) = H_hat;
        
        % Calculate columns to process in this block
        cols = i+1 : min(i + nb_symbs_between_training, ...
            nb_tot_symbs + (i + nb_symbs_between_training == nb_tot_symbs) * realmax);

        % Apply correction to data symbols
        % For Block fading, we assume H is constant for these symbols
        for k = cols
            rx_matrix_equalized(:, k) = rx_matrix(:, k) .* exp(-1i * mod(angle(H_hat), 2*pi)) ./ abs(H_hat);
            
            % Store the same H for these symbols (for visualization)
            H_evolution(:, k) = H_hat;
        end
        
        % Correct the training symbol itself
        rx_matrix_equalized(:, i) = rx_matrix(:, i) .* exp(-1i * mod(angle(H_hat), 2*pi)) ./ abs(H_hat);

    end

% -------------------------------------------------------------------------
% Case 2: Block Viterbi (Phase Tracking)
% -------------------------------------------------------------------------
elseif strcmp(conf.channel_type, 'Block_Viterbi') 
    % Tracks rotation given to the symbols by phase noise

    % Shifts for Viterbi calculation
    shift = zeros(conf.ofdm.ncarrier, 6) + pi/2*(-1:4);
    
    % Initialize a matrix of phases
    theta_hat_matrix = zeros(conf.ofdm.ncarrier, nb_tot_symbs);
    
    % Loop over every set of symbols training + data
    for i = 1 : nb_symbs_between_training + 1 : nb_tot_symbs

        % Extract the training
        training_rx = rx_matrix(:, i);
        
        % Get the estimated channel from training
        H_hat = training_rx ./ training;
        
        % Store training channel estimate
        H_evolution(:, i) = H_hat;

        % Remove channel on the training
        rx_matrix_equalized(:,i) = rx_matrix(:,i) .* exp(-1i * mod(angle(H_hat), 2*pi)) ./ abs(H_hat);
        
        % Initialize the phase tracking with the training phase
        theta_hat_matrix(:,i) = mod(angle(H_hat), 2*pi);

        % Loop over data symbols in this block
        for j = i+1 : min(i + nb_symbs_between_training, nb_tot_symbs + (i + nb_symbs_between_training == nb_tot_symbs)*realmax)
            
            % Take the previous phase shift
            theta_hat_prev = theta_hat_matrix(:,j-1); 
        
            % Generate a matrix storing in each column the vector theta_hat_prev.
            theta_hat_prev_matrix = ones(conf.ofdm.ncarrier, 6) .* theta_hat_prev;
            
            % Estimate the new phase in the [-pi/4, pi/4] interval (QPSK modulation)
            % Uses the 4th power to remove modulation
            theta_hat = (1/4) * angle(-(rx_matrix(:,j).^4));
        
            % Produce a matrix storing in each row the shifted versions of theta_hat
            theta_hat_shifted = shift + theta_hat;
            
            % Extract vector containing theta_hat closer to previous symbol
            [~, idx] = min(abs(theta_hat_shifted - theta_hat_prev_matrix), [], 2);
            
            theta_hat_correct = zeros(conf.ofdm.ncarrier, 1);
            for k = 1:conf.ofdm.ncarrier
                theta_hat_correct(k,1) = theta_hat_shifted(k, idx(k));
            end

            % Filter the phase obtained (0.01 new + 0.99 old)
            %theta_hat_matrix(:,j) = mod(0.01*theta_hat_correct + 0.99*theta_hat_prev, 2*pi);

            % TRY THIS: More responsive filter
            alpha = 0.2; % Weight for the new measurement
            theta_hat_matrix(:,j) = mod(alpha*theta_hat_correct + (1-alpha)*theta_hat_prev, 2*pi);
          
            % [NEW] Reconstruct the full complex channel for this specific symbol
            % H_current = |H_training| * exp(j * tracked_phase)
            H_current = abs(H_hat) .* exp(1i * theta_hat_matrix(:,j));
            H_evolution(:, j) = H_current;

            % Perform the channel removing using the tracked phase and estimated magnitude
            rx_matrix_equalized(:,j) = rx_matrix(:,j) ./ H_current;
        end
    end

% -------------------------------------------------------------------------
% Case 3: Comb Pilot (Optional/Legacy)
% -------------------------------------------------------------------------
elseif strcmp(conf.channel_type, 'Comb') 
    
    for i = 1 : size(rx_matrix, 2)
        symb = rx_matrix(:, i);
        
        % Extract the training symbs
        Y = symb(1 : conf.comb_insertion_rate + 1 : end);
        
        % Perform fft to get the channel transfer function
        H_hat_comb = Y ./ conf.training_comb;

        % Perform the correction (Interpolation logic simplified here)
        % Note: This block is strictly copied from provided logic, but 
        % H_evolution is not easily reconstructible without full interpolation code.
        % We will skip H_evolution for Comb as it wasn't the focus of Task 3.
        
        idxs = 1 : conf.comb_insertion_rate + 1: size(rx_matrix, 1);
        symb_equalized = [];
        H_interp_col = []; % To store interpolated channel
        
        for j = 1 : length(H_hat_comb) - 1
            % Interpolate phase and mag (Zero Order Hold in provided code essentially)
            segment_len = idxs(j+1) - idxs(j);
            phase_corr = angle(H_hat_comb(j));
            mag_corr = abs(H_hat_comb(j));
            
            correction_factor = exp(-1i * mod(phase_corr, 2*pi)) ./ mag_corr;
            tmp = symb(idxs(j) : idxs(j+1)-1) .* correction_factor;
            symb_equalized = [symb_equalized ; tmp];
            
            % Reconstruct H for this segment
            H_interp_col = [H_interp_col; ones(segment_len, 1) * H_hat_comb(j)];
        end
        % Last segment
        phase_corr = angle(H_hat_comb(end));
        mag_corr = abs(H_hat_comb(end));
        correction_factor = exp(-1i * mod(phase_corr, 2*pi)) ./ mag_corr;
        tmp = symb(idxs(end) : end) .* correction_factor;
        symb_equalized = [symb_equalized ; tmp];
        
        H_interp_col = [H_interp_col; ones(length(tmp), 1) * H_hat_comb(end)];

        rx_matrix_equalized(:,i) = symb_equalized;
        H_evolution(:, i) = H_interp_col;
    end
end
    
%% VISUALIZATION FOR TASK 3
% Only plot if we have valid data in H_evolution
if (strcmp(conf.channel_type,'Block') || strcmp(conf.channel_type,'Block_Viterbi'))

    % --- 1. Define Axes ---
    
    % Frequency Axis: Centered on f_c (e.g., 7000Hz to 9000Hz)
    f_spacing = conf.ofdm.bandwidth / conf.ofdm.ncarrier;
    freq_axis = (0 : conf.ofdm.ncarrier-1) * f_spacing - conf.ofdm.bandwidth/2 + conf.f_c;

    % Time Axis for PDP: Centered around 0 delay
    % Resolution is 1/Bandwidth (approx 0.5ms)
    time_res = 1 / conf.ofdm.bandwidth; 
    time_axis_pdp = ((-conf.ofdm.ncarrier/2) : (conf.ofdm.ncarrier/2 - 1)) * time_res;

    % Symbol Index Axis (Time Evolution)
    sym_axis = 1:size(H_evolution, 2);

    % --- 2. Prepare Data ---
    
    % A. FREQUENCY DOMAIN
    % Shift data so DC component is in the center of the array
    H_evol_shifted = fftshift(H_evolution, 1); 
    H_avg_shifted  = mean(H_evol_shifted, 2);

    % B. TIME DOMAIN (Power Delay Profile)
    % 1. Take IFFT of raw H (before shift) to get impulse response
    h_impulse_time = ifft(H_evolution, [], 1);
    % 2. Shift so that delay=0 is in the center of the plot
    h_impulse_shifted = fftshift(h_impulse_time, 1);
    % 3. Calculate Power and Average
    pdp = mean(abs(h_impulse_shifted).^2, 2); 
    
    % --- 3. Generate Plots ---

    % PLOT 1: Power Delay Profile
    figure('Name', 'Task 3: Power Delay Profile');
    plot(time_axis_pdp, 10*log10(pdp), 'LineWidth', 1.5);
    xlabel('Delay (s)');
    ylabel('Power (dB)');
    title('Power Delay Profile (Averaged)');
    grid on; axis tight;
    % Note: A peak at 0s means direct path. Peaks at >0s are echoes.

    % PLOT 2: Average Frequency Response
    figure('Name', 'Task 3: Channel Frequency Response');
    
    subplot(2,1,1);
    plot(freq_axis, 20*log10(abs(H_avg_shifted)), 'LineWidth', 1.5);
    xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
    title('Average Frequency Response (Magnitude)'); 
    grid on; xlim([min(freq_axis) max(freq_axis)]);
    
    subplot(2,1,2);
    % Unwrap removes the discontinuities (+/- pi jumps)
    plot(freq_axis, unwrap(angle(H_avg_shifted)), 'LineWidth', 1.5);
    xlabel('Frequency (Hz)'); ylabel('Phase (rad)');
    title('Average Frequency Response (Phase)'); 
    grid on; xlim([min(freq_axis) max(freq_axis)]);

    % PLOT 3: Channel Magnitude Evolution (Spectrogram)
    figure('Name', 'Task 3: Channel Magnitude Evolution');
    imagesc(sym_axis, freq_axis, 20*log10(abs(H_evol_shifted)));
    colorbar;
    xlabel('OFDM Symbol Index (Time)');
    ylabel('Frequency (Hz)');
    title('Channel Magnitude Evolution [dB]');
    axis xy; % Corrects Y-axis direction

    % PLOT 4: Channel Phase Evolution
    % This helps identify Doppler drift (diagonal lines) or constant rotation
    figure('Name', 'Task 3: Channel Phase Evolution');
    imagesc(sym_axis, freq_axis, unwrap(angle(H_evol_shifted)));
    colorbar;
    xlabel('OFDM Symbol Index (Time)');
    ylabel('Frequency (Hz)');
    title('Channel Phase Evolution [Rad]');
    axis xy;
end

end