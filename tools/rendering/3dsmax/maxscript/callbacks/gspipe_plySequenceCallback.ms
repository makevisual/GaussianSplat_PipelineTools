-- gspipe_plySequenceCallback.ms
-- Wires gspipe_plyUpdate.run() into 3ds Max callbacks and provides a
-- scripted custom attribute so the registration travels with the .max
-- file. Assumes gspipe_plySequence.ms has been fileIn'd first
-- (defines gspipe_plyUpdate).
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
