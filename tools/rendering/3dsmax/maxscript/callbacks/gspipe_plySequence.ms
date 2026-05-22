----------------------------------
---------- Update Struct ---------
----------------------------------

-- gspipe_plySequence.ms
-- Walks every VRayGaussiansGeom node in the scene, reads sequence
-- settings from each node's user properties, computes the per-frame
-- .ply path for the current time, and assigns it to .file.
--
-- User properties read from each node:
--   gspipe_plyAnimationEnabled  bool    if not true, the node is skipped
--   gspipe_plySequencePath      string  path to ANY existing frame file
--   gspipe_plyOffset            int     added to current frame
--   gspipe_plySequenceMissing   name    #nearest or #none (default #none)
--
-- Manual invocation only in this iteration; no callback registration.
-- See tools/rendering/3dsmax/plan.md.

global gspipe_plyUpdate

struct gspipe_plyUpdateStruct (

    quiet = True,

    fn gspipe_isAllDigits s = (
        local ok = s.count > 0
        for i = 1 to s.count while ok do
            if findString "0123456789" (substring s i 1) == undefined do ok = false
        ok
    ),

    fn gspipe_lastDotPos s = (
        local p = 0
        for i = 1 to s.count do if (substring s i 1) == "." do p = i
        p
    ),

    fn gspipe_parseInt v default:0 = (
        -- getUserProp's auto-coercion doesn't reliably handle leading '-',
        -- so parse the sign explicitly before delegating to `as integer`.
        if v == undefined then default
        else if classOf v == Integer then v
        else if classOf v == Float   then (v as integer)
        else (
            local s = v as string
            local sign = 1
            if s.count > 0 and (substring s 1 1) == "-" do (
                sign = -1
                s = substring s 2 -1
            )
            if gspipe_isAllDigits s then (sign * (s as integer)) else default
        )
    ),

    fn gspipe_parsePlySeqPath path = (
        -- "C:\...\Goku.0001.ply" -> #(dir, base, padding, ext); undefined if unparseable.
        local dir  = getFilenamePath path
        local stem = getFilenameFile path
        local ext  = getFilenameType path
        local lastDot = gspipe_lastDotPos stem
        if lastDot == 0 then undefined
        else (
            local base   = substring stem 1 (lastDot - 1)
            local digits = substring stem (lastDot + 1) -1
            if not (gspipe_isAllDigits digits) then undefined
            else #(dir, base, digits.count, ext)
        )
    ),

    fn gspipe_findNearestPly dir base padding ext target = (
        local files = getFiles (dir + base + ".*" + ext)
        local bestPath = ""
        local bestDist = -1
        for f in files do (
            local stem = getFilenameFile f
            local lastDot = gspipe_lastDotPos stem
            if lastDot != 0 do (
                local fbase  = substring stem 1 (lastDot - 1)
                local digits = substring stem (lastDot + 1) -1
                if fbase == base and gspipe_isAllDigits digits do (
                    local dist = abs ((digits as integer) - target)
                    if bestDist < 0 or dist < bestDist do (
                        bestDist = dist
                        bestPath = f
                    )
                )
            )
        )
        bestPath
    ),

    fn gspipe_updatePlySequences = (
        local curFrame = (currentTime as integer) / ticksPerFrame
        local nodes = for n in objects where (classOf n) == VRayGaussiansGeom collect n

        for n in nodes do (
             local enabledStr = toLower ((getUserProp n "gspipe_plyAnimationEnabled") as string)
             if enabledStr == "true" do (
                 local seqPath = getUserProp n "gspipe_plySequencePath"
                 if seqPath != undefined and (seqPath as string) != "" do (
                     seqPath = seqPath as string
                     local offset = gspipe_parseInt (getUserProp n "gspipe_plyOffset")

                     local missingStr = (getUserProp n "gspipe_plySequenceMissing") as string
                     if missingStr.count > 0 and (substring missingStr 1 1) == "#" do
                         missingStr = substring missingStr 2 -1
                     local nearest = (toLower missingStr) == "nearest"

                     local parsed = gspipe_parsePlySeqPath seqPath
                     if parsed == undefined then (
                         format "[gspipe] %  unparseable plySequencePath: %\n" n.name seqPath
                     ) else (
                         local dir = parsed[1]; local base = parsed[2]
                         local padding = parsed[3]; local ext = parsed[4]
                         local target = curFrame + offset
                         local frameStr = formattedPrint target format:("%0" + (padding as string) + "d")
                         local candidate = dir + base + "." + frameStr + ext
                         local finalPath = if doesFileExist candidate then candidate
                             else if nearest then (gspipe_findNearestPly dir base padding ext target)
                             else ""
                         if gspipe_plyUpdate.quiet != true then ( format "[gspipe] %  ->  \"%\"\n" n.name finalPath ) --quiet:quiet 
                         n.file = finalPath
                     )
                 )
             )
        )
        ok
    ),

    fn run = (
        gspipe_updatePlySequences()
    )
)

