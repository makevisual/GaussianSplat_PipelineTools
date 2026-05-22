-- gspipe_plySequenceCallback.ms
-- Wires gspipe_plyUpdate.run() into 3ds Max callbacks and provides a
-- scripted custom attribute so the registration travels with the .max
-- file. Assumes gspipe_plySequence.ms has been fileIn'd first
-- (defines gspipe_plyUpdate).
--
-- Safe to re-fileIn: register() first removes any prior callbacks
-- under the stable id, so a broken handler can be cleared by simply
-- re-loading this file - no Max restart required.

struct gspipe_plyCallbackStruct (
    cbId = #gspipe_plySequence,

    fn register = (
        callbacks.removeScripts id:cbId
        callbacks.addScript #timeChange     "gspipe_plyUpdate.run()" id:cbId
        callbacks.addScript #preRenderFrame "gspipe_plyUpdate.run()" id:cbId
        format "[gspipe] callbacks registered (id: %)\n" cbId
        ok
    ),

    fn unregister = (
        callbacks.removeScripts id:cbId
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
