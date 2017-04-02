tools = require 'tools'
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


function love.load()

    for _, w in pairs(wal_list) do table.insert(walls, Wall.new(unpack(w))) end
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
            ray.distance = tools.distance(origin, ray.target)
            ray.angle = tools.normaliseRadian(math.atan2(segment.a.y - origin.y, segment.a.x - origin.x))
            local dx = segment.a.x - origin.x
            local dy = segment.a.y - origin.y
            ray.delta = tools.normalize({ x = dx, y = dy })
            ray.dot = tools.dot(ray.delta, segment.n)
            segment.facing = tools.ternary(ray.dot < 0, true, false)
            local pdot = tools.dot(ray.delta, segment.delta)
            segment.parallel = tools.ternary(math.abs(pdot) == 1, true, false)
            ray.b = { x = ray.target.x + ray.delta.x * 1000, y = ray.target.y + ray.delta.y * 1000 }
            ray.intersect = ray.target
            ray.shadowpoints = nil
            segment.ray = ray
        end

        for i=1, 4 do
            local prev = i - 1
            if prev < 1 then prev = 4 end

            local current = wall.segments[i]
            local previous = wall.segments[prev]
            
            current.ray.blocked = false

            if not current.facing and not previous.facing then current.ray.blocked = true end

            if current.parallel then
                local sray = {}
                local samedir = tools.ternary(tools.vequal(current.delta, current.ray.delta), true, false)
                sray.a = tools.ternary(samedir, current.b, current.a)
                sray.b = { x = sray.a.x + current.ray.delta.x * 1000, y = sray.a.y + current.ray.delta.y * 1000 }
                local cInt = tools.getClosestInterection(sray, walls)
                if samedir then 
                    current.ray.shadowpoints = {{x = cInt.x, y = cInt.y}, { x = current.a.x, y = current.a.y }}
                else
                    current.ray.shadowpoints = {{x = cInt.x, y = cInt.y}, { x = current.b.x, y = current.b.y }}
                end
                table.insert(rays, current.ray)
            end

            if not current.ray.blocked and previous.parallel then
                current.ray.blocked = true
            end

            if not current.ray.blocked and not current.ray.shadowpoints then
                local cInt = tools.getClosestInterection({ a = current.ray.a, b = current.ray.target }, walls)
                if cInt then current.ray.intersect = cInt end
                if current.ray.intersect.distance and current.ray.intersect.distance < current.ray.distance then
                    current.ray.blocked = true
                end
            end

            if not current.ray.blocked and not current.ray.shadowpoints then

                if current.facing and previous.facing then 
                    current.ray.shadowpoints = {{x = current.ray.target.x, y = current.ray.target.y}}
                    table.insert(rays, current.ray) 
                end

                if not current.facing and previous.facing then
                    local sray = { a = current.ray.target }
                    sray.b = { x = sray.a.x + current.ray.delta.x * 1000, y = sray.a.y + current.ray.delta.y * 1000 }
                    local cInt = tools.getClosestInterection(sray, walls)
                    current.ray.shadowpoints = {{x = cInt.x, y = cInt.y},{x = current.ray.target.x, y = current.ray.target.y}}
                    table.insert(rays, current.ray)
                end

                if current.facing and not previous.facing then
                    local sray = { a = current.ray.target }
                    sray.b = { x = sray.a.x + current.ray.delta.x * 1000, y = sray.a.y + current.ray.delta.y * 1000 }
                    local cInt = tools.getClosestInterection(sray, walls)
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
            local color = tools.ternary(segment.facing, {255,255,0}, {0,255,0})
            color = tools.ternary(segment.parallel, {0,0,255}, color)
            love.graphics.setColor(color)
            love.graphics.line(segment.a.x, segment.a.y, segment.b.x, segment.b.y)

            -- ray
            local color = tools.ternary(segment.ray.blocked, {255,0,0,0},{100,100,100,100})
            love.graphics.setColor(color)
            love.graphics.line(segment.ray.a.x, segment.ray.a.y, segment.ray.b.x, segment.ray.b.y)

        end
    end

    -- single ray draw
    -- local ray = walls[2].segments[3].ray
    -- local color = tools.ternary(ray.blocked, {255,0,0,100},{100,100,100,100})
    -- love.graphics.setColor(color)
    -- love.graphics.line(ray.a.x, ray.a.y, ray.b.x, ray.b.y)
    -- love.graphics.setColor(255 ,255, 0)
    -- if ray.shadowpoints then
    --     for _, sp in pairs(ray.shadowpoints) do love.graphics.circle('fill', sp.x, sp.y, 5) end
    -- end

    -- shadowpoints
    love.graphics.setColor(255 ,255, 0)
    for _, ray in pairs(rays) do
        for _, sp in pairs(ray.shadowpoints) do
            love.graphics.circle('fill', sp.x, sp.y, 5)
        end
    end

    -- shadow mesh
    love.graphics.setColor(255, 255, 255, 50)
    love.graphics.draw(mesh)

    -- origin
    love.graphics.setColor(255, 0, 100)
    love.graphics.circle('fill', origin.x, origin.y, 4)

    -- walls
    -- love.graphics.setColor(0, 255, 0)
    -- for _, wall in pairs(walls) do
    --     if wall.visible then love.graphics.rectangle('fill', wall.x, wall.y, wall.width, wall.height) end
    -- end
        
end
