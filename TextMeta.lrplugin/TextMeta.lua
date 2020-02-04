--[[
        TextMeta.lua
--]]


local TextMeta, dbg = Object:newClass{ className = "TextMeta", register = true }



--- Constructor for extending class.
--
function TextMeta:newClass( t )
    return Object.newClass( self, t )
end


--- Constructor for new instance.
--
function TextMeta:new( t )
    local o = Object.new( self, t )
    return o
end



function TextMeta:init()
    return true -- nuthin to do
end


-- must be wrapped in cat-access/err-handling context externally.
function TextMeta:updatePhoto( photo, cache, acceptUncached, i )
    local chg
    local function upd( id, val, name )
        
        local sts, msg = custMeta:update( photo, id, val, nil, true ) -- no version specified, true => no-throw
        if sts ~= nil then
            if sts then
                app:logVerbose( "^1 metadata updated: ^2", name, str:to( val ) )
                chg = true
            else
                app:logVerbose( "^1 metadata unchanged, still: ^2", name, str:to( val ) )
            end
        else
            app:logError( "Unable to update '^1' metadata to '^2', error message: ^3", name, str:to( val ), msg )
        end
    end
    local photoPath = cache:getRawMetadata( photo, 'path', acceptUncached )
    local isVirtualCopy = cache:getRawMetadata( photo, 'isVirtualCopy', acceptUncached )
    local copyName = cache:getFormattedMetadata( photo, 'copyName', acceptUncached )
    if i then
        if isVirtualCopy then
            app:log( "#^1 ^2 (^3)", i, photoPath, copyName  )
        else
            app:log( "#^1: ^2", i, photoPath )
        end
    else
        -- background task - don't log each photo checked - just the ones that change (upon return).
    end
    local folderPath = LrPathUtils.parent( photoPath ) -- not nil
    local parentFolderPath = LrPathUtils.parent( folderPath ) -- may be nil.
    local grandparentFolderPath
    local grandparentFolderName
    local greatGrandparentFolderPath
    local greatGrandparentFolderName
    local parentFolderName
    if str:is( parentFolderPath ) then
        parentFolderName = LrPathUtils.leafName( parentFolderPath )
        grandparentFolderPath = LrPathUtils.parent( parentFolderPath )
    end
    if str:is( grandparentFolderPath ) then
        grandparentFolderName = LrPathUtils.leafName( grandparentFolderPath )
        greatGrandparentFolderPath = LrPathUtils.parent( grandparentFolderPath )
    end
    if str:is( greatGrandparentFolderPath ) then
        greatGrandparentFolderName = LrPathUtils.leafName( greatGrandparentFolderPath )
    end
    local folderName = LrPathUtils.leafName( folderPath )
    local filename = cache:getFormattedMetadata( photo, 'fileName', acceptUncached )
    local title = cache:getFormattedMetadata( photo, 'title', acceptUncached )
    local cap = cache:getFormattedMetadata( photo, 'caption', acceptUncached )
    local headline = cache:getFormattedMetadata( photo, 'headline', acceptUncached )
    if cap ~= nil then -- will be string.
        cap = str:squeezeToFit( cap:gsub( "%c", " - " ), 80 ) -- substitute dash for eol and other chars, then squeeze into 80 chars for condensed lib-filter display.
    end
    if headline ~= nil then -- will be string.
        headline = str:squeezeToFit( headline:gsub( "%c", " - " ), 80 ) -- substitute dash for eol and other chars, then squeeze into 80 chars for condensed lib-filter display.
    end
    upd( 'filename', filename, "Filename" )
    upd( 'copyName', copyName, "Copy Name" )
    upd( 'title', title, "Title" )
    upd( 'miniCap', cap, "Mini Caption" )
    upd( 'miniHeadline', headline, "Mini Headline" )
    upd( 'folderPath', folderPath, "Folder Path" )
    upd( 'greatGrandparentFolderName', greatGrandparentFolderName, "Great Grandparent Folder Name" )
    upd( 'grandparentFolderName', grandparentFolderName, "Grandparent Folder Name" )
    upd( 'parentFolderName', parentFolderName, "Parent Folder Name" )
    upd( 'folderName', folderName, "Folder Name" )
    return chg
