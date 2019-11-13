-- use "/^(SymGauge).*/i" to filter for messages in the simulator debug dialog of this widget.
-- Author: Sven Bardos ()
-- Thanks to RealTadango (https://github.com/RealTadango/FrSky) for his lua script repos.

local widgetName = 'SymGauge'

local options = {
    {'Source', SOURCE, 1},
    {'Min', VALUE, -1024, -1024, 1024},
    {'Max', VALUE, 1024, -1024, 1024},
    {'Needle', COLOR, WHITE},
    {'Spot1', VALUE, 0, -1024, 1024}
    -- {"Spot2", VALUE, 0, -1024, 1024}, -- https://github.com/opentx/opentx/issues/4741 current limit of options = 5
    -- {"RMod", STRING, "Damp"},
    -- {"LMod", STRING, "Head"},
    -- {"Off", STRING, "Off"},
}

-- Constants due the limit of options in current firmware 2.3.1
local leftModeStr = 'Head'
local rightModeStr = 'Damp'
local offModeStr = 'Off'
local dumpEnabled = false --set to 'true' to see some debug infos in the simulator.
local stepSize
local radAngle
local spotBottomOffset
local radSpot1Angle
local spotCircleRadius
local spotLength
local spot2Value = 0 -- change this value to activate a second sweet spot. Unfortunately this will be activated for all widget instances.

local function background(wgt)
    return
end

function create(zone, options)
    local context = {zone = zone, options = options}
    return context
end

function drawGauge(context)
    if context == nil then
        dmp('drawGauge: context == nil')
        return
    end

    if context.back == nil then
        imageFile = '/WIDGETS/SymGauge/sg_' .. context.zone.h .. '.png'
        dmp('selected imageFile: ' .. imageFile)

        context.back = Bitmap.open(imageFile)

        if context.back == nil then
            return
        end

        w, h = Bitmap.getSize(context.back)
        context.bmpWidth = w
        context.bmpHeight = h

        dmp('imageFile width: ' .. context.bmpWidth)
        dmp('imageFile height: ' .. context.bmpHeight)
        dmp('zone width: ' .. context.zone.w)
        dmp('zone height: ' .. context.zone.h)
    end

    lcd.drawBitmap(context.back, context.zone.x, context.zone.y)
    value = getValue(context.options.Source)

    if (value == nil) then
        return
    end

    range =
        math.abs(
        math.min(context.options.Min, context.options.Max) - math.max(context.options.Min, context.options.Max)
    )
    stepSize = math.pi / range
    radAngle = stepSize * value + math.pi -- + math.pi to rotate to the y-axis, so "0" is vertically aligned.

    --Some pre calculation that may be overridden when in zone "DrawText2P1", because in this mode we can't be relative to the image height anymore.
    innerCircleRadius = context.bmpHeight * 0.15
    needleLength = context.bmpHeight * 0.85 - innerCircleRadius

    spotBottomOffset = context.bmpHeight * 0.015
    radSpot1Angle = stepSize * context.options.Spot1 + math.pi -- + math.pi to rotate to the y-axis, so "0" is vertically aligned.
    spotCircleRadius = context.bmpHeight * 0.7
    spotLength = context.bmpHeight * 0.2
    -- Zone sizes WxH(wo menu / w menu):
    -- TopBar 39x78
    -- 2x4 = 160x32
    -- 2x2 = 225x122/98
    -- 2x1 = 225x252/207
    -- 2+1 = 192x152 & 180x70
    -- 1x1 = 460/390x252/217/172
    -- Heights: 32,39,70,98,122,172,207,217,252
    if
        (context.zone.w == 460 or context.zone.w == 450 or context.zone.w == 390) and
            (context.zone.h == 252 or context.zone.h == 217 or context.zone.h == 207 or context.zone.h == 172)
     then
        --dmp('DrawText1x1Zone')
        DrawText1x1Zone(context, value)
    elseif (context.zone.w == 192 and context.zone.h == 152) then
        --dmp('DrawText2P1')
        needleLength = 95 * 0.85 - innerCircleRadius -- 95px is the height of the gauge. We can't use the image height, because our image is 152px
        spotBottomOffset = 95 * 0.015
        spotCircleRadius = 95 * 0.7
        spotLength = 95 * 0.2
        DrawText2P1(context, value)
    elseif (context.zone.w == 160 and context.zone.h == 32) then
        dmp('DrawText2x4')
        DrawText2x4(context, value)
    else
        flags1 = CENTER + TEXT_COLOR
        flags2 = CENTER + TEXT_BGCOLOR

        textBottomOffset = context.bmpHeight * 0.6

        lcd.drawNumber(
            math.floor(context.zone.x + context.bmpWidth * 0.5),
            math.floor(context.zone.y + context.bmpHeight - textBottomOffset),
            value,
            flags1
        )
        -- draw text again with small shadow effect (-1) for better contrast.
        lcd.drawNumber(
            math.floor(context.zone.x + (context.bmpWidth - 1) * 0.5),
            math.floor(context.zone.y + context.bmpHeight - textBottomOffset - 1),
            value,
            flags2
        )
    end

    --draw sweet spot1
    if context.options.Spot1 ~= 0 then
        radSpot1Angle = stepSize * context.options.Spot1 + math.pi -- + math.pi to rotate to the y-axis, so "0" is vertically aligned.
        x = math.floor(context.zone.x + (context.bmpWidth * 0.5))
        y = math.floor(context.zone.y + context.bmpHeight - spotBottomOffset)
        x1 = math.floor(x - (spotCircleRadius * math.sin(radSpot1Angle)))
        y1 = math.floor(y + (spotCircleRadius * math.cos(radSpot1Angle)))
        x2 = math.floor(x1 - (spotLength * math.sin(radSpot1Angle)))
        y2 = math.floor(y1 + (spotLength * math.cos(radSpot1Angle)))
        lcd.setColor(CUSTOM_COLOR, lcd.RGB(248, 248, 248)) -- Color of the sweet spot1
        lcd.drawLine(x1, y1, x2, y2, SOLID, CUSTOM_COLOR)
    end

     --draw sweet spot2
     if context.options.Spot1 ~= 0 then
        radSpot2Angle = stepSize * spot2Value + math.pi -- + math.pi to rotate to the y-axis, so "0" is vertically aligned.
        x = math.floor(context.zone.x + (context.bmpWidth * 0.5))
        y = math.floor(context.zone.y + context.bmpHeight - spotBottomOffset)
        x1 = math.floor(x - (spotCircleRadius * math.sin(radSpot2Angle)))
        y1 = math.floor(y + (spotCircleRadius * math.cos(radSpot2Angle)))
        x2 = math.floor(x1 - (spotLength * math.sin(radSpot2Angle)))
        y2 = math.floor(y1 + (spotLength * math.cos(radSpot2Angle)))
        lcd.setColor(CUSTOM_COLOR, lcd.RGB(248, 248, 248)) -- Color of the sweet spot2
        lcd.drawLine(x1, y1, x2, y2, SOLID, CUSTOM_COLOR)
    end

    --draw needle
    bottomOffset = context.bmpHeight * 0.015 -- make the rotation point of the needle a little bit above the bottom border of the bitmap.
    x = math.floor(context.zone.x + (context.bmpWidth * 0.5))
    y = math.floor(context.zone.y + context.bmpHeight - bottomOffset)
    x1 = math.floor(x - (innerCircleRadius * math.sin(radAngle)))
    y1 = math.floor(y + (innerCircleRadius * math.cos(radAngle)))
    x2 = math.floor(x1 - (needleLength * math.sin(radAngle)))
    y2 = math.floor(y1 + (needleLength * math.cos(radAngle)))

    lcd.setColor(CUSTOM_COLOR, context.options.Needle)
    lcd.drawLine(x1, y1, x2, y2, SOLID, CUSTOM_COLOR)
end

function DrawText2x4(context, value)
    valueFlags1 = CENTER + TEXT_COLOR + MIDSIZE
    valueflags2 = CENTER + TEXT_BGCOLOR + MIDSIZE

    sourceFlags1 = CENTER + TEXT_COLOR + SMLSIZE
    sourceflags2 = CENTER + TEXT_BGCOLOR + SMLSIZE

    modeFlags1 = CENTER + TEXT_COLOR + SMLSIZE
    modeFlags2 = CENTER + TEXT_BGCOLOR + SMLSIZE

    modeBottomOffset = context.bmpHeight * 1
    valueBottomOffset = context.bmpHeight * 0.7
    sourceBottomOffset = context.bmpHeight * 1
    valueRightOffset = context.zone.w * 0.275
    sourceRightOffset = context.zone.w * 0.05
    modeRightOffset = context.zone.w * 0.5

    lcd.drawNumber(
        math.floor(context.zone.x + context.zone.w - valueRightOffset),
        math.floor(context.zone.y + context.bmpHeight - valueBottomOffset),
        value,
        valueFlags1
    )

    lcd.drawNumber(
        math.floor((context.zone.x + context.zone.w - 1) - valueRightOffset),
        math.floor(context.zone.y + context.bmpHeight - valueBottomOffset - 1),
        value,
        valueflags2
    )

    lcd.drawSource(
        math.floor(context.zone.x + context.zone.w - sourceRightOffset),
        math.floor(context.zone.y + context.bmpHeight - sourceBottomOffset),
        context.options.Source,
        sourceFlags1
    )

    lcd.drawSource(
        math.floor(context.zone.x + context.zone.w - 1 - sourceRightOffset),
        math.floor(context.zone.y + context.bmpHeight - sourceBottomOffset - 1),
        context.options.Source,
        sourceflags2
    )
    -- mode text
    if value == 0 then
        lcd.drawText(
            math.floor(context.zone.x + context.zone.w - modeRightOffset),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset),
            offModeStr,
            modeFlags1
        )

        lcd.drawText(
            math.floor(context.zone.x + context.zone.w - modeRightOffset),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset - 1),
            offModeStr,
            modeFlags2
        )
    elseif value > 0 then
        lcd.drawText(
            math.floor(context.zone.x + context.zone.w - modeRightOffset),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset),
            rightModeStr,
            modeFlags1
        )

        lcd.drawText(
            math.floor(context.zone.x + context.zone.w - 1 - modeRightOffset),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset - 1),
            rightModeStr,
            modeFlags2
        )
    elseif value < 0 then
        lcd.drawText(
            math.floor(context.zone.x + context.zone.w - modeRightOffset),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset),
            leftModeStr,
            modeFlags1
        )

        lcd.drawText(
            math.floor(context.zone.x + context.zone.w - 1 - modeRightOffset),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset - 1),
            leftModeStr,
            modeFlags2
        )
    end
