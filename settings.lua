local prefix = "smart_trains"
data:extend({
    {
        type = "bool-setting",
        name = prefix .. "_set_autorefuel",
        setting_type = "runtime-global",
        default_value = false,
        order = "a"
    },
    -- {
    --     type = "bool-setting",
    --     name = prefix .. "enable_module",
    --     setting_type = "startup",
    --     default_value = true,
    --     order = "a"
    -- },
    -- {
    --     type = "bool-setting",
    --     name = prefix .. "free_wires",
    --     setting_type = "runtime-global",
    --     default_value = false,
    --     order = "a"
    -- }
})