gspipe_plyUpdate = gspipe_plyUpdateStruct()
-- gspipe_plyUpdate.run() 




----------------------------------
----------- Callbacks ------------
----------------------------------

-- Wires gspipe_plyUpdate.run() into 3ds Max callbacks and provides a
-- scripted custom attribute so the registration travels with the
-- .max file.
--
-- Two callbacks are installed:
--   #preRenderEval       - fires before the renderer evaluates objects
--                          for each rendered frame. Right place to
--                          mutate .file; #preRenderFrame is too late
--                          because the scene has already been
--                          snapshotted.
--   registerTimeCallback - separate subsystem driven by slider motion.
--                          Takes a function reference, not an event-
--                          name string, so the previous reference is
--                          cached in a module-level global to survive
--                          re-fileIn cycles.
--
-- Safe to re-fileIn: register() clears the id-based callback AND
-- unregisters any previously cached time-callback before installing
-- fresh ones - no Max restart needed when something breaks.

global gspipe_plyTimeCallbackRef

fn gspipe_plyTimeChangeHandler = gspipe_plyUpdate.run()

struct gspipe_plyCallbackStruct (
    cbId = #gspipe_plySequence,

    fn register = (
        callbacks.removeScripts id:cbId
        if gspipe_plyTimeCallbackRef != undefined do
            unregisterTimeCallback gspipe_plyTimeCallbackRef

        callbacks.addScript #preRenderEval "gspipe_plyUpdate.run()" id:cbId

        gspipe_plyTimeCallbackRef = gspipe_plyTimeChangeHandler
        registerTimeCallback gspipe_plyTimeCallbackRef

        format "[gspipe] callbacks registered (id: %)\n" cbId
        ok
    ),

    fn unregister = (
        callbacks.removeScripts id:cbId
        if gspipe_plyTimeCallbackRef != undefined do (
            unregisterTimeCallback gspipe_plyTimeCallbackRef
            gspipe_plyTimeCallbackRef = undefined
        )
        format "[gspipe] callbacks unregistered (id: %)\n" cbId
        ok
    )
)

-- Scripted custom attribute. Attach to any scene node (Point helpers
-- work well) and save the scene; on subsequent loads, its `on load`
-- handler re-installs the callbacks. Requires gspipe_plyCallback to
-- already be defined in the session - render-farm workers should
-- load both .ms files via a startup script.
gspipe_plySequenceSceneCA = attributes gspipe_plySequenceSceneCA
(
    parameters main rollout:params (
        enabled type:#boolean default:true ui:chkEnabled
    )

    rollout params "Gspipe PLY Sequence Callback" (
        checkbox chkEnabled "Auto-register on scene load" checked:true
        button btnReinstall "Re-install callbacks now"
        on btnReinstall pressed do
            if gspipe_plyCallback != undefined do gspipe_plyCallback.register()
    )

    on load do (
        if enabled and gspipe_plyCallback != undefined do
            gspipe_plyCallback.register()
    )
)

gspipe_plyCallback = gspipe_plyCallbackStruct()
gspipe_plyCallback.register()