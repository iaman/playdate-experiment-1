import "CoreLibs/easing"
import "CoreLibs/timer"

local gfx <const> = playdate.graphics

-- Screen Properties
local screenWidth <const> = 200
local screenHeight <const> = 120
local rainAreaHorizontalBuffer <const> = 40

-- Timer Properties
local momentum, momentumTimer, preFadeMomentum
local momentumTimerMinLength <const> = 1000
local momentumTimerMaxLength <const> = 3000

-- Droplet consts
local droplets <const> = {}
local dropletSpeed <const> = 5
local dropletGravity <const> = playdate.geometry.vector2D.new( 0, 1 )
local dropletMinCount <const> = 2
local dropletMaxCount <const> = 4


-- Raindrop consts
local raindropMinDistance <const> = 4
local raindropMaxDistance <const> = 8
local raindrops <const> = {}
local raindropSpeed <const> = 9
local raindropMinPositions <const> = 2
local raindropMaxPositions <const> = 7
local raindropVerticalSpacing <const> = 1


-- Droplet type setup
local Droplet = {
  x = 0,
  y = 0,
  angle = 0
}

Droplet.__index = Droplet

function Droplet.new( x, y, angle )
  local newMeta = {
    cullMe = false,
    x = 0,
    y = screenHeight,
    vector
  }

  if ( type( x ) == "number" ) then
    newMeta.x = x
  end

  if ( type ( y ) == "number" ) then
    newMeta.y = y
  end

  if ( type ( angle ) ~= "number" ) then
    angle = 1.5 * math.pi
  end

  newMeta.vector = playdate.geometry.vector2D.new(
    math.cos( angle ) * dropletSpeed,
    math.sin( angle ) * dropletSpeed
  )

  local self = setmetatable( newMeta, Droplet )
  self.__index = newMeta

  return self
end

function Droplet.setRenderer()
  gfx.setColor( gfx.kColorWhite )
end

function Droplet:drip()
  self.vector:addVector( dropletGravity )

  self.x = self.vector.dx + self.x
  self.y = self.vector.dy + self.y

  if ( self.y >= screenHeight or self.y < 0 ) then
    self.cullMe = true
  end
end

function Droplet:render()
  gfx.drawPixel( self.x, self.y )
end


-- Raindrop type setup
local RainDrop = {
  positions = {},
}

RainDrop.__index = RainDrop

function RainDrop.new( x, y, positionCount )
  local newMeta = {
    positions = {}
  }

  if ( type( positionCount ) == "number" and positionCount > 2) then
    positionCount = math.floor( positionCount )
  else
    positionCount = 2
  end

  for i = 1, positionCount do
    newMeta.positions[i] = {}

    if ( type( x ) == "number" ) then
      newMeta.positions[i].x = x
    else
      newMeta.positions[i].x = 0
    end

    if ( type( y ) == "number" ) then
      newMeta.positions[i].y = y
    else
      newMeta.positions[i].y = 0
    end
  end

  local self = setmetatable( newMeta, RainDrop )
  self.__index = newMeta

  return self
end

function RainDrop.setRenderer()
  gfx.setLineCapStyle( gfx.kLineCapStyleRound )
  gfx.setLineWidth( 1 )
  gfx.setColor( gfx.kColorWhite )
end

function RainDrop:render()
  for i = 1, # self.positions - 1 do
    local position = self.positions[ i ]
    local nextPosition = self.positions[ i + 1 ]

    if ( position.x ~= nextPosition.x and position.y ~= nextPosition.y ) then
      gfx.drawLine( position.x, position.y, nextPosition.x, nextPosition.y )
    end
  end
end

