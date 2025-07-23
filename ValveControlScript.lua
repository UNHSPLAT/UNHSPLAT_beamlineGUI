

-- This function runs repeatedly in the background
function valveSafety()
    local turbo1GV
    local turbo2GV
    local beamRoughV1
    local chamberBeamGV
    local beamRoughV2
    local chamberRoughv2
    local chamberRoughV1
    local cryo1GV

    beamRoughV1 = 1
    beamRoughV2 = 2
    turbo2GV = 3
    turbo1GV = 4
    cryo1GV = 5
    chamberBeamGV = 6
    chamberRoughv2 = 7
    chamberRoughV1 = 8

    function turbo1GV_safeOpen()
        --Checks that beamRoughV1 is on and beamRoughV2 is closed before opening turbo1GV
        local safe
        safe = true
        if outlet[turbo1GV].physical_state == on or outlet[turbo1GV].transient_state == on then 
            if outlet[beamRoughV1].physical_state == off then
            --outlet beamRoughV1 is off, not safe to proceed    
                LOG("outlet beamRoughV1 is off, enable rough pump to open valve")
                outlet[turbo1GV].off()
            elseif outlet[beamRoughV2].physical_state == on then
                LOG("beamRoughV2 must be closed to open turbo1GV")
                outlet[turbo1GV].off()
            end
        end
    end

    function turbo2GV_safeOpen()
        --Checks that beamRoughV1 is on and beamRoughV2 is closed before opening turbo2GV
        local safe
        safe = true
        if outlet[turbo2GV].physical_state == on or outlet[turbo2GV].transient_state == on then 
            if outlet[beamRoughV1].physical_state == off then
            --outlet beamRoughV1 is off, not safe to proceed    
                LOG("outlet beamRoughV1 is off, enable rough pump to open valve")
                outlet[turbo2GV].off()
            elseif outlet[beamRoughV2].physical_state == on then
                LOG("beamRoughV2 must be closed to open turbo2GV")
                outlet[turbo2GV].off()
            end
        end
    end

    function cryo1GV_safeOpen()
        --Checks that chamberRoughV2 is closed AND either chamberBeamGV or beamRoughV2 is closed
        if outlet[cryo1GV].physical_state == on or outlet[cryo1GV].transient_state == on then
            if outlet[chamberRoughv2].physical_state == on then
                LOG("chamberRoughV2 must be closed to open cryo1GV")
                outlet[cryo1GV].off()
            elseif outlet[chamberBeamGV].physical_state == on and outlet[beamRoughV2].physical_state == on then
                LOG("either chamberBeamGV or beamRoughV2 must be closed to open cryo1GV")
                outlet[cryo1GV].off()
            end
        end
    end

    function chamberRoughV2_safeOpen()
        --Checks that cryo1GV is closed, chamberRoughV2 is closed and chamberRoughV1 is open
        if outlet[chamberRoughv2].physical_state == on or outlet[chamberRoughv2].transient_state == on then
            if outlet[cryo1GV].physical_state == on then
                LOG("cryo1GV must be closed to open chamberRoughV2")
                outlet[chamberRoughv2].off()
            elseif outlet[beamRoughv2].physical_state == on then
                LOG("chamberRoughV2 must be closed to proceed")
                outlet[chamberRoughv2].off()
            elseif outlet[chamberRoughV1].physical_state == off then
                LOG("chamberRoughV1 must be open to open chamberRoughV2")
                outlet[chamberRoughv2].off()
            end
        end
    end

    function beamRoughV2_safeOpen()
        --Checks that turbo1GV, turbo2GV, chamberRoughV2, and chamberBeamGV are closed, and chamberRoughV1 is open
        if outlet[beamRoughV2].physical_state == on or outlet[beamRoughV2].transient_state == on then
            if outlet[turbo1GV].physical_state == on then
                LOG("turbo1GV must be closed to open beamRoughV2")
                outlet[beamRoughV2].off()
            elseif outlet[turbo2GV].physical_state == on then
                LOG("turbo2GV must be closed to open beamRoughV2")
                outlet[beamRoughV2].off()
            elseif outlet[chamberRoughv2].physical_state == on then
                LOG("chamberRoughV2 must be closed to open beamRoughV2")
                outlet[beamRoughV2].off()
            elseif outlet[chamberBeamGV].physical_state == on then
                LOG("chamberBeamGV must be closed to open beamRoughV2")
                outlet[beamRoughV2].off()
            elseif outlet[chamberRoughV1].physical_state == off then
                LOG("chamberRoughV1 must be open to open beamRoughV2")
                outlet[beamRoughV2].off()
            end
        end
    end

    function chamberBeamGV_safeOpen()
        --Checks if either one beam GV and chamber GV are open, or if all GVs are closed
        if outlet[chamberBeamGV].physical_state == on or outlet[chamberBeamGV].transient_state == on then
            local anyBeamGVOpen = outlet[turbo1GV].physical_state == on or outlet[turbo2GV].physical_state == on
            local chamberOpen = outlet[cryo1GV].physical_state == on
            local allGVsClosed = outlet[turbo1GV].physical_state == off and 
                                outlet[turbo2GV].physical_state == off and
                                outlet[cryo1GV].physical_state == off

            if not ((anyBeamGVOpen and chamberOpen) or allGVsClosed) then
                LOG("Either one beam GV and chamber GV must be open, or all GVs must be closed")
                outlet[chamberBeamGV].off()
            end
        end
    end
    
    while true do
        turbo1GV_safeOpen()
        turbo2GV_safeOpen()
        cryo1GV_safeOpen()
        chamberRoughV2_safeOpen()
        beamRoughV2_safeOpen()
        chamberBeamGV_safeOpen()
        delay(.1)
    end
end