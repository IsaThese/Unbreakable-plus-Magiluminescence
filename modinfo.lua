name = "Unbreakable+ Magiluminescence"
description = "Magiluminescence does not disappear at 0%, and can be turned on/off while equipped (like the Magician's Top Hat)."
author = "isaac"
version = "1.2.1.4"
forumthread = ""

api_version = 10

icon_atlas = "modicon.xml"
icon = "modicon.tex"

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false

-- Clients need this so Turn On/Off shows in the inventory action UI.
all_clients_require_mod = true
client_only_mod = false
server_only_mod = false

server_filter_tags = { "magiluminescence", "yellowamulet", "quality of life" }

configuration_options =
{
    {
        name = "UNBREAKABLE",
        label = "Unbreakable",
        hover = "If enabled, Magiluminescence stays at 0% instead of disappearing (like the original mod).",
        options =
        {
            { description = "Yes", data = true },
            { description = "No", data = false },
        },
        default = true,
    },
    {
        name = "DURABILITY_LOSS",
        label = "Durability Loss",
        hover = "If disabled, Magiluminescence never loses durability while used.",
        options =
        {
            { description = "Yes", data = true, hover = "Vanilla: drains while active." },
            { description = "No", data = false, hover = "Infinite durability while active." },
        },
        default = true,
    },
    {
        name = "TOGGLEABLE",
        label = "Toggleable",
        hover = "If enabled, Turn On/Off appears while equipped (click, right-click, or Ctrl).",
        options =
        {
            { description = "Yes", data = true },
            { description = "No", data = false },
        },
        default = true,
    },
}
