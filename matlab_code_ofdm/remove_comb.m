function [data_only_matrix] = remove_comb(frame_matrix, conf)
%REMOVE_COMB Removes pilot tones from the received symbol matrix to extract data.
%   Based on the insertion rate defined in the configuration, this function strips
%   out the known pilot subcarriers, leaving only the payload data for demapping.
%
%   INPUTS
%   - frame_matrix: Matrix of equalized OFDM symbols containing both data and pilots
%   - conf: System configuration structure (defining pilot insertion rate)
%
%   OUTPUTS
%   - data_only_matrix: Matrix containing only the relevant data subcarriers

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
