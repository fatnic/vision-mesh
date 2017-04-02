Wall = require 'wall'

local width, height = love.graphics:getDimensions()

wal_list = {
    { 0, 0, width, height },
    { 20*16, 5*16, 10*16, 10*16 },
    { 30*16, 25*16, 10*16, 10*16 }
}

local walls = {}
local origin = { x = 50, y = 50 }

local rays = {}

function dot(v0, v1)
    local n0 = normalize(v0)
    local n1 = normalize(v1)
    return n0.x * n1.x + n0.y * n1.y
end

function mag(v)
    return math.sqrt(v.x * v.x + v.y * v.y)
end

function normalize(v)
    local m = mag(v)
    return { x = v.x / m, y = v.y / m }
end

function angleBetween(v0, v1)
    local dp = dot(v0, v1)
    local mag0 = mag(v0)
    local mag1 = mag(v1)
    return math.acos(dp / mag0 / mag1)
end

function distance(v0 ,v1)
    local dx = v1.x - v0.x
    local dy = v1.y - v0.y
    return math.sqrt(dx * dx + dy * dy)
end

function normaliseRadian(rad)
    local result = rad % (2 * math.pi)
    if result < 0 then result = result + (2 * math.pi) end
    return result
end

function ternary(cond, t, f)
    if cond then return t else return f end
end

function segmentsIntersect(s1, s2)
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

function getClosestInterection(ray)
    local closestIntersect = nil

    for _, wall in pairs(walls) do
        for _, segment in pairs(wall.segments) do
            local int = segmentsIntersect(ray, segment)
            if int and not (int.x == ray.a.x and int.y == ray.a.y) then
                int.distance = distance(ray.a, int)
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

function clamp(val, low, high)
    if val < low then return low end
    if val > high then return high end
    return val
end

function getFurthestSegmentEnd(segment)
    local da = distance(origin, segment.a)
    local db = distance(origin, segment.b)
    if da < db then return segment.b end
    return segment.a 
end

function love.load()

    for _, w in pairs(wal_list) do
        table.insert(walls, Wall.new(unpack(w)))
    end
    walls[1].visible = false
    walls[1].segments[1].n = { x = 0, y = 1 }
    walls[1].segments[2].n = { x = -1, y = 0 }
    walls[1].segments[3].n = { x = 0, y = -1 }
    walls[1].segments[4].n = { x = 1, y = 0 }

end

