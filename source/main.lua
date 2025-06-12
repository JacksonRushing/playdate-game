import "imports"

local pd <const> = playdate
local gfx <const> = playdate.graphics

local initializedGame = false

local cameraScroll = 0

-- Defining player variables
local playerX, playerY = 0, PLAYER_SPAWN_Y

local raycastLine
local velocityLine

local closestPoint

local upVector = pd.geometry.vector2D.new(1,0)

local drawClone = false
local loopPlayer = true
local lastFramePlayerX = playerX
local lastFramePlayerY = playerY
local inputVelocity = pd.geometry.vector2D.new(0,0)
local gravityVelocity = 0
local xVelLastFrame, yVelLastFrame = 0, 0
local grounded = false
local onSlope = false
local groundBlock = nil

local spikeBlocks = {}
local activeBlock
local lastBlockSpawn = 0

local rightButton = pd.kButtonDown
local leftButton = pd.kButtonUp
local jumpButton = pd.kButtonRight

local menu = playdate.getSystemMenu()
menu:addCheckmarkMenuItem("Loop Player", loopPlayer, function(value)
    loopPlayer = value
end)

if pd.isSimulator then
    rightButton = pd.kButtonRight
    leftButton = pd.kButtonLeft
    jumpButton = pd.kButtonUp
    
end

SpikeBlock =
{
    
} 

function playdate.debugDraw()
    if closestPoint ~= nil then
    gfx.drawCircleAtPoint(closestPoint.x, closestPoint.y, 2)
    end
end
function clamp(value, min, max)
    return math.max(math.min(value, max), min)
end

function SpikeBlock:new(o)
    o = o or {}
    local self = setmetatable(o, SpikeBlock)
    self.__index = self
    
    self.transform = playdate.geometry.affineTransform.new()
    self.line = 0
    self.polygon = 0
    self.draw = SpikeBlock.draw
    self.fall = SpikeBlock.fall
    self.getNormal = SpikeBlock.getNormal
    
    self.setTransform = SpikeBlock.setTransform
    self.posX = 0
    self.posY = 0
    self.height = 0
    self.width = 0
    self.rotation = 0
    self.falling = true
    self.normal = nil
    return self
end

function initPlatforms()
    clearPlatforms()
    
    local b = nextBlock(false)
    b.rotation = 45
    b.posX = 30
    b.posY = 20
    b:setTransform()
    
    
    b = nextBlock(false)
    b.rotation = -120
    b.posX = 30
    b.posY = 40
    b:setTransform()
    
    b = nextBlock(false)
    b.rotation = 120
    b.posY = 150
    b.posX = 30
    b:setTransform()
    
  
end
-- 
-- function checkGroundCollisions()
--     for i,v in ipairs(spikeBlocks) do
--         if v ~= nil then
--             x1, y1, x2, y2 = v.line:unpack()
--             min = math.min(x1, x2)
--             if min <= 0 then
--                 xDelta = -min
--                 x1 += xDelta
--                 x2 += xDelta
--                 
--                 v.posX += xDelta
--                 v.line = playdate.geometry.lineSegment.new(x1, y1, x2, y2)
--                 
--                 
--                 v.falling = false
--                 if v == activeBlock then
--                     activeBlock = nil
--                 end
--             end
--         end
--     end
--     
-- end

function checkCollisions()
    for j, blockA in ipairs(spikeBlocks) do
        if blockA.falling == true then
            for i, blockB in ipairs(spikeBlocks) do
                if blockB ~= nil and blockB ~= blockA then
                    if blockB.line:intersectsLineSegment(blockA.line) then
                        blockA.falling = false
                        if activeBlock == blockA then 
                            activeBlock = nil
                        end
                    end
                end
            end
        end
        
    end
end

function SpikeBlock:fall(deltaTime)
    if self.falling then
        self.posX -= BLOCK_FALL_VELOCITY * deltaTime
        print(self.rotation)
    end
end

