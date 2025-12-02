function [symbols] = QPSK_mapping(in_bits)

%Constellation:
GrayMap = 1/sqrt(2) * [(-1-1j) (-1+1j) ( 1-1j) ( 1+1j)];
symbols = GrayMap(bi2de(in_bits, 'left-msb')+1).';
end

