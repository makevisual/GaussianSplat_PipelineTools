----------------------------------
--------- Editor Struct ----------
----------------------------------

-- gspipe_plySequenceEditor.ms
-- Companion UI for gspipe_plySequence.ms (callbacks/). Lists every
-- VRayGaussiansGeom node in the scene and lets the user view/edit the
-- four user properties that the callback reads:
--
--   gspipe_plyAnimationEnabled  bool    if not true, the node is skipped
--   gspipe_plySequencePath      string  path to ANY existing frame file
--   gspipe_plyOffset            int     added to current frame
--   gspipe_plySequenceMissing   name    #nearest or #none (default #none)
--
-- Also exposes global callback-system controls: quiet flag,
-- register / unregister / verify of gspipe_plyCallback.
--
-- Reuses helpers from gspipe_plyUpdate (path parsing, nearest finder,
-- int parsing). Requires gspipe_plySequence.ms to be loaded first.
--
-- Invocation:
--   fileIn @"...\gspipe_plySequence.ms"
--   fileIn @"...\gspipe_plySequenceEditor.ms"
--   gspipe_plySeqEditorShow()

global gspipe_plySeqEditor
global gspipe_plySeqEditorTimeCbRef

struct gspipe_plySeqEditorStruct (

    statusEnumDisabled    = #disabled,
    statusEnumUnparseable = #unparseable,
    statusEnumExact       = #exact,
    statusEnumNearest     = #nearest,
    statusEnumNone        = #none,
    statusEnumUninit      = #uninit,

    fn collectNodes = (
        for n in objects where (classOf n) == VRayGaussiansGeom collect n
    ),

    fn hasProp node propName = (
        (getUserProp node propName) != undefined
    ),

    fn isInitialized node = (
        (hasProp node "gspipe_plyAnimationEnabled") or \
        (hasProp node "gspipe_plySequencePath") or \
        (hasProp node "gspipe_plyOffset") or \
        (hasProp node "gspipe_plySequenceMissing")
    ),

    fn readEnabled node = (
        local raw = getUserProp node "gspipe_plyAnimationEnabled"
        if raw == undefined then false
        else (toLower (raw as string)) == "true"
    ),

    fn readPath node = (
        local raw = getUserProp node "gspipe_plySequencePath"
        if raw == undefined then "" else (raw as string)
    ),

    fn readOffset node = (
        gspipe_plyUpdate.gspipe_parseInt (getUserProp node "gspipe_plyOffset")
    ),

    fn readMissing node = (
        local raw = getUserProp node "gspipe_plySequenceMissing"
        if raw == undefined then "#none"
        else (
            local s = raw as string
            if s.count > 0 and (substring s 1 1) != "#" then s = "#" + s
            if (toLower s) == "#nearest" then "#nearest" else "#none"
        )
    ),

    fn frameNumberFromFile filePath = (
        -- Pull the trailing integer out of a resolved frame path, e.g.
        --   "C:/foo/bar.0042.ply" -> 42
        -- Returns undefined when there's nothing parseable.
        if filePath == undefined or (filePath as string) == "" then undefined
        else (
            local stem = getFilenameFile (filePath as string)
            local lastDot = gspipe_plyUpdate.gspipe_lastDotPos stem
            if lastDot == 0 then undefined
            else (
                local digits = substring stem (lastDot + 1) -1
                if gspipe_plyUpdate.gspipe_isAllDigits digits then (digits as integer)
                else undefined
            )
        )
    ),

    fn resolveStatus node curFrame = (
        -- Returns #(statusSym, targetFrame, loadedFrame, candidatePath, resolvedPath)
        -- where loadedFrame/resolvedPath come from the node's current .file.
        if not (isInitialized node) then
            #(#uninit, undefined, undefined, "", "")
        else (
            local enabled = readEnabled node
            local seqPath = readPath node
            local offset = readOffset node
            local missing = readMissing node
            local loadedFrame = frameNumberFromFile node.file

            if not enabled then
                #(#disabled, undefined, loadedFrame, "", (node.file as string))
            else if seqPath == "" then
                #(#none, undefined, loadedFrame, "", (node.file as string))
            else (
                local parsed = gspipe_plyUpdate.gspipe_parsePlySeqPath seqPath
                if parsed == undefined then
                    #(#unparseable, undefined, loadedFrame, "", (node.file as string))
                else (
                    local dir = parsed[1]; local base = parsed[2]
                    local padding = parsed[3]; local ext = parsed[4]
                    local target = curFrame + offset
                    local frameStr = formattedPrint target format:("%0" + (padding as string) + "d")
                    local candidate = dir + base + "." + frameStr + ext
                    if doesFileExist candidate then
                        #(#exact, target, loadedFrame, candidate, (node.file as string))
                    else if missing == "#nearest" then (
                        local nearestPath = gspipe_plyUpdate.gspipe_findNearestPly dir base padding ext target
                        if nearestPath == "" then
                            #(#none, target, loadedFrame, candidate, (node.file as string))
                        else
                            #(#nearest, target, loadedFrame, nearestPath, (node.file as string))
                    )
                    else
                        #(#none, target, loadedFrame, candidate, (node.file as string))
                )
            )
        )
    ),

    fn applyEnabled nodes value = (
        for n in nodes do setUserProp n "gspipe_plyAnimationEnabled" (if value then true else false)
    ),

    fn applyOffset nodes value = (
        for n in nodes do setUserProp n "gspipe_plyOffset" value
    ),

    fn applyMissing nodes value = (
        local v = if value == "#nearest" then "#nearest" else "#none"
        for n in nodes do setUserProp n "gspipe_plySequenceMissing" v
    ),

    fn applyPath nodes pathStr = (
        for n in nodes do setUserProp n "gspipe_plySequencePath" pathStr
    ),

    fn initializeNode node pathStr = (
        setUserProp node "gspipe_plyAnimationEnabled" true
        setUserProp node "gspipe_plySequencePath"     pathStr
        setUserProp node "gspipe_plyOffset"           0
        setUserProp node "gspipe_plySequenceMissing"  "#nearest"
    )
)

