import "CoreLibs/graphics"
import "CoreLibs/easing"
import "CoreLibs/timer"

local gfx <const> = playdate.graphics

-- Screen Properties
local screenScale <const> = 1
local screenWidth <const> = 400 / screenScale
local screenHeight <const> = 240 / screenScale

-- Timer Properties
local momentum, momentumTimer, preFadeMomentum
local momentumTimerMinLength <const> = 1000
local momentumTimerMaxLength <const> = 3000

-- Droplet consts
local droplets <const> = {}
local dropletSpeed <const> = 10 / screenScale
local dropletGravity <const> = playdate.geometry.vector2D.new( 0, 2 / screenScale )
local dropletMinCount <const> = 2
local dropletMaxCount <const> = 4
local dropletSize <const> = 1 / screenScale


-- Raindrop consts
local raindropDistance <const> = 40 / screenScale
local raindropVariance <const> = 16 / screenScale
local raindrops <const> = {}
local raindropSpeed <const> = 18 / screenScale
local raindropMinSegments <const> = 1
local raindropMaxSegments <const> = 6
local raindropVerticalSpacing <const> = 2
local raindropThickness <const> = 2 / screenScale
local rainAreaHorizontalBuffer <const> = ( raindropSpeed / 2 * math.sqrt( 2 ) )


-- Droplet type setup
local Droplet = {
  renderMe = false,
  x = 0,
  y = screenHeight
}

Droplet.__index = Droplet

function Droplet.new()
  local newMeta = {}

  newMeta.vector = playdate.geometry.vector2D.new( 0, 0 )

  local self <const> = setmetatable( newMeta, Droplet )
  self.__index = newMeta

  return self
end

function Droplet:drip()
  self.vector:addVector( dropletGravity )

  self.x += self.vector.dx
  self.y += self.vector.dy

  if ( self.y >= screenHeight or self.y < 0 ) then
    self.renderMe = false
  end
end

function Droplet:reset( x, y, angle )
  if ( type ( x ) == "number" ) then
    self.x = x
  end

  if ( type ( y ) == "number" ) then
    self.y = y
  end

  if ( type ( angle ) ~= "number" ) then
    angle = 1.5 * math.pi
  end

  self.vector.dx = math.cos( angle ) * dropletSpeed
  self.vector.dy = math.sin( angle ) * dropletSpeed

  self.renderMe = true
end

function Droplet:render()
  gfx.fillCircleAtPoint( self.x, self.y, dropletSize )
end


-- Raindrop type setup
local RainDrop = {
  x = 0,
  y = 0
}

RainDrop.__index = RainDrop

function RainDrop.new( x, y, segmentCount )
  local newMeta = {
    segmentVectors = {},
    droplets = {}
  }

  if ( type( segmentCount ) == "number" and segmentCount > 2) then
    segmentCount = math.floor( segmentCount )
  else
    segmentCount = 2
  end

  if ( type( x ) == "number" ) then
    newMeta.x = x
  end

  if ( type( y ) == "number" ) then
    newMeta.y = y
  end

  local segmentVector <const> = playdate.geometry.vector2D.new( 0, 0 )

  for i = 1, segmentCount do
    newMeta.segmentVectors[ i ] = segmentVector
    newMeta.droplets[ i ] = Droplet.new()
  end

  local self <const> = setmetatable( newMeta, RainDrop )
  self.__index = newMeta

  return self
end

function RainDrop.setRenderer()
  gfx.setLineCapStyle( gfx.kLineCapStyleRound )
  gfx.setLineWidth( raindropThickness )
  gfx.setColor( gfx.kColorWhite )
end

function RainDrop:render()
  local currentX = self.x
  local currentY = self.y

  for i = 1, # self.segmentVectors do
    local segmentVector <const> = self.segmentVectors[ i ]
    local changeX <const> = segmentVector.dx
    local changeY <const> = segmentVector.dy

    if ( changeX ~= 0 or changeY ~= 0 ) then
      newX = currentX - changeX
      newY = currentY - changeY

      gfx.drawLine( currentX, currentY, newX, newY )

      currentX = newX
      currentY = newY
    end

    local droplet <const> = self.droplets[ i ]

    if ( droplet.renderMe ) then
      droplet:render()
    end
  end
