function [txsignal, conf] = txofdm(txbits,conf)
% Digital Transmitter
%
%   [txsignal conf] = tx(txbits,conf) implements a complete transmitter
%   using a single carrier preamble followed by OFDM data in digital domain.
%
%   txbits  : Information bits
%   conf    : Universal configuration structure

%% Transmission parameters


%% Preamble generation and mapping
preamble = preamble_generate(conf.sc.nsyms); % generate preamble of 100 bits (no need to map for bpsk)
preamble_mapped = -2 .* preamble + 1; % bpsk_modulate the preamble
preamble_upsample = upsample(preamble_mapped,conf.sc.os_factor); %OFDM has a different OS factor
preamble_shaped = conv(preamble_upsample, conf.sc.txpulse, 'valid');
preamble_upconverted = up_conversion(preamble_shaped, conf.f_c, conf.f_s);

txsignal = zeros(10000,1);
txsignal(1:length(preamble_upconverted)) = preamble_upconverted;