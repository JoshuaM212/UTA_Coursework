function open_iq_filter(fileName, freq)
    % creates rx and fills with data from iq file
    len = 2048000/4
    2;
    file = fopen(fileName, "rb");
    rx = zeros (len, 1);
    for i = 1 : len
        re = fread(file, 1, "uint8=>double") - 128;
        im = fread(file, 1, "uint8=>double") - 128;
        offset = complex(cos(2*pi*i/2048000*freq), sin(2*pi*i/2048000*freq));
        rx(i) = complex(re, im) * offset;
    end
    fclose(file);

    % FIR filter to convole with the rx signal (8 khz cutoff freq)
    Fs = 2048000; % Sampling Frequency
    Fpass = 8000; % Passband Frequency
    Fstop = 64000; % Stopband Frequency
    Dpass = 0.057501127785; % Passband Ripple
    Dstop = 0.0001; % Stopband Attenuation
    dens = 20; % Density Factor
    [N, Fo, Ao, W] = firpmord([Fpass, Fstop]/(Fs/2), [1 0], [Dpass, Dstop]);
    h8000 = firpm(N, Fo, Ao, W, {dens});

    % removes 63/64 samples, for final decimated data
    rxFilt = conv(rx, h8000);
    rx_filtered = rxFilt(1:2048000/8000:end);

    % plot constellation
    figure(1)
    plot(rx_filtered, 'b.')
    % Set the x and y axis limits
    xlim([-200, 200]);
    ylim([-200, 200]);
    
    %{
    length(rx_filtered)
    for i=1400 : 2000 % 1565
        clf(figure(1))
        
        xlim([-200, 200]);
        ylim([-200, 200]);
        hold on;
        plot(rx_filtered(i), 'ro', 'MarkerSize', 10, 'LineWidth', 4);
        plot(rx_filtered, 'b.')
        key = waitforbuttonpress;
        hold off;
    end
    %}

end
