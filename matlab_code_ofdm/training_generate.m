function output = training_generate(output_length)

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