end


function TextMeta:updateMetadata()
    app:call( Service:new{ name="Update", async=true, progress=true, guard=App.guardVocal, main = function( call ) -- Make simple Call to avoid log prompt.
        call.nChg = 0
        call.nSame = 0
        local s, m = background:pause()
        if s then
            -- works:
            local photos = dia:promptForTargetPhotos{ prefix="Update metadata of", call=call } -- updates scope - creates if need be.
            if call:isQuit() then
                return
            end
            --[[ works too: save for example
            local components = dia:promptForTargetPhotos{ prefix="Update metadata of", returnComponents=true, call=call }
            if call:isQuit() then -- e.g. no photos in catalog.
                return
            end
            local button = app:show{
                confirm = components.confirm, 
                subs = components.subs,
                buttons = components.buttons,
                actionPrefKey = components.actionPrefKey,
            }
            local photos
            if button == 'ok' then
                photos = components.okPhotos
            elseif button == 'other' then
                photos = components.otherPhotos
            elseif button == 'cancel' then
                call:cancel()
                return
            end
            --]]
            assert( #photos > 0, "no photos" ) -- this should never happen if call is not quit.

            call:setCaption( "Preparing metadata..." )
            local cache = lrMeta:createCache{ photos=photos, rawIds={ 'path', 'isVirtualCopy' }, fmtIds={ 'fileName', 'copyName', 'title', 'caption', 'headline' } }
            app:log()
            local yc = 0
            call:setCaption( "Updating metadata..." )
            local s, m = cat:updatePrivate( 20, function( context, phase )
                -- breaking into chunks is unnecessary for 12,000 photo catalog, when only updating private metadata, however finalizing still takes a very long time.
                local i1 = ( phase - 1 ) * 1000 + 1
                local i2 = math.min( phase * 1000, #photos )
                local n = i2 - i1 + 1
                call:setCaption( "Updating photos ^1-^2", i1, i2 )
                local chg
                local function upd( photo, id, val, name )
                    local sts, msg = custMeta:update( photo, id, val, nil, true )
                    if sts ~= nil then
                        if sts then
                            app:logVerbose( "^1 metadata updated: ^2", name, str:to( val ) )
                            chg = true
                        else
                            app:logVerbose( "^1 metadata unchanged, still: ^2", name, str:to( val ) )
                        end
                    else
                        app:logError( "Unable to update '^1' metadata to '^2', error message: ^3", name, str:to( val ), msg )
                    end
                end
                for i = i1, i2 do
                    call:setPortionComplete( i - 1, #photos )
                    local photo = photos[i]
                    yc = app:yield( yc )
                    local chg = self:updatePhoto( photo, cache, false, i ) -- all metadata should be cached.
                    if chg then
                        call.nChg = call.nChg + 1
                    else
                        call.nSame = call.nSame + 1
                    end
                    if call:isQuit() then -- now looks at call.scope when present.
                        return true -- done
                    end
                end
                call:setCaption( "Finalizing updated metadata..." )
                if i2 < #photos then
                    app:sleep( 1 ) -- So user can see caption message, even if no finalization required.
                    app:logVerbose( "End of phase ^1", phase )
                    return false -- continue
                else
                    app:logVerbose( "End of last phase of update: ^1", phase )
                    call:setPortionComplete( 1 )
                end
            end )
            if s then
                --app:log( "Metadata in catalog updated without a hitch." )
            else
                app:error( "Unable to update metadata in catalog - ^1", m )
            end
        else
            app:error( m ) -- message indicates problem fairly completely, if I remember correctly.
        end
    end, finale=function( call, status, message )
        background:continue()
        if status and not call:isCanceled() and not call:isAborted() then
            app:log()
            app:log( "Metadata in catalog updated without a hitch." )
            app:log()
            app:log( "^1 updated", str:plural( call.nChg, "photo", true ) )
            app:log( "^1 unchanged.", str:plural( call.nSame, "photo", true ) )
            app:log()
        end
    end } )
end



return TextMeta