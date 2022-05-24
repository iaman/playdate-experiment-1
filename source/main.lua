import "CoreLibs/easing"
import "CoreLibs/timer"

local gfx <const> = playdate.graphics
local screenWidth <const> = 400
local screenHeight <const> = 240
local rainAreaHorizontalBuffer <const> = 200
local momentum, momentumTimer

local droplets <const> = {}
local dropletSpeed <const> = 6
local dropletMinCount <const> = 2
local dropletMaxCount <const> = 4


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
    angle = 0
  }

  if ( type( x ) == "number" ) then
    newMeta.x = x
  end

  if ( type ( y ) == "number" ) then
    newMeta.y = y
  end

  if ( type ( angle ) == "number" ) then
    newMeta.angle = angle
  end

  local self = setmetatable( newMeta, Droplet )
  self.__index = newMeta

  return self
end

function Droplet.setRenderer()
  gfx.setColor( gfx.kColorWhite )
end

function Droplet:drip()
  self.x = math.cos( self.angle ) * dropletSpeed + self.x
  self.y = math.sin( self.angle ) * dropletSpeed + self.y

  if ( self.angle > 1.5 * math.pi ) then
    self.angle = self.angle + math.pi * math.random( 2, 4 ) / 32
  else
    self.angle = self.angle - math.pi * math.random( 2, 4 ) / 32
  end

  if ( self.y >= screenHeight or self.y < 0 ) then
    self.cullMe = true
  end
end

function Droplet:render()
  gfx.drawPixel( self.x, self.y )
  gfx.drawPixel( self.x, self.y + 1 )
  gfx.drawPixel( self.x, self.y - 1 )
  gfx.drawPixel( self.x - 1, self.y )
  gfx.drawPixel( self.x + 1, self.y )
end

local raindropMinDistance <const> = 8
local raindropMaxDistance <const> = 16
local raindrops <const> = {}
local raindropSpeed <const> = 18
local raindropMinPositions <const> = 2
local raindropMaxPositions <const> = 8
local raindropVerticalSpacing <const> = 1

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
  gfx.setLineWidth( 2 )
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
        local slope = ( self.positions[i - 1].y - self.positions[i].y ) / ( self.positions[i - 1].x - self.positions[i].x )
        local dropletXPos = -1 * ( ( ( self.positions[i - 1].y - 240 ) / slope ) - self.positions[i - 1].x )

        table.insert( droplets, Droplet.new( dropletXPos, screenHeight, math.random( 18, 30 ) / 16 * math.pi ) )
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

function startUp()
  momentum = 0
  momentumTimer = playdate.timer.new( 2000, 1, 0, playdate.easingFunctions.outQuad )

  momentumTimer:pause()

  momentumTimer.updateCallback = function( timer )
    momentum = momentum * timer.value
  end

  momentumTimer.repeats = true

  momentumTimer.timerEndedCallback = function ( timer )
    momentum = 0;
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

function playdate.update()
  local crankChange, crankChangeAccel = playdate.getCrankChange()

  local parsedMomentum = 0

  if ( momentum < math.pi and momentum > -math.pi ) then
    momentum += crankChangeAccel / 720
  end

  if ( momentum > 0.25 * math.pi ) then
    momentum = 0.25 * math.pi
  elseif ( momentum < -0.25 * math.pi ) then
    momentum = -0.25 * math.pi
  end

  parsedMomentum = momentum + 0.5 * math.pi

  if ( crankChange > 0 or crankChange < 0 ) then
    momentumTimer:reset()
  elseif ( momentumTimer.currentTime < 1 ) then
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