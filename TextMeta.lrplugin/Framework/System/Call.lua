--[[
        Call.lua
        
        A glorified pcall, which uses cleanup handlers, and assures at least default error handling.
        
        Benefits include extensibility for calls that go beyond the simplest case, wrapping
        
        basic functionality with more elaborate start / cleanup code (see 'Service' class as example).
--]]


local Call, dbg = Object:newClass{ className = "Call" }



--- Constructor for class extension.
--
function Call:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance objects.
--      
--  <p>Table parameter elements:</p><blockquote>
--      
--          - name:         (string, required) operation name, used for context debugging and as guard key.<br>
--          - async:        (boolean, default false) true => main function runs as asynchronous task. false => synchronous.<br>
--          - guard:        (number, default 0) 0 or nil => no guard, 1 => silent, 2 => vocal. Hint: Use App constants; App.guardSilent and App.guardVocal.<br>
--          - object:       (table, default nil) if main (and finale if applicable) is method, object is required, else leave blank to call main (and finale if applicable) as static function.<br>
--          - main:         (function, required) main function or method.<br>
--          - finale:       (function, default nil) pass finale function if something to do after main completes or aborts.</blockquote>
--
--  @param  t               Table holding call paramaters.
--
function Call:new( t )
    
    if not t then
        error( "Call constructor requires parameter table." )
    elseif not t.name then
        error( "Call constructor requires name in parameter table." )
    elseif not t.main then
        error( "Call requires main function in parameter table." )
    end
    if app:isAdvDbgEna() then -- make sure its unwrapped if not debugging, since finale handlers depend on it.
        t.main = Debug.showErrors( t.main )
    end
    local o = Object.new( self, t )
    o.abortMessage = ''
    o.cancelMessage = nil
    return o
end



--- Constructor for a call-like object that just keeps a set of stats, without being "performed" (no main function...).
--
function Call:newStats( names )
    local o = Object.new( self )
    o:initStats( names )
    return o
end



---  Initialize call stats - optional, but recommended - to avoid nagging when debug is enabled.
--
function Call:initStats( names )
    self.stats = {}
    for i, name in ipairs( names ) do
        self.stats[name] = 0
    end
end



---  Initialize call stats - optional, but recommended - to avoid nagging when debug is enabled.
--
function Call:assureStats( names )
    if self.stats == nil then
        self:initStats( names )
        return
    end
    for i, name in ipairs( names ) do
        if self.stats[name] == nil then
            self.stats[name] = 0
        -- else stat already defined.
        end
    end
end



--- Increment a call stat: may or may not be initialized.
--
function Call:incrStat( name, amt )
    if not str:is( name ) then
        app:callingError( "no name" )
    end
    if self.stats == nil then
        self.stats = {}
        Debug.pause( "stats not init before incr of", name )
    end
    if self.stats[name] == nil then
        Debug.pause( "stat does not for incr:", name )
        self.stats[name] = 0
    end
    self.stats[name] = self.stats[name] + (amt or 1)
end



--- get stat value, 0 if undefined.
--
function Call:getStat( name )
    if not str:is( name ) then
        app:callingError( "no name" )
    end
    if self.stats == nil then
        Debug.pause( "stats not init for get of", name )
        return 0
    end
    if self.stats[name] == nil then
        Debug.pause( "stat does not exist for getting:", name )
        return 0
    end
    return self.stats[name]
end



--- get stat value, 0 if undefined.
--
function Call:setStat( name, val )
    if not str:is( name ) then
        app:callingError( "no name" )
    end
    if self.stats == nil then
        Debug.pause( "stats not init for seting", name )
        self.stats = {}
    elseif self.stats[name] == nil then
        Debug.pause( "stat has not been defined/init:", name )
    end
    self.stats[name] = val
end



--- Abort call or service.
--
--  @usage Note: Do not call base class abort method here.
--
function Call:abort( message )
    if str:is( message ) then
        self.abortMessage = message -- serves as boolean indicating "is-aborted" as well as providing the message.
    else
        self.abortMessage( "unable to ascertain reason for abort" )
    end
end



--- Cancel call or service.
--
--  @usage      cancelation means don't bother user again.
--
function Call:cancel( message )
    if message == nil then
        self.cancelMessage = self.name .. " was canceled."
    else
        self.cancelMessage = message -- empty string for cancelation without message.
    end
end



--- Determine if a call was canceled.
--
--  @usage      cancelation means don't bother user again.
--
--  @return cancel-message which serves as boolean (if not nil) and optional message (if not the empty string).
--
function Call:isCanceled()
    return self.cancelMessage ~= nil -- (note: unlike abort, it is legal to cancel with an empty message).
end



--- Determine if call has been aborted.
--
function Call:isAborted()
    return str:is( self.abortMessage )
end



--- Determine if call has quit due to cancelation or abortion.
--
--  @usage      Does not check for scope canceled, nor scope done.
--
function Call:isQuit( scope )
    if self:isCanceled() or self:isAborted() or _G.shutdown then
        return true
    else
        if scope == nil then
            scope = self.scope
        end
        if scope ~= nil and scope:isCanceled() then
            self:cancel()
            return true
        else
            return false
        end
    end
end