function SpikeBlock:getNormal()
    local normal = pd.geometry.vector2D.new(0,0)
    local lineVector = pd.geometry.vector2D.new(self.line.x2 - self.line.x1,  self.line.y2 - self.line.y1)
    if self.rotation > 180 then
        normal.x = -lineVector.y
        normal.y = lineVector.x
    else
        normal.x = lineVector.y
        normal.y = -lineVector.x
    end
    
    normal:normalize()
    return normal
end

function SpikeBlock:setTransform()
    
    if self.rotation > 360 or self.rotation < -360 then
        self.rotation = self.rotation % 360
    end
    
    if self.rotation < 0 then
        self.rotation = 360 + self.rotation
    end
    
    self.transform = pd.geometry.affineTransform.new()
    self.transform:rotate(self.rotation)
    self.transform:translate(self.posX, self.posY)
    
    p1x = -self.width / 2
    p2x = self.width / 2
    p1y = 0
    p2y = 0
    
    line = pd.geometry.lineSegment.new(p1x, p1y, p2x, p2y)
    transformedLine = self.transform:transformedLineSegment(line)
    self.line = transformedLine
    
    --calculate normal
    local lineVector = self.line:segmentVector()
    local perpVector = pd.geometry.vector2D.new(lineVector.y, lineVector.x)
    
end

function SpikeBlock:draw()
    
    if self.polygon == 0 then
        --print("tried to draw nil polygon, creating")
        newVertices = {}
        newVertices[1] = -(self.width / 2)
        newVertices[2] = - (self.height / 2)
        
        newVertices[3] = (self.width / 2)
        newVertices[4] = - (self.height / 2)
        
        newVertices[5] =(self.width / 2)
        newVertices[6] = (self.height / 2)
        
        newVertices[7] =  - (self.width / 2)
        newVertices[8] = (self.height / 2)
        
        self.polygon = pd.geometry.polygon.new(table.unpack(newVertices))
        self.polygon:close()
    end
    
    transformedPolygon = self.transform:transformedPolygon(self.polygon)
    if DRAW_BOX then
        if self == activeBlock then
            gfx.fillPolygon(transformedPolygon)
        else
            gfx.drawPolygon(transformedPolygon)
        end
    end
    if DRAW_LINE then
        gfx.drawLine(self.line)
    end
    
end

function generateBlock()
    newBlock = SpikeBlock:new()
    newBlock.width = math.random(BLOCK_MIN_WIDTH, BLOCK_MAX_WIDTH)
    newBlock.height = BLOCK_HEIGHT
    newBlock.rotation = 0
    newBlock.posX = BLOCK_SPAWN_Y + (BLOCK_HEIGHT / 2)
    halfWidth = math.ceil(newBlock.width / 2)
    newBlock.posY = math.random(halfWidth, 240 - halfWidth)
    
    return newBlock
end

function nextBlock(setActive)
    newBlock = generateBlock()
    if setActive then
        activeBlock = newBlock
    end
    newBlock:setTransform()
    table.insert(spikeBlocks, newBlock)
    return newBlock
end

function drawPlayerSprite(posX, posY, running, focusX, focusY)
    local flipArg = gfx.kImageUnflipped
    local currentSprite = nil
    
    if running then
        currentSprite = playerSpriteRunning
        
        local flip = (pd.getCurrentTimeMilliseconds() % 200) < 100
        if flip then 
            flipArg = gfx.kImageFlippedY
        end
    else
        currentSprite = playerSprite
    end
    
    currentSprite:drawAnchored(posX, posY, 0.0, 0.5, flipArg)
    
    local pupilOffsetX = 0
    local pupilOffsetY = 0
    
    if focusX ~= -1 or focusY ~= -1  then
        local deltaX = focusX - (posY)
        local deltaY = focusY - posY
        local delta = pd.geometry.vector2D.new(deltaX, deltaY)
        delta:normalize()
        --print(deltaX, deltaY, delta.x, delta.y)
        pupilOffsetX = math.floor(delta.x * EYE_LOOK_RADIUS)
        pupilOffsetY = math.floor(delta.y * EYE_LOOK_RADIUS)
    end
    
    --draw pupil
    --gfx.setColor(gfx.kColorBlack)
    playerPupil:drawAnchored(posX + pupilOffsetX, posY + pupilOffsetY, 0.0, 0.5)