end

function RainDrop:fall( momentum )

  for i = # self.segmentVectors, 1, -1 do
    if ( i ~= 1 ) then
      self.segmentVectors[ i ] = self.segmentVectors[ i - 1 ]
    end

    self.droplets[ i ]:drip()
  end

  if ( self.x >= screenWidth + rainAreaHorizontalBuffer + raindropSpeed ) then
    self.x -= ( screenWidth + rainAreaHorizontalBuffer ) + 2 * raindropSpeed
  elseif ( self.x <= -1 * raindropSpeed ) then
    self.x += ( screenWidth + rainAreaHorizontalBuffer ) + 2 * raindropSpeed
  end

  local raindropAngle <const> = math.random( -7, 7 ) / 100 + momentum

  self.segmentVectors[ 1 ] = playdate.geometry.vector2D.new(
    math.cos( raindropAngle ) * raindropSpeed,
    math.sin( raindropAngle ) * raindropSpeed
  )

  local firstSegmentVector <const> = self.segmentVectors[ 1 ]

  self.x += firstSegmentVector.dx
  self.y += firstSegmentVector.dy

  if ( self.y >= screenHeight ) then
    local currentX = self.x
    local currentY = self.y
    local newX = self.x
    local newY = self.y

    for i = 1, # self.segmentVectors do
      local segmentVector <const> = self.segmentVectors[ i ]
      local changeX <const> = segmentVector.dx
      local changeY <const> = segmentVector.dy

      newX = currentX - changeX
      newY = currentY - changeY

      if ( currentY >= screenHeight and newY < screenHeight and not self.droplets[ i ].renderMe ) then
        local slope = changeY / changeX
        local dropletXPos = -1 * ( ( ( newY - screenHeight ) / slope ) - newX )

        self.droplets[ i ]:reset( dropletXPos, screenHeight, math.random( 18, 30 ) / 16 * math.pi )
      end

      currentY = newY
      currentX = newX
    end

    if ( newY >= screenHeight ) then
      self:reset()
    end
  end
end

function RainDrop:reset()
  self.y = -2 * raindropSpeed
end


-- Initial set-up
function startUp()
  playdate.display.setScale( screenScale )
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

  while ( x <= screenWidth + rainAreaHorizontalBuffer ) do
    x = x + raindropDistance + math.random( -raindropVariance, raindropVariance )

    while ( y >= -1 * screenHeight ) do
      local segmentCount = math.random( raindropMinSegments, raindropMaxSegments )

      table.insert( raindrops, RainDrop.new( x, y - math.random( 0, raindropSpeed * segmentCount ), segmentCount ) )

      y = y - ( raindropSpeed * ( segmentCount + raindropVerticalSpacing ) )
    end

    y = 0
  end

  gfx.setBackgroundColor( gfx.kColorBlack )
  gfx.setImageDrawMode( gfx.kColorXOR )
  gfx.setClipRect( 0, 0, screenWidth, screenHeight )

  gfx.clear()
end

startUp()


-- Main loop
function playdate.update()
  local crankChange, crankChangeAccel = playdate.getCrankChange()

  if ( ( momentum < 720 and crankChange > 0 ) or ( momentum > -720 and crankChange < 0 ) ) then
    momentum += crankChangeAccel
  end

  if ( playdate.buttonIsPressed( playdate.kButtonLeft ) ) then
    momentum += 40
  elseif ( playdate.buttonIsPressed( playdate.kButtonRight ) ) then
    momentum -= 40
  end

  if ( momentum > 720 ) then
    momentum = 720
  elseif ( momentum < -720 ) then
    momentum = -720
  end

  local parsedMomentum <const> = ( ( momentum / 2880 ) + 0.5 ) * math.pi

  if ( crankChange > 0 or crankChange < 0 or playdate.buttonIsPressed( playdate.kButtonLeft ) or playdate.buttonIsPressed( playdate.kButtonRight ) ) then
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
    local raindrop <const> = raindrops[ i ]
    raindrop:fall( parsedMomentum )
    raindrop:render()
  end

  playdate.drawFPS()

  playdate.timer.updateTimers()
end