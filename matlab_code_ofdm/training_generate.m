function output = training_generate(output_length)
%TRAINING_GENERATE Generates the pseudo-random sequence used for pilot symbols.
%   Uses a Linear Feedback Shift Register (LFSR) to create a known binary sequence,
%   which is then mapped to QPSK to serve as training pilots or channel estimation headers.
%
%   INPUTS
%   - output_length: Desired length of the training sequence in bits
%
%   OUTPUTS
%   - output: Column vector containing the generated pseudo-random bits

    polynomial = [1 1 0 0 0 1 1 0]';
    
    state = ones(size(polynomial));
    
    output = zeros(output_length, 1);
    
    for i = 1:output_length
        output(i) = state(1);
        feedback = mod(sum(state .* polynomial), 2);
        state = circshift(state, -1);
        state(end) = feedback;
    end
end
