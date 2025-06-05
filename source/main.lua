import "imports"

local pd <const> = playdate
local gfx <const> = playdate.graphics

-- Defining player variables
local playerX, playerY = 0, PLAYER_SPAWN_Y

local closestPoint

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
    self.setTransform = SpikeBlock.setTransform
    self.posX = 0
    self.posY = 0
    self.height = 0
    self.width = 0
    self.rotation = 0
    self.falling = true
    return self
end

function initPlatforms()
    for k in pairs(spikeBlocks) do
        spikeBlocks[k] = nil
    end
    
    local b = nextBlock()
    b.rotation = 45
    b.posX = 30
    b.posY = 20
    
    b = nextBlock()
    b.rotation = -120
    b.posX = 30
    b.posY = 40
    
    b = nextBlock()
    b.rotation = 120
    b.posY = 150
    b.posX = 30
    
    activeBlock = nil
end

function checkGroundCollisions()
    for i,v in ipairs(spikeBlocks) do
        if v ~= nil then
            x1, y1, x2, y2 = v.line:unpack()
            min = math.min(x1, x2)
            if min <= 0 then
                xDelta = -min
                x1 += xDelta
                x2 += xDelta
                
                v.posX += xDelta
                v.line = playdate.geometry.lineSegment.new(x1, y1, x2, y2)
                
                
                v.falling = false
                if v == activeBlock then
                    activeBlock = nil
                end
            end
        end
    end
    
end

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
    end
end

function SpikeBlock:setTransform()
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

function nextBlock()
    newBlock = generateBlock()
    activeBlock = newBlock
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
    grounded = false
    onSlope = false
    gravityVelocity = PLAYER_JUMP_VELOCITY
end

function drawGroundDebugHud(rightDirection, normal)
    groundSlopePoint = pd.geometry.point.new(210, 170)
    groundSlopeEnd = groundSlopePoint + (rightDirection * 30)
    

    local slopeLine = pd.geometry.lineSegment.new(groundSlopePoint.x, groundSlopePoint.y, groundSlopeEnd.x, groundSlopeEnd.y)
    gfx.drawLine(slopeLine)
    
    local slopeMidpoint = slopeLine:midPoint()
    
    gfx.drawLine(slopeMidpoint.x, slopeMidpoint.y, slopeMidpoint.x + (normal.x * 10), slopeMidpoint.y + (normal.y * 10))
  
end

