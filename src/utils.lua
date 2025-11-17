local utils = {}

-- 运算
function utils.sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end

-- 线性同余随机数
utils.seed = 123456
utils.a = 1664525
utils.c = 1013904223
utils.m = 2^32

function utils.rand()
    utils.seed = (utils.a * utils.seed + utils.c) % utils.m
    return utils.seed / utils.m
end

-- 矩形碰撞检测
function utils.checkCollision(a, b)
    return a.x < b.x + b.w and
           a.x + a.w > b.x and
           a.y < b.y + b.h and
           a.y + a.h > b.y
end

return utils
