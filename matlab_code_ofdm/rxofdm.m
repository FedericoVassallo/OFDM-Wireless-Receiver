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

%% Filter the Downconverted RX Signal

% Apply the low pass filter given
f_cutoff = conf.ofdm.bandwidth + 0.05 * conf.ofdm.bandwidth;      % Define the filter cutoff as 5% above the baseband BW
rx_signal_filtered = ofdmlowpass(rxsignal_downconverted, conf, f_cutoff);

%% Matched filtering ONLY FOR PREAMBLE
% Remember that the OFDM signal has just a low pass filter

%% Frame Synchronization
OFDM_init = frame_sync(rx_signal_filtered, conf);    % First sample of the OFDM signal


rxbits = zeros(conf.nbits,1);
end