function RainDrop:fall( momentum )
  if ( self.positions[ # self.positions ].y >= screenHeight ) then
    self:reset()
  else
    for i = # self.positions, 2, -1 do
      if ( self.positions[i].y < screenHeight and self.positions[i - 1].y >= screenHeight ) then
        if ( math.random( 0, 4 ) > 2 ) then
          local slope = ( self.positions[i - 1].y - self.positions[i].y ) / ( self.positions[i - 1].x - self.positions[i].x )
          local dropletXPos = -1 * ( ( ( self.positions[i - 1].y - 240 ) / slope ) - self.positions[i - 1].x )

          table.insert( droplets, Droplet.new( dropletXPos, screenHeight, math.random( 18, 30 ) / 16 * math.pi ) )
        end
      end

      self.positions[i].y = self.positions[i - 1].y
    end
  end

  if ( self.positions[ 1 ].x >= screenWidth + rainAreaHorizontalBuffer + raindropSpeed ) then
    for i = 1, # self.positions do
      self.positions[ i ].x = self.positions[ i ].x - ( screenWidth + rainAreaHorizontalBuffer ) - 2 * raindropSpeed
    end
  elseif ( self.positions[ 1 ].x <= -1 * raindropSpeed ) then
    for i = 1, # self.positions do
      self.positions[ i ].x = self.positions[ i ].x + ( screenWidth + rainAreaHorizontalBuffer ) + 2 * raindropSpeed
    end
  else
    for i = # self.positions, 2, -1 do
      self.positions[i].x = self.positions[i - 1].x
    end
  end

  local raindropAngle = math.random( -7, 7 ) / 100 + momentum

  self.positions[ 1 ].x = math.cos( raindropAngle ) * raindropSpeed + self.positions[ 1 ].x
  self.positions[ 1 ].y = math.sin( raindropAngle ) * raindropSpeed + self.positions[ 1 ].y
end

function RainDrop:reset()
  local newY = screenHeight - self.positions[ 1 ].y

  for i = 1, # self.positions do
    self.positions[ i ].y = newY
  end
end


-- Initial set-up
function startUp()
  playdate.display.setScale( 2 )
  momentum = 0
  momentumTimer = playdate.timer.new( momentumTimerMinLength, 1, 0, playdate.easingFunctions.outQuad )

  momentumTimer:pause()

  momentumTimer.updateCallback = function( timer )
    momentum = preFadeMomentum * timer.value
  end

  momentumTimer.repeats = true

  momentumTimer.timerEndedCallback = function ( timer )
    momentumTimer.duration = momentumTimerMinLength
    momentum = 0
    preFadeMomentum = 0
    momentumTimer:pause()
  end

  local x = -1 * rainAreaHorizontalBuffer
  local y = 0
  local i = 1

  while ( x <= screenWidth + rainAreaHorizontalBuffer ) do
    x = x + math.random( raindropMinDistance, raindropMaxDistance )

    while ( y >= -1 * screenHeight ) do
      local positionCount = math.random( raindropMinPositions, raindropMaxPositions )

      raindrops[i] = RainDrop.new( x, y - math.random( 0, raindropSpeed * positionCount ), positionCount )
      i = i + 1

      y = y - ( raindropSpeed * ( positionCount + raindropVerticalSpacing ) )
    end

    y = 0
  end

  gfx.setBackgroundColor( gfx.kColorBlack )
  gfx.setImageDrawMode( gfx.kColorXOR )

  gfx.clear()
end

startUp()


-- Main loop
function playdate.update()
  local crankChange, crankChangeAccel = playdate.getCrankChange()

  local parsedMomentum = 0

  if ( momentum < 720 and momentum > -720 ) then
    momentum += crankChangeAccel
  end

  if ( momentum > 720 ) then
    momentum = 720
  elseif ( momentum < -720 ) then
    momentum = -720
  end

  parsedMomentum = ( ( momentum / 2880 ) + 0.5 ) * math.pi

  if ( crankChange > 0 or crankChange < 0 ) then
    preFadeMomentum = momentum
    momentumTimer:reset()

    if ( momentumTimer.duration < momentumTimerMaxLength ) then
      momentumTimer.duration += 30
    end

    if ( momentumTimer.duration > momentumTimerMaxLength ) then
      momentumTimer.duration = momentumTimerMaxLength
    end
  elseif ( momentumTimer.currentTime < 1 ) then
    preFadeMomentum = momentum
    momentumTimer:start()
  end

  gfx.clear()

  RainDrop.setRenderer()

  for i = 1, # raindrops do
    raindrops[i]:fall( parsedMomentum )
    raindrops[i]:render()
  end

  Droplet.setRenderer()

  for i = 1, # droplets do
    droplets[i]:drip()
    droplets[i]:render()
  end

  for i = # droplets, 1, -1 do
    if ( droplets[i].cullMe ) then
      droplets[i].__index = nil
      droplets[i] = nil
      table.remove( droplets, i )
    end
  end

  playdate.timer.updateTimers()
end