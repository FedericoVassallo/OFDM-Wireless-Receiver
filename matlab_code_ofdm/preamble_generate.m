function output = preamble_generate(output_length)
%PREAMBLE_GENERATE Generates a pseudo-noise sequence for frame synchronization using LFSR.
%   Produces a repetitive, known binary sequence used to create the packet preamble.
%   This sequence enables the receiver to detect the start of the frame via correlation.
%
%   INPUTS
%   - output_length: Desired length of the preamble sequence
%
%   OUTPUTS
%   - output: Column vector containing the generated preamble bits

    polynomial = [1 0 0 0 1 0 0 0 0]';
    
    % All memories are initialized with ones
    state = ones(size(polynomial));
    
    output = zeros(output_length, 1);
    
    for i = 1:output_length
        output(i) = state(1);
        feedback = mod(sum(state .* polynomial), 2);
        state = circshift(state, -1);
        state(end) = feedback;
    end
end
