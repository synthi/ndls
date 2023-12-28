local src = {}

do
    src.crow = {}

    for i = 1,2 do
        patcher.add_source('crow in '..i)
    end

    -- src: https://github.com/monome/norns/blob/e8ae36069937df037e1893101e73bbdba2d8a3db/lua/core/crow.lua#L14
    local function re_enable_clock_source_crow()
        if params.lookup["clock_source"] then
            if params:string("clock_source") == "crow" then
                norns.crow.clock_enable()
            end
        end
    end

    function src.crow.update()
        local mapped = { false, false }

        for _,dest in ipairs(patcher.destinations) do
            local source = patcher.get_assignment(dest)
            if source == 'crow in 1' then mapped[1] = true
            elseif source == 'crow in 2' then mapped[2] = true end
        end
        
        for i, map in ipairs(mapped) do if map then
            crow.input[i].mode('stream', 0.01)
            crow.input[i].stream = function(v)
                patcher.set_source('crow in '..i, v)
            end
        end end
        if not mapped[1] then re_enable_clock_source_crow() end
    end

    norns.crow.add = src.crow.update
end

do
    src.lfos = {}
    
    for i = 1,2 do
        patcher.add_source('lfo '..i)

        src.lfos[i] = lfos:add{
            min = -5,
            max = 5,
            depth = 0.1,
            mode = 'free',
            period = 0.25,
            baseline = 'center',
            action = function(scaled, raw) 
                patcher.set_source('lfo '..i, scaled) 
            end,
        }
    end

    src.lfos.reset_params = function()
        for i = 1,2 do
            params:set('lfo_mode_lfo_'..i, 2)
            -- params:set('lfo_max_lfo_'..i, 5)
            -- params:set('lfo_min_lfo_'..i, -5)
            params:set('lfo_baseline_lfo_'..i, 2)
            params:set('lfo_lfo_'..i, 2)
        end
    end
end

do
    patcher.add_source('midi')

    local middle_c = 60

    local m = midi.connect()
    m.event = function(data)
        local msg = midi.to_msg(data)

        if msg.type == "note_on" then
            local note = msg.note
            local volt = (note - middle_c)/12

            patcher.set_source('midi', volt)
        end
    end

    src.midi = m
end

return src