end

function DrawText2P1(context, value)
    valueFlags1 = CENTER + TEXT_COLOR + DBLSIZE
    valueflags2 = CENTER + TEXT_BGCOLOR + DBLSIZE

    sourceFlags1 = CENTER + TEXT_COLOR + MIDSIZE
    sourceflags2 = CENTER + TEXT_BGCOLOR + MIDSIZE

    modeFlags1 = CENTER + TEXT_COLOR + DBLSIZE
    modeFlags2 = CENTER + TEXT_BGCOLOR + DBLSIZE

    modeBottomOffset = context.bmpHeight * 0.85
    valueBottomOffset = context.bmpHeight * 0.35
    sourceBottomOffset = context.bmpHeight * 1

    lcd.drawNumber(
        math.floor(context.zone.x + context.bmpWidth * 0.5),
        math.floor(context.zone.y + context.bmpHeight - valueBottomOffset),
        value,
        valueFlags1
    )

    lcd.drawNumber(
        math.floor(context.zone.x + (context.bmpWidth - 1) * 0.5),
        math.floor(context.zone.y + context.bmpHeight - valueBottomOffset - 1),
        value,
        valueflags2
    )

    lcd.drawSource(
        math.floor(context.zone.x + context.bmpWidth * 0.5),
        math.floor(context.zone.y + context.bmpHeight - sourceBottomOffset),
        context.options.Source,
        sourceFlags1
    )

    lcd.drawSource(
        math.floor(context.zone.x + (context.bmpWidth - 1) * 0.5),
        math.floor(context.zone.y + context.bmpHeight - sourceBottomOffset - 1),
        context.options.Source,
        sourceflags2
    )
    -- mode text
    if value == 0 then
        lcd.drawText(
            math.floor(context.zone.x + context.bmpWidth * 0.5),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset),
            offModeStr,
            modeFlags1
        )

        lcd.drawText(
            math.floor(context.zone.x + (context.bmpWidth - 1) * 0.5),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset - 1),
            offModeStr,
            modeFlags2
        )
    elseif value > 0 then
        lcd.drawText(
            math.floor(context.zone.x + context.bmpWidth * 0.5),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset),
            rightModeStr,
            modeFlags1
        )

        lcd.drawText(
            math.floor(context.zone.x + (context.bmpWidth - 1) * 0.5),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset - 1),
            rightModeStr,
            modeFlags2
        )
    elseif value < 0 then
        lcd.drawText(
            math.floor(context.zone.x + context.bmpWidth * 0.5),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset),
            leftModeStr,
            modeFlags1
        )

        lcd.drawText(
            math.floor(context.zone.x + (context.bmpWidth - 1) * 0.5),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset - 1),
            leftModeStr,
            modeFlags2
        )
    end
