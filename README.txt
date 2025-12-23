audiotrans.m                 - Main script for standard OFDM audio transmission and channel simulation.
audiotrans_throughput.m      - Main script testing the maximum throughput and BER across different bandwidth and CP.
channel_tracking.m           - Performs channel estimation and equalization using Block or Comb methods.
channel_tracking_diversity.m - Implements Maximum Ratio Combining (MRC) for diversity reception.
comb_training.m              - Inserts pilot tones into OFDM symbols for Comb-based channel estimation.
demapper.m                   - Demaps complex QPSK symbols into a binary bit stream.
diversity_trans.m            - Main script for diversity transmission using two microphones (the one of the PC and the USB).
frame_sync.m                 - Detects the start of the data frame using matched filtering using preamble.
image_decoder.m              - Decodes a received bit stream into an image and displays it.
imagetrans.m                 - Main script for transmitting and reconstructing an image file.
matched_filter.m             - Filters the signal with a root-raised cosine pulse for synchronization.
ofdm_rx_resampling.m         - Downsamples the received signal from the audio card rate to the OFDM baseband rate. (Given)
ofdm_tx_resampling.m         - Upsamples the OFDM baseband signal to the audio card sampling rate for transmission. (Given)
ofdmlowpass.m                - Applies a lowpass filter. (Given)
preamble_generate.m          - Generates a pseudo-noise sequence for frame synchronization using lfsr.
QPSK_mapping.m               - Maps binary data bits to complex QPSK constellation symbols.
remove_comb.m                - Removes pilot tones from the received symbol matrix to extract data when using Comb.
rrc.m                        - Generates Root Raised Cosine filter coefficients for pulse shaping. (Given)
rxofdm.m                     - Standard receiver function performing sync, FFT, equalization, and demapping.
rxofdm_diversity.m           - Diversity receiver function combining signals from two sources using MRC.
training_generate.m          - Generates the pseudo-random sequence used for pilot symbols.

txofdm.m                     - Standard transmitter function generating the full OFDM signal structure.
