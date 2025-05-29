

playerSpriteSmall = playdate.graphics.image.new(16,16)
playdate.graphics.pushContext(playerSpriteSmall)
	--body
	playdate.graphics.drawRoundRect(4, 6, 8, 10, 1)
	--eye
	playdate.graphics.drawRoundRect(6, 10, 4, 4, 2)
playdate.graphics.popContext()

playerSprite = playdate.graphics.image.new(32,32)
playdate.graphics.pushContext(playerSprite)
	--body
	playdate.graphics.fillRoundRect(6, 8, 26, 16, 3)
	
	--leg_left
	playdate.graphics.fillRoundRect(0, 12, 6, 2, 2)
	--leg_right
	playdate.graphics.fillRoundRect(0, 18, 6, 2, 2)

	
	--eye
	playdate.graphics.setColor(playdate.graphics.kColorWhite)
	playdate.graphics.fillRoundRect(18, 12, 8, 8, 2)
	
	--pupil
	--playdate.graphics.setColor(playdate.graphics.kColorBlack)
	--playdate.graphics.fillCircleAtPoint(22, 16, 2)
	
playdate.graphics.popContext()

playerSpriteRunning = playdate.graphics.image.new(32,32)
playdate.graphics.pushContext(playerSpriteRunning)
	--body
	playdate.graphics.fillRoundRect(6, 8, 26, 16, 3)
	
	--leg_left
	playdate.graphics.fillRoundRect(0, 12, 6, 2, 2)
	--leg_right
	playdate.graphics.fillRoundRect(2, 18, 4, 2, 2)
	
	
	--eye
	playdate.graphics.setColor(playdate.graphics.kColorWhite)
	playdate.graphics.fillRoundRect(18, 12, 8, 8, 2)
	
	--pupil
	--playdate.graphics.setColor(playdate.graphics.kColorBlack)
	--playdate.graphics.fillCircleAtPoint(22, 16, 2)
playdate.graphics.popContext()

playerPupil = playdate.graphics.image.new(32,32)
playdate.graphics.pushContext(playerPupil)
	playdate.graphics.setColor(playdate.graphics.kColorBlack)
	playdate.graphics.fillCircleAtPoint(22, 16, 2)
playdate.graphics.popContext()