end

-- function grounded()
--     --temporary, eventually will check collision
--     if playerX == 0 then
--         return true
--     end
--     return false
-- end

function jump()
    
    gravityVelocity = PLAYER_JUMP_VELOCITY
    
    if grounded and inputVelocity.x ~= 0 then
        gravityVelocity += inputVelocity.x * PLAYER_JUMP_SLOPE_RATIO
        inputVelocity.x = 0
    end
    
    grounded = false
    onSlope = false
end



function init()
    -- remove all platforms
    clearPlatforms()
    
    -- add ground platform

end

function clearPlatforms()
    for k in pairs(spikeBlocks) do
        spikeBlocks[k] = nil
    end
    
    local groundBlock = nextBlock(false)
    groundBlock.falling = false
    groundBlock.posX = -0.5
    groundBlock.posY = 120
    groundBlock.rotation = 90.0
    groundBlock.width = 240
    groundBlock:setTransform()
end

function drawGroundDebugHud(rightDirection, normal)
    groundSlopePoint = pd.geometry.point.new(210, 170)
    groundSlopeEnd = groundSlopePoint + (rightDirection * 30)
    

    local slopeLine = pd.geometry.lineSegment.new(groundSlopePoint.x, groundSlopePoint.y, groundSlopeEnd.x, groundSlopeEnd.y)
    gfx.drawLine(slopeLine)
    
    local slopeMidpoint = slopeLine:midPoint()
    
    gfx.drawLine(slopeMidpoint.x, slopeMidpoint.y, slopeMidpoint.x + (normal.x * 10), slopeMidpoint.y + (normal.y * 10))
  
end

function getOverlappingWall(lineSegment, blocks)
    local intersectingBlocks = {}
    local intersectingPoint = pd.geometry.point.new(0,0)
    local maxX = -1
    for i, block in ipairs(blocks) do
        if not isPlatform(block) then
            local intersects, intersection = lineSegment:intersectsLineSegment(block.line)
            if intersects then
                table.insert(intersectingBlocks, {block, intersection})
            end
        end
    end
    
    local collidingBlock = nil
    for i, intersection in ipairs(intersectingBlocks) do
        if intersection[2].x > maxX then
            maxX = intersection[2].x
            collidingBlock = intersection[1]
            intersectingPoint = intersection[2]
        end
    end
    
    return collidingBlock, intersectingPoint
    
end

function getOverlappingBlock(lineSegment, blocks)
    local intersectingBlocks = {}
    local intersectingPoint = pd.geometry.point.new(0,0)
    local maxX = -1
    for i, block in ipairs(blocks) do
        local intersects, intersection = lineSegment:intersectsLineSegment(block.line)
        if intersects then
            table.insert(intersectingBlocks, {block, intersection})
        end
    end
    
    local collidingBlock = nil
    for i, intersection in ipairs(intersectingBlocks) do
        if intersection[2].x > maxX then
            maxX = intersection[2].x
            collidingBlock = intersection[1]
            intersectingPoint = intersection[2]
        end
    end
    
    
    
    return collidingBlock, intersectingPoint
end

function getNearestPointOnGround(playerPos, block)
    local normal = block:getNormal()
    local offsetX = normal.x * block.height * 0.5
    local offsetY = normal.y * block.height * 0.5
    
    --offsetX += block.posX
    --offsetY += block.posY
    local groundLine = block.line:offsetBy(offsetX, offsetY)
    
    return groundLine:closestPointOnLineToPoint(playerPos)
end

