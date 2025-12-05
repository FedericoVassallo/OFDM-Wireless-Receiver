function [rx_matrix_equalized] = channel_tracking(rx_matrix, conf)
% CHANNEL_TRACKING: Estimation and correction of the channel.nb_symbs_between_training
% 
% INPUT: rx_matrix = matrix storing in each column an OFDM symbol (freq domain).
%        conf = structure storing all our global variables
% OUTPUT: rx_matrix_equalized = matrix storing in each column the OFDM data
%         symbols after equalization.

nb_symbs_between_training = conf.number_OFDM_symb; % Entire frame is one block in your current TX

% Determine total symbols based on the input matrix size
nb_tot_symbs = size(rx_matrix, 2); 

% Use the training symbol defined in txofdm.m
training = conf.ofdm.training_symbol; 

h_hat = zeros(conf.ofdm.ncarrier, 1); % Initializing h_hat storage

% Block Channel Case
if strcmp(conf.channel_type, 'Block')

    % At every loop we work on a training symbol + all the data symbols between it
    % and the subsequent training (or the end of the frame).
    
    for i = 1 : nb_symbs_between_training + 1 : nb_tot_symbs
      
        % Extract the training
        training_rx = rx_matrix(:, i);
        
        % Divide the rx training by the original one and get the estimated channel
        H_hat = training_rx ./ training;
        h_hat = fftshift(ifft(H_hat)); % Store impulse response for plotting
        
        % Perform the channel removing from the symbols
        % Calculate columns to process in this block
        cols = i : min(i + nb_symbs_between_training, ...
        nb_tot_symbs + (i + nb_symbs_between_training == nb_tot_symbs) * realmax);

        % Apply correction
        rx_matrix_equalized(:, cols) = rx_matrix(:, cols) .* exp(-1i * mod(angle(H_hat), 2*pi)) ./ abs(H_hat);

    end

elseif strcmp(conf.channel_type, 'Block_Viterbi') 
    % Block Channel with Phase noise case: Viterbi - Viterbi
    % Tracks rotation given to the symbols by phase noise

    % Shifts for Viterbi calculation
    shift = zeros(conf.ofdm.ncarrier, 6) + pi/2*(-1:4);
    
    % Initialize a matrix of phases
    theta_hat_matrix = zeros(conf.ofdm.ncarrier, nb_tot_symbs);
    
    % Loop over every set of symbols training + data
    for i = 1 : nb_symbs_between_training + 1 : nb_tot_symbs

        % Extract the training
        training_rx = rx_matrix(:, i);
        
        % Divide the rx training by the original one and get the estimated channel
        H_hat = training_rx ./ training;
        h_hat = fftshift(ifft(H_hat)); 

         % Remove channel on the training
        rx_matrix_equalized(:,i) = rx_matrix(:,i) .* exp(-1i * mod(angle(H_hat), 2*pi)) ./ abs(H_hat);
        
        % Add the phase shift of the training to the theta_hat_matrix
        theta_hat_matrix(:,i) = mod(angle(H_hat), 2*pi);

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
            theta_hat_matrix(:,j) = mod(0.01*theta_hat_correct + 0.99*theta_hat_prev, 2*pi);
          
            % Perform the channel removing using H_hat magnitude and NEW phase
            rx_matrix_equalized(:,j) = rx_matrix(:,j) .* exp(-1i * theta_hat_matrix(:,j)) ./ abs(H_hat);
        end
    end

elseif strcmp(conf.channel_type, 'Comb') 
    % Note: Your current TX does not support Comb (interleaved pilots).
    % This section is kept for completeness as requested.
    
    for i = 1 : size(rx_matrix, 2)
        symb = rx_matrix(:, i);
        
        % Extract the training symbs
        Y = symb(1 : conf.comb_insertion_rate + 1 : end);
        
        % Perform fft to get the channel transfer function
        H_hat = Y ./ conf.training_comb;

        % Perform the correction
        idxs = 1 : conf.comb_insertion_rate + 1: size(rx_matrix, 1);
        symb_equalized = [];
        for j = 1 : length(H_hat) - 1
            tmp = symb(idxs(j) : idxs(j+1)-1) .* exp(-1i * mod(angle(H_hat(j)), 2*pi)) ./ abs(H_hat(j));
            symb_equalized = [symb_equalized ; tmp];
        end
        tmp = symb(idxs(end) : end) .* exp(-1i * mod(angle(H_hat(end)), 2*pi)) ./ abs(H_hat(end)); 
        symb_equalized = [symb_equalized ; tmp];

        rx_matrix_equalized(:,i) = symb_equalized;
    end
end
    
%% Plot the impulse response
if (strcmp(conf.channel_type,'Block') || strcmp(conf.channel_type,'Block_Viterbi'))

    % Updated time vector using conf.ofdm.ncarrier
    time = 0 : (1/conf.f_s) : conf.ofdm.ncarrier/conf.f_s - 1/conf.f_s;
    
    figure
    plot(time, abs(h_hat).^2);
    xlabel('Time, s');
    ylabel('Channel Magnitude')
    title('Channel Impulse Response')
    % xlim([0 0.02]) % Optional: adjust based on result
    grid on;
    axis square; box on;
end

%%  Plot the channel magnitude and phase
if (strcmp(conf.channel_type,'Block') || strcmp(conf.channel_type,'Block_Viterbi'))
    % Updated frequency vector using conf.ofdm.bandwidth and conf.ofdm.ncarrier
    frequency = 0 : conf.ofdm.bandwidth / conf.ofdm.ncarrier : conf.ofdm.bandwidth * (1 - 1/conf.ofdm.ncarrier);
    frequency = frequency + conf.f_c - conf.ofdm.bandwidth / 2;
    
    figure
    subplot(2,1,1); plot(frequency, 20*log10(abs(H_hat)./ max(abs(H_hat)) ));
    xlabel('Frequency, Hz');
    ylabel('Magnitude, dB')
    title('Channel Magnitude over Frequency');
    grid on;
    subplot(2,1,2); plot(frequency, unwrap(angle(H_hat)));
    xlabel('Frequency, Hz');
    ylabel('Phase, rad')
    title('Channel Phase over Frequency');
    grid on;
end

end