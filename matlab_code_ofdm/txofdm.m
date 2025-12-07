function [txsignal, conf] = txofdm(txbits,conf)
% Digital Transmitter
%
%   [txsignal conf] = tx(txbits,conf) implements a complete transmitter
%   using a single carrier preamble followed by OFDM data in digital domain.
%
%   txbits  : Information bits
%   conf    : Universal configuration structure

%% Transmission parameters
conf.txbits = txbits;

%% Preamble generation and mapping
preamble_bits = preamble_generate(conf.sc.nsyms); % generate preamble of 500 bits (no need to map for bpsk)
preamble_mapped = -2 .* preamble_bits + 1; % bpsk_modulate the preamble
preamble_upsample = upsample(preamble_mapped,conf.sc.os_factor); %OFDM has a different OS factor
preamble_shaped = conv(preamble_upsample, conf.sc.txpulse, 'same');

%% Training symbols
training_bits = training_generate(2*conf.ofdm.ncarrier);
training_bits = reshape(training_bits, [2, length(training_bits)/2]).';
training_symb = QPSK_mapping(training_bits);

conf.ofdm.training_symbol = training_symb;

%% Data symbols
txbits = reshape(txbits, [2, length(txbits)/2]).';
tx_symbol = QPSK_mapping(txbits);

%% Add the Training symbols before the Data symbols 
all_symb = [training_symb; tx_symbol];

%% We calculate the number of total OFDM symbols and  add padding size if needed
number_OFDM_symb = ceil(length(all_symb) / conf.ofdm.ncarrier); % to see if ceil is needed
conf.number_OFDM_symb = number_OFDM_symb; % to check

pad_size = (number_OFDM_symb * conf.ofdm.ncarrier) - length(all_symb);

if pad_size > 0
        all_symb = [all_symb; zeros(pad_size, 1)];
end

%% Implement the Serial to Parallel reshape

OFDM_grid = reshape(all_symb, [conf.ofdm.ncarrier, number_OFDM_symb]);

%% Perform standard IFFT on the grid

tx_time_domain = ifft(OFDM_grid, conf.ofdm.ncarrier);

%% Add of Cyclic Prefix

%Extract the CP part (last cp_len samples from every column)
cp_part = tx_time_domain(end - conf.ofdm.cplen + 1 : end, :);

tx_with_cp = [cp_part; tx_time_domain];

%% Implement the Parallel to Serial conversion

OFDM_serial = tx_with_cp(:);

%% Do the resampling

OFDM_resampled = ofdm_tx_resampling(OFDM_serial, conf);

conf.OFDM_resampled_length = length(OFDM_resampled);

%% Normalization 

% normalization for OFDM 
average_energy_OFDM = sum(abs(OFDM_resampled).^2)/length(OFDM_resampled);
normalized_OFDM = (1/sqrt(average_energy_OFDM))*OFDM_resampled;

% normalization for preamble
average_energy_preamble = sum(abs(preamble_shaped).^2)/length(preamble_shaped);
normalized_preamble = (1/sqrt(average_energy_preamble))*preamble_shaped;

%% Final signal 
txsignal = [normalized_preamble(:); normalized_OFDM];

%% Upconversion
time = 0:(1/conf.f_s) : size(txsignal,1)/conf.f_s - (1/conf.f_s);
txsignal = real(txsignal.*exp(1i*2*pi*conf.f_c.*time.'));

max_val = max(abs(txsignal));
if max_val > 0.95
   txsignal = txsignal * (0.95 / max_val);
end
