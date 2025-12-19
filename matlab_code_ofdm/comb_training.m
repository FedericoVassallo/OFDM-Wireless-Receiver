function [frame_vec, training_comb] = comb_training(data_symbs, conf)
% COMB_TRAINING: Interleaves pilots and data within OFDM symbols
% 
% INPUT: 
%   data_symbs : Vector of mapped QPSK data symbols
%   conf       : Configuration struct (needs conf.comb_insertion_rate)
%
% OUTPUT:
%   frame_vec     : The final vector of symbols (Pilots + Data)
%   training_comb : The specific pilot values used (for receiver)

    % Extract the specific pilots for Comb
    % We take 1 pilot every 'comb_insertion_rate' + 1 symbols
    step = conf.comb_insertion_rate + 1;
    training_comb = conf.ofdm.training_symbol(1 : step : end);
    
    % Initialize variables
    frame_vec = [];             % The final output vector
    tmp_ofdm_symb = [];         % Buffer for current OFDM symbol
    
    idx_data = 1;               % Pointer for input data
    idx_pilot = 1;              % Pointer for pilots
    
    % Loop until all data is processed
    while idx_data <= length(data_symbs)
        
        % Get current pilot
        current_pilot = training_comb(idx_pilot);
        
        % Determine how much data we want to grab (Insertion Rate)
        % We try to grab 'conf.comb_insertion_rate' symbols
        len_chunk = min(conf.comb_insertion_rate, length(data_symbs) - idx_data + 1);
        data_chunk = data_symbs(idx_data : idx_data + len_chunk - 1);
        
        % Check if [Pilot + Data] fits in the current OFDM symbol
        space_available = conf.ofdm.ncarrier - length(tmp_ofdm_symb);
        block_size = 1 + length(data_chunk); % 1 Pilot + Data
        
        if block_size <= space_available
            % CASE A: IT FITS
            tmp_ofdm_symb = [tmp_ofdm_symb; current_pilot; data_chunk];
            idx_data = idx_data + len_chunk;
            
        else
            % CASE B: IT OVERFLOWS (Split the block)
            % Add the pilot
            tmp_ofdm_symb = [tmp_ofdm_symb; current_pilot];
            space_available = space_available - 1;
            
            % Fill the rest of the symbol with as much data as possible
            data_part1 = data_symbs(idx_data : idx_data + space_available - 1);
            tmp_ofdm_symb = [tmp_ofdm_symb; data_part1];
            
            % Push the full symbol to output
            frame_vec = [frame_vec; tmp_ofdm_symb];
            
            % Reset buffer for next symbol
            tmp_ofdm_symb = [];
            
            % Advance data index (we only consumed 'space_available' data)
            idx_data = idx_data + space_available;
            % Note: The remaining data from this chunk will be picked up 
            % in the next iteration of the while loop logic naturally 
            % but strictly speaking, we just proceed to next pilot logic
            % effectively splitting the "chunk" across symbol boundary.
        end
        
        % Check if buffer is exactly full (rare edge case)
        if length(tmp_ofdm_symb) == conf.ofdm.ncarrier
             frame_vec = [frame_vec; tmp_ofdm_symb];
             tmp_ofdm_symb = [];
        end
        
        % Rotate pilot index
        idx_pilot = idx_pilot + 1;
        if idx_pilot > length(training_comb)
            idx_pilot = 1;
        end
    end
    
    % Append any remaining partial symbol
    if ~isempty(tmp_ofdm_symb)
        frame_vec = [frame_vec; tmp_ofdm_symb];
    end

end