local tools = {}

function tools.dot(v0, v1)
    local n0 = tools.normalize(v0)
    local n1 = tools.normalize(v1)
    return n0.x * n1.x + n0.y * n1.y
end

function tools.mag(v)
    return math.sqrt(v.x * v.x + v.y * v.y)
end

function tools.normalize(v)
    local m = tools.mag(v)
    return { x = v.x / m, y = v.y / m }
end

function tools.angleBetween(v0, v1)
    local dp = tools.dot(v0, v1)
    local mag0 = tools.mag(v0)
    local mag1 = tools.mag(v1)
    return math.acos(dp / mag0 / mag1)
end

function tools.distance(v0 ,v1)
    local dx = v1.x - v0.x
    local dy = v1.y - v0.y
    return math.sqrt(dx * dx + dy * dy)
end

function tools.normaliseRadian(rad)
    local result = rad % (2 * math.pi)
    if result < 0 then result = result + (2 * math.pi) end
    return result
end

function tools.ternary(cond, t, f)
    if cond then return t else return f end
end

function tools.segmentsIntersect(s1, s2)
    local a, b = s1.a, s1.b
    local c, d = s2.a, s2.b

    local L1 = {X1=a.x,Y1=a.y,X2=b.x,Y2=b.y}
    local L2 = {X1=c.x,Y1=c.y,X2=d.x,Y2=d.y}

    local d = (L2.Y2 - L2.Y1) * (L1.X2 - L1.X1) - (L2.X2 - L2.X1) * (L1.Y2 - L1.Y1)

    if (d == 0) then return false end

    local n_a = (L2.X2 - L2.X1) * (L1.Y1 - L2.Y1) - (L2.Y2 - L2.Y1) * (L1.X1 - L2.X1)
    local n_b = (L1.X2 - L1.X1) * (L1.Y1 - L2.Y1) - (L1.Y2 - L1.Y1) * (L1.X1 - L2.X1)

    local ua = n_a / d
    local ub = n_b / d

    if (ua >= 0 and ua <= 1 and ub >= 0 and ub <= 1) then
        local x = L1.X1 + (ua * (L1.X2 - L1.X1))
        local y = L1.Y1 + (ua * (L1.Y2 - L1.Y1))
        return {x=x, y=y}
    end

    return false
end

function tools.getClosestInterection(ray, walls)
    local closestIntersect = nil

    for _, wall in pairs(walls) do
        for _, segment in pairs(wall.segments) do
            local int = tools.segmentsIntersect(ray, segment)
            if int and not (int.x == ray.a.x and int.y == ray.a.y) then
                int.distance = tools.distance(ray.a, int)
                if closestIntersect then
                    if int.distance < closestIntersect.distance then closestIntersect = int end
                else
                    closestIntersect = int
                end
            end
        end
    end

    return closestIntersect
end

function tools.clamp(val, low, high)
    if val < low then return low end
    if val > high then return high end
    return val
end

function tools.getFurthestSegmentEnd(segment)
    local da = distance(origin, segment.a)
    local db = distance(origin, segment.b)
    if da < db then return segment.b end
    return segment.a 
end

function tools.vequal(v0, v1)
    return v0.x == v1.x and v0.y == v1.y
end

function pvec(v)
    return v.x .. "," .. v.y
end

return tools