function playdate.debugDraw()
    -- for i,v in ipairs(spikeBlocks) do
    --     if v ~= nil then
    --         local midpoint = v.line:midPoint()
    --         local normal = v:getNormal()
    --         
    --         local endPoint = pd.geometry.point.new(midpoint.x + (normal.x * 20), midpoint.y + (normal.y * 20))
    --         
    --         gfx.drawLine(midpoint.x, midpoint.y, endPoint.x, endPoint.y)
    --         gfx.drawCircleAtPoint(endPoint.x, endPoint.y, 2)
    --     end
    -- end
    
    gfx.drawLine(raycastLine)
    gfx.drawLine(velocityLine)
    local normalizedVelocity = inputVelocity:normalized()
    gfx.drawLine(25,25, 25 + (normalizedVelocity.x * 15), 25 + (normalizedVelocity.y * 15))
    local playerRect = getPlayerRect()
    gfx.drawRect(playerRect:unpack())
end

function getPlayerRect()
    
    -- playerX + legs, playerY, 
    local playerRect = pd.geometry.rect.new(playerX + PLAYER_LEG_LENGTH, playerY - HALF_WIDTH, PLAYER_HEIGHT, PLAYER_WIDTH)
    
    return playerRect
end

function isPlatform(block)
    local trimmedRotation = block.rotation % 180
    if trimmedRotation < 30 or trimmedRotation > 150 then
        return false
    else
        return true
    end
end

