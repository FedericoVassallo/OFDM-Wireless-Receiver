function [data_only_matrix] = remove_comb(frame_matrix, conf)
% REMOVE_TRAINING: Removes interleaved pilot rows (Comb) from the matrix
% INPUT: frame_matrix = Equalized OFDM matrix (rows=subcarriers)
%        conf = configuration structure
% OUTPUT: data_only_matrix = Matrix containing only data subcarriers

    % Define indices of the pilots (Training Symbols)
    % These must match the insertion logic in comb_training.m
    idxs = 1 : conf.comb_insertion_rate + 1 : conf.ofdm.ncarrier;
    
    data_only_matrix = [];
    
    % Loop through the gaps between pilots to extract data
    for i = 1 : length(idxs) - 1
        % Extract rows between current pilot and next pilot
        tmp = frame_matrix(idxs(i) + 1 : idxs(i+1) - 1, :);
        data_only_matrix = [data_only_matrix ; tmp];
    end
    
    % Handle the data after the last pilot (if any)
    if(idxs(end) ~= size(frame_matrix, 1))
        tmp = frame_matrix(idxs(end) + 1 : end, :);
        data_only_matrix = [data_only_matrix ; tmp];
    end
end