function [rx_matrix_combined] = channel_tracking_diversity(rx_mat1, rx_mat2, conf)
% CHANNEL_TRACKING_DIVERSITY
% Implements Maximum Ratio Combining (MRC) for two receiver branches.

nb_tot_symbs = size(rx_mat1, 2);
n_c = conf.ofdm.ncarrier;

rx_matrix_combined = zeros(n_c, nb_tot_symbs);

% Training Symbols
training = conf.ofdm.training_symbol; 

%% Comb     

if strcmp(conf.channel_type, 'Comb')
    
    pilot_spacing = conf.comb_insertion_rate + 1;
    pilot_idxs = (1 : pilot_spacing : n_c).';
    all_idxs = (1 : n_c).';
    
    for i = 1 : nb_tot_symbs
        % Branch 1
        Y1 = rx_mat1(:, i);
        Pilots1 = Y1(pilot_idxs);
        H_hat1_p = Pilots1 ./ conf.training_comb;
        H1 = interp1(pilot_idxs, H_hat1_p, all_idxs, 'linear', 'extrap');
        
        % Branch 2 
        Y2 = rx_mat2(:, i);
        Pilots2 = Y2(pilot_idxs);
        H_hat2_p = Pilots2 ./ conf.training_comb;
        H2 = interp1(pilot_idxs, H_hat2_p, all_idxs, 'linear', 'extrap');
        
        % Maximum Ratio Combining (MRC)
        
        numerator = conj(H1) .* Y1 + conj(H2) .* Y2;
        denominator = (abs(H1).^2 + abs(H2).^2);
        
        % Avoid division by zero
        denominator(denominator < 1e-10) = 1e-10;
        
        rx_matrix_combined(:, i) = numerator ./ denominator;
    end

%% Block
elseif strcmp(conf.channel_type, 'Block')
    
    % Assume first symbol is training
    % Estimate H1 and H2 once at the beginning
    
    % Branch 1 Training
    H1_block = rx_mat1(:,1) ./ training;
    
    % Branch 2 Training
    H2_block = rx_mat2(:,1) ./ training;
    
    % Equalization for all symbols
    numerator = conj(H1_block) .* rx_mat1 + conj(H2_block) .* rx_mat2;
    denominator = (abs(H1_block).^2 + abs(H2_block).^2);
    denominator(denominator < 1e-10) = 1e-10;
    
    rx_matrix_combined = numerator ./ denominator;
    
%% Block Viterbi   

elseif strcmp(conf.channel_type, 'Block_Viterbi')
    
    % Initial Estimation
    H1 = rx_mat1(:,1) ./ training;
    H2 = rx_mat2(:,1) ./ training;
    
    % Phase tracking state
    theta1 = mod(angle(H1), 2*pi);
    theta2 = mod(angle(H2), 2*pi);
    
    % Viterbi parameters
    shift = zeros(n_c, 6) + pi/2*(-1:4);
    
    for j = 1 : nb_tot_symbs
        if j == 1
            % Just apply the training estimate
            H1_curr = H1;
            H2_curr = H2;
        else
            % Update H1 Phase
            % Estimate raw phase from data 
            ph_raw1 = (1/4) * angle(-(rx_mat1(:,j).^4));
            % Find closest to previous
            theta_prev_mat = repmat(theta1, 1, 6);
            theta_shifted = shift + ph_raw1;
            [~, idx] = min(abs(theta_shifted - theta_prev_mat), [], 2);
            theta_new1 = zeros(n_c, 1);
            for k=1:n_c, theta_new1(k) = theta_shifted(k, idx(k)); end
            % Filter
            theta1 = mod(0.8*theta_new1 + 0.2*theta1, 2*pi);
            H1_curr = abs(H1) .* exp(1i * theta1);
            
            % Update H2 Phase 
            ph_raw2 = (1/4) * angle(-(rx_mat2(:,j).^4));
            theta_prev_mat = repmat(theta2, 1, 6);
            theta_shifted = shift + ph_raw2;
            [~, idx] = min(abs(theta_shifted - theta_prev_mat), [], 2);
            theta_new2 = zeros(n_c, 1);
            for k=1:n_c, theta_new2(k) = theta_shifted(k, idx(k)); end
            theta2 = mod(0.8*theta_new2 + 0.2*theta2, 2*pi);
            H2_curr = abs(H2) .* exp(1i * theta2);
        end
        
        % MRC Combine
        num = conj(H1_curr) .* rx_mat1(:,j) + conj(H2_curr) .* rx_mat2(:,j);
        den = (abs(H1_curr).^2 + abs(H2_curr).^2);
        rx_matrix_combined(:, j) = num ./ den;
    end
end

end