function open_iq_sweep(fileName)
  % creates rx and fills with data from iq file
  len = 2048000/100;

  freq_range = (-4000):5:(4000);  % good points to check: 3480 2485

  for freq = freq_range
    file = fopen(fileName, "rb");
    rx = zeros(len, 1);
    for i = 1 : len
        re = fread(file, 1, "uint8=>double") - 128;
        im = fread(file, 1, "uint8=>double") - 128;
        offset = complex(cos(2*pi*i/2048000*freq), sin(2*pi*i/2048000*freq));
        rx(i) = complex(re, im) * offset;
    end
    fclose(file);

    % FIR filter to convole with the rx signal (8 khz cutoff freq)
    Fs = 2048000;            % Sampling Frequency
    Fpass = 8000;            % Passband Frequency
    Fstop = 64000;           % Stopband Frequency
    Dpass = 0.057501127785;  % Passband Ripple
    Dstop = 0.0001;          % Stopband Attenuation
    dens  = 20;              % Density Factor
    [N, Fo, Ao, W] = firpmord([Fpass, Fstop]/(Fs/2), [1 0], [Dpass, Dstop]);
    h8000  = firpm(N, Fo, Ao, W, {dens});
    % removes 63/64 samples, for final decimated data 
    rxFilt = conv(rx, h8000);
    rxFilt = rxFilt(1:2048000/8000:end);

    % Plot constellation
    clf;
    plot(rxFilt, '.');
    xlabel("In-phase");
    ylabel("Quadrature");
    title("Filtered Constellation: ", freq);
    axis equal;
    grid on;
    drawnow;
    end
end

