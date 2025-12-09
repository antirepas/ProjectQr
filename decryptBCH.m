function [corrected_bits] = decryptBCH(decoded_col_vector)
    % DECRYPTBCH performs BCH(15, 5) decoding on the QR Code Format Information.
    % decoded_col_vector must be a 15x1 column vector of 0s and 1s (unmasked FI).
   
    decoded_row_double = double(decoded_col_vector'); 
    
    gf_data = gf(decoded_row_double, 1); 
    
    [msg_corrected_gf, ~] = bchdec(gf_data, 15, 5, 'end');
    
    corrected_bits = double(msg_corrected_gf.x);
    
end
