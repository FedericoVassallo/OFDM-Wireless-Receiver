function beginning_of_data = frame_sync(rx_signal, conf)

%% Parameters
rolloff = 0.22;
L = conf.sc.os_factor;
detection_threshold = 70;

%% Define the pulse
pulse = rrc(L, rolloff, conf.sc.txpulse_length * L);

%% Filter the received signal
rx_signal_mf_filtered = conv(rx_signal, pulse, 'same');
preamble_bpsk = 1 - 2*preamble_generate(conf.sc.nsyms);

%% Inizialize vectors
current_peak_value = 0;
samples_after_threshold = L;
vecT = zeros(1,length(L * conf.sc.nsyms + 1 : length(rx_signal_mf_filtered)));
vecC = zeros(1,length(L * conf.sc.nsyms + 1 : length(rx_signal_mf_filtered)));

%% Sliding window
for i = L * conf.sc.nsyms + 1 : length(rx_signal_mf_filtered)
    r = rx_signal_mf_filtered(i - L * conf.sc.nsyms : L : i - L);
    %r = conv(r, pulse,'full');
    c = preamble_bpsk' * r; 
    T = abs(c)^2 / abs(r' * r);
    vecT(i) = T;
    vecC(i) = c;

    %% Check if the value is > then the detection_threshold
    if (T > detection_threshold || samples_after_threshold < L)
        samples_after_threshold = samples_after_threshold - 1;
        if (T > current_peak_value)
            beginning_of_data = i;
            current_peak_value = T;
        end
        if (samples_after_threshold == 0)
            figure
            plot(abs(vecT))
            return;
        end
    end
end

% Plot
figure
plot(abs(vecT))
    hold on
    plot(abs(vecC))
if samples_after_threshold == L
    fprintf("Error\n");
end
end