-- playdate.update function is required in every project!
function playdate.update()
    if not initializedGame then
        init()
        initializedGame = true
    end
    
    -- Clear screen
    gfx.clear()
    
    pd.drawFPS(380, 0)
    
    --update delta time
    local deltaTime = playdate.getElapsedTime()
    playdate.resetElapsedTime()
    
    local inputX = 0
    local inputY = 0
    local rightDirection = pd.geometry.vector2D.new(0, 1)
    local drawClone = false
    
    
    
    --update blocks
    
    if activeBlock ~= nil then
        activeBlock.rotation = playdate.getCrankPosition()
    end
    
    for i,v in ipairs(spikeBlocks) do
        if v ~= nil then
            v:fall(deltaTime)
            v:setTransform()
        end
    end
    
    --check collisions between blocks
    checkCollisions()
    
    
    
    if (pd.buttonJustPressed(pd.kButtonB)) then
        nextBlock(true)
    end
    
    if (pd.buttonJustPressed(pd.kButtonA)) then
        initPlatforms()
    end
    
    if (pd.buttonIsPressed(leftButton)) then
        inputY -= 1
    end
    
    if (pd.buttonIsPressed(rightButton)) then
        inputY += 1
    end
    
    if (pd.buttonJustPressed(jumpButton)) then
        --jump
        if grounded then
            jump()
        end
        grounded = false
        onSlope = false
    end
    
    --Calculate velocity
    --p1 is player position offset upwards
    --p2 is player position offset downwards
    
    local playerPoint = pd.geometry.point.new(playerX, playerY)
    local p1 = pd.geometry.point.new(playerX + GROUND_RAYCAST_OFFSET, playerY)
    local p2 = pd.geometry.point.new(p1.x - GROUND_RAYCAST_LENGTH, playerY)
    raycastLine = pd.geometry.lineSegment.new(p1.x, p1.y, p2.x, p2.y)
    
    local overlappingBlock, overlappingPoint = getOverlappingBlock(raycastLine, spikeBlocks)
    grounded = false
    if overlappingBlock ~= nil then
        inputVelocity:projectAlong(overlappingBlock.line:segmentVector())
        if isPlatform(overlappingBlock) then
            grounded = true
        else
            grounded = false
            
        end
    end
    
    
    if grounded then
        rightDirection:projectAlong(overlappingBlock.line:segmentVector())
        local nearestPoint = getNearestPointOnGround(playerPoint, overlappingBlock)
        
        playerX = nearestPoint.x
        --playerY = nearestPoint.y
        
    end    
    
    
    if (not pd.buttonIsPressed(jumpButton) and gravityVelocity > JUMP_CANCEL_THRESHOLD) then
        gravityVelocity = PLAYER_MIN_JUMP_VELOCITY
    end
    
    
    if gravityVelocity > 0  and not grounded then
        gravityVelocity -= PLAYER_GRAVITY * deltaTime
    else
        gravityVelocity -= FALLING_GRAVITY * deltaTime
    end
    
    if grounded and gravityVelocity < 0  then
        gravityVelocity = 0
    end
    
    totalXVelocity = gravityVelocity + inputVelocity.x
    
    local playerInputAccelerationAmount = deltaTime * PLAYER_ACCELERATION
    
    inputVelocity.x += rightDirection.x * playerInputAccelerationAmount * inputY
    inputVelocity.y += rightDirection.y * playerInputAccelerationAmount * inputY    
    
    
    --calculate drag
    
    local turning = inputVelocity.y > 0 and inputY < 0 or inputVelocity.y < 0 and inputY > 0
    
    
    
    if grounded and (inputVelocity.x ~= 0 or inputVelocity.y ~= 0) and (turning or inputY == 0) then
        local dragDirection = -inputVelocity:normalized()
        inputVelocity.x += deltaTime * dragDirection.x * DRAG_ACCELERATION 
        inputVelocity.y += deltaTime * dragDirection.y * DRAG_ACCELERATION 
        
        if (dragDirection.x > 0 and inputVelocity.x > 0) or (dragDirection.x < 0 and inputVelocity.x < 0) then
            inputVelocity.x = 0
        end
        
        if (dragDirection.y > 0 and inputVelocity.y > 0) or (dragDirection.y < 0 and inputVelocity.y < 0) then
            inputVelocity.y = 0
        end
        
    end
    
    gfx.drawLine(180, 180, 180 + (rightDirection.x * 10), 180 + (rightDirection.y * 10))
    gfx.drawCircleAtPoint(180 + (rightDirection.x * 10), 180 + (rightDirection.y * 10), 2)
    
    --clamp velocity
    inputVelocity.y = clamp(inputVelocity.y, -PLAYER_MAX_VELOCITY, PLAYER_MAX_VELOCITY)
    
    if totalXVelocity < -PLAYER_MAX_FALL_VELOCITY then 
        totalXVelocity = -PLAYER_MAX_FALL_VELOCITY
    end
    
    
    
    
    
    
    
    
    
    --Move player based on velocity
    local deltaX = deltaTime * (inputVelocity.x + gravityVelocity)
    local deltaY = deltaTime * (inputVelocity.y)
    
    local movedPlayerX = playerX + deltaX
    local movedPlayerY = playerY + deltaY
    
    
    
    --check for tunneling
    
    velocityLine = pd.geometry.lineSegment.new(playerX, playerY, movedPlayerX, movedPlayerY)
    local velocityDirection = velocityLine:segmentVector():normalized()
    local velocityMagnitude = velocityLine:length() + (BLOCK_HEIGHT * 0.5)
    
    -- add half block height , offset start by character width in y direction
    
    local yDirection = 0
    if deltaY > 0 then 
        yDirection = 1
    elseif deltaY < 0 then 
        yDirection = -1
    end
    
    local velocityOffset = pd.geometry.vector2D.new(velocityDirection.x * velocityMagnitude, (velocityDirection.y * velocityMagnitude) )--+ yDirection * PLAYER_WIDTH * 0.5)
    
    local velocityStartPoint = pd.geometry.point.new(playerX + PLAYER_LEG_LENGTH, playerY + (-yDirection * HALF_WIDTH))
    
    --velocityStartPoint.y += yDirection * PLAYER_WIDTH * 0.5
    
    local velocityEndPoint = velocityStartPoint:offsetBy(velocityOffset.x, velocityOffset.y + (yDirection * PLAYER_WIDTH))
    
    velocityLine = pd.geometry.lineSegment.new(velocityStartPoint.x, velocityStartPoint.y, velocityEndPoint.x, velocityEndPoint.y)
    
    
    
    local overlappingBlock, overlappingPoint = getOverlappingBlock(velocityLine, spikeBlocks)
    
    
    
    if overlappingBlock  ~= nil then
        local normal = overlappingBlock:getNormal()
        local velocityVector = velocityLine:segmentVector()
        local correctDirection = normal:dotProduct(velocityVector) < 0 
        local isntPlatform = not isPlatform(overlappingBlock)
        if (isntPlatform) or (not isntPlatform and correctDirection) then
            
            local formatted = string.format("prevented tunneling %i wall: %s direction: %s ", pd.getCurrentTimeMilliseconds(), tostring(isntPlatform), tostring(correctDirection))
            print(formatted)
            
            
            
            -- get vector from nearest point on line to current player pos
            local playerPoint = pd.geometry.point.new(playerX, playerY)
            local nearestPoint = overlappingBlock.line:closestPointOnLineToPoint(playerPoint)
            --local correctionVector = pd.geometry.vector2D.new(playerPoint.x - nearestPoint.x, playerPoint.y - nearestPoint.y).normalized()
            
            local correctionYDirection = 0
            
            local correctionY = playerPoint.y - nearestPoint.y
            
            if correctionY > 0 then 
                correctionYDirection = 1
            elseif correctionY < 0 then
                correctionYDirection = -1
            end
            
            
            if normal:dotProduct(velocityVector) > 0 then
                normal = -normal
            end
            
            movedPlayerX = nearestPoint.x + (normal.x * BLOCK_HEIGHT * 0.5)
             
            
            if isntPlatform then
                -- movedPlayerY = nearestPoint.y + (normal.y * BLOCK_HEIGHT * 0.5)
                --movedPlayerY += (correctionYDirection * PLAYER_WIDTH * 0.5)
                movedPlayerY = nearestPoint.y + (correctionYDirection * (HALF_WIDTH + 2))
                
                inputVelocity.y = 0
            end
            
            if not isntPlatform then
                inputVelocity:projectAlong(overlappingBlock.line:segmentVector()) 
                print("is platform, projecting along block")
                inputVelocity *= PLAYER_REDIRECT_VELOCITY_RATIO 
                grounded = true
            end
        end   
    end
    
    --case where running along ground
    --     ->\
    
    --'floating' too high when jumping off slope
    
    --intersecting with walls
    
    
    playerX = movedPlayerX
    playerY = movedPlayerY
    
    
    
    
    --clamp player position
    if playerX <= 0 then
        playerX = 0
    end
    
    if not loopPlayer then
        playerY = clamp(playerY, HALF_WIDTH, 240 - HALF_WIDTH)
    end
    
    local focusX = -1
    local focusY = -1
    
    if activeBlock ~= nil then
        focusX = activeBlock.posX
        focusY = activeBlock.posY
    end
    
    local cloneY = 0
    
    local drawClone = playerY < HALF_WIDTH or playerY > 240 - HALF_WIDTH
    
    if playerY < 0 then 
        playerY = 240
    elseif playerY > 240 then
        playerY = 0
    end
    
    local running = inputY ~= 0
    
    drawPlayerSprite(playerX, playerY, running, focusX, focusY)
    if drawClone then
        if playerY < 120 then
            cloneY = playerY + 240
        else
            cloneY = playerY - 240
        end
        
        drawPlayerSprite(playerX, cloneY, running, focusX, focusY)
    end
    
    --local angle = math.rad(playdate.getCrankPosition())
    
    --draw blocks
    for i,v in ipairs(spikeBlocks) do
        if v ~= nil then
            v:draw()
        end
    end
    
    
    
    
    if grounded then
        gfx.fillCircleAtPoint(380, 220, 5)
    else
        gfx.drawCircleAtPoint(380, 220, 5)
    end
    
    gfx.drawText(inputVelocity.x, 50, 0)
    gfx.drawText(inputVelocity.y, 50, 25)
    gfx.drawText(gravityVelocity, 50, 50)
    
    xVelLastFrame = xVelocity
    yVelLastFrame = yVelocity
    
    lastFramePlayerX = playerX
    lastFramePlayerY = playerY
    
    end
