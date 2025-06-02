import "imports"

local pd <const> = playdate
local gfx <const> = playdate.graphics

-- Defining player variables
local playerX, playerY = 0, PLAYER_SPAWN_Y
local lastFramePlayerX = playerX
local lastFramePlayerY = playerY
local xVelocity, yVelocity = 0, 0
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

if pd.isSimulator then
    rightButton = pd.kButtonRight
    leftButton = pd.kButtonLeft
    jumpButton = pd.kButtonUp
    
end

SpikeBlock =
{
    
} 
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
    if self == activeBlock then
        gfx.fillPolygon(transformedPolygon)
    else
        gfx.drawPolygon(transformedPolygon)
    end
    --gfx.drawLine(self.line)
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
    xVelocity = PLAYER_JUMP_VELOCITY
end

-- playdate.update function is required in every project!
function playdate.update()
    -- Clear screen
    gfx.clear()
    
    --update delta time
    local deltaTime = playdate.getElapsedTime()
    playdate.resetElapsedTime()
    
    -- local currentTime = pd.getCurrentTimeMilliseconds()
    -- if  currentTime - lastBlockSpawn > TIME_BETWEEN_BLOCK_FALL then
    --     lastBlockSpawn = currentTime
    --     nextBlock()
    -- end
    
    --playdate.graphics.drawText(deltaTime, 0, 0)
    
    local inputX = 0
    local inputY = 0
    local rightDirection = pd.geometry.vector2D.new(0, -1)
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
        end
        
        
        
        rightDirection.y *= -1
        onSlope = false
        if grounded and groundBlock ~= nil then
            onSlope = true
            rightDirection:projectAlong(groundBlock.line:segmentVector())
            rightDirection:normalize()
            
        end
        
        if (not pd.buttonIsPressed(jumpButton) and xVelocity > JUMP_CANCEL_THRESHOLD) then
            xVelocity = PLAYER_MIN_JUMP_VELOCITY
        end
        
        print(rightDirection)
        --print(rightDirection:magnitude())
        print(inputY)
        
        if inputY ~= 0 then
            --check if we're turning around
            if (yVelocity > 0 and inputY < 0) or (yVelocity < 0 and inputY > 0) then
                --yVelocity += inputY * DRAG_ACCELERATION * deltaTime
                yVelocity += inputY * DRAG_ACCELERATION * rightDirection.y * deltaTime
                xVelocity += DRAG_ACCELERATION * rightDirection.x * deltaTime
                playdate.graphics.drawText("turning!", 0, 30)
            end
                
            --yVelocity += inputY * PLAYER_ACCELERATION *  deltaTime
            yVelocity += inputY * PLAYER_ACCELERATION * rightDirection.y * deltaTime
            xVelocity += PLAYER_ACCELERATION * rightDirection.x * deltaTime
            
        else
            local dragSign = 1
            if yVelocity >= 0 then
                dragSign = -1
            end
            
            yVelocity += dragSign * DRAG_ACCELERATION *  deltaTime
            --yVelocity += dragSign * DRAG_ACCELERATION * rightDirection.y *  deltaTime
            --xVelocity += dragSign * DRAG_ACCELERATION * rightDirection.x * deltaTime
            
            -- make sure we don't overshoot
            if (dragSign == -1 and yVelocity < 0) or (dragSign == 1 and yVelocity > 0) then
                yVelocity = 0
            end
        end
        
        if xVelocity > 0 then
            xVelocity -= PLAYER_GRAVITY * deltaTime
        else
            xVelocity -= FALLING_GRAVITY * deltaTime
        end
        
        if grounded then
            xVelocity = 0
        end
    
        
        --clamp velocity
        yVelocity = clamp(yVelocity, -PLAYER_MAX_VELOCITY, PLAYER_MAX_VELOCITY)
        if xVelocity < -PLAYER_MAX_FALL_VELOCITY then 
            xVelocity = -PLAYER_MAX_FALL_VELOCITY
        end
        
        -- Move player
        
        local deltaPosX = xVelocity * deltaTime
        local deltaPosY = yVelocity * deltaTime
        
        playerX += deltaPosX
        playerY += deltaPosY
        
        local p2x = playerX - GROUND_RAYCAST_LENGTH
        local p2y = playerY
        
        raycastLine = pd.geometry.lineSegment.new(playerX + GROUND_RAYCAST_OFFSET, playerY, p2x, p2y)
        
        --gfx.drawLine(raycastLine)
        
        --check collision with box lines
        grounded = false
        
        if xVelocity <= 0 then
            local intersectingBlocks = {}
            for i, block in ipairs(spikeBlocks) do
                local intersects, intersection = raycastLine:intersectsLineSegment(block.line)
                if intersects then
                    table.insert(intersectingBlocks, {block, intersection})
                end
            end
            local maxX = -1
            local surface = nil
            local collidingBlock
            for i, intersection in ipairs(intersectingBlocks) do
                if intersection[2].x > maxX then
                    maxX = intersection[2].x
                    collidingBlock = intersection[1]
                end
            end
            if maxX ~= -1 then
                
                normal = collidingBlock.line:segmentVector():rightNormal()
                
                if normal:dotProduct(raycastLine:segmentVector()) > 0 then
                    normal = collidingBlock.line:segmentVector():leftNormal()
                end
                
                surface = collidingBlock.line:offsetBy(normal.x * BLOCK_HEIGHT * 0.5, normal.y * BLOCK_HEIGHT * 0.5)
                playerPoint = pd.geometry.point.new(playerX, playerY)
                closestPoint = surface:closestPointOnLineToPoint(playerPoint)
                
                --playerX  = maxX
                grounded = true
                onSlope = true
                groundBlock = collidingBlock
            end
            
            if maxX == -1 or grounded == false then
                groundBlock = nil
            end
        end
        
        --clamp player position
        if playerX <= 0 then
            playerX = 0
        end
        
        if playerX == 0 and not grounded then
            grounded = true
        end
        
        
    end
    -- Draw player
    local flipArg = gfx.kImageUnflipped
    if inputY ~= 0 then
        local flip = (pd.getCurrentTimeMilliseconds() % 200) < 100
        if flip then 
            flipArg = gfx.kImageFlippedY
        end
        
        playerSpriteRunning:drawAnchored(playerX, playerY, 0.0, 0.5, flipArg)
    else
        playerSprite:drawAnchored(playerX, playerY, 0.0, 0.5)
    end
    
    --local angle = math.rad(playdate.getCrankPosition())
    
    local pupilOffsetX = 0
    local pupilOffsetY = 0
    
    if activeBlock ~= nil then
        
        local deltaX = activeBlock.posX - (playerX)
        local deltaY = activeBlock.posY - playerY
        local delta = pd.geometry.vector2D.new(deltaX, deltaY)
        delta:normalize()
        --print(deltaX, deltaY, delta.x, delta.y)
        pupilOffsetX = math.floor(delta.x * EYE_LOOK_RADIUS)
        pupilOffsetY = math.floor(delta.y * EYE_LOOK_RADIUS)
    end
    
    --draw pupil
    --gfx.setColor(gfx.kColorBlack)
    --gfx.fillCircleAtPoint(playerX + 22.0, playerY, 2)
    playerPupil:drawAnchored(playerX + pupilOffsetX, playerY + pupilOffsetY, 0.0, 0.5)
    
    if grounded then
        gfx.fillCircleAtPoint(380, 220, 5)
    else
        gfx.drawCircleAtPoint(380, 220, 5)
    end
    
    groundSlopePoint = pd.geometry.point.new(210, 170)
    groundSlopeEnd = groundSlopePoint + (rightDirection * 30)
    
    gfx.drawLine(groundSlopePoint.x, groundSlopePoint.y, groundSlopeEnd.x, groundSlopeEnd.y)
    
    gfx.drawText(xVelocity, 0, 0)
    gfx.drawText(yVelocity, 0, 20)
    
    xVelLastFrame = xVelocity
    yVelLastFrame = yVelocity
    
    lastFramePlayerX = playerX
    lastFramePlayerY = playerY
    
end
