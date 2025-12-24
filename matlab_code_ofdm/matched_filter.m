function [filtered_signal, h] = matched_filter(signal, os_factor, mf_length)
%MATCHED_FILTER Filters the signal with a root-raised cosine pulse for synchronization.
%   Convolves the input signal with a Root-Raised Cosine (RRC) filter to maximize SNR
%   at the optimal sampling instant, aiding in precise symbol timing recovery.
%
%   INPUTS
%   - signal: The input signal vector
%   - os_factor: Oversampling factor (samples per symbol)
%   - mf_length: One-sided length of the filter in symbols
%
%   OUTPUTS
%   - filtered_signal: The output of the convolution (full length)
%   - h: The filter coefficients used
    
    rolloff_factor = 0.22;
    
    h = rrc(os_factor, rolloff_factor, mf_length);
    filtered_signal = conv(h, signal, 'full'); 