function love.update(dt)
    rays = {}

    for _, wall in pairs(walls) do
        for _, segment in pairs(wall.segments) do
            ray = { a = origin }
            ray.target = segment.a
            ray.distance = distance(origin, ray.target)
            ray.angle = normaliseRadian(math.atan2(segment.a.y - origin.y, segment.a.x - origin.x))
            ray.delta = { x = math.cos(ray.angle), y = math.sin(ray.angle) }
            ray.dot = dot(ray.delta, segment.n)
            segment.facing = ternary(ray.dot < 0, true, false)
            local pdot = dot(ray.delta, segment.delta)
            segment.parallel = ternary(math.abs(pdot) == 1, true, false)
            ray.b = { x = ray.target.x + ray.delta.x * 1000, y = ray.target.y + ray.delta.y * 1000 }
            ray.intersect = ray.target
            segment.ray = ray
        end

        for i=1, 4 do
            local prev = i - 1
            if prev < 1 then prev = 4 end

            local current = wall.segments[i]
            local previous = wall.segments[prev]
            
            current.ray.blocked = false

            if not current.facing and not previous.facing then 
                current.ray.blocked = true 
            end

            if not current.ray.blocked then
                local cInt = getClosestInterection({ a = current.ray.a, b = current.ray.target })
                if cInt then current.ray.intersect = cInt end
                if current.ray.intersect.distance and current.ray.intersect.distance < current.ray.distance then
                    current.ray.blocked = true
                end
            end

            if not current.ray.blocked then

                if current.parallel then
                    local furthest = getFurthestSegmentEnd(current)
                    local sray = { a = furthest } 
                    sray.b = { x = sray.a.x + current.ray.delta.x * 1000, y = sray.a.y + current.ray.delta.y * 1000 }
                    local cInt = getClosestInterection(sray)
                    current.ray.shadowpoints = {{x = cInt.x, y = cInt.y}}
                    table.insert(rays, current.ray)
                end

                if previous.parallel and current.ray.shadowpoints then
                    current.ray.blocked = true 
                end

                if not current.ray.blocked and current.facing and previous.facing then 
                    current.ray.shadowpoints = {{x = current.ray.target.x, y = current.ray.target.y}}
                    table.insert(rays, current.ray) 
                end

                if not current.ray.blocked and (not current.facing and previous.facing) then
                    local sray = { a = current.ray.target }
                    sray.b = { x = sray.a.x + current.ray.delta.x * 1000, y = sray.a.y + current.ray.delta.y * 1000 }
                    local cInt = getClosestInterection(sray)
                    current.ray.shadowpoints = {{x = cInt.x, y = cInt.y},{x = current.ray.target.x, y = current.ray.target.y}}
                    table.insert(rays, current.ray)
                end

                if not current.ray.blocked and (current.facing and not previous.facing) then
                    local sray = { a = current.ray.target }
                    sray.b = { x = sray.a.x + current.ray.delta.x * 1000, y = sray.a.y + current.ray.delta.y * 1000 }
                    local cInt = getClosestInterection(sray)
                    current.ray.shadowpoints = {{x = current.ray.target.x, y = current.ray.target.y}, {x = cInt.x, y = cInt.y}}
                    table.insert(rays, current.ray)
                end

            end

        end

    end

    table.sort(rays, function(a, b) return a.angle < b.angle end)

    local points = {}
    table.insert(points, {origin.x, origin.y})

    for _, ray in pairs(rays) do
        for _, sp in pairs(ray.shadowpoints) do
            table.insert(points, {sp.x, sp.y})
        end
    end

    table.insert(points, points[2])

    mesh = love.graphics.newMesh(points, 'fan')

end

function love.mousemoved(x, y)
    origin.x = x
    origin.y = y
end

function love.draw()

    for _, wall in pairs(walls) do
        for _, segment in pairs(wall.segments) do

            -- segment facing or parallel
            local color = ternary(segment.facing, {255,255,0}, {0,255,0})
            color = ternary(segment.parallel, {0,0,255}, color)
            love.graphics.setColor(color)
            love.graphics.line(segment.a.x, segment.a.y, segment.b.x, segment.b.y)

            -- ray
            -- local color = ternary(segment.ray.blocked, {255,0,0,0},{100,100,100,100})
            -- love.graphics.setColor(color)
            -- love.graphics.line(segment.ray.a.x, segment.ray.a.y, segment.ray.b.x, segment.ray.b.y)

        end
    end

    local ray = walls[3].segments[1].ray
    local color = ternary(ray.blocked, {255,0,0,100},{100,100,100,100})
    love.graphics.setColor(color)
    love.graphics.line(ray.a.x, ray.a.y, ray.b.x, ray.b.y)
    love.graphics.setColor(255 ,255, 0)
    if ray.shadowpoints then
        for _, sp in pairs(ray.shadowpoints) do love.graphics.circle('fill', sp.x, sp.y, 5) end
    end

    -- shadowpoints
    -- love.graphics.setColor(255 ,255, 0)
    -- for _, ray in pairs(rays) do
    --     for _, sp in pairs(ray.shadowpoints) do
    --         love.graphics.circle('fill', sp.x, sp.y, 5)
    --     end
    -- end

    -- shadow mesh
    -- love.graphics.setColor(255, 255, 255, 50)
    -- love.graphics.draw(mesh)

    -- origin
    love.graphics.setColor(255, 0, 100)
    love.graphics.circle('fill', origin.x, origin.y, 4)

    -- walls
    -- love.graphics.setColor(0, 255, 0)
    -- for _, wall in pairs(walls) do
    --     if wall.visible then love.graphics.rectangle('fill', wall.x, wall.y, wall.width, wall.height) end
    -- end
        
end
