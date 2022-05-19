function [BP] = bitslicing(A)

    tf = isa(A,'double');
    if tf == 1
        A = uint8(A);
    end
    
    for i = 1:8
    BP{i} = bitget(A,i)*2^7;
    end
    
 montage(BP);
    
end