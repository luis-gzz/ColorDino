local utils = {}

function hex2rgb (hex)
    local hex = hex:gsub("#","")
    if hex:len() == 3 then
        return (tonumber("0x"..hex:sub(1,1))*17)/255, (tonumber("0x"..hex:sub(2,2))*17)/255, (tonumber("0x"..hex:sub(3,3))*17)/255
    else
        return tonumber("0x"..hex:sub(1,2))/255, tonumber("0x"..hex:sub(3,4))/255, tonumber("0x"..hex:sub(5,6))/255
    end
end
utils.hex2rgb = hex2rgb

function distance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end
utils.distance = distance

function angleBetweenTwoPts(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.deg(math.atan2(dx, dy))
end
utils.angleBetweenTwoPts = angleBetweenTwoPts

function randomFloat(lower, greater)
    return lower + math.random()  * (greater - lower);
end
utils.randomFloat = randomFloat


return utils