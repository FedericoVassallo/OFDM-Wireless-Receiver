function [txsignal, conf] = txofdm(txbits,conf)
% Digital Transmitter
%
%   [txsignal conf] = tx(txbits,conf) implements a complete transmitter
%   using a single carrier preamble followed by OFDM data in digital domain.
%
%   txbits  : Information bits
%   conf    : Universal configuration structure

txsignal = zeros(10000,1);