-- playdate.update function is required in every project!
function playdate.update()
    -- Clear screen
    gfx.clear()
    
    pd.drawFPS(380, 0)
    
    --update delta time
    local deltaTime = playdate.getElapsedTime()
    playdate.resetElapsedTime()
    
    local inputX = 0
    local inputY = 0
    local rightDirection = pd.geometry.vector2D.new(0, -1)
    local drawClone = false
    
    -- Draw crank indicator if crank is docked
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:draw()
    else
        --Gameplay Loop
        if activeBlock ~= nil then
            activeBlock.rotation = playdate.getCrankPosition()
        end
        
        --draw blocks
        for i,v in ipairs(spikeBlocks) do
            if v ~= nil then
                v:fall(deltaTime)
                v:setTransform()
            end
        end
        
        --check collisions between blocks and between block and ground
        checkGroundCollisions()
        checkCollisions()
        
        for i,v in ipairs(spikeBlocks) do
            if v ~= nil then
                v:draw()
            end
        end
        
        if (pd.buttonJustPressed(pd.kButtonB)) then
            nextBlock()
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
        
        if (not pd.buttonIsPressed(jumpButton) and gravityVelocity > JUMP_CANCEL_THRESHOLD) then
            gravityVelocity = PLAYER_MIN_JUMP_VELOCITY
        end
        
        if gravityVelocity > 0  and not grounded then
            gravityVelocity -= PLAYER_GRAVITY * deltaTime
        else
            gravityVelocity -= FALLING_GRAVITY * deltaTime
        end
        
        rightDirection.y *= -1 --why
        if onSlope then
            rightDirection:projectAlong(groundBlock.line:segmentVector())
            rightDirection:normalize()
        end
        
        gfx.drawLine(180, 180, 180 + (rightDirection.x * 10), 180 + (rightDirection.y * 10))
        gfx.drawCircleAtPoint(180 + (rightDirection.x * 10), 180 + (rightDirection.y * 10), 2)
        --print(rightDirection)
        --print(rightDirection:magnitude())
        --print(inputY)
        
        if not grounded and inputVelocity.x ~= 0 then 
            --inputVelocity.x = 0
            --drag input velocity x
            local dragSign = 1
            if inputVelocity.x >= 0 then
               dragSign = -1
            end
            
            inputVelocity.x += dragSign * DRAG_ACCELERATION * deltaTime
            
            -- if (dragSign == -1 and inputVelocity.x < 0) or (dragSign == 1 and inputVelocity.x > 0) then
            --     inputVelocity.x = 0
            --     print("overshot drag on input velocity x airborne")
            -- end
        end
        
        if inputY ~= 0 then
            --check if we're turning around
            if (inputVelocity.y > 0 and inputY < 0) or (inputVelocity.y < 0 and inputY > 0) then
                --yVelocity += inputY * DRAG_ACCELERATION * deltaTime
                inputVelocity.y += inputY * DRAG_ACCELERATION * rightDirection.y * deltaTime
                inputVelocity.x += inputY * DRAG_ACCELERATION * rightDirection.x * deltaTime
                playdate.graphics.drawText("turning!", 0, 30)
            end
                
            --yVelocity += inputY * PLAYER_ACCELERATION *  deltaTime
            inputVelocity.y += inputY * PLAYER_ACCELERATION * rightDirection.y * deltaTime
            inputVelocity.x += inputY * PLAYER_ACCELERATION * rightDirection.x * deltaTime
            
        else
            local dragSign = 1
            if inputVelocity.y >= 0 then
               dragSign = -1
            end
            
            --yVelocity += dragSign * DRAG_ACCELERATION *  deltaTime
            inputVelocity.y += dragSign * DRAG_ACCELERATION * rightDirection.y *  deltaTime
            -- inputVelocity.x += dragSign * DRAG_ACCELERATION * rightDirection.x * deltaTime * -1
            
            -- make sure we don't overshoot
            if (dragSign == -1 and inputVelocity.y < 0) or (dragSign == 1 and inputVelocity.y > 0) then
               inputVelocity.y = 0
            end
            
            -- if (dragSign == -1 and inputVelocity.x < 0) or (dragSign == 1 and inputVelocity.x > 0) then
            --     inputVelocity.x = 0
            --     
            -- end
        end
        
        totalXVelocity = gravityVelocity + inputVelocity.x
        
        --clamp velocity
        inputVelocity.y = clamp(inputVelocity.y, -PLAYER_MAX_VELOCITY, PLAYER_MAX_VELOCITY)
        
        if totalXVelocity < -PLAYER_MAX_FALL_VELOCITY then 
            totalXVelocity = -PLAYER_MAX_FALL_VELOCITY
        end
        
        
        
        
        
        
        
        -- Move player
        
        local deltaPosX = totalXVelocity * deltaTime
        local deltaPosY = (inputVelocity.y) * deltaTime
        
        local movedPosX = playerX + deltaPosX
        local movedPosY = playerY + deltaPosY
        
        
        local p2x = movedPosX - GROUND_RAYCAST_LENGTH
        local p2y = movedPosY
        
        raycastLine = pd.geometry.lineSegment.new(movedPosX + GROUND_RAYCAST_OFFSET, movedPosY, p2x, p2y)
        
        gfx.drawLine(raycastLine)
        
        playerX += deltaPosX
        playerY += deltaPosY
        
        
        
        if grounded then
            gravityVelocity = 0
        end
        
        grounded = false
        --if gravityVelocity + inputVelocity.x <= 0 then
            
        local intersectingBlocks = {}
        for i, block in ipairs(spikeBlocks) do
            local intersects, intersection = raycastLine:intersectsLineSegment(block.line)
            if intersects then
                table.insert(intersectingBlocks, {block, intersection})
            end
        end
        local maxX = -1
        local surface = nil
        local normal
        
        local collidingBlock
        for i, intersection in ipairs(intersectingBlocks) do
            if intersection[2].x > maxX then
                maxX = intersection[2].x
                collidingBlock = intersection[1]
            end
        end
        onSlope = false
        if maxX ~= -1 and gravityVelocity <= 0 then
            normal = collidingBlock.line:segmentVector():rightNormal()
            
            if normal:dotProduct(raycastLine:segmentVector()) > 0 then
                normal = collidingBlock.line:segmentVector():leftNormal()
                print("left normal")
            else 
                print("right normal")
            end
            
            surface = collidingBlock.line:offsetBy(normal.x * BLOCK_HEIGHT * 0.5, normal.y * BLOCK_HEIGHT * 0.5)
            playerPoint = pd.geometry.point.new(playerX, playerY)
            closestPoint = surface:closestPointOnLineToPoint(playerPoint)
            
            --playerX  = maxX
            grounded = true
            onSlope = true
            groundBlock = collidingBlock
            gravityVelocity = 0
        end
        
        if maxX == -1 or grounded == false then
            groundBlock = nil
        end
        if onSlope then
            playerX = closestPoint.x
            drawGroundDebugHud(rightDirection, normal)
            --playerY = closestPoint.y
        end
        --end
        
        --clamp player position
        if playerX <= 0 then
            playerX = 0
        end
        
        if loopPlayer then
            drawClone = playerY < HALF_WIDTH or playerY > 240 - HALF_WIDTH
            
            if playerY < 0 then 
                playerY = 240
            elseif playerY > 240 then
                playerY = 0
            end
        else
            playerY = clamp(playerY, HALF_WIDTH, 240 - HALF_WIDTH)
        end
        
        
        if playerX == 0 and not grounded then
            grounded = true
        end
        
    end
    
    -- Draw player
    local cloneY = 0
    
    local running = inputY ~= 0
    
    local focusX = -1
    local focusY = -1
    
    if activeBlock ~= nil then
        focusX = activeBlock.posX
        focusY = activeBlock.posY
    end
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
    
    
    
    
    if grounded then
        gfx.fillCircleAtPoint(380, 220, 5)
    else
        gfx.drawCircleAtPoint(380, 220, 5)
    end
    
    
    
    gfx.drawText(inputVelocity.x, 0, 0)
    gfx.drawText(inputVelocity.y, 0, 25)
    gfx.drawText(gravityVelocity, 0, 50)
    
    xVelLastFrame = xVelocity
    yVelLastFrame = yVelocity
    
    lastFramePlayerX = playerX
    lastFramePlayerY = playerY
    
    end
