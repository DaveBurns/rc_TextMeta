--[[
        LrMetadata.lua
--]]        


local LrMetadata, dbg = Object:newClass{ className = 'LrMetadata', register = true }


local Cache = Object:newClass{ className='LrMetadataCache', register=false }

--[[
        Example use of cache objects:
        
        local cache = lrMeta:createCache()
        local photos = catalog:getTargetPhotos()
        cache:loadFormattedMetadata( photos, { 'copyName' } )
        cache:loadRawMetadata( photos, { 'path' } )
        for i, photo in ipairs( photos ) do        
            local cn = cache:getFormattedMetadata( photo, 'copyName' )
            local pth = cache:getRawMetadata( photo, 'path' )
            local fnc = my:getFancy( blah, blah, blah, cache )
            -- ...
        end
--]]

--- Constructor for new instance.
--
--  @usage presently no way to extend internal cache class.<br>
--         if that changes, then provide new class constructor and go through object factory to create.
--
function Cache:new( t )
    local o = Object.new( self, t )
    return o
end



--- Assure specified formatted metadata is in cache for short-term future use.
--
--  @usage      @10/Jul/2012 15:51, clears any previous metadata from cache - original intention was to add-to, but that hasn't happened yet.
--
function Cache:loadFormattedMetadata( photos, names )
    self.fmtMeta = catalog:batchGetFormattedMetadata( photos, names )
    self.fmtLookup = {}
    for i, name in ipairs( names ) do
        self.fmtLookup[name] = true
    end
end    
    


--- Get specified formatted metadata, hopefully from cache.
--
function Cache:getFormattedMetadata( photo, name, acceptUncached )
    if self.fmtMeta ~= nil then
        if self.fmtLookup[name] then
            if self.fmtMeta[photo] ~= nil then
                return self.fmtMeta[photo][name]
            elseif acceptUncached then
                return photo:getFormattedMetadata( name )
            else
                app:error( "need formatted metadata named '^1' for photo", name )
            end
        elseif acceptUncached then
            dbg( "Formatted metadata uncached for name: ^1", name )
            return photo:getFormattedMetadata( name )
        else
            app:error( "Formatted metadata not available in cache for name: ^1", name )
        end
    elseif acceptUncached then
        dbg( "No formatted metadata in cache, fetching from photo for name: ^1", name )
        return photo:getFormattedMetadata( name )
    else
        app:error( "No formatted metadata in cache." )
    end
end



--- Cache specified raw metadata for short-term future use.
--
--  @usage      @10/Jul/2012 15:51, clears any previous metadata from cache - original intention was to add-to, but that hasn't happened yet.
--
function Cache:loadRawMetadata( photos, names )
    self.rawMeta = catalog:batchGetRawMetadata( photos, names )
    self.rawLookup = {} -- name lookup
    for i, name in ipairs( names ) do
        self.rawLookup[name] = true
    end
end    



--- Add raw metadata to cache - note: photos may be different, caller of get-raw-metadata beware.
--
function Cache:addRawMetadata( photos, names )
    if self.rawMeta == nil or self.rawLookup == nil then
        self:loadRawMetadata( photos, names )
        return self.rawMeta
    end
    local rawMeta = catalog:batchGetRawMetadata( photos, names )
    tab:appendArray( self.rawMeta, rawMeta )
    tab:addToSet( self.rawLookup, names )
    return self.rawMeta
end



--- Add raw metadata to cache - note: photos may be different, caller of get-raw-metadata beware.
--
function Cache:addFormattedMetadata( photos, names )
    if self.fmtMeta == nil or self.fmtLookup == nil then
        self:loadFormattedMetadata( photos, names )
        return self.fmtMeta
    end
    local fmtMeta = catalog:batchGetFormattedMetadata( photos, names )
    tab:appendArray( self.fmtMeta, fmtMeta )
    tab:addToSet( self.fmtLookup, names )
    return self.fmtMeta
end



--- Get specified raw metadata, hopefully from cache.
--
function Cache:getRawMetadata( photo, name, acceptUncached )
    if self.rawMeta ~= nil then
        if self.rawLookup[name] then -- is guaranteed to be in for some, but not all photos (since the introduction of add-metadata functions).
            --Debug.pause( name, self.rawMeta[photo][name] )
            if self.rawMeta[photo] ~= nil then
                return self.rawMeta[photo][name]
            elseif acceptUncached then
                return photo:getRawMetadata( name )
            else
                app:error( "need metadata for photo" )
            end
        elseif acceptUncached then
            dbg( "Raw metadata uncached for name: ^1", name )
            return photo:getRawMetadata( name )
        else
            app:error( "Raw metadata not available in cache for name: ^1", name )
        end
    elseif acceptUncached then
        dbg( "No raw metadata in cache, fetching from photo for name: ^1", name )
        return photo:getRawMetadata( name )
    else
        app:error( "No raw metadata in cache." )
    end
end



--- Get raw metadata table - for legacy methods that still require separate, raw-meta and fmt-meta tables.
--
function Cache:getRawMeta()
    return self.rawMeta
end



--- Get formatted metadata table - for legacy methods that still require separate, raw-meta and fmt-meta tables.
--
function Cache:getFmtMeta()
    return self.fmtMeta
end



--  L R - M E T A D A T A   M E T H O D S



--- Create metadata cache for local use.
--
--  @param      t       (table, optional) members: photos, rawIds, fmtIds. If provided cache will be pre-loaded.
--
function LrMetadata:createCache( t )
    local c = Cache:new()
    t = t or {}
    if t.photos then
        if t.rawIds then
            c:loadRawMetadata( t.photos, t.rawIds )
        end
        if t.fmtIds then
            c:loadFormattedMetadata( t.photos, t.fmtIds )
        end
    end
    return c
end



--- Constructor for extending class.
--
function LrMetadata:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function LrMetadata:new( t )
    local o = Object.new( self, t )
    return o
end



--- Determine if key is known in formatted metadata.
--
function LrMetadata:isKnownKey( photo, name )
    photo = photo or cat:getAnyPhoto() or app:error( "no photos" )
    local s, m = LrTasks.pcall( photo.getFormattedMetadata, photo, name )
    if s then
        return true
    else
        return false
    end
end



--- Determine if key is known in raw metadata.
--
function LrMetadata:isKnownRawKey( photo, name )
    local s, m = LrTasks.pcall( photo.getRawMetadata, photo, name )
    if s then
        return true
    else
        return false
    end
end



-- Get specified formatted metadata, from cache if available.
--
--  @usage good for functions that can take advantage of a cache created externally, or not.
--
function LrMetadata:getFormattedMetadata( photo, name, cache, acceptUncached )
    if cache then
        return cache:getFormattedMetadata( photo, name, acceptUncached )
    else
        return photo:getFormattedMetadata( name )
    end
end



--- Get specified raw metadata, from cache if available.
--
--  @usage good for functions that can take advantage of a cache created externally, or not.
--
function LrMetadata:getRawMetadata( photo, name, cache, acceptUncached )
    if cache then
        return cache:getRawMetadata( photo, name, acceptUncached )
    else
        return photo:getRawMetadata( name )
    end
end



return LrMetadata
