function [b] = demapper(symbol)
%DEMAPPER Demaps complex QPSK symbols into a binary bit stream
%   Converts the equalized complex symbols back into the original logical
%   bit sequence based on the quadrant they occupy.
%
%   INPUTS
%   - symbol: Vector or matrix of complex QPSK symbols
%
%   OUTPUTS
%   - b: Column vector of the recovered binary bits

bit1 = real(symbol) > 0;
bit2 = imag(symbol) > 0;

% b is a two colomn vector col1: real, col2: imag
b = [bit1 bit2];
b = b';
b = b(:);

end

