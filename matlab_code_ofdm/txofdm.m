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
preamble_bits = preamble_generate(conf.sc.nsyms); % generate preamble of 100 bits (no need to map for bpsk)
preamble_mapped = -2 .* preamble_bits + 1; % bpsk_modulate the preamble
preamble_upsample = upsample(preamble_mapped,conf.sc.os_factor); %OFDM has a different OS factor
preamble_shaped = conv(preamble_upsample, conf.sc.txpulse, 'valid');

%% Training symbols
training_bits = training_generate(2*conf.ofdm.ncarrier);
training_bits = reshape(training_bits, [2, length(training_bits)/2]).';
training_symb = QPSK_mapping(training_bits);

%% Data symbols
txbits = reshape(txbits, [2, length(txbits)/2]).';


%% Final signal 
txsignal = zeros(10000,1);
txsignal(1:length(preamble_shaped)) = preamble_shaped;

%% Upconversion
time = 0:(1/conf.f_s) : size(txsignal,1)/conf.f_s - (1/conf.f_s);
txsignal = real(txsignal.*exp(1i*2*pi*conf.f_c.*time.'));