--- Used by background task so it can be canceled, but not stay canceled forever.
--
function Call:unQuit()
    self.abortMessage = ''
    self.cancelMessage = nil
end



-- Get abort message for display.
--
-- @return empty string if not aborted.
--
function Call:getAbortMessage()
    return self.abortMessage or ''
end



-- Don't call without context.
function Call:_createDefaultScope( cap )
    self.scope = LrProgressScope {
        title = str:fmt( "^1 - ^2", app:getAppName(), self.name ),
        functionContext = self.context,
        caption = cap,
    }
    self.cap = cap
end



--- Set a caption on a progress indicator.
--
--  @usage normally pre-created, but will create default scope on demand if need be.
--
function Call:setCaption( fmt, ... )
    if self.context then
        local prevCap = self.cap or ""
        self.cap = str:fmtx( fmt, ... )
        if not self.scope then
            self:_createDefaultScope( self.cap )
        elseif not self.scope:isCanceled() then -- must be allowed even on done scopes.
            self.scope:setCaption( self.cap )
        -- else - ignore incoming captions on canceled scopes (must be allowed even on done scopes).
        end
        return prevCap
    else
        app:callingError( "Call not active." )
    end
end



--- Get caption, usually for subsequent restoral.
--
function Call:getCaption()
    return self.cap or ""
end



--- Convenience function for setting portion complete on encapsulated scope.
--
--  @param      amt     (number, required) number completed.
--  @param      ttl     (number, default=1) out of total.
--
function Call:setPortionComplete( amt, ttl )
    if self.context then
        if not self.scope then
            self:_createDefaultScope( "Please wait..." )
        elseif not self.scope:isCanceled() then -- must be allowed even on done scopes.
            self.scope:setPortionComplete( amt, ttl or 1 )
        -- else - ignore incoming progress on canceled scopes
        end
    else
        app:callingError( "Call not active." )
    end
end
    


--- Call (perform) main function.
--
--  @usage          Normally no need to override - pass main function to constructor instead.
--  @usage          Called as static function if object nil, else method.
--  @usage          Errors thrown in main are caught by App and passed to finale.
--
function Call:perform( context, ... )

    _G.service = 'started' -- used to support debug-script, which waits a short time for this, and if seen, waits forever for the finale to set 'done' state.
    -- dbg( "Doin service: ", self:getFullClassName() )

    if self.progress ~= nil then
        local typ = type( self.progress )
        if typ == 'boolean' then
            if self.progress then
                self.cap = "Please wait..."
                self.scope = LrProgressScope {
                    title = str:fmt( "^1 - ^2", app:getAppName(), self.name ),
                    functionContext = context,
                    caption = self.cap, -- change this if you want.
                }
            else
                self.scope = nil
            end
        elseif typ == 'string' then -- scope-spec = 
            self.cap = "Please wait..."
            self.scope = LrProgressScope {
                title = typ,
                functionContext = context,
                caption = self.cap, -- change this if you want.
            }
        elseif typ == 'table' then
            self.cap = self.progress.caption or "Please wait..."
            self.scope = LrProgressScope {
                title = self.progress.title or str:fmt( "^1 - ^2", app:getAppName(), self.name ),
                functionContext = context,
                caption = self.cap,
            }
        -- else hope for the best...
        end
    -- else no scope.    
    end
    
    if self.preserve ~= nil then
        if self.preserve.selPhotos then
            self.selPhotos = cat:saveSelPhotos() -- and view filter.
        end
    end

    --self.canceled = false -- until 29/Oct/2011 2:48
    self.cancelMessage = nil -- after 29/Oct/2011 2:48
    self.abortMessage = ''
    self.context = context
    
    if self.object then
        -- self.object.call = self -- this is tempting, but presumptious: if user defined a call member it would stomp on it.
        self.main( self.object, self, ... ) -- call main function as a method of specified object.
    else
        self.main( self, ... )
    end
end



--- "Cleanup" function called after main function, even if main aborted due to error.
--
--  <p>I'm not real crazy about the term "cleanup", but the big deal is that its guaranteed to be called
--  regardless of the status of main function execution. "cleanup" activities can include things like
--  clearing recursion guards, logging results, and displaying a successful completion or error message.</p>
--
--  @usage          Normally no need to override - pass finale function to constructor instead.
--  @usage          App calls this in protected fashion - if error in cleanup function, default error handler is called.
--
function Call:cleanup( status, message )
    if str:is( self.abortMessage ) then
        app:log( "'^1' aborted: ^2", self.name, self.abortMessage )
    elseif str:is( self.cancelMessage ) then
        app:log( self.cancelMessage )
    end
    if self.selPhotos then
        cat:restoreSelPhotos( self.selPhotos )
    end
    if self.finale then
        if self.object then
            self.finale( self.object, self, status, message )
        else
            self.finale( self, status, message )
        end
    elseif status then
        -- no finale func/method, but main func executed without error - good enough...
    elseif not self:isQuit() then
        App.defaultFailureHandler( false, message ) -- for user.
    end
    if self:getClassName() == 'Call' then
        _G.service = 'done' -- supports debug-script @2/Sep/2011.
    -- else let derived type do it when totally done.
    end
end



return Call