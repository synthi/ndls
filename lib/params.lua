-- add metaparams
do
    local mult = function(self, a, b, c)
        return a * (b + c)
    end
    --TODO: switch to decibels / exp
    mparams:add{
        id = 'vol',
        type = 'control', controlspec = cs.def{ default = 1, max = 2.5 },
        random_min_default = 0.5, random_max_default = 1.5,
        sum = mult,
        action = function(i, v)
            sc.lvlmx[i].vol = v; sc.lvlmx:update(i)
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    mparams:add{
        id = 'pan',
        type = 'control', 
        controlspec = cs.def{ 
            min = -1, max = 1, default = 0,
        },
        random_min_default = -1, random_max_default = 1,
        action = function(i, v)
            sc.panmx[i].pan = v; sc.panmx:update(i)
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    mparams:add{
        id = 'old',
        type = 'control', 
        controlspec = cs.def{ default = 0.8, max = 1 },
        cs_base = cs.def{ default = 0.8, max = 1 },
        cs_preset = cs.def{ default = 1, max = 1 },
        random_min_default = 0.5, random_max_default = 1,
        sum = mult,
        action = function(i, v)
            sc.oldmx[i].old = v; sc.oldmx:update(i)
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    mparams:add{
        id = 'cut', type = 'control', 
        controlspec = cs.def{ min = 0, max = 1, default = 1, quantum = 1/100/2, step = 0 },
        cs_preset = cs.def{ min = -1, max = 1, default = 0, quantum = 1/100/2/2, step = 0 },
        random_min_default = -0.5, random_max_default = 0,
        action = function(i, v)
            softcut.post_filter_fc(i, util.linexp(0, 1, 20, 20000, v))
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    mparams:add{
        id = 'q', type = 'control', 
        controlspec = cs.def{ min = 0, max = 1, default = 0.4 },
        cs_preset = cs.def{ min = -1, max = 1, default = 0 },
        random_min_default = -0.3, random_max_default = 0.3,
        action = function(i, v)
            softcut.post_filter_rq(i, util.linexp(0, 1, 0.01, 20, 1 - v))
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    local types = { 'lp', 'bp', 'hp', 'dry' }
    mparams:add{
        id = 'type', type = 'option', options = types, 
        action = function(i, v)
            for _,k in pairs(types) do softcut['post_filter_'..k](i, 0) end
            softcut['post_filter_'..types[v]](i, 1)
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    mparams:add{
        id = 'loop',
        type = 'binary', behavior = 'toggle', default = 1, default_preset = 0,
        action = function(n, v)
            sc.loopmx[n].loop = v; sc.loopmx:update(n)

            nest.grid.make_dirty()
            nest.screen.make_dirty()
        end
    }
    mparams:add{
        id = 'rate',
        type = 'number', 
        min = -7, max = 2, default = 0, 
        min_preset = -9, max_preset = 9, default_preset = 0,
        random_min_default = -1, random_max_default = 1,
        unsum = function(self, sum, b, c)
            return sum - b - c
        end,
        action = function(i, v)
            sc.ratemx[i].oct = v; sc.ratemx:update(i)
            nest.grid.make_dirty()
        end
    }
    mparams:add{
        id = 'rev',
        type = 'binary', behavior = 'toggle',
        action = function(i, v) 
            sc.ratemx[i].dir = v>0 and -1 or 1; sc.ratemx:update(i) 
            nest.grid.make_dirty()
        end
    }

    --TODO: build into rate mparam slew data
    mparams:add{
        id = 'rate_slew', type = 'control', 
        controlspec = cs.def{ min = 0, max = 2.5, default = 0 },
        action = function(i, v)
            sc.slew(i, v)
        end
    }

    --TODO: send/return as single metaparam (option type)
    --TODO: rec overdub flag
end

-- add metaparam options
do
    params:add_separator('metaparam options')

    do
        params:add_group('default view',  #mparams.list)

        view_options.options = { 'preset', 'base' }
        view_options.vals = { preset = 1, base = 2 }
        local prst, base = view_options.vals.preset, view_options.vals.base
        local defaults = { old = base, q = base }

        for _,m in ipairs(mparams.list) do
            local id = m.id
            params:add{
                name = id, id = id..'_view', type = 'option',
                options = view_options.options, default = defaults[id] or prst,
                allow_pmap = false,
            }
        end
    end

    do
        params:add_group('reset actions', 15 + voices*1)
    
        do
            params:add_separator('window')
            do
                local names = { 'random', 'default' }
                local funcs = { windowparams.resets.random, windowparams.resets.default }
                params:add{
                    id = 'window_reset_presets', name = 'presets', type = 'option',
                    options = names, default = 1, allow_pmap = false,
                    action = function(v)
                        wparams:set_reset('preset', funcs[v])
                    end
                }
            end
            --TODO: window base reset
        end

        local function add_reset_param(id, scope, names, funcs)
            scope = scope or 'preset'
            local sname = (scope == 'preset') and 'presets' or 'base'
            params:add{
                id = id..'_reset_'..sname, name = sname, type = 'option',
                options = names, default = 1, allow_pmap = false,
                action = function(v)
                    mparams:set_reset(id, scope, funcs[v])
                end
            }
        end

        do
            local id = 'old'
            params:add_separator(id)
            add_reset_param(
                id, 'preset', 
                { 'default', 'random' },
                { metaparams.resets.default, metaparams.resets.random }
            )

            local function default(self, param_id, t)
                local silent = true
                params:set(
                    param_id, params:get(id..'_reset_default_'..t), silent
                )
            end

            add_reset_param(
                id, 'base',
                { 'none', 'default' },
                { windowparams.resets.none, default }
            )
            for n = 1,voices do
                params:add{
                    id = id..'_reset_default_'..n, name = 'default track '..n, type = 'control',
                    controlspec = cs.def{ default = 0.8, max = 1 },
                }
            end
        end
        do
            local id = 'vol'
            params:add_separator(id)
            add_reset_param(
                id, 'preset', 
                { 'default', 'random' },
                { metaparams.resets.default, metaparams.resets.random }
            )
            
            local function low_all(self, param_id)
                local silent = true
                params:set(param_id, 0, silent)
            end
            local function low_other(self, param_id, t, b)
                local silent = true
                local v = (t==b) and 1 or 0
                params:set(param_id, v, silent)
            end

            add_reset_param(
                id, 'base',
                { 'none', 'default', 'low (all buffers)', 'low (other buffers)' },
                { windowparams.resets.none, windowparams.resets.default, low_all, low_other }
            )
        end
        params:add_separator('pan')
        params:add_separator('q')
        params:add_separator('cut')
        params:add_separator('type')
        params:add_separator('loop')
        params:add_separator('rate')
        params:add_separator('rev')
    end

    do
        params:add_group('randomization', 3 + mparams:random_range_params_count())

        params:add_separator('window')
        params:add{
            id = 'len min', name = 'min', type = 'control', 
            controlspec = cs.def{ min = 0, max = 1, default = 0.15 },
            allow_pmap = false,
        }
        params:add{
            id = 'len max', name = 'max', type = 'control', 
            controlspec = cs.def{ min = 0.5, max = 10, default = 0.75 },
            allow_pmap = false,
        }

        mparams:add_random_range_params()
    end

    --TODO: slew group

    do
        params:add_group('data', (
            wparams:base_params_count()
            + wparams:preset_params_count()
            + mparams:base_params_count()
            + mparams:preset_params_count()
        ))

        wparams:add_base_params()
        wparams:add_preset_params()
        mparams:add_base_params()
        mparams:add_preset_params()
    end
end

-- add softcut options
do
    params:add_separator('softcut options')

    --TODO: input routing per-voice 🧠
    local ir_op = { 'left', 'right' }
    params:add{
        type = 'option', id = 'input routing', options = ir_op,
        action = function(v)
            sc.inmx.route = ir_op[v]
            for i = 1,voices do sc.inmx:update(i) end
        end,
        allow_pmap = false,
    }

    params:add{
        id = 'alias',
        type = 'binary', behavior = 'toggle', default = 0,
        action = function(v)
            for i = 1, voices do
                sc.aliasmx[i].alias = v; sc.aliasmx:update(i)
            end
        end,
        allow_pmap = false,
    }

    params:add{
        type = 'control', id = 'rec transition',
        controlspec = cs.def{ default = 1, min = 0, max = 5 },
        allow_pmap = false,
        action = function(v)
            for i = 1, voices do
                softcut.recpre_slew_time(i, v)
            end
        end
    }

    --TODO: rate glide enable/disable
end

-- add mappable params
for i = 1, voices do 
    params:add_separator('mappables, track '..i)

    --TODO: group each track ?
    params:add{
        name = 'rec', id = 'rec '..i,
        type = 'binary', behavior = 'toggle', 
        action = function(v)
            local n = i

            sc.oldmx[n].rec = v; sc.oldmx:update(n)

            local z = sc.buffer[n]
            if not sc.punch_in[z].recorded then
                sc.punch_in:set(z, v)

                --TODO: refactor reset call into sc.punch_in
                if v==0 and sc.punch_in[z].recorded then 
                    preset:reset(n)
                end
            end

            nest.grid.make_dirty()
            nest.screen.make_dirty()
        end
    }
    params:add{
        name = 'clear', id = 'clear '..i,
        type = 'binary', behavior = 'trigger', 
        action = function()
            local n = i
            local b = sc.buffer[n]

            params:set('rec '..i, 0) 
            sc.punch_in:clear(b)

            for ii = 1, voices do
                mparams:reset(ii, b, 'base')
                --wparams:reset(ii, b, 'base')
            end
            mparams:bang(n)
            --wparams:bang(n)

            nest.grid.make_dirty()
            nest.screen.make_dirty()
        end
    }

    -- TODO: wparam & mparam mappables

    params:add{
        name = 'bend', id = 'bnd '..i,
        type = 'control', controlspec = cs.def{ min = -1, max = 1, default = 0 },
        action = function(v) 
            sc.ratemx[i].bnd = v; sc.ratemx:update(i) 
            nest.screen.make_dirty(); nest.arc.make_dirty()
        end
    }
    params:add{
        name = 'buffer', id = 'buffer '..i,
        type = 'number', min = 1, max = buffers, default = i,
        action = function(v)
            sc.buffer[i] = v; sc.buffer:update(i)

            nest.arc.make_dirty()
            nest.screen.make_dirty()
            nest.grid.make_dirty()
        end
    }
    for b = 1,buffers do
        params:add{
            name = 'buffer '..b..' preset', id = 'preset '..i..' buffer '..b,
            type = 'number', min = 1, max = presets, default = 1,
            action = function(v)
                preset[i][b] = v; preset:update(i, b)

                nest.arc.make_dirty()
                nest.screen.make_dirty()
                nest.grid.make_dirty()
            end
        }
    end
    params:add{
        name = 'send', id = 'send '..i,
        type = 'binary', behavior = 'toggle', default = 1,
        action = function(v) 
            sc.sendmx[i].send = v; sc.sendmx:update() 

            if v > 0 and params:get('return '..i) > 0 then
                sc.sendmx[i].ret = 0; sc.sendmx:update() 
                params:set('return '..i, 0, true)
            end
            nest.grid.make_dirty()
        end
    }
    params:add{
        name = 'return', id = 'return '..i,
        type = 'binary', behavior = 'toggle',
        action = function(v) 
            sc.sendmx[i].ret = v; sc.sendmx:update()

            if v > 0 and params:get('send '..i) > 0 then
                sc.sendmx[i].send = 0; sc.sendmx:update() 
                params:set('send '..i, 0, true)
            end
            nest.grid.make_dirty()
        end
    }
end