gspipe_plySeqEditor = gspipe_plySeqEditorStruct()


----------------------------------
------------ Rollout -------------
----------------------------------

-- All grid mutation and event wiring happens here. The struct above
-- stays UI-agnostic so its behavior could be exercised from the
-- listener without opening the dialog.

rollout gspipe_plySeqEditorRollout "Gspipe PLY Sequence Editor" width:760 height:520
(
    -- ------- Global settings group -------
    groupBox grpGlobal "Global Settings" pos:[8,4] width:744 height:72
    checkbox chkQuiet "Quiet logging" pos:[20,24] width:140 height:18 checked:true
    label    lblCbHeader "Callback:" pos:[180,26] width:60 height:18
    label    lblCbState  "UNKNOWN"   pos:[240,26] width:120 height:18
    button   btnRegister   "Register"   pos:[380,22] width:80 height:24
    button   btnUnregister "Unregister" pos:[464,22] width:90 height:24
    button   btnVerify     "Verify"     pos:[558,22] width:70 height:24
    label    lblHint "Doubleclick name = select in scene.  Doubleclick path cell = set path." pos:[20,50] width:720 height:18

    -- ------- Grid -------
    dotNetControl dgv "System.Windows.Forms.DataGridView" pos:[8,84] width:744 height:380

    -- ------- Action buttons -------
    button btnRefresh        "Refresh"            pos:[8,472]  width:90  height:28
    button btnInitSelected   "Initialize Selected" pos:[104,472] width:130 height:28
    button btnSetPath        "Set Path..."        pos:[240,472] width:90  height:28
    button btnSelectInScene  "Select In Scene"    pos:[336,472] width:110 height:28
    label  lblFrameInfo      ""                   pos:[460,478] width:290 height:18

    -- ------- Local state -------
    local colStatus, colName, colEnabled, colPath, colOffset, colMissing, colLoaded
    local idxStatus = 0, idxName = 1, idxEnabled = 2, idxPath = 3, idxOffset = 4, idxMissing = 5, idxLoaded = 6
    local rowNodes = #()              -- INode per row index
    local suppressEvents = false

    fn statusColor sym = (
        case sym of (
            (#exact):       (dotNetClass "System.Drawing.Color").FromArgb 80 180 80
            (#nearest):     (dotNetClass "System.Drawing.Color").FromArgb 230 200 60
            (#none):        (dotNetClass "System.Drawing.Color").FromArgb 220 130 50
            (#unparseable): (dotNetClass "System.Drawing.Color").FromArgb 200 60 60
            (#disabled):    (dotNetClass "System.Drawing.Color").FromArgb 130 130 130
            (#uninit):      (dotNetClass "System.Drawing.Color").FromArgb 80 80 80
            default:        (dotNetClass "System.Drawing.Color").Gray
        )
    )

    fn statusLabel sym = (
        case sym of (
            (#exact):       "EXACT"
            (#nearest):     "NEAREST"
            (#none):        "NONE"
            (#unparseable): "ERROR"
            (#disabled):    "DISABLED"
            (#uninit):      "UNINIT"
            default:        ""
        )
    )

    fn curFrame = ((currentTime as integer) / ticksPerFrame)

    fn updateCallbackLabel = (
        if gspipe_plyCallback == undefined then
            lblCbState.text = "MISSING"
        else if not (isProperty gspipe_plyCallback #isRegistered) then
            -- Older gspipe_plySequence.ms is loaded - re-fileIn that file.
            lblCbState.text = "STALE (re-fileIn callback)"
        else if gspipe_plyCallback.isRegistered() then
            lblCbState.text = "REGISTERED"
        else
            lblCbState.text = "UNREGISTERED"
    )

    fn writeRowStatus rowIdx info = (
        -- info is the tuple returned by resolveStatus.
        local sym = info[1]
        local loadedFrame = info[3]
        suppressEvents = true
        dgv.Rows.Item[rowIdx].Cells.Item[idxStatus].Style.BackColor = statusColor sym
        dgv.Rows.Item[rowIdx].Cells.Item[idxStatus].Value           = statusLabel sym
        dgv.Rows.Item[rowIdx].Cells.Item[idxStatus].ToolTipText     = statusLabel sym
        local loadedStr = if loadedFrame == undefined then "--" else (loadedFrame as string)
        dgv.Rows.Item[rowIdx].Cells.Item[idxLoaded].Value = loadedStr
        suppressEvents = false
    )

    fn refreshRows = (
        if dgv == undefined or dgv.RowCount == 0 then return ok
        local cf = curFrame()
        lblFrameInfo.text = "frame " + (cf as string)
        for i = 0 to dgv.RowCount - 1 do (
            local n = rowNodes[i + 1]
            if isValidNode n do (
                local info = gspipe_plySeqEditor.resolveStatus n cf
                writeRowStatus i info
            )
        )
    )

    fn buildColumns = (
        dgv.Columns.Clear()

        colStatus = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
        colStatus.HeaderText = "Status"
        colStatus.Width = 80
        colStatus.ReadOnly = true
        dgv.Columns.Add colStatus

        colName = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
        colName.HeaderText = "Name"
        colName.Width = 160
        colName.ReadOnly = true
        dgv.Columns.Add colName

        colEnabled = dotNetObject "System.Windows.Forms.DataGridViewCheckBoxColumn"
        colEnabled.HeaderText = "Enabled"
        colEnabled.Width = 60
        dgv.Columns.Add colEnabled

        colPath = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
        colPath.HeaderText = "Path  (doubleclick to set)"
        colPath.Width = 260
        colPath.ReadOnly = true
        dgv.Columns.Add colPath

        colOffset = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
        colOffset.HeaderText = "Offset"
        colOffset.Width = 56
        dgv.Columns.Add colOffset

        colMissing = dotNetObject "System.Windows.Forms.DataGridViewComboBoxColumn"
        colMissing.HeaderText = "Missing"
        colMissing.Width = 70
        colMissing.Items.Add "#none"
        colMissing.Items.Add "#nearest"
        dgv.Columns.Add colMissing

        colLoaded = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
        colLoaded.HeaderText = "Loaded"
        colLoaded.Width = 56
        colLoaded.ReadOnly = true
        dgv.Columns.Add colLoaded
    )

    fn populateGrid = (
        suppressEvents = true
        dgv.Rows.Clear()
        rowNodes = #()
        local nodes = gspipe_plySeqEditor.collectNodes()
        local cf = curFrame()
        for n in nodes do (
            local enabled = gspipe_plySeqEditor.readEnabled n
            local pathStr = gspipe_plySeqEditor.readPath n
            local offset  = gspipe_plySeqEditor.readOffset n
            local missing = gspipe_plySeqEditor.readMissing n
            local newIdx = dgv.Rows.Add()
            local row = dgv.Rows.Item[newIdx]
            row.Cells.Item[idxName].Value    = n.name
            row.Cells.Item[idxEnabled].Value = enabled
            row.Cells.Item[idxPath].Value    = pathStr
            row.Cells.Item[idxOffset].Value  = (offset as string)
            row.Cells.Item[idxMissing].Value = missing
            append rowNodes n
        )
        suppressEvents = false
        lblFrameInfo.text = "frame " + (cf as string) + "  (" + (rowNodes.count as string) + " gaussian" + (if rowNodes.count == 1 then ")" else "s)")
        refreshRows()
    )

    fn refreshSingleRow rowIdx = (
        if rowIdx < 0 or rowIdx >= dgv.RowCount then return ok
        local n = rowNodes[rowIdx + 1]
        if not (isValidNode n) then return ok
        local info = gspipe_plySeqEditor.resolveStatus n (curFrame())
        writeRowStatus rowIdx info
    )

    fn selectedNodes = (
        local out = #()
        if dgv.SelectedRows.Count > 0 then (
            for i = 0 to dgv.SelectedRows.Count - 1 do (
                local rIdx = dgv.SelectedRows.Item[i].Index
                local n = rowNodes[rIdx + 1]
                if isValidNode n do appendIfUnique out n
            )
        ) else if dgv.CurrentRow != undefined then (
            local n = rowNodes[dgv.CurrentRow.Index + 1]
            if isValidNode n do append out n
        )
        out
    )

    fn pickPlyFile = (
        getOpenFileName \
            caption:"Pick any frame of the .ply sequence" \
            types:"PLY files (*.ply)|*.ply|All files (*.*)|*.*|"
    )

    -- ------- dotNet event handlers -------

    fn onCellValueChanged sender args = (
        if suppressEvents then return ok
        local rIdx = args.RowIndex
        local cIdx = args.ColumnIndex
        if rIdx < 0 or cIdx < 0 then return ok
        local n = rowNodes[rIdx + 1]
        if not (isValidNode n) then return ok
        local cell = sender.Rows.Item[rIdx].Cells.Item[cIdx]
        case cIdx of (
            (idxEnabled): (
                local v = cell.Value
                local boolVal = (v == true)
                setUserProp n "gspipe_plyAnimationEnabled" boolVal
            )
            (idxOffset): (
                local raw = cell.Value
                local parsed = gspipe_plyUpdate.gspipe_parseInt raw default:0
                setUserProp n "gspipe_plyOffset" parsed
                suppressEvents = true
                cell.Value = (parsed as string)
                suppressEvents = false
            )
            (idxMissing): (
                local s = (cell.Value as string)
                if s.count > 0 and (substring s 1 1) != "#" then s = "#" + s
                local v = if (toLower s) == "#nearest" then "#nearest" else "#none"
                setUserProp n "gspipe_plySequenceMissing" v
            )
            default: ()
        )
        refreshSingleRow rIdx
    )

    fn onCellDoubleClick sender args = (
        local rIdx = args.RowIndex
        local cIdx = args.ColumnIndex
        if rIdx < 0 then return ok
        local n = rowNodes[rIdx + 1]
        if not (isValidNode n) then return ok
        case cIdx of (
            (idxName): (
                select n
                max zoomext sel
            )
            (idxPath): (
                local picked = pickPlyFile()
                if picked != undefined and picked != "" do (
                    setUserProp n "gspipe_plySequencePath" picked
                    suppressEvents = true
                    sender.Rows.Item[rIdx].Cells.Item[idxPath].Value = picked
                    suppressEvents = false
                    refreshSingleRow rIdx
                )
            )
            default: ()
        )
    )

    -- ------- MaxScript control handlers -------

    on chkQuiet changed state do (
        if gspipe_plyUpdate != undefined do gspipe_plyUpdate.quiet = state
    )

    on btnRegister pressed do (
        if gspipe_plyCallback != undefined do gspipe_plyCallback.register()
        updateCallbackLabel()
    )

    on btnUnregister pressed do (
        if gspipe_plyCallback != undefined do gspipe_plyCallback.unregister()
        updateCallbackLabel()
    )

    on btnVerify pressed do updateCallbackLabel()

    on btnRefresh pressed do populateGrid()

    on btnInitSelected pressed do (
        local sel = selectedNodes()
        local uninits = for n in sel where not (gspipe_plySeqEditor.isInitialized n) collect n
        if uninits.count == 0 then (
            format "[gspipe] No uninitialized rows selected.\n"
            return ok
        )
        local picked = pickPlyFile()
        if picked == undefined or picked == "" then return ok
        for n in uninits do gspipe_plySeqEditor.initializeNode n picked
        populateGrid()
    )

    on btnSetPath pressed do (
        local sel = selectedNodes()
        if sel.count == 0 then (
            format "[gspipe] No rows selected.\n"
            return ok
        )
        local picked = pickPlyFile()
        if picked == undefined or picked == "" then return ok
        gspipe_plySeqEditor.applyPath sel picked
        populateGrid()
    )

    on btnSelectInScene pressed do (
        local sel = selectedNodes()
        if sel.count > 0 do (
            select sel
            max zoomext sel
        )
    )

    -- ------- dotNet grid event handlers -------

    on dgv CellValueChanged sender args do
        onCellValueChanged sender args

    on dgv CellDoubleClick sender args do
        onCellDoubleClick sender args

    -- ------- Lifecycle -------

    on gspipe_plySeqEditorRollout open do (
        if gspipe_plyUpdate == undefined then (
            lblFrameInfo.text = "ERROR: gspipe_plySequence.ms is not loaded."
        ) else (
            chkQuiet.checked = (gspipe_plyUpdate.quiet == true)
            dgv.AllowUserToAddRows = false
            dgv.AllowUserToDeleteRows = false
            dgv.RowHeadersVisible = false
            dgv.MultiSelect = true
            dgv.SelectionMode = (dotNetClass "System.Windows.Forms.DataGridViewSelectionMode").FullRowSelect
            dgv.AutoSizeRowsMode = (dotNetClass "System.Windows.Forms.DataGridViewAutoSizeRowsMode").AllCells
            buildColumns()
            populateGrid()

            if gspipe_plySeqEditorTimeCbRef != undefined do
                unregisterTimeCallback gspipe_plySeqEditorTimeCbRef
            gspipe_plySeqEditorTimeCbRef = refreshRows
            registerTimeCallback gspipe_plySeqEditorTimeCbRef

            updateCallbackLabel()
        )
    )

    on gspipe_plySeqEditorRollout close do (
        if gspipe_plySeqEditorTimeCbRef != undefined do (
            unregisterTimeCallback gspipe_plySeqEditorTimeCbRef
            gspipe_plySeqEditorTimeCbRef = undefined
        )
    )
)

fn gspipe_plySeqEditorShow = (
    -- Recreate the dialog each time so re-fileIn picks up edits.
    try (destroyDialog gspipe_plySeqEditorRollout) catch ()
    createDialog gspipe_plySeqEditorRollout 760 520
)
