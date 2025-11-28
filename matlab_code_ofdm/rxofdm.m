function [rxbits, conf] = rxofdm(rxsignal,conf)
% Digital Receiver
%
%   [txsignal conf] = tx(txbits,conf) implements a complete causal
%   receiver in digital domain.
%
%   rxsignal    : received signal
%   conf        : configuration structure
%
%   rxbits      : received bits
%

%% Transmission Parameters


%% Downconversion
% Keep in mind that downconversion is done once for the entire signal
rxsignal_downconverted = down_conversion(rxsignal,conf.f_c,conf.f_s);

%% Matched filtering ONLY FOR PREAMBLE
% Remember that the OFDM signal has just a low pass filter


rxbits = zeros(conf.nbits,1);
end