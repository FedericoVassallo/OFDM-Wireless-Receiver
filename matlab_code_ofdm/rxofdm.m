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

% Define the time frame
time = 0:(1/conf.f_s) : size(rxsignal,1)/conf.f_s - (1/conf.f_s);

% Perform the downconversion by removing the RF carrier
rxsignal_downconverted = (rxsignal.*exp(-1i*2*pi*conf.f_c.*time.'));
% Keep in mind that downconversion is done once for the entire signal

%% Filter the Downconverted RX Signal

% Apply the low pass filter given
f_cutoff = conf.ofdm.bandwidth + 0.05 * conf.ofdm.bandwidth;      % Define the filter cutoff as 5% above the baseband BW
rx_signal_filtered = ofdmlowpass(rxsignal_downconverted, conf, f_cutoff);

%% Matched filtering ONLY FOR PREAMBLE
% Remember that the OFDM signal has just a low pass filter

%% Frame Synchronization
OFDM_start = frame_sync(rx_signal_filtered, conf);    % First sample of the OFDM signal



rxbits = zeros(conf.nbits,1);
end