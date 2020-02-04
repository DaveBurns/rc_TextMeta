--[[
        ExtendedBackground.lua
--]]

local ExtendedBackground, dbg, dbgf = Background:newClass{ className = 'ExtendedBackground' }



--- Constructor for extending class.
--
--  @usage      Although theoretically possible to have more than one background task,
--              <br>its never been tested, and its recommended to just use different intervals
--              <br>for different background activities if need be.
--
function ExtendedBackground:newClass( t )
    return Background.newClass( self, t )
end



--- Constructor for new instance.
--
--  @usage      Although theoretically possible to have more than one background task,
--              <br>its never been tested, and its recommended to just use different intervals
--              <br>for different background activities if need be.
--
function ExtendedBackground:new( t )
    local interval
    local minInitTime
    local idleThreshold
    if app:getUserName() == '_RobCole_' and app:isAdvDbgEna() then
        interval = .1
        idleThreshold = 1
        minInitTime = 3
    else
        interval = .1
        idleThreshold = 1 -- (every other cycle) appx 1/sec.
        -- default min-init-time is 10-15 seconds or so.
    end    
    local o = Background.new( self, { interval=interval, minInitTime=minInitTime, idleThreshold=idleThreshold } )
    o.cache = lrMeta:createCache{} -- create "null" cache.
    return o
end



--- Initialize background task.
--
--  @param      call object - usually not needed, but its got the name, and context... just in case.
--
function ExtendedBackground:init( call )
    local s, m = textMeta:init() -- initialize stuff common to on-demand services as well as background task.
    if s then    
        self.initStatus = true
        -- this pref name is not assured nor sacred - modify at will.
        if not app:getPref( 'background' ) then -- check preference that determines if background task should start.
            self:quit() -- indicate to base class that background processing should not continue past init.
        end
    else
        self.initStatus = false
        app:logError( "Unable to initialize due to error: " .. str:to( m ) )
        app:show( { error="Unable to initialize." } )
    end
end



--- Process photo, presumably same logic for most-selected photo as
--
function ExtendedBackground:processPhoto( photo, call, idle )
    local s, m = cat:updatePrivate( 1, function( context, phase )
        local sts, chg = LrTasks.pcall( textMeta.updatePhoto, textMeta, photo, self.cache, true ) -- cache is null - accept uncached.
        if sts then
            if chg then
                app:logv( "photo metadata changed in background task: ^1", photo:getRawMetadata( 'path' ) )
            else
                --Debug.pause( "No change (background task) to: ^1", photo:getRawMetadata( 'path' ) )
            end
        else
            -- ###1 app:error( chg ) -- this can happen if update-photo throws an error due to photo being removed from catalog.
            -- this error is not clearing @28/Oct/2012 23:03.
        end
    end )
    if s then
        --dbgf( "Photo processed (background task): ^1", photo:getRawMetadata( 'path' ) )
        -- self.enoughForNow = true -- only significant when called from periodic non-idle process function.
    else
        Debug.logn( "Catalog access error after one try: " .. str:to( m ) )
    end
end



--- Background processing method.
--
--  @param      call object - usually not needed, but its got the name, and context... just in case.
--
function ExtendedBackground:process( call )

    local photo = catalog:getTargetPhoto() -- most-selected.
    if photo then
        self:processPhoto( photo, call, false ) -- set self--enough-for-now if time intensive processing encountered which does not always occur.
    end
    self:considerIdleProcessing( call )
    
end



return ExtendedBackground