end

function DrawText1x1Zone(context, value)
    valueFlags1 = CENTER + TEXT_COLOR + DBLSIZE
    valueflags2 = CENTER + TEXT_BGCOLOR + DBLSIZE

    sourceFlags1 = CENTER + TEXT_COLOR + MIDSIZE
    sourceflags2 = CENTER + TEXT_BGCOLOR + MIDSIZE

    modeFlags1 = CENTER + TEXT_COLOR + MIDSIZE
    modeFlags2 = CENTER + TEXT_BGCOLOR + MIDSIZE

    modeBottomOffset = context.bmpHeight * 0.35
    valueBottomOffset = context.bmpHeight * 0.525
    sourceBottomOffset = context.bmpHeight * 0.65

    lcd.drawNumber(
        math.floor(context.zone.x + context.bmpWidth * 0.5),
        math.floor(context.zone.y + context.bmpHeight - valueBottomOffset),
        value,
        valueFlags1
    )

    lcd.drawNumber(
        math.floor(context.zone.x + (context.bmpWidth - 1) * 0.5),
        math.floor(context.zone.y + context.bmpHeight - valueBottomOffset - 1),
        value,
        valueflags2
    )

    lcd.drawSource(
        math.floor(context.zone.x + context.bmpWidth * 0.5),
        math.floor(context.zone.y + context.bmpHeight - sourceBottomOffset),
        context.options.Source,
        sourceFlags1
    )

    lcd.drawSource(
        math.floor(context.zone.x + (context.bmpWidth - 1) * 0.5),
        math.floor(context.zone.y + context.bmpHeight - sourceBottomOffset - 1),
        context.options.Source,
        sourceflags2
    )
    -- mode text
    if value == 0 then
        lcd.drawText(
            math.floor(context.zone.x + context.bmpWidth * 0.5),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset),
            offModeStr,
            modeFlags1
        )

        lcd.drawText(
            math.floor(context.zone.x + (context.bmpWidth - 1) * 0.5),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset - 1),
            offModeStr,
            modeFlags2
        )
    elseif value > 0 then
        lcd.drawText(
            math.floor(context.zone.x + context.bmpWidth * 0.5),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset),
            rightModeStr,
            modeFlags1
        )

        lcd.drawText(
            math.floor(context.zone.x + (context.bmpWidth - 1) * 0.5),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset - 1),
            rightModeStr,
            modeFlags2
        )
    elseif value < 0 then
        lcd.drawText(
            math.floor(context.zone.x + context.bmpWidth * 0.5),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset),
            leftModeStr,
            modeFlags1
        )

        lcd.drawText(
            math.floor(context.zone.x + (context.bmpWidth - 1) * 0.5),
            math.floor(context.zone.y + context.bmpHeight - modeBottomOffset - 1),
            leftModeStr,
            modeFlags2
        )
    end
end

function update(context, options)
    context.options = options
    context.back = nil
end

function refresh(context)
    dmpContext(context)
    drawGauge(context)
end

function dmp(str)
    if dumpEnabled then
        print(widgetName .. ': ' .. str)
    end
end

function dmpContext(context)
    if dumpEnabled then
        for key, value in pairs(context) do
            print('\t', key, value)
            if key == 'options' then
                for okey, ovalue in pairs(value) do
                    print('\t\t', okey, ovalue)
                end
            end
        end
    end
end

return {
    name = widgetName,
    options = options,
    create = create,
    update = update,
    background = background,
    refresh = refresh
}
