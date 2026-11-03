-- AI_Vietnamese config. Edit values, then restart the game.
return {
    enabled          = true,    -- translate to Vietnamese on launch
    toggle_key       = "HOME",  -- key that turns the Vietnamese overlay on/off in game (nil to disable)
    interval         = 200,     -- widget sweep period in milliseconds
    startup_delay    = 30.0,    -- seconds to stay idle after load (UE4SS finishes its own start-up ~16 s)
    hook_data_tables = true,    -- also translate item / weapon / monster text served by the game's data tables
    hook_rich_text   = true,    -- translate map / minimap labels in the same frame the game writes them (no English flicker)
    font_fix         = true,    -- draw Vietnamese text with the bundled Vietnamese serif font (no heavy fallback letters)
    font_file        = "font/CormorantGaramond-SemiBold.ttf",  -- relative to the AI_Vietnamese folder; must be a TTF/OTF with Vietnamese glyphs
    harvest          = false,   -- dev: log anything left untranslated to Scripts\vi_harvest.txt
}
